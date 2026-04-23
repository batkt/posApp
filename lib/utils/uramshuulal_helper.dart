/// Active promotion rows on a product (`aguulakh.uramshuulal`), web-style date/time window.
abstract final class UramshuulalHelper {
  UramshuulalHelper._();

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is Map && v[r'$date'] != null) {
      final inner = v[r'$date'];
      if (inner is String) return DateTime.tryParse(inner);
      if (inner is int) {
        return DateTime.fromMillisecondsSinceEpoch(inner, isUtc: true)
            .toLocal();
      }
    }
    return null;
  }

  /// `YYYYMMDDHHmm` style ordering as on web (local wall clock).
  static int _stamp(DateTime d) =>
      d.year * 100000000 +
      d.month * 1000000 +
      d.day * 10000 +
      d.hour * 100 +
      d.minute;

  static DateTime _combineDateAndTime(DateTime day, DateTime? timeOfDay) {
    if (timeOfDay == null) return day;
    return DateTime(
      day.year,
      day.month,
      day.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
  }

  /// True when current moment is inside [ekhlekhOgnoo..duusakhOgnoo] and
  /// [ekhlekhTsag..duusakhTsag] on that calendar span (same idea as web POS gift icon).
  static bool isActiveNow(Map<String, dynamic> row, DateTime now) {
    final startD = _parse(row['ekhlekhOgnoo']);
    final endD = _parse(row['duusakhOgnoo']);
    if (startD == null || endD == null) return false;

    final startT = _parse(row['ekhlekhTsag']);
    final endT = _parse(row['duusakhTsag']);

    final start = _combineDateAndTime(
      DateTime(startD.year, startD.month, startD.day),
      startT,
    );
    final end = _combineDateAndTime(
      DateTime(endD.year, endD.month, endD.day),
      endT,
    );

    final n = _stamp(now);
    return _stamp(start) <= n && n <= _stamp(end);
  }

  static List<Map<String, dynamic>> activePromotions(
    List<Map<String, dynamic>> rows,
    DateTime now,
  ) {
    return rows.where((e) => isActiveNow(e, now)).toList();
  }

  static String? promotionPickId(Map<String, dynamic> row) {
    final v = row['uramshuulaliinId'] ?? row['_id'] ?? row['id'];
    return v?.toString();
  }
}
