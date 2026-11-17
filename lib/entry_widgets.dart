import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

String formatDemoCard(String value) => value.replaceAll(RegExp(r'\D'), '')
  .replaceAllMapped(RegExp(r'.{1,4}'), (match) => '${match[0]} ').trim();

class DemoCardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final allDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = allDigits.substring(0, math.min(16, allDigits.length));
    final caret = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final beforeCaret = math.min(digits.length,
      newValue.text.substring(0, caret).replaceAll(RegExp(r'\D'), '').length);
    final formatted = formatDemoCard(digits);
    final offset = beforeCaret + (beforeCaret == 0 ? 0 : (beforeCaret - 1) ~/ 4);
    return TextEditingValue(text: formatted,
      selection: TextSelection.collapsed(offset: math.min(offset, formatted.length)));
  }
}

class EntryIcon extends StatelessWidget {
  const EntryIcon(this.name, {super.key, this.width = 24, this.height,
    this.color = const Color(0xFF666B6B)});
  final String name;
  final double width;
  final double? height;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/icons/$name.svg',
    width: width, height: height ?? width,
    colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn));
}

