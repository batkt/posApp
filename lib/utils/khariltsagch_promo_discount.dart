/// Web `posKhariltsagchModal.js` → `uramshuulalKhungulult` + `pages/khyanalt/posSystem/index.js` `niitDunNoat` хөнгөлөлт.
abstract final class KhariltsagchPromoDiscount {
  KhariltsagchPromoDiscount._();

  static double _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double _r2(double x) =>
      double.parse(x.clamp(0.0, double.infinity).toStringAsFixed(2));

  /// Same object shape as web `khariltsagchOruulya` before `POST /guilgeeniiTuukhKhadgalya`.
  static Map<String, dynamic> buildCheckoutPayload({
    required Map<String, dynamic> khariltsagchRow,
    double bonusAshiglasan = 0,
  }) {
    final id = khariltsagchRow['_id']?.toString() ?? '';
    final ner = khariltsagchRow['ner']?.toString() ?? '';
    return {
      'ner': ner,
      'id': id,
      'bonus': {
        'ashiglasan': bonusAshiglasan,
        'umnukh': _n(khariltsagchRow['onoo']),
        'nemegdsen': 0,
      },
      'khunglult': {
        'khunglultiinTurul': khariltsagchRow['khunglukhTurul'],
        'dun': _n(khariltsagchRow['khunglukhDun']),
        'khuvi': _n(khariltsagchRow['khunglukhKhuvi']),
      },
    };
  }

  /// Total `hungulsunDun` from customer хөнгөлөлт / бонус (matches web `niitDunNoat` discount part).
  static double computeHungulsunDunTotal({
    required List<double> lineGrossBeforeDiscount,
    required Map<String, dynamic> payload,
  }) {
    final kh = payload['khunglult'];
    if (kh is! Map) return 0;

    final turul = '${kh['khunglultiinTurul'] ?? ''}'.trim();
    final khuvi = _n(kh['khuvi']);
    final dun = _n(kh['dun']);

    final bonus = payload['bonus'];
    final ashiglasan = bonus is Map ? _n(bonus['ashiglasan']) : 0.0;

    var hungulsunDun = 0.0;
    var niitDun = 0.0;

    for (final g0 in lineGrossBeforeDiscount) {
      var z = g0.clamp(0.0, double.infinity);
      var h = 0.0;
      if (z > 0) {
        var tempKhuvi = 0.0;
        if (turul == 'Хувь' && khuvi > 0) {
          tempKhuvi = khuvi;
        }
        if (tempKhuvi > 0) {
          h = _r2((z / 100) * tempKhuvi);
        }
        if (ashiglasan > 0) {
          final base = h > 0 ? h : z;
          if (base > 0) {
            tempKhuvi = (ashiglasan * 100) / base;
            h = _r2(h + ((h > 0 ? h : z) / 100) * tempKhuvi);
          }
        }
        z = _r2(z - h);
      }
      hungulsunDun = _r2(hungulsunDun + h);
      niitDun = _r2(niitDun + z);
    }

    if (turul == 'Мөнгөн дүн' && dun > 0 && niitDun > 0) {
      final tempKhuvi = (dun * 100) / niitDun;
      hungulsunDun = _r2((niitDun / 100) * tempKhuvi);
    }

    return hungulsunDun;
  }
}
