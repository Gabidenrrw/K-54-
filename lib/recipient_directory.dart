import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'phone_input.dart';

class DemoRecipient {
  const DemoRecipient({required this.phone, required this.name, this.card = '', this.photoPath = ''});
  final String phone, name, card;
  final String photoPath;
  Map<String, String> toStorage() => {'phone': phone, 'name': name, 'card': card,
    if (photoPath.isNotEmpty) 'photoPath': photoPath};
}

/// Local demo directory. No banking lookup or remote requests.
class RecipientDirectory {
  RecipientDirectory(this.preferences) {
    final raw = preferences?.getString('demo_recipient_directory_v1');
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map || item['phone'] is! String || item['name'] is! String) continue;
        final key = phoneDirectoryKey(item['phone'] as String);
        final name = (item['name'] as String).trim();
        final card = item['card'] is String ? (item['card'] as String).replaceAll(RegExp(r'\D'), '') : '';
        if (key == null || name.isEmpty || name.length > 50 || (card.isNotEmpty && card.length != 16)) continue;
        if (_entries.any((entry) => entry.phone == key || (card.isNotEmpty && entry.card == card))) continue;
        _entries.add(DemoRecipient(phone: key, name: name, card: card,
          photoPath: item['photoPath'] is String ? item['photoPath'] as String : ''));
      }
    } on FormatException {
      // Preserve invalid stored content until the user saves a valid directory.
    }
  }
  final SharedPreferences? preferences;
  List<DemoRecipient> _entries = [];
  List<DemoRecipient> get entries => List.unmodifiable(_entries);

  DemoRecipient? byPhone(String value) {
    final key = phoneDirectoryKey(value);
    if (key == null) return null;
    for (final entry in _entries) {
      if (entry.phone == key) return entry;
    }
    return null;
  }

  DemoRecipient? byCard(String value) {
    final key = value.replaceAll(RegExp(r'\D'), '');
    if (key.length != 16) return null;
    for (final entry in _entries) {
      if (entry.card == key) return entry;
    }
    return null;
  }

  Future<void> save(DemoRecipient recipient, {String? previousPhone}) async {
    final key = phoneDirectoryKey(recipient.phone);
    final name = recipient.name.trim();
    final card = recipient.card.replaceAll(RegExp(r'\D'), '');
    if (key == null || name.isEmpty || name.length > 50 || (card.isNotEmpty && card.length != 16)) {
      throw const FormatException('Проверьте телефон, имя и номер карты.');
    }
    final previous = previousPhone == null ? null : phoneDirectoryKey(previousPhone);
    if (_entries.any((entry) => entry.phone != previous &&
        (entry.phone == key || (card.isNotEmpty && entry.card == card)))) {
      throw const FormatException('Этот телефон или карта уже есть в базе.');
    }
    final next = [..._entries];
    final index = next.indexWhere((entry) => entry.phone == previous);
    final validated = DemoRecipient(phone: key, name: name, card: card, photoPath: recipient.photoPath);
    if (index < 0) { next.add(validated); } else { next[index] = validated; }
    final persisted = await preferences?.setString('demo_recipient_directory_v1',
      jsonEncode(next.map((entry) => entry.toStorage()).toList()));
    if (persisted == false) throw StateError('Не удалось сохранить базу на устройстве.');
    _entries = next;
  }
}
