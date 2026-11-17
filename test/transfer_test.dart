import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transfer_demo/main.dart';
import 'package:transfer_demo/transfer_data.dart';
import 'package:transfer_demo/demo_receipt.dart';

void main() {
  test('amounts are parsed exactly into minor units', () {
    expect(TransferData.parseAmount('12 345,67'), 1234567);
    expect(TransferData.parseAmount('0.01'), 1);
    expect(TransferData.parseAmount('1,2'), 120);
    expect(TransferData.parseAmount('999999999'), 99999999900);
    for (final invalid in ['', '0', '-1', '1.234', '1,2,3', 'NaN', '1000000000']) {
      expect(TransferData.parseAmount(invalid), isNull, reason: invalid);
    }
  });

  test('grouped display retains fractional precision', () {
    const data = TransferData(minorUnits: 1234567, recipientName: 'Тест');
    expect(data.amountText, '12 345,67 ₸');
    expect(data.editableAmount, '12345,67');
  });

  testWidgets('editing updates screen, receipt and saved data', (tester) async {
    tester.view.physicalSize = const Size(1080, 2344);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(MainApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.text('100 ₸'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('670 000 ₸')).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('return_transfers'))).dy));

    await tester.tap(find.byKey(const Key('edit_data')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recipient_input')), 'Тестовый получатель');
    await tester.enterText(find.byKey(const Key('amount_input')), '12345,67');
    await tester.enterText(find.byKey(const Key('sender_input')), 'Тестовый отправитель');
    await tester.tap(find.byKey(const Key('apply_data')));
    await tester.pumpAndSettle();
    expect(find.text('12 345,67 ₸'), findsOneWidget);
    expect(find.text('Тестовый получатель'), findsOneWidget);
    expect(preferences.getInt('demo_amount'), 1234567);
    expect(preferences.getString('demo_recipient'), 'Тестовый получатель');
    expect(preferences.getString('demo_sender'), 'Тестовый отправитель');

    await tester.tap(find.text('Показать квитанцию'));
    await tester.pumpAndSettle();
    expect(find.text('Тестовый получатель'), findsOneWidget);
    expect(find.text('Тестовый отправитель'), findsOneWidget);
    final number = tester.widget<Text>(find.byKey(const Key('receipt_number'))).data!;
    expect(number, matches(RegExp(r'^ТЕСТ-[1-9][0-9]{17}$')));
    await tester.tap(find.byKey(const Key('close_receipt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite_toggle')));
    await tester.pumpAndSettle();
    expect(preferences.getBool('demo_favorite'), true);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MainApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.text('12 345,67 ₸'), findsOneWidget);
    expect(find.text('Тестовый получатель'), findsOneWidget);
  });

  testWidgets('invalid editor input keeps the current display data', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_data')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recipient_input')), '   ');
    await tester.enterText(find.byKey(const Key('amount_input')), '0');
    await tester.ensureVisible(find.byKey(const Key('apply_data')));
    await tester.tap(find.byKey(const Key('apply_data')));
    await tester.pumpAndSettle();
    expect(find.text('Введите имя получателя'), findsOneWidget);
    expect(find.text('Введите сумму от 0,01 до 999 999 999 ₸'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('demo receipt uses 18 random digits and Astana time across midnight', () {
    const data = TransferData(minorUnits: 10000, recipientName: 'Тест', senderName: 'Отправитель');
    final generator = Random(42);
    final receipts = List.generate(10, (_) => DemoReceipt.create(data,
      random: generator, now: DateTime.utc(2026, 10, 3, 21, 32)));
    expect(receipts.map((receipt) => receipt.number).toSet().length, 10);
    for (final receipt in receipts) {
      expect(receipt.number, matches(RegExp(r'^DEMO-[1-9][0-9]{17}$')));
      expect(receipt.dateText, '04.10.2026 02:32');
      expect(receipt.shareText, startsWith('ДЕМО — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ'));
      expect(receipt.shareText, contains('Отправитель: Отправитель'));
    }
  });

  testWidgets('receipt number is stable, share stays marked and favorites synchronize', (tester) async {
    tester.view.physicalSize = const Size(1080, 2344);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'demo_sender': 'Тестовый отправитель'});
    final preferences = await SharedPreferences.getInstance();
    const channel = MethodChannel('dev.preview.transfer_demo/share');
    String? sharedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'shareText');
        sharedText = (call.arguments as Map)['text'] as String;
        return null;
      });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(MainApp(preferences: preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать квитанцию'));
    await tester.pumpAndSettle();
    final number = tester.widget<Text>(find.byKey(const Key('receipt_number'))).data;
    await tester.tap(find.byKey(const Key('receipt_action_star')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('receipt_number'))).data, number);
    expect(preferences.getBool('demo_favorite'), true);
    await tester.tap(find.byKey(const Key('receipt_action_share')));
    await tester.pumpAndSettle();
    expect(sharedText, startsWith('ПЛАТЁЖ НЕ ВЫПОЛНЯЛСЯ — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ'));
    expect(sharedText, contains(number!));
    await tester.tap(find.byKey(const Key('receipt_sender')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sender_input')), 'Другой отправитель');
    await tester.tap(find.byKey(const Key('apply_data')));
    await tester.pumpAndSettle();
    expect(find.text('Другой отправитель'), findsOneWidget);
    expect(preferences.getString('demo_sender'), 'Другой отправитель');
    expect(tester.widget<Text>(find.byKey(const Key('receipt_number'))).data, isNot(number));
    await tester.tap(find.byKey(const Key('close_receipt')));
    await tester.pumpAndSettle();
    expect(find.text('100 ₸'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
