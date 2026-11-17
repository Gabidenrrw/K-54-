import 'package:flutter/services.dart';

String phoneNationalDigits(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if ((value.trimLeft().startsWith('+7') && digits.startsWith('7')) ||
      (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8')))) {
    digits = digits.substring(1);
  }
  return digits;
}

String? phoneDirectoryKey(String value) {
  final digits = phoneNationalDigits(value);
  return digits.length == 10 && !RegExp(r'^0+$').hasMatch(digits) ? '7$digits' : null;
}

String formatDemoPhone(String value) {
  final digits = phoneNationalDigits(value);
  final limited = digits.substring(0, digits.length.clamp(0, 10));
  if (limited.isEmpty) return '+7';
  final output = StringBuffer('+7 (');
  for (var index = 0; index < limited.length; index++) {
    if (index == 3) {
      output.write(') ');
    } else if (index == 6 || index == 8) {
      output.write(' ');
    }
    output.write(limited[index]);
  }
  return output.toString();
}

/// Fixed country prefix; handles local, +7 and 8-prefixed pasted numbers.
class DemoPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var national = phoneNationalDigits(newValue.text);
    var before = phoneNationalDigits(newValue.text.substring(0,
      newValue.selection.baseOffset.clamp(0, newValue.text.length))).length;
    if (oldValue.selection.isCollapsed && newValue.selection.isCollapsed &&
        oldValue.text.length == newValue.text.length + 1 &&
        national == phoneNationalDigits(oldValue.text)) {
      final deletedAt = newValue.selection.baseOffset;
      if (deletedAt >= 3 && deletedAt < oldValue.text.length &&
          oldValue.text[deletedAt] == ' ' && before > 0) {
        national = national.replaceRange(before - 1, before, '');
        before--;
      }
    }
    final formatted = formatDemoPhone(national);
    final count = before.clamp(0, phoneNationalDigits(formatted).length);
    var offset = 2;
    var seen = 0;
    for (var index = 2; index < formatted.length && seen < count; index++) {
      if (RegExp(r'\d').hasMatch(formatted[index])) seen++;
      offset = index + 1;
    }
    return TextEditingValue(text: formatted,
      selection: TextSelection.collapsed(offset: offset));
  }
}
