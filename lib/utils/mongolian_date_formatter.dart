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

  /// Бүх огноо `YYYY-MM-DD` тоон хэлбэртэй (жиш. `2026-09-07`).
  ///
  /// Өмнө нь "7 9-р сар, 2026 (Даваа)" / "2026 оны 9-р сарын 7" гэх мэт
  /// үгэн хэлбэрүүд зэрэгцэн ашиглагдаж, дэлгэц бүр өөр өөр харагддаг байв.
  static String formatDate(DateTime date) => formatDateYmdCompact(date);

  static String formatShortDate(DateTime date) => formatDateYmdCompact(date);

  static String formatDateYmdWords(DateTime date) =>
      formatDateYmdCompact(date);

  /// Эхлэл — төгсгөл.
  static String formatDateRangeLine(DateTime start, DateTime end) {
    return '${formatDateYmdWords(start)} — ${formatDateYmdWords(end)}';
  }

  /// Narrow filter label: `2026-04-05` (year–month–day only).
  static String formatDateYmdCompact(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Same as [formatDateRangeLine] but compact Latin digits — for date filter buttons.
  static String formatDateRangeCompact(DateTime start, DateTime end) {
    return '${formatDateYmdCompact(start)} — ${formatDateYmdCompact(end)}';
  }

  /// Section title for sales history — `2026-09-07 (Даваа)`.
  static String formatSalesHistorySectionDate(DateTime date) {
    final local = date.toLocal();
    final weekday = mongolianWeekdays[local.weekday - 1];
    return '${formatDateYmdCompact(local)} ($weekday)';
  }

  /// Wall-clock time in the device locale; [seconds] for transaction lists.
  static String formatTime(DateTime date, {bool seconds = false}) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    if (!seconds) {
      return '$hour:$minute';
    }
    final sec = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$sec';
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${formatTime(date)}';
  }

  /// Receipt / thermal: `2026-09-07       13:59:59` (no weekday).
  static String formatReceiptNumericDateTime(DateTime date) {
    final local = date.toLocal();
    return '${formatDateYmdCompact(local)}       '
        '${formatTime(local, seconds: true)}';
  }

  static String formatRelativeDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);
    
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
