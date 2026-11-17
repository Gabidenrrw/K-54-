/// Display data only: this model does not represent a bank transaction.
class TransferData {
  const TransferData({required this.minorUnits, required this.recipientName,
    this.senderName = '', this.recipientPhotoPath = '', this.recipientPhone = ''});

  final int minorUnits;
  final String recipientName;
  final String senderName;
  final String recipientPhotoPath;
  final String recipientPhone;

  static int? parseAmount(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[ \u00a0\u202f]'), '')
        .replaceAll(',', '.');
    if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final amount =
        int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    return amount > 0 && amount <= 99999999900 ? amount : null;
  }

  String get amountText {
    final whole = (minorUnits ~/ 100).toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]} ',
    );
    final fraction = minorUnits % 100;
    return fraction == 0
        ? '$whole ₸'
        : '$whole,${fraction.toString().padLeft(2, '0')} ₸';
  }

  String get editableAmount => (minorUnits % 100 == 0)
      ? '${minorUnits ~/ 100}'
      : '${minorUnits ~/ 100},${(minorUnits % 100).toString().padLeft(2, '0')}';
}
