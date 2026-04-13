import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pos_session.dart';
import '../models/sales_model.dart';
import 'api_service.dart';

/// POS backend (posBack) — same routes as Next.js `pos` (`posUilchilgee`).
class PosTransactionService {
  PosTransactionService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  Map<String, String> _headers() {
    final h = Map<String, String>.from(ApiConfig.defaultHeaders);
    final t = posApiService.token;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'bearer $t';
    }
    return h;
  }

  static dynamic _decodeBody(String body) {
    final t = body.trim();
    if (t.isEmpty) return null;
    try {
      return jsonDecode(t);
    } catch (_) {
      return t;
    }
  }

  /// Same as web `POST /zakhialgiinDugaarAvya` when the first line item is added.
  Future<String?> fetchZakhialgiinDugaar() async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/zakhialgiinDugaarAvya');
    final res = await _http
        .post(uri, headers: _headers(), body: jsonEncode({}))
        .timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PosTransactionException(
        _messageFromErrorBody(res.body) ?? 'Захиалгын дугаар авахад алдаа',
        statusCode: res.statusCode,
      );
    }
    final data = _decodeBody(res.body);
    if (data == null) return null;
    if (data is String) return data;
    return data.toString();
  }

  /// Same payload shape as `tulburTuluhModal.js` → `POST /guilgeeniiTuukhKhadgalya`.
  Future<dynamic> submitGuilgeeniiTuukh({
    required PosSession session,
    required SalesModel sales,
    required String paymentTurul,
    required double niitUne,
    required double tulsunDun,
    required double hariult,
    required double hungulsunDun,
    required double noatiinDun,
    required double noatguiDun,
    required double nhatiinDun,
    required String guilgeeniiDugaar,
    bool baraaNUATModalOpen = true,
    Map<String, dynamic>? khariltsagch,
  }) async {
    final items = sales.currentSaleItems;
    final baraanuud = items.map((line) {
      final p = line.product;
      final lineTotal = line.unitPrice * line.quantity;
      return {
        'baraa': p.toBaraaDocument(
          fallbackSalbariinId: session.salbariinId,
        ),
        'niitUne': lineTotal.toStringAsFixed(2),
        'too': line.quantity,
        'salbariinId': p.salbariinId ?? session.salbariinId,
      };
    }).toList();

    final lineUne =
        paymentTurul == 'belen' ? tulsunDun - hariult : tulsunDun;
    final tulbur = [
      {
        'turul': paymentTurul,
        'une': lineUne,
      }
    ];

    final body = <String, dynamic>{
      'baiguullagiinId': session.baiguullagiinId,
      'salbariinId': session.salbariinId,
      'turul': 'pos',
      'tulsunDun': tulsunDun,
      'hungulsunDun': double.parse(hungulsunDun.toStringAsFixed(2)),
      'noatiinDun': double.parse(noatiinDun.toStringAsFixed(2)),
      'noatguiDun': double.parse(noatguiDun.toStringAsFixed(2)),
      'nhatiinDun': double.parse(nhatiinDun.toStringAsFixed(2)),
      'hariult': hariult,
      'niitUne': double.parse(niitUne.toStringAsFixed(2)),
      'khariltsagch': khariltsagch,
      'guilgeeniiDugaar': guilgeeniiDugaar,
      'baraaNUATModalOpen': baraaNUATModalOpen,
      'baraanuud': baraanuud,
      'tulbur': tulbur,
      'ajiltan': session.ajiltanPayload,
    };

    body.removeWhere((k, v) => v == null);

    final uri = Uri.parse('${ApiConfig.posBaseUrl}/guilgeeniiTuukhKhadgalya');
    final res = await _http
        .post(uri, headers: _headers(), body: jsonEncode(body))
        .timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PosTransactionException(
        _messageFromErrorBody(res.body) ?? 'Гүйлгээ хадгалахад алдаа',
        statusCode: res.statusCode,
      );
    }

    return _decodeBody(res.body);
  }

  static String? _messageFromErrorBody(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        return j['aldaa']?.toString() ??
            j['message']?.toString() ??
            j['error']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Maps app payment ids to backend `turul` keys.
  static String paymentMethodToTurul(String id) {
    switch (id) {
      case 'cash':
        return 'belen';
      case 'card':
        return 'cart';
      case 'account':
        return 'khariltsakh';
      case 'credit':
        return 'zeel';
      default:
        return 'belen';
    }
  }
}

class PosTransactionException implements Exception {
  PosTransactionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
