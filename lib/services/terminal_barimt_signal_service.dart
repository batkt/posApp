import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class TerminalBarimtSignalException implements Exception {
  TerminalBarimtSignalException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TerminalBarimtSignalItem {
  TerminalBarimtSignalItem({
    required this.id,
    required this.barimtType,
    required this.barimtData,
    required this.initiatorNer,
    required this.initiatorAjiltanId,
    this.tailbar = '',
  });

  final String id;
  final String barimtType;
  final Map<String, dynamic> barimtData;
  final String initiatorNer;
  final String initiatorAjiltanId;
  final String tailbar;

  static TerminalBarimtSignalItem? tryParse(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final rawData = m['barimtData'];
    final Map<String, dynamic> barimtData = (rawData is Map)
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    return TerminalBarimtSignalItem(
      id: id,
      barimtType: m['barimtType']?.toString() ?? 'ebarimt',
      barimtData: barimtData,
      initiatorNer: m['initiatorNer']?.toString() ?? '',
      initiatorAjiltanId: m['initiatorAjiltanId']?.toString() ?? '',
      tailbar: m['tailbar']?.toString() ?? '',
    );
  }
}

/// Mobile → posBack → POS: remote thermal receipt printing request.
class TerminalBarimtSignalService {
  TerminalBarimtSignalService({http.Client? httpClient})
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

  Future<void> createRequest({
    required String salbariinId,
    String barimtType = 'ebarimt',
    required Map<String, dynamic> barimtData,
    String tailbar = '',
  }) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalBarimtKhuseeltUusgey');
    debugPrint('>>> [TerminalBarimtSignalService] POST $uri with salbariinId: "$salbariinId"');
    final res = await _http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'salbariinId': salbariinId,
            'barimtType': barimtType,
            'barimtData': barimtData,
            'tailbar': tailbar,
          }),
        )
        .timeout(ApiConfig.timeout);
    debugPrint('>>> [TerminalBarimtSignalService] Response status: ${res.statusCode}, body: ${res.body}');
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TerminalBarimtSignalException(
        _errMsg(decoded) ?? 'Баримт хэвлэх хүсэлт илгээхэд алдаа',
        statusCode: res.statusCode,
      );
    }
    if (decoded is Map && decoded['success'] == false) {
      throw TerminalBarimtSignalException(
        _errMsg(decoded) ?? 'Амжилтгүй',
        statusCode: res.statusCode,
      );
    }
  }

  Future<List<TerminalBarimtSignalItem>> fetchPending({
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalBarimtKhuseeltPending');
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
      throw TerminalBarimtSignalException(
        _errMsg(decoded) ?? 'Жагсаалт авахад алдаа',
        statusCode: res.statusCode,
      );
    }
    if (decoded is! Map) return const [];
    final data = decoded['data'];
    if (data is! List) return const [];
    return data
        .map((e) => TerminalBarimtSignalItem.tryParse(Map<String, dynamic>.from(e as Map)))
        .whereType<TerminalBarimtSignalItem>()
        .toList();
  }

  Future<void> markCompleted(String id) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalBarimtKhuseeltDuussan');
    final res = await _http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({'id': id}),
        )
        .timeout(ApiConfig.timeout);
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TerminalBarimtSignalException(
        _errMsg(decoded) ?? 'Тэмдэглэхэд алдаа',
        statusCode: res.statusCode,
      );
    }
  }

  Future<void> cancelRequest(String id) async {
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/terminalBarimtKhuseeltTsuts');
    final res = await _http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({'id': id}),
        )
        .timeout(ApiConfig.timeout);
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TerminalBarimtSignalException(
        _errMsg(decoded) ?? 'Цуцлахад алдаа',
        statusCode: res.statusCode,
      );
    }
  }
}
