class DorvonNegLineInput {
  const DorvonNegLineInput({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String id;
  final String name;
  final double unitPrice;
  final int quantity;
}

class DorvonNegTieCandidate {
  const DorvonNegTieCandidate({
    required this.id,
    required this.name,
    required this.price,
    required this.availableUnits,
  });

  final String id;
  final String name;
  final double price;
  final int availableUnits;
}

class DorvonNegCalcResult {
  const DorvonNegCalcResult({
    this.freeCount = 0,
    this.discount = 0,
    this.freeUnitsById = const {},
    this.tieCandidates = const [],
    this.tieSlotsNeeded = 0,
  });

  final int freeCount;
  final double discount;
  final Map<String, int> freeUnitsById;
  final List<DorvonNegTieCandidate> tieCandidates;
  final int tieSlotsNeeded;

  bool get hasTie => tieCandidates.isNotEmpty;
}

class _Unit {
  const _Unit(this.id, this.name, this.price);
  final String id;
  final String name;
  final double price;
}

/// "N-т 1 үнэгүй" урамшуулал — сагсанд байгаа НИЙТ ширхэгээс (бараа ялгаагүй)
/// [buleg] (жиших 4) тутамд хамгийн хямд 1 нэгж үнэгүй болно (2×[buleg] бол
/// хамгийн хямд 2 гэх мэт). Group size ([buleg]) идэвхтэй `uramshuulal` (турул
/// "khamgiinKhyamd") бичлэгээс ирнэ — `UramshuulalService.fetchActive`. Web
/// хувилбартай (`pages/khyanalt/posSystem/index.js`) ижил тэнцвэр (tie)
/// шийдвэрлэлттэй: чөлөөлөгдөх сүүлийн нэгжийн үнэ өөр өөр 2+ баранд тэнцүү
/// орвол [tieCandidates]-аар кассчингаас сонгуулна, эсрэг тохиолдолд автомат.
/// Version 1: зөвхөн тоо ширхэгээр тооцно, хайрцаг задлах онцлогийг тооцохгүй.
abstract final class DorvonNegUramshuulal {
  DorvonNegUramshuulal._();

  static const DorvonNegCalcResult empty = DorvonNegCalcResult();

  static DorvonNegCalcResult compute({
    required List<DorvonNegLineInput> lines,
    required int buleg,
    Map<String, int> manualPicks = const {},
  }) {
    if (buleg <= 0) return empty;

    final units = <_Unit>[];
    for (final line in lines) {
      for (var i = 0; i < line.quantity; i++) {
        units.add(_Unit(line.id, line.name, line.unitPrice));
      }
    }
    final freeCount = units.length ~/ buleg;
    if (freeCount <= 0) return empty;

    final sorted = [...units]..sort((a, b) => a.price.compareTo(b.price));
    final boundaryPrice = sorted[freeCount - 1].price;
    final strictlyBelow = sorted.where((u) => u.price < boundaryPrice).toList();
    final tiedAtBoundary = sorted.where((u) => u.price == boundaryPrice).toList();
    final slotsNeeded = freeCount - strictlyBelow.length;

    final tiedByLine = <String, DorvonNegTieCandidate>{};
    for (final u in tiedAtBoundary) {
      final existing = tiedByLine[u.id];
      tiedByLine[u.id] = DorvonNegTieCandidate(
        id: u.id,
        name: u.name,
        price: u.price,
        availableUnits: (existing?.availableUnits ?? 0) + 1,
      );
    }
    final ambiguous =
        tiedAtBoundary.length > slotsNeeded && tiedByLine.length > 1;

    List<_Unit> chosenTied;
    if (!ambiguous) {
      chosenTied = tiedAtBoundary.take(slotsNeeded).toList();
    } else {
      int pickedFor(DorvonNegTieCandidate c) {
        final raw = manualPicks[c.id] ?? 0;
        if (raw < 0) return 0;
        return raw > c.availableUnits ? c.availableUnits : raw;
      }

      final manualTotal =
          tiedByLine.values.fold<int>(0, (s, c) => s + pickedFor(c));
      if (manualTotal == slotsNeeded) {
        chosenTied = [];
        for (final c in tiedByLine.values) {
          final n = pickedFor(c);
          for (var i = 0; i < n; i++) {
            chosenTied.add(_Unit(c.id, c.name, c.price));
          }
        }
      } else {
        // Кассчин хараахан сонгоогүй байна — жагсаалтын дараалалаар автоматаар.
        chosenTied = tiedAtBoundary.take(slotsNeeded).toList();
      }
    }

    final freeUnits = [...strictlyBelow, ...chosenTied];
    final discount = freeUnits.fold<double>(0, (s, u) => s + u.price);
    final freeUnitsById = <String, int>{};
    for (final u in freeUnits) {
      freeUnitsById[u.id] = (freeUnitsById[u.id] ?? 0) + 1;
    }

    return DorvonNegCalcResult(
      freeCount: freeCount,
      discount: discount,
      freeUnitsById: freeUnitsById,
      tieCandidates: ambiguous ? tiedByLine.values.toList() : const [],
      tieSlotsNeeded: ambiguous ? slotsNeeded : 0,
    );
  }
}
