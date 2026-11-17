import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'transfer_data.dart';

class TransferEditor extends StatefulWidget {
  const TransferEditor({super.key, required this.data});
  final TransferData data;

  @override
  State<TransferEditor> createState() => _TransferEditorState();
}

class _TransferEditorState extends State<TransferEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.data.recipientName);
  late final _amount = TextEditingController(text: widget.data.editableAmount);
  late final _sender = TextEditingController(text: widget.data.senderName);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _sender.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Переводы'),
      backgroundColor: Colors.white,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Данные перевода',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Деньги не переводятся. Платёж не выполняется.',
                style: TextStyle(fontSize: 15, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 32),
              TextFormField(
                key: const Key('recipient_input'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Имя получателя',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите имя получателя'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('amount_input'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9., \u00a0\u202f]'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  suffixText: '₸',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    TransferData.parseAmount(value ?? '') == null
                    ? 'Введите сумму от 0,01 до 999 999 999 ₸'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('sender_input'), controller: _sender,
                textCapitalization: TextCapitalization.words, maxLength: 50,
                decoration: const InputDecoration(labelText: 'Отправитель',
                  hintText: 'Введите имя для квитанции', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('apply_data'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2100E8),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    TransferData(
                      minorUnits: TransferData.parseAmount(_amount.text)!,
                      recipientName: _name.text.trim(),
                      senderName: _sender.text.trim(),
                      recipientPhotoPath: widget.data.recipientPhotoPath,
                      recipientPhone: widget.data.recipientPhone,
                    ),
                  );
                },
                child: const Text(
                  'Показать экран',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
