class MongolianDateFormatter {
  static const List<String> mongolianMonths = [
    '1-р сар',
    '2-р сар',
    '3-р сар',
    '4-р сар',
    '5-р сар',
    '6-р сар',
    '7-р сар',
    '8-р сар',
    '9-р сар',
    '10-р сар',
    '11-р сар',
    '12-р сар',
  ];

  static const List<String> mongolianWeekdays = [
    'Даваа',
    'Мягмар',
    'Лхагва',
    'Пүрэв',
    'Баасан',
    'Бямба',
    'Ням',
  ];

  static String formatDate(DateTime date) {
    final day = date.day;
    final month = mongolianMonths[date.month - 1];
    final year = date.year;
    final weekday = mongolianWeekdays[date.weekday - 1];
    
    return '$day $month, $year ($weekday)';
  }

  static String formatShortDate(DateTime date) {
    final day = date.day;
    final month = mongolianMonths[date.month - 1];
    final year = date.year;
    
    return '$day $month $year';
  }

  /// Албан ёсны уншигдахуйц: **2026 оны 4-р сарын 5** (цонх, товч, хугацааны сонголт).
  static String formatDateYmdWords(DateTime date) {
    final local = date.toLocal();
    final y = local.year;
    final m = mongolianMonths[local.month - 1];
    final d = local.day;
    return '$y оны $mын $d';
  }

  /// Эхлэл — төгсгөл (мөр бүрт монгол сарын нэрээр).
  static String formatDateRangeLine(DateTime start, DateTime end) {
    return '${formatDateYmdWords(start)} — ${formatDateYmdWords(end)}';
  }

  /// Section title for sales history (weekday + calendar date in Mongolian).
  static String formatSalesHistorySectionDate(DateTime date) {
    final weekday = mongolianWeekdays[date.weekday - 1];
    return '$weekday · ${formatShortDate(date)}';
  }

  static String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${formatTime(date)}';
  }

  /// Receipt / thermal: `2026/04/21       13:59:59` (no weekday — avoids "Мягмар" etc.).
  static String formatReceiptNumericDateTime(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '$y/$mo/$d       $h:$mi:$s';
  }

  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Өнөөдөр';
    } else if (difference.inDays == 1) {
      return 'Өчигдөр';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} хоногийн өмнө';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks долоо хоногийн өмнө';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months сарын өмнө';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years жилийн өмнө';
    }
  }
}
