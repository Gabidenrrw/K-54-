import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'demo_receipt.dart';
import 'transfer_data.dart';
import 'transfer_editor.dart';
import 'recipient_photo.dart';
import 'phone_input.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.data, this.initialFavorite = false,
    this.onDataChanged, this.onFavoriteChanged});
  final TransferData data;
  final bool initialFavorite;
  final ValueChanged<TransferData>? onDataChanged;
  final ValueChanged<bool>? onFavoriteChanged;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late TransferData _data = widget.data;
  late DemoReceipt _receipt = DemoReceipt.create(_data);
  late bool _favorite = widget.initialFavorite;
  static const _shareChannel = MethodChannel('dev.preview.transfer_demo/share');

  Future<void> _edit() async {
    final data = await Navigator.push<TransferData>(context,
      MaterialPageRoute(builder: (_) => TransferEditor(data: _data)));
    if (data == null || !mounted) return;
    setState(() { _data = data; _receipt = DemoReceipt.create(data); });
    widget.onDataChanged?.call(data);
  }

  Future<void> _share() async {
    try {
      await _shareChannel.invokeMethod<void>('shareText', {'text': _receipt.displayShareText});
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть меню отправки.')));
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: _receipt.displayShareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Данные квитанции скопированы.')));
    }
  }

  void _cancel() => showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: const Text('Запросить отмену'),
    content: const Text(''),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: Column(children: [
      Container(height: 60, color: Colors.white, alignment: Alignment.bottomRight,
        padding: const EdgeInsets.only(right: 10),
        child: IconButton(key: const Key('close_receipt'), tooltip: 'Закрыть',
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          onPressed: () => Navigator.pop(context), icon: const _ReceiptIcon('close', size: 24))),
      Expanded(child: ColoredBox(color: const Color(0xFFEFEFF1),
        child: LayoutBuilder(builder: (context, constraints) {
        final width = math.min(constraints.maxWidth * 0.72, 420.0);
        return SingleChildScrollView(child: Center(child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 26),
          child: SizedBox(width: width, child: ClipPath(clipper: const _ReceiptEdge(),
            child: ColoredBox(color: Colors.white, child: _ReceiptCard(
              receipt: _receipt, onEditSender: _edit)),
          )),
        )));
      }))),
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(8, 15, 8, 19),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ReceiptAction(icon: 'share', label: 'Поделиться', onTap: _share),
          _ReceiptAction(icon: 'repeat', label: 'Повторить\nперевод', onTap: _edit),
          _ReceiptAction(icon: 'cancel', label: 'Запросить\nотмену', onTap: _cancel),
          _ReceiptAction(icon: 'star', label: 'Сохранить\nв Частые', selected: _favorite,
            onTap: () {
              setState(() => _favorite = !_favorite);
              widget.onFavoriteChanged?.call(_favorite);
            }),
        ])),
    ])),
  );
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt, required this.onEditSender});
  final DemoReceipt receipt;
  final VoidCallback onEditSender;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 39, 18, 25), child: Row(children: [
      SvgPicture.asset('assets/icons/brand.svg', width: 44, height: 44),
    ])),
    Container(color: const Color(0xFFD1E6C7), padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Перевод успешно совершен',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF38824C))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(receipt.data.amountText,
            style: const TextStyle(fontSize: 38, height: 1.12, fontWeight: FontWeight.w600, color: Color(0xFF25813D)))),
      ])),
    Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 13), child: Row(children: [
      RecipientPhoto(path: receipt.data.recipientPhotoPath), const SizedBox(width: 16),
      Expanded(child: Semantics(label: 'Получатель: ${receipt.data.recipientName}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(receipt.data.recipientName, style: const TextStyle(fontSize: 15, color: Color(0xFF3D3D3D))),
          Text(receipt.data.recipientPhone.isEmpty ? 'Kaspi.Gold' : formatDemoPhone(receipt.data.recipientPhone),
            style: const TextStyle(fontSize: 15, color: Color(0xFF3D3D3D))),
        ]))),
    ])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Column(children: [
      const _ReceiptRow(label: 'Тип перевода', value: 'Перевод\nклиенту Kaspi', verticalPadding: 10),
      _ReceiptRow(label: '№ квитанции', value: receipt.displayNumber, valueSize: 11.5,
        valueKey: const Key('receipt_number')),
      _ReceiptRow(label: 'Дата и время\nпо Астане', value: receipt.dateText, verticalPadding: 9),
      const _ReceiptRow(label: 'Комиссия', value: '0 ₸'),
      InkWell(key: const Key('receipt_sender'), onTap: onEditSender,
        child: _ReceiptRow(label: 'Отправитель', value: receipt.data.senderName.isEmpty ? 'Не указан' : receipt.data.senderName)),
      const _ReceiptRow(label: 'Откуда', value: 'Kaspi Gold', last: true),
    ])),
    const SizedBox(height: 60),
  ]);
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.verticalPadding = 7,
    this.valueSize = 13, this.last = false, this.valueKey});
  final String label, value;
  final double verticalPadding, valueSize;
  final bool last;
  final Key? valueKey;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE8E8E8), width: 0.7))),
    padding: EdgeInsets.symmetric(vertical: verticalPadding),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 13, height: 1.25, color: Color(0xFF808080)))),
      const SizedBox(width: 8),
      Expanded(flex: 6, child: Text(value, key: valueKey, textAlign: TextAlign.right,
        style: TextStyle(fontSize: valueSize, height: 1.25, color: const Color(0xFF454545)))),
    ]),
  );
}

class _ReceiptIcon extends StatelessWidget {
  const _ReceiptIcon(this.name, {this.size = 28, this.selected = false});
  final String name;
  final double size;
  final bool selected;
  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/icons/$name.svg', width: size, height: size,
    colorFilter: ColorFilter.mode(selected ? const Color(0xFFE0443E) : const Color(0xFF686E6E), BlendMode.srcIn));
}

class _ReceiptAction extends StatelessWidget {
  const _ReceiptAction({required this.icon, required this.label, required this.onTap, this.selected = false});
  final String icon, label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(
    key: Key('receipt_action_$icon'), onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Column(children: [
      _ReceiptIcon(icon, selected: selected),
      const SizedBox(height: 17),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, height: 1.3, color: Color(0xFF747474))),
    ])),
  ));
}

/// Scalloped paper edge, drawn in vectors rather than a stretched screenshot.
class _ReceiptEdge extends CustomClipper<Path> {
  const _ReceiptEdge();
  @override
  Path getClip(Size size) {
    const radius = 3.0;
    final count = (size.width / 13).round();
    final step = size.width / count;
    final path = Path()..moveTo(0, radius);
    for (int index = 0; index < count; index++) {
      final x = index * step;
      path.quadraticBezierTo(x + step / 4, -radius, x + step / 2, radius);
      path.quadraticBezierTo(x + 3 * step / 4, 3 * radius, x + step, radius);
    }
    path.lineTo(size.width, size.height - radius);
    for (int index = count; index > 0; index--) {
      final x = index * step;
      path.quadraticBezierTo(x - step / 4, size.height + radius, x - step / 2, size.height - radius);
      path.quadraticBezierTo(x - 3 * step / 4, size.height - 3 * radius, x - step, size.height - radius);
    }
    return path..close();
  }
  @override
  bool shouldReclip(_ReceiptEdge oldClipper) => false;
}

