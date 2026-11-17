import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_demo/demo_receipt.dart';
import 'package:transfer_demo/transfer_data.dart';
import 'package:transfer_demo/transfer_entry.dart';

void main() {
  test('visible receipt wording changes while legacy metadata stays compatible', () {
    final receipt = DemoReceipt.create(const TransferData(minorUnits: 10000, recipientName: 'Тест'), random: Random(42));
    expect(receipt.number, matches(RegExp(r'^DEMO-[1-9][0-9]{17}$')));
    expect(receipt.shareText, startsWith('ДЕМО — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ'));
    expect(receipt.displayNumber, matches(RegExp(r'^ТЕСТ-[1-9][0-9]{17}$')));
    expect(receipt.displayNumber.split('-').last, receipt.number.substring(5));
    expect(receipt.displayShareText, startsWith('ПЛАТЁЖ НЕ ВЫПОЛНЯЛСЯ — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ'));
    expect(receipt.displayShareText, contains('Платёж не выполнялся.'));
    expect(receipt.displayShareText, contains(receipt.displayNumber));
    expect(receipt.displayShareText, isNot(contains('ДЕМО')));
    expect(receipt.displayShareText, isNot(contains('DEMO-')));
    expect(receipt.displayShareText.toLowerCase(), isNot(contains('макет')));
  });

  for (final size in [const Size(1080, 2344), const Size(945, 1680)]) {
    testWidgets('QR layout fits $size and close preserves entry data', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2.625;
      tester.view.padding = const FakeViewPadding(top: 80, bottom: 66);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const TransferEntryApp());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('entry_phone')), '+7 701 123 45 67');
      await tester.enterText(find.byKey(const Key('entry_amount')), '123');
      await tester.tap(find.byKey(const Key('entry_tab_2')));
      await tester.pumpAndSettle();
      expect(find.text('Kaspi QR'), findsOneWidget);
      expect(find.text('QR-кодты сканерлеңіз'), findsOneWidget);
      expect(find.text('Онлайн рәсімдеу'), findsOneWidget);
      expect(find.text('Бөліп төлеу 0-0-12'), findsOneWidget);
      expect(find.byKey(const Key('qr_torch')), findsOneWidget);
      final footer = find.byKey(const Key('qr_online_panel'));
      expect(tester.getBottomLeft(footer).dy, lessThanOrEqualTo(size.height / 2.625));
      expect(tester.getTopLeft(find.byKey(const Key('qr_close'))).dy,
        lessThan(tester.getTopLeft(footer).dy));
      expect(find.textContaining('ДЕМО'), findsNothing);
      await tester.tap(find.byKey(const Key('qr_close')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('entry_phone'))).controller!.text, '+7 701 123 45 67');
      expect(find.text('Перевести 123 ₸'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
