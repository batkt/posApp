import 'api_service.dart';
import 'pos_transaction_service.dart';

/// TokiPay — вэбийн `components/modalBody/toki`-тай ижил серверийн endpoint-ууд.
/// Нэвтрэх мэдээлэл байгууллага бүрийн тохиргоонд, зөвхөн сервер дээр.
class TokiService {
  TokiService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await _api.post<dynamic>(path, body: body, parser: (json) => json);
    if (!resp.success || resp.data is! Map) {
      throw PosTransactionException(resp.message ?? 'TokiPay алдаа');
    }
    return Map<String, dynamic>.from(resp.data as Map);
  }

  /// `{ orderId, qrText, ... }` — qrText-ийг QR болгож харуулна.
  Future<Map<String, dynamic>> qrGargaya({
    required double dun,
    required String baiguullagiinId,
    required String salbariinId,
    required String guilgeeniiDugaar,
  }) =>
      _post('/tokiQrGargaya', {
        'dun': dun,
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'guilgeeniiDugaar': guilgeeniiDugaar,
      });

  /// Хэрэглэгчийн Toki апп руу төлбөрийн хүсэлт илгээнэ.
  Future<Map<String, dynamic>> utasaarGargaya({
    required double dun,
    required String baiguullagiinId,
    required String salbariinId,
    required String guilgeeniiDugaar,
    required String utas,
  }) =>
      _post('/tokiUtasaarGargaya', {
        'dun': dun,
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'guilgeeniiDugaar': guilgeeniiDugaar,
        'utas': utas,
      });

  /// `{ tulsunEsekh, tuluv: PENDING|APPROVED|EXPIRED|CANCELLED, ... }`
  Future<Map<String, dynamic>> shalgakh(String orderId) =>
      _post('/tokiShalgakh', {'orderId': orderId});

  Future<void> tsutslakh(String orderId) async {
    try {
      await _post('/tokiTsutslakh', {'orderId': orderId});
    } catch (_) {}
  }
}
