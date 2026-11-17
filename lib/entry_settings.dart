import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'transfer_data.dart';

class EntrySettingsData {
  const EntrySettingsData({required this.recipientName, required this.senderName,
    required this.balanceMinorUnits});
  final String recipientName, senderName;
  final int balanceMinorUnits;
}

class EntrySettings extends StatefulWidget {
  const EntrySettings({super.key, required this.data, this.onOpenDirectory});
  final EntrySettingsData data;
  final VoidCallback? onOpenDirectory;
  @override
  State<EntrySettings> createState() => _EntrySettingsState();
}

class _EntrySettingsState extends State<EntrySettings> {
  final _form = GlobalKey<FormState>();
  late final _recipient = TextEditingController(text: widget.data.recipientName);
  late final _sender = TextEditingController(text: widget.data.senderName);
  late final _balance = TextEditingController(text: TransferData(
    minorUnits: widget.data.balanceMinorUnits, recipientName: '').editableAmount);

  int? _parseBalance(String value) => RegExp(r'^0([.,]0{1,2})?$').hasMatch(value.trim())
    ? 0 : TransferData.parseAmount(value);

  @override
  void dispose() {
    _recipient.dispose(); _sender.dispose(); _balance.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Настройки'),
    content: SizedBox(width: 340, child: SingleChildScrollView(child: Form(key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.onOpenDirectory == null) TextFormField(key: const Key('entry_recipient_setting'), controller: _recipient,
          maxLength: 50, decoration: const InputDecoration(labelText: 'Получатель'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Введите имя получателя' : null),
        if (widget.onOpenDirectory != null) const Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('Имя получателя определяется по номеру из базы.')),
        TextFormField(key: const Key('entry_sender_setting'), controller: _sender,
          maxLength: 50, decoration: const InputDecoration(labelText: 'Отправитель')),
        TextFormField(key: const Key('entry_balance_setting'), controller: _balance,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
          decoration: const InputDecoration(labelText: 'Баланс', suffixText: '₸'),
          validator: (value) => _parseBalance(value ?? '') == null ? 'Введите корректную сумму' : null),
        if (widget.onOpenDirectory != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(key: const Key('open_recipient_directory'),
            onPressed: widget.onOpenDirectory, icon: const Icon(Icons.person_add_outlined),
            label: const Text('База получателей'))),
      ])))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
      TextButton(key: const Key('save_entry_settings'), onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, EntrySettingsData(recipientName: _recipient.text.trim(),
          senderName: _sender.text.trim(), balanceMinorUnits: _parseBalance(_balance.text)!));
      }, child: const Text('Сохранить')),
    ],
  );
}
