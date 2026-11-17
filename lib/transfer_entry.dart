import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'entry_settings.dart';
import 'entry_widgets.dart';
import 'transfer_data.dart';
import 'transfer_screen.dart';
import 'phone_input.dart';
import 'recipient_directory.dart';
import 'recipient_directory_screen.dart';
import 'qr_scanner_screen.dart';

/// New entry flow; MainApp's existing confirmation-only contract stays available.
class TransferEntryApp extends StatelessWidget {
  const TransferEntryApp({super.key, this.preferences});
  final SharedPreferences? preferences;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Переводы',
    theme: ThemeData(fontFamily: 'RobotoEntry', scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2100E8)),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: Color(0xFF252525), fontWeight: FontWeight.w400))),
    home: TransferEntryScreen(preferences: preferences),
  );
}

class TransferEntryScreen extends StatefulWidget {
  const TransferEntryScreen({super.key, this.preferences});
  final SharedPreferences? preferences;
  @override
  State<TransferEntryScreen> createState() => _TransferEntryScreenState();
}

class _TransferEntryScreenState extends State<TransferEntryScreen> {
  int _tab = 0;
  bool _opening = false;
  late String _recipient = widget.preferences?.getString('demo_recipient') ?? 'Габиден Ж.';
  late final _recipientName = TextEditingController(text: _recipient);
  late String _sender = widget.preferences?.getString('demo_sender') ?? '';
  late int _balance = widget.preferences?.getInt('demo_entry_balance') ?? 327750;
  late final _card = TextEditingController(text: formatDemoCard(
    widget.preferences?.getString('demo_entry_card') == '0000000000000000' ? '' :
    widget.preferences?.getString('demo_entry_card') ?? ''));
  late final _phone = TextEditingController(text: formatDemoPhone(
    widget.preferences?.getString('demo_entry_phone') == '+7 000 000 00 00' ? '' :
    widget.preferences?.getString('demo_entry_phone') ?? ''));
  late final _directory = RecipientDirectory(widget.preferences);
  late final _amount = TextEditingController(text:
    widget.preferences?.getString('demo_entry_amount') ?? '');
  late final _message = TextEditingController(text:
    widget.preferences?.getString('demo_entry_message') ?? '');

  DemoRecipient? get _matchedRecipient => _tab == 0
    ? _directory.byPhone(_phone.text) : _directory.byCard(_card.text);
  bool get _showRecipientBanner => _tab == 0
    ? phoneDirectoryKey(_phone.text) != null : _matchedRecipient != null;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_recipientChanged);
    _card.addListener(_recipientChanged);
    if (phoneDirectoryKey(_phone.text) != null) {
      _recipient = _directory.byPhone(_phone.text)?.name ?? '';
      _recipientName.text = _recipient;
    }
  }

  void _recipientChanged() {
    if (!mounted) return;
    if (_tab == 0) {
      final name = _directory.byPhone(_phone.text)?.name ?? '';
      if (_recipientName.text != name) _recipientName.text = name;
      _recipient = name;
    }
    setState(() {});
  }

  Future<void> _manageDirectory() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) =>
      RecipientDirectoryScreen(directory: _directory)));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phone.removeListener(_recipientChanged); _card.removeListener(_recipientChanged);
    _card.dispose(); _phone.dispose(); _recipientName.dispose(); _amount.dispose(); _message.dispose(); super.dispose();
  }

  String get _balanceText {
    final whole = (_balance ~/ 100).toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]} ');
    return '$whole,${(_balance % 100).toString().padLeft(2, '0')} ₸';
  }

  String get _amountText => TransferData(minorUnits: TransferData.parseAmount(_amount.text) ?? 0,
    recipientName: _recipient).amountText;

  void _notice(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100)));
  }

  Future<void> _settings() async {
    final result = await showDialog<EntrySettingsData>(context: context,
      builder: (_) => EntrySettings(data: EntrySettingsData(recipientName: _recipient,
        senderName: _sender, balanceMinorUnits: _balance), onOpenDirectory: _manageDirectory));
    if (result == null || !mounted) return;
    setState(() {
      _recipient = result.recipientName;
      _recipientName.text = result.recipientName;
      _sender = result.senderName;
      _balance = result.balanceMinorUnits;
    });
    await _persistEntry();
  }

  Future<void> _persistEntry() async {
    final preferences = widget.preferences;
    if (preferences == null) return;
    try {
      await preferences.setString('demo_recipient', _recipient);
      await preferences.setString('demo_sender', _sender);
      await preferences.setInt('demo_entry_balance', _balance);
      await preferences.setString('demo_entry_card', _card.text.replaceAll(RegExp(r'\D'), ''));
      await preferences.setString('demo_entry_phone', _phone.text);
      await preferences.setString('demo_entry_amount', _amount.text);
      await preferences.setString('demo_entry_message', _message.text);
    } catch (_) {
      if (mounted) _notice('Не удалось сохранить данные на устройстве.');
    }
  }

  Future<void> _saveResult(TransferData data, bool favorite) async {
    if (!mounted) return;
    setState(() {
      _recipient = data.recipientName;
      _recipientName.text = data.recipientName;
      _sender = data.senderName;
      _amount.text = data.editableAmount;
    });
    await _persistEntry();
    await widget.preferences?.setInt('demo_amount', data.minorUnits);
    await widget.preferences?.setBool('demo_favorite', favorite);
  }

  Future<void> _submit() async {
    if (_opening) return;
    final amount = TransferData.parseAmount(_amount.text);
    if (amount == null) { _notice('Введите сумму больше 0 ₸.'); return; }
    if (amount > _balance) { _notice('Сумма больше баланса. Измените баланс в настройках карты.'); return; }
    final phone = phoneDirectoryKey(_phone.text);
    final digits = _card.text.replaceAll(RegExp(r'\D'), '');
    if ((_tab == 0 && phone == null) || (_tab != 0 && digits.length != 16)) {
      _notice(_tab == 0 ? 'Введите 11 цифр тестового телефона.' : 'Введите 16 цифр тестовой карты.'); return;
    }
    final matched = _matchedRecipient;
    if (_tab != 0 && matched == null) {
      _notice('Получатель не найден. Добавьте номер и имя в базу получателей.'); return;
    }
    final recipientName = _tab == 0 ? _recipientName.text.trim() : matched!.name;
    if (recipientName.isEmpty) {
      _notice('Введите имя получателя в жёлтом поле.'); return;
    }
    _recipient = recipientName;
    FocusScope.of(context).unfocus();
    setState(() {
      _opening = true;
      _balance -= amount;
    });
    await _persistEntry();
    if (!mounted) return;
    try {
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => TransferScreen(
        initialData: TransferData(minorUnits: amount, recipientName: recipientName, senderName: _sender,
          recipientPhotoPath: matched?.photoPath ?? '',
          recipientPhone: _tab == 0 ? phone! : matched!.phone),
        initialFavorite: widget.preferences?.getBool('demo_favorite') ?? false,
        onSave: _saveResult, onReturnToTransfers: () => Navigator.pop(context),
      )));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _scan() async {
    final controller = TextEditingController(text: _card.text);
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Тестовая карта'),
      content: TextField(controller: controller, keyboardType: TextInputType.number,
        inputFormatters: [DemoCardFormatter()], decoration: const InputDecoration(labelText: '16 цифр карты')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Применить'))],
    ));
    // The dialog's reverse transition still uses its controller after pop.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value != null && mounted) setState(() => _card.text = value);
  }

  Future<void> _selectTab(int index) async {
    if (index != 2) { setState(() => _tab = index); return; }
    FocusScope.of(context).unfocus();
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const QrScannerScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Column(children: [
    SizedBox(height: 48, child: Stack(alignment: Alignment.center, children: [
      const Center(child: Text('Клиенту Kaspi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
      Positioned(left: 5, child: IconButton(tooltip: 'Назад', onPressed: () async {
        if (!await Navigator.maybePop(context)) await SystemNavigator.pop();
      }, icon: const EntryIcon('back', width: 25))),
      Positioned(right: 13, child: InkWell(onTap: _settings,
        child: const Padding(padding: EdgeInsets.symmetric(vertical: 10),
          child: Icon(Icons.tune, size: 30, color: Colors.white)))),
    ])),
    Expanded(child: SingleChildScrollView(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 16), child: InkWell(
        key: const Key('entry_source_card'), onTap: _settings, borderRadius: BorderRadius.circular(13),
        child: Container(height: 68, padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Row(children: [
            const EntryIcon('gold_card', width: 40, height: 32, color: null),
            const SizedBox(width: 20),
            const Expanded(child: Text('Kaspi Gold', style: TextStyle(fontSize: 16))),
            Text(_balanceText, key: const Key('entry_balance'), style: const TextStyle(fontSize: 15, color: Color(0xFF555555))),
          ])))),
      SizedBox(height: 20, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFF3F3F3))),
        Positioned(top: -4, child: InkWell(onTap: _settings, child: Container(width: 28, height: 28,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          alignment: Alignment.center, child: const EntryIcon('down', width: 23)))),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Column(children: [
        Container(height: 40, padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(16)),
          child: Row(children: List.generate(3, (index) => Expanded(child: InkWell(
            key: Key('entry_tab_$index'), onTap: () => _selectTab(index),
            child: Container(alignment: Alignment.center,
              decoration: BoxDecoration(color: _tab == index ? const Color(0xFFFAFAFA) : Colors.transparent,
                borderRadius: BorderRadius.circular(14)),
              child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (index == 2) ...[const EntryIcon('kaspi_qr', width: 17, color: Color(0xFF303030)), const SizedBox(width: 5)],
                Text(['Телефон', 'Карта', 'Kaspi QR'][index], style: const TextStyle(fontSize: 13)),
              ]))),
          ))))),
        const SizedBox(height: 24),
        ClipRRect(borderRadius: BorderRadius.circular(14), child: Column(children: [
          Container(height: 74, color: const Color(0xFFF0F0F0), padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              if (_tab != 0) ...[
                const EntryIcon('gold_card', width: 40, height: 32, color: null),
                const SizedBox(width: 20),
              ],
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_tab == 0 ? 'Телефон получателя' : _tab == 2 ? 'Kaspi QR получателя' : 'Kaspi Gold получателя',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF858585))),
                const SizedBox(height: 4),
                if (_tab == 0) TextField(key: const Key('entry_phone'), controller: _phone,
                  keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                  inputFormatters: [DemoPhoneFormatter()],
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none))
                else TextField(key: const Key('entry_card'), controller: _card,
                  keyboardType: TextInputType.number, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                  inputFormatters: [DemoCardFormatter()],
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none)),
              ])),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _tab == 0 ? 'Выбрать получателя' : 'Ввести тестовую карту',
                onPressed: _tab == 0 ? _manageDirectory : _scan,
                constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                padding: EdgeInsets.zero,
                icon: _tab == 0
                    ? const EntryIcon('contact', width: 25, color: null)
                    : const EntryIcon('scan_card', width: 26, color: Color(0xFFC15D58)),
              ),
            ])),
          if (_showRecipientBanner) Container(key: const Key('entry_recipient_banner'),
            height: 66, color: const Color(0xFFC2B858),
            padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_tab == 0)
                    TextField(
                      key: const Key('entry_recipient_name'),
                      controller: _recipientName,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      cursorColor: Colors.white,
                      onChanged: (value) => _recipient = value.trim(),
                      decoration: const InputDecoration(
                        hintText: 'Имя получателя',
                        hintStyle: TextStyle(color: Color(0xDDFFFFFF)),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                    )
                  else
                    Text(_matchedRecipient!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Деньги поступят на карту Kaspi Gold', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.white)),
                ])),
              ])),
        ])),
        const SizedBox(height: 24),
        Container(height: 68, padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(13)),
          child: LayoutBuilder(builder: (context, constraints) {
            final painter = TextPainter(text: TextSpan(text: _amount.text.isEmpty ? '0' : _amount.text,
              style: const TextStyle(fontFamily: 'RobotoEntry', fontSize: 21, fontWeight: FontWeight.w400)),
              textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context))..layout();
            return Row(children: [
              SizedBox(width: math.min(painter.width + 10, constraints.maxWidth - 35), child: TextField(
                key: const Key('entry_amount'), controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w400),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')), LengthLimitingTextInputFormatter(15)],
                onChanged: (_) => setState(() {}), decoration: const InputDecoration(
                  hintText: '0', hintStyle: TextStyle(color: Color(0xFF252525)), isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero))),
              const Text('₸', style: TextStyle(fontSize: 21)),
            ]);
          })),
        const SizedBox(height: 24),
        SizedBox(height: 88, child: TextField(key: const Key('entry_message'), controller: _message,
          expands: true, maxLines: null, maxLength: 50, textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontSize: 15), onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: 'Сообщение получателю',
            hintStyle: const TextStyle(color: Color(0xFF929292)), counterText: '', filled: true,
            fillColor: const Color(0xFFF0F0F0), contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none)))),
        Padding(padding: const EdgeInsets.only(top: 5, right: 18), child: Align(alignment: Alignment.centerRight,
          child: Text('${_message.text.characters.length}/50', key: const Key('entry_message_counter'),
            style: const TextStyle(fontSize: 10, color: Color(0xFF999999))))),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8,
          children: ['Спасибо!', 'За обед', 'Возвращаю :)'].map((message) => InkWell(
            key: Key('entry_suggestion_$message'), borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _message.text = message),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFECEBF6), borderRadius: BorderRadius.circular(18)),
              child: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFF4540AB)))),
          )).toList())),
        const SizedBox(height: 20),
      ])),
    ]))),
    Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), child: SizedBox(width: double.infinity, height: 54,
      child: FilledButton(key: const Key('entry_submit'), onPressed: _opening ? null : _submit,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF342BEA), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text('Перевести $_amountText', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500))))),
  ])));
}
