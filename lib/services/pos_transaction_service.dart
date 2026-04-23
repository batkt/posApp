import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;

import '../models/pos_session.dart';
import '../models/sales_model.dart';
import 'api_service.dart';

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

  static double _finiteDouble(num? value, {double fallback = 0}) {
    final v = value?.toDouble();
    if (v == null || !v.isFinite || v.isNaN) return fallback;
    return v;
  }

  static double _fixed2Num(num? value, {double fallback = 0}) {
    return double.parse(
        _finiteDouble(value, fallback: fallback).toStringAsFixed(2));
  }

  static String _fixed2String(num? value, {double fallback = 0}) {
    return _finiteDouble(value, fallback: fallback).toStringAsFixed(2);
  }

  Map<String, dynamic> _buildSaleBaraa({
    required dynamic product,
    required String fallbackSalbariinId,
    required double unitPrice,
    required double lineTotal,
  }) {
    final noatBodohEsekh = product.noatBodohEsekh == true;
    final nhatBodohEsekh = product.nhatBodohEsekh == true;
    final lineNet = noatBodohEsekh ? (lineTotal / 1.1) : lineTotal;
    final lineVat = noatBodohEsekh ? (lineTotal - lineNet) : 0.0;

    return {
      if ((product.id ?? '').toString().isNotEmpty) '_id': product.id,
      'ner': product.name,
      'code': product.code,
      'barCode': product.barCode,
      'baiguullagiinId': product.baiguullagiinId,
      'salbariinId': product.salbariinId ?? fallbackSalbariinId,
      'angilal': product.angilal ?? product.category,
      'khemjikhNegj': product.khemjikhNegj,
      'niitUne': _fixed2Num(unitPrice),
      'zarakhUne': _fixed2Num(unitPrice),
      // posBack ebarimtShine builder uses this directly for totalAmount.
      'zarsanNiitUne': _fixed2Num(lineTotal),
      'hungulsunDun': 0,
      'urtugUne': _fixed2Num(product.urtugUne ?? product.costPrice),
      'uldegdel': _fixed2Num(product.uldegdel ?? product.stock),
      'idevkhteiEsekh': product.isAvailable,
      'zurgiinId': product.zurgiinId,
      'noatBodohEsekh': noatBodohEsekh,
      'nhatBodohEsekh': nhatBodohEsekh,
      'ognooniiMedeelelBurtgekhEsekh': product.ognooniiMedeelelBurtgekhEsekh,
      'noatiinDun': _fixed2Num(lineVat),
      'nhatiinDun': 0,
      'noatguiDun': _fixed2Num(lineNet),
      'shirkheglekhEsekh': product.shirkheglekhEsekh,
      'negKhairtsaganDahiShirhegiinToo':
          _fixed2Num(product.negKhairtsaganDahiShirhegiinToo),
      // Keep frontend-compatible keys; Product model doesn't expose these lists.
      'buuniiUneJagsaalt': const [],
      'uramshuulal': const [],
      'nemeltMedeelel': const [],
      'orlogdsonEsekh': product.orlogdsonEsekh,
      'zarlagdsanEsekh': product.zarlagdsanEsekh,
      'ajiltan': product.ajiltan,
    }..removeWhere((_, v) => v == null);
  }

  /// Recursively removes invalid numeric values before sending JSON to backend.
  static dynamic _sanitizeJson(dynamic value) {
    if (value is num) {
      final v = value.toDouble();
      return (v.isFinite && !v.isNaN) ? value : 0;
    }
    if (value is String) {
      final t = value.trim().toLowerCase();
      if (t == 'nan' || t == 'infinity' || t == '-infinity') return '0';
      if (t.contains('nan') || t.contains('infinity')) return '0';
      final parsed = double.tryParse(t);
      if (parsed != null && (!parsed.isFinite || parsed.isNaN)) return '0';
      return value;
    }
    if (value is List) {
      return value.map(_sanitizeJson).toList();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _sanitizeJson(v);
      });
      return out;
    }
    return value;
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
    bool baraaNUATModalOpen = false,
    Map<String, dynamic>? khariltsagch,
    /// Web `tulburTuluhModal`: `tulbur[]` with `turul: "zeel"` must include `khariltsagchiinId`
    /// for `guilgeeRoute` receivable (`avlagaGuilgeeKhadgalya`).
    String? zeelKhariltsagchiinId,
  }) async {
    final items = sales.currentSaleItems;
    final baraanuud = items.map((line) {
      final p = line.product;
      final qty = _finiteDouble(line.quantity);
      final unitPrice = _finiteDouble(line.unitPrice);
      final lineTotal = unitPrice * qty;
      return {
        'baraa': _buildSaleBaraa(
          product: p,
          fallbackSalbariinId: session.salbariinId,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
        ),
        'niitUne': _fixed2String(lineTotal),
        'too': qty,
        'salbariinId': p.salbariinId ?? session.salbariinId,
      };
    }).toList();

    // Web `tulbur`: `[{ turul, une, khariltsagchiinId? }]`
    // Cash: `une` = төлсөн дүн minus хариулт; card/dans/zeel: full `tulsunDun`.
    final lineUne = paymentTurul == 'belen'
        ? _finiteDouble(tulsunDun) - _finiteDouble(hariult)
        : _finiteDouble(tulsunDun);
    if (paymentTurul == 'zeel') {
      final zid = zeelKhariltsagchiinId?.trim();
      if (zid == null || zid.isEmpty) {
        throw PosTransactionException('Зээл төлбөрт харилцагч сонгоно уу');
      }
    }
    final tulburLine = <String, dynamic>{
      'turul': paymentTurul,
      'une': _fixed2Num(lineUne),
    };
    final zTrim = zeelKhariltsagchiinId?.trim();
    if (paymentTurul == 'zeel' && zTrim != null && zTrim.isNotEmpty) {
      tulburLine['khariltsagchiinId'] = zTrim;
    }
    final tulbur = [tulburLine];

    final body = <String, dynamic>{
      'baiguullagiinId': session.baiguullagiinId,
      'salbariinId': session.salbariinId,
      'turul': 'pos',
      'tulsunDun': _fixed2Num(tulsunDun),
      'hungulsunDun': _fixed2Num(hungulsunDun),
      'noatiinDun': _fixed2Num(noatiinDun),
      'noatguiDun': _fixed2Num(noatguiDun),
      'nhatiinDun': _fixed2Num(nhatiinDun),
      'hariult': _fixed2Num(hariult),
      'niitUne': _fixed2Num(niitUne),
      'khariltsagch': khariltsagch,
      'guilgeeniiDugaar': guilgeeniiDugaar,
      'baraaNUATModalOpen': baraaNUATModalOpen,
      'baraanuud': baraanuud,
      'tulbur': tulbur,
      'ajiltan': session.ajiltanPayload,
    };

    body.removeWhere((k, v) => v == null);

    final safeBody = _sanitizeJson(body);
    var encodedBody = jsonEncode(safeBody);
    encodedBody = encodedBody
        .replaceAll('"NaN"', '"0"')
        .replaceAll('"nan"', '"0"')
        .replaceAll('"Infinity"', '"0"')
        .replaceAll('"-Infinity"', '"0"')
        .replaceAll('"infinity"', '"0"')
        .replaceAll('"-infinity"', '"0"');
    if (kDebugMode && encodedBody.toLowerCase().contains('nan')) {
      debugPrint('[guilgeeniiTuukhKhadgalya] encoded body still had NaN token');
    }
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/guilgeeniiTuukhKhadgalya');
    final res = await _http
        .post(uri, headers: _headers(), body: encodedBody)
        .timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PosTransactionException(
        _messageFromErrorBody(res.body) ?? 'Гүйлгээ хадгалахад алдаа',
        statusCode: res.statusCode,
      );
    }

    return _decodeBody(res.body);
  }

  /// Parses [submitGuilgeeniiTuukh] response: plain id string or `{ guilgeeniiId }`.
  static String? parseGuilgeeniiMongoIdFromSaveResponse(dynamic body) {
    if (body == null) return null;
    if (body is String) {
      final s = body.trim();
      if (s.isEmpty) return null;
      if (RegExp(r'^[a-f\d]{24}$', caseSensitive: false).hasMatch(s)) {
        return s;
      }
      return s;
    }
    if (body is Map) {
      final v = body['guilgeeniiId'] ?? body['_id'];
      return v?.toString();
    }
    return body.toString();
  }

  /// Same as web `POST /ebarimtShivye` after successful sale save.
  /// Returns decoded response only when e-barimt creation succeeded.
  Future<Map<String, dynamic>?> requestEbarimtAfterSale({
    required String guilgeeniiMongoId,
    required String baiguullagiinId,
    required String salbariinId,
    String register = '',
    String? turul,
    String? customerTin,
  }) async {
    if (guilgeeniiMongoId.isEmpty) return null;
    final uri = Uri.parse('${ApiConfig.posBaseUrl}/ebarimtShivye');
    final payload = _sanitizeJson(<String, dynamic>{
      'guilgeeniiId': guilgeeniiMongoId,
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
      'register': register,
      if (turul != null && turul.isNotEmpty) 'turul': turul,
      if (customerTin != null && customerTin.isNotEmpty)
        'customerTin': customerTin,
    });
    try {
      final res = await _http
          .post(uri, headers: _headers(), body: jsonEncode(payload))
          .timeout(ApiConfig.timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint('[ebarimtShivye] HTTP ${res.statusCode}');
          debugPrint('[ebarimtShivye] payload=${jsonEncode(payload)}');
          debugPrint('[ebarimtShivye] body=${res.body}');
        }
        return null;
      }
      final data = _decodeBody(res.body);
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final ok = m['success'] == true ||
            m['status']?.toString().toUpperCase() == 'SUCCESS';
        if (!ok && kDebugMode) {
          debugPrint('[ebarimtShivye] payload=${jsonEncode(payload)}');
          debugPrint('[ebarimtShivye] response=${jsonEncode(m)}');
        }
        return ok ? m : null;
      }
      if (kDebugMode) {
        debugPrint('[ebarimtShivye] payload=${jsonEncode(payload)}');
        debugPrint('[ebarimtShivye] non-map response=${res.body}');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Convenience wrapper for citizen e-barimt (`register: ''`).
  Future<Map<String, dynamic>?> requestCitizenEbarimtAfterSale({
    required String guilgeeniiMongoId,
    required String baiguullagiinId,
    required String salbariinId,
  }) {
    return requestEbarimtAfterSale(
      guilgeeniiMongoId: guilgeeniiMongoId,
      baiguullagiinId: baiguullagiinId,
      salbariinId: salbariinId,
      register: '',
    );
  }

  /// Same as web `GET /tatvaraasBaiguullagaAvya/:regno` — TIN / org lookup for register.
  Future<Map<String, dynamic>?> fetchTatvarRegisterInfo(String regNo) async {
    final trimmed = regNo.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.parse(
      '${ApiConfig.posBaseUrl}/tatvaraasBaiguullagaAvya/${Uri.encodeComponent(trimmed)}',
    );
    try {
      final res =
          await _http.get(uri, headers: _headers()).timeout(ApiConfig.timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final data = _decodeBody(res.body);
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
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
      case 'qpay':
        return 'qpay';
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

  /// Snackbars: short Mongolian only — no stacked PlatformException / JSON noise.
  static String toUserMessage(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return raw;

    // UniPOS / terminal: show exactly one of these phrases if present (substring match).
    const terminalSnippets = <String>[
      'Карт унших хугацаа дууссан',
      'Карт унших оролдлого хийгдээгүй',
      'Карттай харьцахад алдаа гарлаа',
      'Сүлжээний холболтонд алдаа гарлаа',
    ];
    for (final s in terminalSnippets) {
      if (t.contains(s)) return s;
    }

    final l = t.toLowerCase();
    if (t.contains('Гүйлгээ цуцлагдсан') ||
        (l.contains('гүйлгээ') && l.contains('цуцлагдсан')) ||
        (l.contains('transaction') && l.contains('cancel')) ||
        l.contains('txn has been cancelled') ||
        l.contains('txn cancelled') ||
        l.contains('user cancel')) {
      return 'Төлбөр цуцлагдсан';
    }

    t = _stripVerboseErrorWrapper(t);
    // One line, reasonable length for snackbar.
    final line = t.split(RegExp(r'[\r\n]+')).map((s) => s.trim()).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => t,
        );
    if (line.length > 160) {
      return '${line.substring(0, 157)}…';
    }
    return line;
  }

  static String _stripVerboseErrorWrapper(String t) {
    var u = t;
    const pfx = 'PlatformException(';
    if (u.startsWith(pfx)) {
      const msgKey = 'message: ';
      final i = u.indexOf(msgKey);
      if (i >= 0) {
        var rest = u.substring(i + msgKey.length).trim();
        if (rest.startsWith('"')) {
          rest = rest.substring(1);
          final end = rest.indexOf('"');
          if (end > 0) return rest.substring(0, end).trim();
        }
      }
    }
    return u;
  }

  @override
  String toString() => message;
}

/// Snackbar-safe text for payment failures ([PosTransactionException] or any [Object]).
String posPaymentErrorUserMessage(Object error) {
  if (error is PosTransactionException) {
    return PosTransactionException.toUserMessage(error.message);
  }
  if (error is PlatformException) {
    final msg = (error.message ?? '').trim();
    if (msg.isNotEmpty) {
      return PosTransactionException.toUserMessage(msg);
    }
    final det = error.details?.toString().trim();
    if (det != null && det.isNotEmpty) {
      return PosTransactionException.toUserMessage(det);
    }
    return PosTransactionException.toUserMessage(error.code);
  }
  return PosTransactionException.toUserMessage(error.toString());
}
