import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'transfer_data.dart';
import 'transfer_editor.dart';
import 'receipt_screen.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    required this.initialData,
    this.initialFavorite = false,
    this.onSave,
    this.onReturnToTransfers,
  });
  final TransferData initialData;
  final bool initialFavorite;
  final Future<void> Function(TransferData, bool)? onSave;
  final VoidCallback? onReturnToTransfers;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late TransferData _data = widget.initialData;
  late bool _favorite = widget.initialFavorite;
  List<_Recommendation> _recommendations = const [];
  bool _loadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final random = Random();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(
        'https://dummyjson.com/products?limit=10&skip=${random.nextInt(170)}',
      ));
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Product catalog returned ${response.statusCode}');
      }
      final payload = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final rate = await _loadKztRate(client);
      final products = (payload['products'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((product) => (product['thumbnail'] as String?)?.isNotEmpty == true)
          .map((product) => _Recommendation.fromJson(product, rate))
          .toList()
        ..shuffle(random);
      if (products.length < 2) throw const FormatException('Not enough products');
      if (!mounted) return;
      setState(() {
        _recommendations = products;
        _loadingRecommendations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRecommendations = false);
    } finally {
      client.close(force: true);
    }
  }

  Future<double> _loadKztRate(HttpClient client) async {
    try {
      final request = await client.getUrl(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) return 500;
      final payload = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final rates = payload['rates'] as Map<String, dynamic>;
      return (rates['KZT'] as num).toDouble();
    } catch (_) {
      return 500;
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<TransferData>(
      context,
      MaterialPageRoute(builder: (_) => TransferEditor(data: _data)),
    );
    if (result == null || !mounted) return;
    setState(() => _data = result);
    await _save();
  }

  Future<void> _save() async {
    try {
      await widget.onSave?.call(_data, _favorite);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось сохранить данные на устройстве. Изменения доступны в текущем сеансе.',
          ),
        ),
      );
    }
  }

  void _receipt() => Navigator.push<void>(context, MaterialPageRoute(
    builder: (_) => ReceiptScreen(data: _data, initialFavorite: _favorite,
      onDataChanged: (data) {
        if (!mounted) return;
        setState(() => _data = data);
        _save();
      },
      onFavoriteChanged: (favorite) {
        if (!mounted) return;
        setState(() => _favorite = favorite);
        _save();
      },
    ),
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Center(
              child: GestureDetector(
                key: const Key('edit_data'),
                behavior: HitTestBehavior.opaque,
                onTap: _edit,
                child: const Text(
                  'Переводы',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 54),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFF63C51D),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const AssetIcon(
                            'check',
                            color: Colors.white,
                            size: 43,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Ваш перевод совершен',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _data.amountText,
                            key: const Key('display_amount'),
                            style: const TextStyle(
                              fontSize: 39,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: const Color(0xFFF3F3F3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          ActionRow(
                            icon: 'receipt',
                            title: 'Показать квитанцию',
                            subtitle: 'Квитанция сохранена в Истории',
                            onTap: _receipt,
                            trailing: const AssetIcon(
                              'chevron',
                              color: Color(0xFF999999),
                              size: 28,
                            ),
                          ),
                          ActionRow(
                            icon: 'star',
                            title: _data.recipientName,
                            subtitle: 'Сохранить в Частые',
                            onTap: () {
                              setState(() => _favorite = !_favorite);
                              _save();
                            },
                            trailing: Transform.scale(
                              scale: 0.87,
                              alignment: Alignment.centerRight,
                              child: CupertinoSwitch(
                                key: const Key('favorite_toggle'),
                                value: _favorite,
                                activeTrackColor: const Color(0xFF63C51D),
                                inactiveTrackColor: const Color(0xFFE0E0E0),
                                onChanged: (value) {
                                  setState(() => _favorite = value);
                                  _save();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Вас могут заинтересовать',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 17),
                        if (_loadingRecommendations)
                          const SizedBox(
                            height: 168,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_recommendations.isEmpty)
                          const SizedBox(
                            height: 90,
                            child: Center(
                              child: Text('Не удалось загрузить товары. Проверьте интернет.'),
                            ),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: ProductCard(recommendation: _recommendations[0])),
                              const SizedBox(width: 7),
                              Expanded(child: ProductCard(recommendation: _recommendations[1])),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                key: const Key('return_transfers'),
                onPressed: widget.onReturnToTransfers ?? _edit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3515F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Вернуться в Переводы',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class AssetIcon extends StatelessWidget {
  const AssetIcon(
    this.name, {
    super.key,
    required this.color,
    required this.size,
  });
  final String name;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });
  final String icon, title, subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(23, 17, 18, 17),
      child: Row(
        children: [
          AssetIcon(icon, color: const Color(0xFFE0443E), size: 27),
          const SizedBox(width: 25),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.recommendation});
  final _Recommendation recommendation;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${recommendation.label}, ${recommendation.price}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  recommendation.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF6EEEE),
                    alignment: Alignment.center,
                    child: Text(
                      recommendation.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF777777)),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 3, 6, 3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7CC23C),
                      borderRadius: BorderRadius.only(topRight: Radius.circular(6)),
                    ),
                    child: Text(
                      recommendation.bonus,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 7, top: 11),
          child: Text(
            recommendation.price,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Recommendation {
  const _Recommendation({required this.imageUrl, required this.label, required this.price, required this.bonus});
  factory _Recommendation.fromJson(Map<String, dynamic> json, double rate) {
    final tenge = ((json['price'] as num) * rate).round();
    final formattedPrice = tenge.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]} ',
    );
    final bonus = (tenge * 0.03).round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]} ',
    );
    return _Recommendation(
        imageUrl: (json['thumbnail'] as String).replaceFirst('http://', 'https://'),
        label: json['title'] as String? ?? 'Товар',
        price: '$formattedPrice ₸',
        bonus: '$bonus Б',
      );
  }
  final String imageUrl, label, price;
  final String bonus;
}


