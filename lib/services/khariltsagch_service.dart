import 'dart:convert';

import 'api_service.dart';

/// Fetches `/khariltsagch` from posBack (same query shape as Next.js).
class KhariltsagchService {
  KhariltsagchService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  /// [search] is applied as case-insensitive regex across ner, ovog, utas, mail, register.
  Future<KhariltsagchListResult> fetchList({
    required String baiguullagiinId,
    required String salbariinId,
    String search = '',
    int page = 1,
    int pageSize = 100,
  }) async {
    final q = search.trim();
    final pattern = RegExp.escape(q);

    final queryMap = <String, dynamic>{
      r'$or': [
        {'ner': {r'$regex': pattern, r'$options': 'i'}},
        {'ovog': {r'$regex': pattern, r'$options': 'i'}},
        {'utas': {r'$regex': pattern, r'$options': 'i'}},
        {'mail': {r'$regex': pattern, r'$options': 'i'}},
        {'register': {r'$regex': pattern, r'$options': 'i'}},
      ],
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
    };

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/khariltsagch',
        queryParams: {
          'query': jsonEncode(queryMap),
          'order': jsonEncode({'createdAt': -1}),
          'khuudasniiDugaar': page.toString(),
          'khuudasniiKhemjee': pageSize.toString(),
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final raw = response.data!['jagsaalt'] as List<dynamic>?;
        return KhariltsagchListResult.ok(
          raw?.map((e) => e as Map<String, dynamic>).toList() ?? [],
        );
      }

      return KhariltsagchListResult.fail(
        response.message ?? 'Харилцагчдын жагсаалт ачаалахад алдаа',
      );
    } catch (e) {
      return KhariltsagchListResult.fail(e.toString());
    }
  }

  /// Web parity: `POST /khariltsagchBurtgeye` (`khariltsagchNemekhModal.js`).
  Future<KhariltsagchRegisterResult> registerBurtgeye({
    required String baiguullagiinId,
    required String salbariinId,
    required String turul,
    String? ovog,
    required String ner,
    required List<String> utas,
    String? register,
    String? mail,
    String? khayag,
  }) async {
    final body = <String, dynamic>{
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
      'turul': turul,
      'khariltsagchiinTurul': turul,
      'ner': ner.trim(),
      'utas': utas.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'khunglukhEsekh': false,
      'khunglukhTurul': 'Мөнгөн дүн',
      'khunglukhDun': 0,
      'khunglukhKhuvi': 0,
      'tsonkhniiTokhirgoo': {'posSystem': true},
    };
    final o = ovog?.trim();
    if (o != null && o.isNotEmpty) body['ovog'] = o;
    final r = register?.trim();
    if (r != null && r.isNotEmpty) body['register'] = r;
    final m = mail?.trim();
    if (m != null && m.isNotEmpty) body['mail'] = m;
    final k = khayag?.trim();
    if (k != null && k.isNotEmpty) body['khayag'] = k;

    try {
      final response = await _api.post<dynamic>(
        '/khariltsagchBurtgeye',
        body: body,
        parser: (d) => d,
      );
      final data = response.data;
      final ok = response.success &&
          (data == 'Amjilttai' ||
              (data != null && data.toString().contains('Amjilttai')));
      if (ok) {
        return KhariltsagchRegisterResult.ok();
      }
      return KhariltsagchRegisterResult.fail(
        response.message ?? 'Бүртгэл амжилтгүй',
      );
    } on ApiException catch (e) {
      return KhariltsagchRegisterResult.fail(e.message);
    } catch (e) {
      return KhariltsagchRegisterResult.fail(e.toString());
    }
  }
}

class KhariltsagchRegisterResult {
  KhariltsagchRegisterResult._({required this.success, this.error});

  final bool success;
  final String? error;

  factory KhariltsagchRegisterResult.ok() =>
      KhariltsagchRegisterResult._(success: true);

  factory KhariltsagchRegisterResult.fail(String message) =>
      KhariltsagchRegisterResult._(success: false, error: message);
}

class KhariltsagchListResult {
  KhariltsagchListResult._({
    required this.success,
    required this.rows,
    this.error,
  });

  final bool success;
  final List<Map<String, dynamic>> rows;
  final String? error;

  factory KhariltsagchListResult.ok(List<Map<String, dynamic>> rows) =>
      KhariltsagchListResult._(success: true, rows: rows);

  factory KhariltsagchListResult.fail(String message) =>
      KhariltsagchListResult._(success: false, rows: [], error: message);
}
