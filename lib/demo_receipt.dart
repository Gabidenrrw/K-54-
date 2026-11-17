import 'dart:math';
import 'transfer_data.dart';

/// Synthetic metadata, explicitly separated from any bank receipt number.
class DemoReceipt {
  const DemoReceipt({required this.data, required this.number, required this.astanaTime});
  final TransferData data;
  final String number;
  final DateTime astanaTime;

  factory DemoReceipt.create(TransferData data, {Random? random, DateTime? now}) {
    final generator = random ?? Random.secure();
    final digits = '90'
        '${List.generate(16, (_) => generator.nextInt(10)).join()}';
    return DemoReceipt(data: data, number: 'DEMO-$digits',
      astanaTime: (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5)));
  }

  String get dateText {
    String two(int value) => value.toString().padLeft(2, '0');
    final time = astanaTime;
    return '${two(time.day)}.${two(time.month)}.${time.year} ${two(time.hour)}:${two(time.minute)}';
  }

  String get shareText => 'ДЕМО — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ\n'
      'Платёж не выполнялся. Этот макет не подтверждает оплату.\n'
      'Сумма: ${data.amountText}\nПолучатель: ${data.recipientName}\n'
      'Отправитель: ${data.senderName.isEmpty ? "Не указан" : data.senderName}\n'
      'Тестовый номер: $number\nДата и время по Астане: $dateText';

  // The legacy metadata/share contract stays available to existing callers.
  String get displayNumber => number.startsWith('DEMO-') ? '${number.substring(5)}' : number;
  String get displayShareText => shareText
    .replaceFirst('ДЕМО — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ', 'ПЛАТЁЖ НЕ ВЫПОЛНЯЛСЯ — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ')
    .replaceFirst('Этот макет не подтверждает оплату.', 'Эта квитанция не подтверждает оплату.')
    .replaceFirst('Тестовый номер: $number', 'Тестовый номер: $displayNumber');
}
