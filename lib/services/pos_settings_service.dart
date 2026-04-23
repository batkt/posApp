import 'dart:convert';

import '../payment/pos_payment_core.dart';
import 'api_service.dart';

/// Organization / branch / employee settings (`tokhirgoo`, web `pages/khyanalt/tokhirgoo`).
class PosSettingsService {
  PosSettingsService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  Future<Map<String, dynamic>?> fetchBaiguullaga(String baiguullagiinId) async {
    final oid = baiguullagiinId.trim();
    if (oid.isEmpty) return null;
    try {
      final response = await _api.get<dynamic>(
        '/baiguullaga/$oid',
        parser: (data) => data,
      );
      if (!response.success || response.data == null) return null;
      dynamic doc = response.data;
      if (doc is Map && doc['data'] is Map) doc = doc['data'];
      if (doc is Map) return Map<String, dynamic>.from(doc);
    } catch (_) {}
    return null;
  }

  /// `POST /salbarAvya` — branch list for “Салбар”.
  Future<List<Map<String, dynamic>>> fetchSalbaruud(String baiguullagiinId) async {
    try {
      final response = await _api.post<dynamic>(
        '/salbarAvya',
        body: {'baiguullagiinId': baiguullagiinId},
        parser: (data) => data,
      );
      if (!response.success || response.data == null) return [];
      final d = response.data;
      if (d is! List) return [];
      return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// `PUT /ajiltan/:id` — same as web `updateMethod('ajiltan', ...)`.
  Future<bool> putAjiltan(Map<String, dynamic> body) async {
    final id = body['_id']?.toString() ?? body['id']?.toString() ?? '';
    if (id.isEmpty) return false;
    try {
      final response = await _api.put<dynamic>(
        '/ajiltan/$id',
        body: body,
        parser: (data) => data,
      );
      return response.success &&
          (response.data == 'Amjilttai' || response.data?.toString() == 'Amjilttai');
    } catch (_) {
      return false;
    }
  }

  /// Org-level keys under `baiguullaga.tokhirgoo` (web `Khaalt`, parts of `Medegdel`).
  Future<bool> tokhirgooOruulya({
    required String baiguullagiinId,
    required Map<String, dynamic> tokhirgooFields,
  }) async {
    try {
      final tokhirgoo = <String, dynamic>{...tokhirgooFields};
      final response = await _api.post<dynamic>(
        '/tokhirgooOruulya',
        body: {
          'baiguullagiinId': baiguullagiinId,
          'tokhirgoo': tokhirgoo,
        },
        parser: (data) => data,
      );
      return response.success &&
          (response.data == 'Amjilttai' || response.data?.toString() == 'Amjilttai');
    } catch (_) {
      return false;
    }
  }

  /// Branch-scoped `salbaruud[i].tokhirgoo` (web `tokhirgooSalbarOruulya`).
  Future<bool> tokhirgooSalbarOruulya({
    required int branchIndex,
    required Map<String, dynamic> tokhirgooPayload,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/tokhirgooSalbarOruulya',
        body: {
          'index': branchIndex,
          'tokhirgoo': tokhirgooPayload,
        },
        parser: (data) => data,
      );
      return response.success &&
          (response.data == 'Amjilttai' || response.data?.toString() == 'Amjilttai');
    } catch (_) {
      return false;
    }
  }

  /// `POST /angilalNemii` — web `BaraaniiAngilal`.
  Future<bool> angilalNemii({
    required String baiguullagiinId,
    required String angilal,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/angilalNemii',
        body: {
          'baiguullagiinId': baiguullagiinId,
          'angilal': angilal.trim(),
        },
        parser: (data) => data,
      );
      return response.success &&
          (response.data == 'Amjilttai' || response.data?.toString() == 'Amjilttai');
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> loyaltyErkhAvya(String baiguullagiinId) async {
    try {
      final response = await _api.post<dynamic>(
        '/loyaltyErkhAvya',
        body: {'baiguullagiinId': baiguullagiinId},
        parser: (data) => data,
      );
      if (!response.success || response.data == null) return null;
      final d = response.data;
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }

  Future<bool> loyaltyErkhOruulya({
    required String baiguullagiinId,
    required bool ashiglakhEsekh,
    required int khunglukhKhuvi,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/loyaltyErkhOruulya',
        body: {
          'id': baiguullagiinId,
          'ashiglakhEsekh': ashiglakhEsekh,
          'khunglukhKhuvi': khunglukhKhuvi,
        },
        parser: (data) => data,
      );
      return response.success &&
          (response.data == 'Amjilttai' || response.data?.toString() == 'Amjilttai');
    } catch (_) {
      return false;
    }
  }

  /// Org + branch `tokhirgoo` merged — web `salbar?.tokhirgoo` / `baiguullaga.tokhirgoo`.
  Future<PosWebTaxContext> loadPosWebTaxContext({
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    final org = await fetchBaiguullaga(baiguullagiinId);
    final orgTok = org?['tokhirgoo'];
    final orgMap = orgTok is Map
        ? Map<String, dynamic>.from(orgTok)
        : <String, dynamic>{};

    final salb = await fetchSalbaruud(baiguullagiinId);
    Map<String, dynamic>? branchTok;
    for (final s in salb) {
      if (s['_id']?.toString() == salbariinId) {
        final t = s['tokhirgoo'];
        if (t is Map) branchTok = Map<String, dynamic>.from(t);
        break;
      }
    }

    final merged = <String, dynamic>{...orgMap};
    if (branchTok != null) merged.addAll(branchTok);

    final borl = merged['borluulaltNUAT'] == true;
    final shine = merged['eBarimtShine'] == true;

    return PosWebTaxContext(
      borluulaltNUAT: borl,
      eBarimtShine: shine,
      isModalOpenTulbur: true,
      baraaNUATModalOpen: false,
    );
  }

  /// Web `useDans` — query uses `barilgiinId` (legacy spelling).
  Future<List<Map<String, dynamic>>> fetchDansList(String salbariinId) async {
    final q = jsonEncode({'barilgiinId': salbariinId});
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/Dans',
        queryParams: {
          'query': q,
          'order': '{"createdAt":-1}',
          'khuudasniiDugaar': '1',
          'khuudasniiKhemjee': '100',
        },
        parser: (data) => data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map),
      );
      if (!response.success || response.data == null) return [];
      final raw = response.data!['jagsaalt'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final posSettingsService = PosSettingsService();
