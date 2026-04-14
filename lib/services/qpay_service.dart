import 'api_service.dart';
import 'pos_transaction_service.dart';

/// Web parity: `POST /qpayGargaya`, `POST /qpayShalgakh` (same as `tulburTuluhModal.js` + `qpay/index.js`).
class QpayService {
  QpayService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  /// Returns `khariu` map (includes `qr_image` base64) from `{ khariu }` response.
  Future<Map<String, dynamic>> gargaya({
    required double dun,
    required String baiguullagiinId,
    required String salbariinId,
    required String zakhialgiinDugaar,
  }) async {
    final resp = await _api.post<dynamic>(
      '/qpayGargaya',
      body: {
        'dun': dun,
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'zakhialgiinDugaar': zakhialgiinDugaar,
      },
      parser: (json) => json,
    );
    if (!resp.success || resp.data == null) {
      throw PosTransactionException(resp.message ?? 'QPay үүсгэхэд алдаа');
    }
    final root = resp.data;
    if (root is! Map) {
      throw PosTransactionException('QPay хариу буруу байна');
    }
    final khariu = root['khariu'];
    if (khariu is! Map) {
      throw PosTransactionException('QPay qr_image авах боломжгүй');
    }
    return Map<String, dynamic>.from(khariu);
  }

  /// `QuickQpayObject.tulsunEsekh === true` after callback or bank confirms.
  Future<bool> shalgakh({
    required String baiguullagiinId,
    required String salbariinId,
    required String zakhialgiinDugaar,
  }) async {
    final resp = await _api.post<dynamic>(
      '/qpayShalgakh',
      body: {
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'zakhialgiinDugaar': zakhialgiinDugaar,
      },
      parser: (json) => json,
    );
    if (!resp.success || resp.data == null) return false;
    final data = resp.data;
    if (data is! Map) return false;
    return data['tulsunEsekh'] == true;
  }
}
