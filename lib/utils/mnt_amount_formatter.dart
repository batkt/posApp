import 'package:intl/intl.dart';

/// All UI money amounts: comma thousands, two decimals (e.g. `100,000.00`).
abstract final class MntAmountFormatter {
  MntAmountFormatter._();

  static final NumberFormat _twoDecimals = NumberFormat('#,##0.00', 'en_US');

  static double _safeDouble(num value) {
    final d = value.toDouble();
    return d.isFinite ? d : 0;
  }

  /// `100,000.00` (no currency symbol).
  static String format(num value) => _twoDecimals.format(_safeDouble(value));

  /// `100,000.00₮` (matches existing cashier-style suffix).
  static String formatTugrik(num value) => '${format(value)}₮';

  /// `100,000.00 ₮` (space before tugrik).
  static String formatTugrikSpaced(num value) => '${format(value)} ₮';

  /// Parses amounts typed in forms: spaces, `10,000` thousands, `10000.5`, `10000,5`.
  static double parseUserAmount(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'\s'), '').replaceAll('\u00a0', '');
    if (s.isEmpty) return 0;

    final dot = s.lastIndexOf('.');
    final comma = s.lastIndexOf(',');
    late String normalized;

    if (dot >= 0 && (comma < 0 || dot > comma)) {
      final intPart = s.substring(0, dot).replaceAll(',', '');
      final frac = s.substring(dot + 1).replaceAll(RegExp(r'[^\d]'), '');
      normalized = frac.isNotEmpty ? '$intPart.$frac' : intPart;
    } else if (comma >= 0 && RegExp(r',\d{1,2}$').hasMatch(s)) {
      final intPart = s.substring(0, comma).replaceAll(',', '');
      final frac = s.substring(comma + 1).replaceAll(RegExp(r'[^\d]'), '');
      normalized = frac.isNotEmpty ? '$intPart.$frac' : intPart;
    } else {
      normalized = s.replaceAll(',', '');
    }

    final v = double.tryParse(normalized);
    if (v == null || !v.isFinite) return 0;
    return v;
  }
}
