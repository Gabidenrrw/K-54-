import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transfer_demo/phone_input.dart';
import 'package:transfer_demo/recipient_directory.dart';
import 'package:transfer_demo/transfer_entry.dart';

void deviceSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2344);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('phone prefix, paste, deletion and insertion keep correct digits and caret', () {
    final formatter = DemoPhoneFormatter();
    TextEditingValue value(String text, [int? caret]) => TextEditingValue(
      text: text, selection: TextSelection.collapsed(offset: caret ?? text.length));
    expect(formatter.formatEditUpdate(value('+7'), value('')).text, '+7');
    for (final pasted in ['7011234567', '87011234567', '+7 (701) 123-45-67']) {
      final result = formatter.formatEditUpdate(value('+7'), value(pasted));
      expect(result.text, '+7 701 123 45 67');
      expect(result.selection.baseOffset, result.text.length);
      expect(phoneDirectoryKey(result.text), '77011234567');
    }
    final deletedSpace = formatter.formatEditUpdate(value('+7 701 123', 7), value('+7 701123', 6));
    expect(deletedSpace.text, '+7 701 23');
    expect(deletedSpace.selection.baseOffset, 5);
    final inserted = formatter.formatEditUpdate(value('+7 701 23', 5), value('+7 7091 23', 6));
    expect(inserted.text, '+7 709 123');
    expect(inserted.selection.baseOffset, 6);
    expect(phoneDirectoryKey('+7 701'), isNull);
    expect(phoneDirectoryKey('+7 000 000 00 00'), isNull);
    expect(formatter.formatEditUpdate(value('+7'), value('70112345678999')).text, '+7 701 123 45 67');
  });

  test('directory normalizes, persists, rejects duplicates and updates atomically', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = RecipientDirectory(preferences);
    await directory.save(const DemoRecipient(phone: '87011234567', name: ' Первый ', card: '1111 2222 3333 4444'));
    expect(directory.byPhone('+7 701 123 45 67')!.name, 'Первый');
    expect(directory.byPhone('+7 701'), isNull);
    expect(directory.byCard('1111222233334444')!.name, 'Первый');
    await expectLater(directory.save(const DemoRecipient(phone: '+7 701 123 45 67', name: 'Дубликат')),
      throwsFormatException);
    await expectLater(directory.save(const DemoRecipient(phone: '+7 702 123 45 67', name: 'Другой', card: '1111222233334444')),
      throwsFormatException);
    await directory.save(const DemoRecipient(phone: '77021234567', name: 'Изменённый', card: '1111222233334444'),
      previousPhone: '77011234567');
    expect(directory.byPhone('77011234567'), isNull);
    expect(directory.entries.length, 1);
    final restored = RecipientDirectory(preferences);
    expect(restored.byPhone('87021234567')!.name, 'Изменённый');
    final stored = jsonDecode(preferences.getString('demo_recipient_directory_v1')!) as List;
    expect((stored.single as Map).keys.toSet(), {'phone', 'name', 'card'});
  });

  test('invalid stored entries cannot produce false matches or crash startup', () async {
    SharedPreferences.setMockInitialValues({'demo_recipient_directory_v1': '[{"phone":"7701","name":"Bad"},null,{"phone":123,"name":"Bad"}]'});
    final preferences = await SharedPreferences.getInstance();
    expect(RecipientDirectory(preferences).entries, isEmpty);
    await preferences.setString('demo_recipient_directory_v1', 'invalid json');
    expect(RecipientDirectory(preferences).entries, isEmpty);
  });

  testWidgets('adding and editing a recipient updates lookup and the whole transfer flow', (tester) async {
    deviceSize(tester);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(TransferEntryApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry_recipient_banner')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('entry_phone'))).controller!.text, '+7');
    await tester.tap(find.byKey(const Key('entry_source_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_recipient_directory')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_directory_recipient')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('directory_phone')), '87011234567');
    await tester.enterText(find.byKey(const Key('directory_name')), 'Первый получатель');
    await tester.enterText(find.byKey(const Key('directory_card')), '1111222233334444');
    await tester.tap(find.byKey(const Key('save_directory_recipient')));
    await tester.pumpAndSettle();
    expect(find.text('+7 701 123 45 67'), findsOneWidget);
    await tester.tap(find.byKey(const Key('directory_77011234567')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('directory_name')), 'Имя из базы');
    await tester.tap(find.byKey(const Key('save_directory_recipient')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry_sender_setting')), 'Тестовый отправитель');
    await tester.tap(find.byKey(const Key('save_entry_settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry_phone')), '+7 701 123 45');
    await tester.pump();
    expect(find.byKey(const Key('entry_recipient_banner')), findsNothing);
    await tester.enterText(find.byKey(const Key('entry_phone')), '87011234567');
    await tester.pump();
    expect(find.text('Имя из базы'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('entry_phone')), '87021234567');
    await tester.pump();
    expect(find.byKey(const Key('entry_recipient_banner')), findsNothing);
    await tester.enterText(find.byKey(const Key('entry_amount')), '100');
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Получатель не найден. Добавьте номер и имя в базу получателей.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('entry_phone')), '87011234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('entry_tab_1')));
    await tester.pump();
    expect(find.byKey(const Key('entry_recipient_banner')), findsNothing);
    await tester.enterText(find.byKey(const Key('entry_card')), '1111222233334444');
    await tester.pump();
    expect(find.text('Имя из базы'), findsOneWidget);
    await tester.tap(find.byKey(const Key('entry_tab_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Имя из базы'), findsOneWidget);
    await tester.tap(find.text('Показать квитанцию'));
    await tester.pumpAndSettle();
    expect(find.text('Имя из базы'), findsOneWidget);
    expect(find.text('Тестовый отправитель'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close_receipt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('return_transfers')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(TransferEntryApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.text('Имя из базы'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
