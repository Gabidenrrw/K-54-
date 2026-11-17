import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transfer_demo/entry_widgets.dart';
import 'package:transfer_demo/transfer_entry.dart';

void deviceSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2344);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('card paste and insertion retain grouping, limit and caret', () {
    final formatter = DemoCardFormatter();
    final pasted = formatter.formatEditUpdate(TextEditingValue.empty,
      const TextEditingValue(text: '1234-5678-9012-345678', selection: TextSelection.collapsed(offset: 22)));
    expect(pasted.text, '1234 5678 9012 3456');
    expect(pasted.selection.baseOffset, 19);
    final inserted = formatter.formatEditUpdate(pasted,
      const TextEditingValue(text: '1234 95678 9012 3456', selection: TextSelection.collapsed(offset: 6)));
    expect(inserted.text, '1234 9567 8901 2345');
    expect(inserted.selection.baseOffset, 6);
  });

  testWidgets('entry validates zero, balance and incomplete recipient', (tester) async {
    deviceSize(tester);
    await tester.pumpWidget(const TransferEntryApp());
    await tester.pumpAndSettle();
    expect(find.text('Клиенту Kaspi'), findsOneWidget);
    expect(find.text('Перевести 0 ₸'), findsOneWidget);
    expect(find.text('3 277,50 ₸'), findsOneWidget);
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Введите сумму больше 0 ₸.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('entry_amount')), '4000');
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Сумма больше баланса. Измените баланс в настройках карты.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('entry_amount')), '100');
    await tester.enterText(find.byKey(const Key('entry_phone')), '+7 701');
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Введите 11 цифр тестового телефона.'), findsOneWidget);
    expect(find.text('Клиенту Kaspi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry data reaches receipt and survives return and restart', (tester) async {
    deviceSize(tester);
    SharedPreferences.setMockInitialValues({
      'demo_entry_phone': '+7 701 123 45 67',
      'demo_recipient_directory_v1': '[{"phone":"77011234567","name":"Тестовый получатель","card":""}]',
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(TransferEntryApp(preferences: preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entry_source_card')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry_sender_setting')), 'Тестовый отправитель');
    await tester.enterText(find.byKey(const Key('entry_balance_setting')), '5000,50');
    await tester.tap(find.byKey(const Key('save_entry_settings')));
    await tester.pumpAndSettle();
    expect(find.text('5 000,50 ₸'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('entry_amount')), '123,45');
    await tester.tap(find.byKey(const Key('entry_suggestion_За обед')));
    await tester.pump();
    expect(find.text('7/50'), findsOneWidget);
    expect(find.text('Перевести 123,45 ₸'), findsOneWidget);
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    expect(find.text('123,45 ₸'), findsOneWidget);
    expect(find.text('Тестовый получатель'), findsOneWidget);
    await tester.tap(find.text('Показать квитанцию'));
    await tester.pumpAndSettle();
    expect(find.text('Тестовый отправитель'), findsOneWidget);
    expect(find.text('123,45 ₸'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close_receipt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('return_transfers')));
    await tester.pumpAndSettle();
    expect(find.text('Клиенту Kaspi'), findsOneWidget);
    expect(find.text('Перевести 123,45 ₸'), findsOneWidget);
    expect(preferences.getString('demo_entry_message'), 'За обед');
    expect(preferences.getInt('demo_entry_balance'), 500050);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(TransferEntryApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.text('Тестовый получатель'), findsOneWidget);
    expect(find.text('Перевести 123,45 ₸'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs and message length work without layout errors', (tester) async {
    deviceSize(tester);
    await tester.pumpWidget(const TransferEntryApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entry_tab_0')));
    await tester.pump();
    expect(find.byKey(const Key('entry_phone')), findsOneWidget);
    await tester.tap(find.byKey(const Key('entry_tab_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qr_camera_preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('qr_close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entry_tab_1')));
    await tester.enterText(find.byKey(const Key('entry_message')), '🙂' * 60);
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('entry_message')));
    expect(field.controller!.text.characters.length, 50);
    expect(find.text('50/50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
