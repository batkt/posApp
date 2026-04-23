/// Matches web `pages/khyanalt/posSystem/index.js` → `buuniiUneAvakh` tier logic.
abstract final class BuuniiUneHelper {
  BuuniiUneHelper._();

  static List<_Tier> _sortedTiers(List<Map<String, dynamic>> raw) {
    final out = <_Tier>[];
    for (final m in raw) {
      final too = (m['buuniiToo'] as num?)?.toDouble() ?? 0;
      final une = (m['buuniiUne'] as num?)?.toDouble() ?? 0;
      out.add(_Tier(too, une));
    }
    out.sort((a, b) => a.buuniiToo.compareTo(b.buuniiToo));
    return out;
  }

  /// Returns wholesale **unit** price when a tier applies; `null` means use [retailUnit].
  static double? resolveUnitPrice({
    required double qty,
    required List<Map<String, dynamic>> buuniiUneJagsaalt,
    required double retailUnit,
  }) {
    if (buuniiUneJagsaalt.isEmpty) return null;
    final t = _sortedTiers(buuniiUneJagsaalt);
    if (t.isEmpty) return null;

    final tempBuunii = t.where((e) => e.buuniiToo > qty).toList();
    if (!(tempBuunii.isNotEmpty && tempBuunii.length < t.length)) {
      return null;
    }

    var turBuuniiUne = retailUnit;
    final tempIkhBuunii = t.where((e) => e.buuniiToo <= qty).toList();
    if (tempIkhBuunii.length == t.length) {
      turBuuniiUne = t.last.buuniiUne;
    } else {
      for (var i = 0; i < t.length; i++) {
        final nextIndex = i + 1;
        if (nextIndex == t.length) continue;
        if (t[i].buuniiToo <= qty && qty < t[nextIndex].buuniiToo) {
          turBuuniiUne = t[i].buuniiUne;
          break;
        }
      }
    }
    return turBuuniiUne;
  }
}

class _Tier {
  _Tier(this.buuniiToo, this.buuniiUne);
  final double buuniiToo;
  final double buuniiUne;
}
