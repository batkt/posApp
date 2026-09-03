import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

import 'socket_service.dart';

class TerminalTulburSignalException implements Exception {
  TerminalTulburSignalException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TerminalPaySignalItem {
  TerminalPaySignalItem({
    required this.id,
    required this.amountMnt,
    required this.initiatorNer,
    required this.initiatorAjiltanId,
    this.tailbar = '',
    this.baraanuud = const [],
  });

  final String id;
  final double amountMnt;
  final String initiatorNer;
  final String initiatorAjiltanId;
  final String tailbar;
  final List<dynamic> baraanuud;

  static TerminalPaySignalItem? tryParse(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final amt = (m['amountMnt'] is num)
        ? (m['amountMnt'] as num).toDouble()
        : double.tryParse(m['amountMnt']?.toString() ?? '') ?? 0;
    final rawBaraanuud = m['baraanuud'] ?? m['items'];
    return TerminalPaySignalItem(
      id: id,
      amountMnt: amt,
      initiatorNer: m['initiatorNer']?.toString() ?? '',
      initiatorAjiltanId: m['initiatorAjiltanId']?.toString() ?? '',
      tailbar: m['tailbar']?.toString() ?? '',
      baraanuud: (rawBaraanuud is List) ? rawBaraanuud : const [],
    );
  }
}

class TerminalTulburSignalService {
  TerminalTulburSignalService({http.Client? httpClient})
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

  static String? _errMsg(dynamic decoded) {
    if (decoded is Map) {
      return decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          decoded['msg']?.toString();
    }
    return null;
  }

  Future<TerminalPaySignalItem?> createRequest({
    required String salbariinId,
    required double amountMnt,
    String tailbar = '',
  }) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalTulburKhuseeltUusgey');
    final res = await _http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'salbariinId': salbariinId,
            'amountMnt': amountMnt,
            'tailbar': tailbar,
          }),
        )
        .timeout(ApiConfig.timeout);
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TerminalTulburSignalException(
        _errMsg(decoded) ?? 'Хүсэлт илгээхэд алдаа',
        statusCode: res.statusCode,
      );
    }
    if (decoded is Map && decoded['success'] == false) {
      throw TerminalTulburSignalException(
        _errMsg(decoded) ?? 'Амжилтгүй',
        statusCode: res.statusCode,
      );
    }

    if (decoded is Map && decoded['data'] is Map) {
      final item = TerminalPaySignalItem.tryParse(Map<String, dynamic>.from(decoded['data']));
      if (item != null) {
        SocketService.instance.notifyLocalPayRequest({
          'id': item.id,
          'amountMnt': item.amountMnt,
          'initiatorNer': item.initiatorNer,
          'initiatorAjiltanId': item.initiatorAjiltanId,
          'tailbar': item.tailbar,
        });
      }
      return item;
    }
    return null;
  }

  Future<List<TerminalPaySignalItem>> fetchPending({
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalTulburKhuseeltPending');
    final res = await _http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'baiguullagiinId': baiguullagiinId,
            'salbariinId': salbariinId,
          }),
        )
        .timeout(ApiConfig.timeout);
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TerminalTulburSignalException(
        _errMsg(decoded) ?? 'Жагсаалт авахад алдаа',
        statusCode: res.statusCode,
      );
    }
    if (decoded is! Map) return const [];
    final data = decoded['data'];
    if (data is! List) return const [];
    return data
        .map((e) => TerminalPaySignalItem.tryParse(Map<String, dynamic>.from(e as Map)))
        .whereType<TerminalPaySignalItem>()
        .toList();
  }

  Future<void> markCompleted(String id) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalTulburKhuseeltDuussan');
    final res = await _http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({'id': id}),
        )
        .timeout(ApiConfig.timeout);
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TerminalTulburSignalException(
        _errMsg(decoded) ?? 'Тэмдэглэхэд алдаа',
        statusCode: res.statusCode,
      );
    }
  }

  Future<void> cancelRequest(String id) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalTulburKhuseeltTsuts');
    final res = await _http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({'id': id}),
        )
        .timeout(ApiConfig.timeout);
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TerminalTulburSignalException(
        _errMsg(decoded) ?? 'Цуцлахад алдаа',
        statusCode: res.statusCode,
      );
    }
  }
}
