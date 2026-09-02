/// One салбар from API `ajiltan.salbaruud` or `/salbarAvya` for login-time selection.
class BranchOption {
  const BranchOption({required this.id, required this.label});

  final String id;
  final String label;

  /// Parses `salbaruud` from `/ajiltanNevtrey` `result` (list of ids or branch maps).
  /// If [orgSalbaruud] is provided, uses its name map to resolve branch IDs into human-readable labels.
  static List<BranchOption> parseList(
    dynamic sal, {
    List<Map<String, dynamic>>? orgSalbaruud,
  }) {
    if (sal is! List || sal.isEmpty) return const [];

    final orgNameMap = <String, String>{};
    if (orgSalbaruud != null && orgSalbaruud.isNotEmpty) {
      for (final b in orgSalbaruud) {
        final id = (b['_id']?.toString() ?? b['id']?.toString() ?? '').trim();
        final name = b['ner'] ??
            b['name'] ??
            b['salbariinNer'] ??
            b['boginoNer'] ??
            b['hayag'];
        String? strName;
        if (name is Map) {
          strName = (name['mn'] ?? name['mon'] ?? name['en'] ?? name.values.firstOrNull)?.toString();
        } else {
          strName = name?.toString();
        }
        if (id.isNotEmpty && strName != null && strName.trim().isNotEmpty) {
          orgNameMap[id] = strName.trim();
        }
      }
    }

    final out = <BranchOption>[];
    for (final e in sal) {
      if (e is String) {
        final id = e.trim();
        if (id.isNotEmpty) {
          final label = orgNameMap[id] ?? id;
          out.add(BranchOption(id: id, label: label));
        }
      } else if (e is Map) {
        final id = (e['_id']?.toString() ?? e['id']?.toString() ?? '').trim();
        if (id.isEmpty) continue;
        final raw = e['ner'] ??
            e['name'] ??
            e['salbariinNer'] ??
            e['boginoNer'] ??
            e['hayag'];
        String? label;
        if (raw is Map) {
          label = (raw['mn'] ?? raw['mon'] ?? raw['en'] ?? raw.values.firstOrNull)
              ?.toString();
        } else {
          label = raw?.toString();
        }
        label = label?.trim();
        if ((label == null || label.isEmpty || label == id) && orgNameMap.containsKey(id)) {
          label = orgNameMap[id];
        }
        out.add(BranchOption(
          id: id,
          label: (label != null && label.isNotEmpty) ? label : id,
        ));
      }
    }
    return out;
  }
}
