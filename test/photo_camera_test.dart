import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transfer_demo/recipient_directory.dart';
import 'package:transfer_demo/recipient_directory_screen.dart';
import 'package:transfer_demo/recipient_photo.dart';
import 'package:transfer_demo/qr_scanner_screen.dart';
import 'package:transfer_demo/transfer_entry.dart';

const png = 'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGNM6dnCgA0wYRUdtBIAS58BtKysl7IAAAAASUVORK5CYII=';

class FakePhotoStore extends RecipientPhotoStore {
  FakePhotoStore(this.path);
  final String path;
  int picks = 0;
  @override
  Future<String?> pick() async { picks++; return path; }
  @override
  Future<String?> recover() async => null;
  @override
  Future<void> discard(String path) async {}
}

void deviceSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2344);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('picked photos are validated, copied permanently and scoped cleanup preserves originals', () async {
    final temporary = await Directory.systemTemp.createTemp('recipient_photos_');
    addTearDown(() => temporary.delete(recursive: true));
    final source = File('${temporary.path}/selected.png');
    await source.writeAsBytes(base64Decode(png));
    final store = RecipientPhotoStore(directory: () async => temporary);
    final saved = await store.importPickedFile(XFile(source.path));
    final other = await store.importPickedFile(XFile(source.path));
    expect(saved, isNot(source.path));
    expect(other, isNot(saved));
    expect(File(saved).readAsBytesSync(), source.readAsBytesSync());
    await store.discard(source.path);
    expect(source.existsSync(), true);
    await store.discard(saved);
    expect(File(saved).existsSync(), false);
    expect(File(other).existsSync(), true);
    final invalid = File('${temporary.path}/invalid.png');
    await invalid.writeAsString('invalid photo');
    await expectLater(store.importPickedFile(XFile(invalid.path)), throwsFormatException);
  });

  test('old directory records remain valid and photos stay associated with their own recipients', () async {
    SharedPreferences.setMockInitialValues({'demo_recipient_directory_v1':
      '[{"phone":"77011234567","name":"Без фото","card":""}]'});
    final preferences = await SharedPreferences.getInstance();
    final directory = RecipientDirectory(preferences);
    expect(directory.entries.single.photoPath, '');
    await directory.save(const DemoRecipient(phone: '77021234567', name: 'Второй', photoPath: '/private/second.jpg'));
    await directory.save(const DemoRecipient(phone: '77031234567', name: 'Третий', photoPath: '/private/third.jpg'));
    final restored = RecipientDirectory(preferences);
    expect(restored.byPhone('77021234567')!.photoPath, '/private/second.jpg');
    expect(restored.byPhone('77031234567')!.photoPath, '/private/third.jpg');
    await restored.save(const DemoRecipient(phone: '77021234567', name: 'Второй'), previousPhone: '77021234567');
    expect(RecipientDirectory(preferences).byPhone('77021234567')!.photoPath, '');
    expect(RecipientDirectory(preferences).byPhone('77031234567')!.photoPath, '/private/third.jpg');
    expect(RecipientPhoto.available('/missing/photo.jpg'), false);
    expect(RecipientPhoto.available(''), false);
  });

  testWidgets('photo upload, cancellation and removal preserve saved recipient data', (tester) async {
    deviceSize(tester);
    final temporary = Directory.systemTemp.createTempSync('photo_form_');
    addTearDown(() => temporary.deleteSync(recursive: true));
    final image = File('${temporary.path}/test.png')..writeAsBytesSync(base64Decode(png));
    SharedPreferences.setMockInitialValues({});
    final directory = RecipientDirectory(await SharedPreferences.getInstance());
    final store = FakePhotoStore(image.path);
    await directory.save(const DemoRecipient(phone: '77011234567', name: 'Клиент'));
    await tester.pumpWidget(MaterialApp(home: RecipientDirectoryScreen(directory: directory, photoStore: store)));
    await tester.pumpAndSettle();
    expect(find.byType(RecipientPhoto), findsNothing);
    await tester.tap(find.byKey(const Key('directory_77011234567')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_recipient_photo')));
    await tester.pumpAndSettle();
    expect(store.picks, 1);
    expect(find.byType(RecipientPhoto), findsOneWidget);
    await tester.tap(find.byKey(const Key('save_directory_recipient')));
    await tester.pumpAndSettle();
    expect(directory.entries.single.photoPath, image.path);
    await tester.tap(find.byKey(const Key('directory_77011234567')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove_recipient_photo')));
    await tester.pump();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(directory.entries.single.photoPath, image.path);
    await tester.tap(find.byKey(const Key('directory_77011234567')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove_recipient_photo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_directory_recipient')));
    await tester.pumpAndSettle();
    expect(directory.entries.single.photoPath, '');
    expect(find.byType(RecipientPhoto), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected photo reaches receipt and survives editing while missing photos stay hidden', (tester) async {
    deviceSize(tester);
    final temporary = Directory.systemTemp.createTempSync('photo_flow_');
    addTearDown(() => temporary.deleteSync(recursive: true));
    final image = File('${temporary.path}/test.png')..writeAsBytesSync(base64Decode(png));
    SharedPreferences.setMockInitialValues({'demo_entry_phone': '+7 701 123 45 67', 'demo_entry_amount': '100'});
    final preferences = await SharedPreferences.getInstance();
    final directory = RecipientDirectory(preferences);
    await directory.save(DemoRecipient(phone: '77011234567', name: 'Клиент', photoPath: image.path));
    await tester.pumpWidget(TransferEntryApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(tester.widget<RecipientPhoto>(find.byType(RecipientPhoto)).path, image.path);
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать квитанцию'));
    await tester.pumpAndSettle();
    expect(tester.widget<RecipientPhoto>(find.byType(RecipientPhoto)).path, image.path);
    await tester.tap(find.byKey(const Key('receipt_sender')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sender_input')), 'Отправитель для фото');
    await tester.tap(find.byKey(const Key('apply_data')));
    await tester.pumpAndSettle();
    expect(tester.widget<RecipientPhoto>(find.byType(RecipientPhoto)).path, image.path);
    await tester.tap(find.byKey(const Key('close_receipt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('return_transfers')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await directory.save(const DemoRecipient(phone: '77011234567', name: 'Клиент'), previousPhone: '77011234567');
    await tester.pumpWidget(TransferEntryApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.byType(RecipientPhoto), findsNothing);
    await tester.tap(find.byKey(const Key('entry_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать квитанцию'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipientPhoto), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every QR is rejected, duplicate detections show one dialog and retry works', (tester) async {
    deviceSize(tester);
    await tester.pumpWidget(const MaterialApp(home: QrScannerScreen()));
    await tester.pumpAndSettle();
    final scanner = tester.widget<MobileScanner>(find.byKey(const Key('qr_camera_preview')));
    expect(scanner.controller!.formats, [BarcodeFormat.qrCode]);
    for (final content in ['https://example.com', 'Kaspi transfer', '', '77011234567']) {
      final capture = BarcodeCapture(barcodes: [Barcode(format: BarcodeFormat.qrCode, rawValue: content)]);
      scanner.onDetect!(capture);
      scanner.onDetect!(capture);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qr_unrecognized')), findsOneWidget);
      expect(find.text('QR-код не распознан'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry_qr')));
      await tester.pumpAndSettle();
    }
    scanner.onDetect!(const BarcodeCapture(barcodes: [Barcode(format: BarcodeFormat.code128, rawValue: '12345')]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qr_unrecognized')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
