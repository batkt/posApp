/// Organization / branch / staff context for POS API calls (posBack via NEXT_PUBLIC_POS_API_URL).
class PosSession {
  const PosSession({
    required this.baiguullagiinId,
    required this.salbariinId,
    required this.ajiltan,
  });

  final String baiguullagiinId;
  final String salbariinId;
  final Map<String, dynamic> ajiltan;

  Map<String, dynamic> get ajiltanPayload {
    final id = ajiltan['_id'] ?? ajiltan['id'];
    final ner = ajiltan['ner'] ?? ajiltan['name'] ?? '';
    final out = <String, dynamic>{
      'id': id?.toString(),
      'ner': ner?.toString() ?? '',
    };
    // Extra fields for sales history / audit (ignored by older clients; persisted if schema allows).
    for (final k in [
      'burtgeliinDugaar',
      'mail',
      'utas',
      'AdminEsekh',
      'adminEsekh',
      'zurgiinId',
    ]) {
      final v = ajiltan[k];
      if (v != null) out[k] = v;
    }
    return out;
  }

  static PosSession? tryParse(Map<String, dynamic>? result) {
    if (result == null) return null;
    final bid = result['baiguullagiinId']?.toString();
    if (bid == null || bid.isEmpty) return null;

    String salbariinId;
    final sal = result['salbaruud'];
    if (sal is List && sal.isNotEmpty) {
      final first = sal.first;
      if (first is String) {
        salbariinId = first;
      } else if (first is Map) {
        salbariinId = first['_id']?.toString() ?? bid;
      } else {
        salbariinId = bid;
      }
    } else {
      // Wrong for `/aguulakh` (branch id must match inventory). [AuthService]
      // replaces this when `salbaruud` is empty by loading the org's first салбар.
      salbariinId = bid;
    }

    return PosSession(
      baiguullagiinId: bid,
      salbariinId: salbariinId,
      ajiltan: result,
    );
  }
}
