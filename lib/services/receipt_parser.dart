import '../models/expense.dart';

class ReceiptParser {
  static final RegExp _money = RegExp(
    r'(?:\$|USD\s*)(\d[\d,]*(?:\.\d{1,2})?)|(?:VND\s*|₫\s*|đ\s*)([\d.,]+)|([\d.,]+)\s*(?:VND|₫|đ)(?![A-Za-z])|\b(\d{1,3}(?:[.,]\d{3})+|\d+[.,]\d{2})\b',
    caseSensitive: false,
  );
  static final RegExp _date = RegExp(
    r'\b(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',
  );
  static final RegExp _totalLabel = RegExp(
    r'\b(grand\s+total|total\s+due|amount\s+due|balance\s+due|total|amount)\b',
    caseSensitive: false,
  );
  static final RegExp _nonMerchant = RegExp(
    r'\b(receipt|invoice|thank you|welcome|subtotal|tax|total|cashier|date|address|phone|tel|www\.)\b',
    caseSensitive: false,
  );

  static Expense parse(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    double? amount;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (!_totalLabel.hasMatch(lines[i])) continue;
      amount = _lastAmount(lines[i]);
      if (amount == null && i + 1 < lines.length) {
        amount = _lastAmount(lines[i + 1]);
      }
      if (amount != null) break;
    }
    if (amount == null) {
      for (final match in _money.allMatches(text)) {
        final value = _amountFrom(match);
        if (value != null && (amount == null || value > amount)) amount = value;
      }
    }

    DateTime? date;
    for (final line in lines) {
      final match = _date.firstMatch(line);
      if (match == null) continue;
      date = _parseDate(match.group(1)!);
      if (date != null) break;
    }

    final merchant = lines.firstWhere(
      (line) =>
          line.length > 2 &&
          line.length < 48 &&
          !_nonMerchant.hasMatch(line) &&
          !_money.hasMatch(line) &&
          !_date.hasMatch(line),
      orElse: () => 'Unknown merchant',
    );

    return Expense(
      merchant: merchant,
      amount: amount ?? 0,
      date: date ?? DateTime.now(),
      category: suggestCategory('$merchant $text'),
    );
  }

  static double? _lastAmount(String line) {
    final matches = _money.allMatches(line).toList();
    if (matches.isNotEmpty) return _amountFrom(matches.last);
    if (_totalLabel.hasMatch(line)) {
      final integers = RegExp(r'\b\d{3,}\b').allMatches(line).toList();
      if (integers.isNotEmpty) return double.tryParse(integers.last.group(0)!);
    }
    return null;
  }

  static double? _amountFrom(RegExpMatch match) {
    final value = match.group(1) ??
        match.group(2) ??
        match.group(3) ??
        match.group(4);
    if (value == null) return null;

    final receiptUsesVnd = RegExp(r'VND|₫|đ', caseSensitive: false)
        .hasMatch(match.group(0)!);
    final isGroupedInteger = RegExp(r'^\d{1,3}(?:[.,]\d{3})+$')
        .hasMatch(value);
    if (receiptUsesVnd || isGroupedInteger) {
      return double.tryParse(value.replaceAll(RegExp(r'[.,]'), ''));
    }
    if (value.contains(',') && value.contains('.')) {
      return double.tryParse(value.replaceAll(',', ''));
    }
    return double.tryParse(value.replaceAll(',', '.'));
  }

  static DateTime? _parseDate(String value) {
    final parts = value.split(RegExp(r'[-/]')).map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;

    int year;
    int month;
    int day;
    if (value.startsWith(RegExp(r'\d{4}-'))) {
      year = parts[0]!;
      month = parts[1]!;
      day = parts[2]!;
    } else if (parts[0]! > 12) {
      // A first component above 12 can only be a day (DD/MM/YYYY).
      day = parts[0]!;
      month = parts[1]!;
      year = parts[2]!;
    } else {
      month = parts[0]!;
      day = parts[1]!;
      year = parts[2]!;
      if (year < 100) year += year < 70 ? 2000 : 1900;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final result = DateTime(year, month, day);
    if (result.month != month || result.day != day) return null;
    return result;
  }

  static String suggestCategory(String text) {
    final value = text.toLowerCase();
    if (RegExp(
            r'coffee|cafe|cà phê|restaurant|nhà hàng|pizza|grocery|siêu thị|market|food|bakery|ăn uống')
        .hasMatch(value)) return 'Food & drink';
    if (RegExp(
            r'uber|lyft|grab|transit|fuel|gas station|parking|metro|xăng|taxi')
        .hasMatch(value)) return 'Transport';
    if (RegExp(r'amazon|store|shop|retail|target|walmart').hasMatch(value)) {
      return 'Shopping';
    }
    if (RegExp(r'pharmacy|clinic|health|medical|dental|nhà thuốc|bệnh viện')
        .hasMatch(value)) {
      return 'Health';
    }
    return 'Other';
  }
}
