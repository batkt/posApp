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
}
