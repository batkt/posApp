/// One салбар from API `ajiltan.salbaruud` for login-time selection.
class BranchOption {
  const BranchOption({required this.id, required this.label});

  final String id;
  final String label;

  /// Parses `salbaruud` from `/ajiltanNevtrey` `result` (list of ids or branch maps).
  static List<BranchOption> parseList(dynamic sal) {
    if (sal is! List || sal.isEmpty) return const [];
    final out = <BranchOption>[];
    for (final e in sal) {
      if (e is String) {
        final id = e.trim();
        if (id.isNotEmpty) out.add(BranchOption(id: id, label: id));
      } else if (e is Map) {
        final id = e['_id']?.toString() ?? e['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final raw = e['ner'] ??
            e['name'] ??
            e['salbariinNer'] ??
            e['boginoNer'] ??
            e['hayag'];
        final label = raw?.toString().trim();
        out.add(BranchOption(
          id: id,
          label: (label != null && label.isNotEmpty) ? label : id,
        ));
      }
    }
    return out;
  }
}
