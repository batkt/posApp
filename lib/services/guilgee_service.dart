import 'dart:convert';
import 'dart:math' as math;

import 'api_service.dart';
import '../models/cart_model.dart';
import '../models/sales_model.dart';
import '../payment/pos_payment_core.dart';

Map<String, dynamic> _stringKeyedMap(Map map) {
  return Map<String, dynamic>.from(
    map.map((k, v) => MapEntry(k.toString(), v)),
  );
}

/// Normalizes `GET /guilgeeniiTuukh` JSON: root may be the paginated object, or `{ success, data: … }`,
/// sometimes with **nested** `data` (zevback / gateway). `jagsaalt` may be a JSON string.
List<dynamic>? _guilgeeListJagsaaltFromResponse(Map<String, dynamic> map) {
  const maxDepth = 10;
  var m = map;

  for (var depth = 0; depth < maxDepth; depth++) {
    dynamic j = m['jagsaalt'];
    if (j is String) {
      try {
        j = jsonDecode(j);
      } catch (_) {
        j = null;
      }
    }
    if (j is List) return j;

    dynamic d = m['data'] ?? m['payload'] ?? m['result'];
    if (d is String) {
      try {
        d = jsonDecode(d);
      } catch (_) {
        return null;
      }
    }
    if (d is List) return d;
    if (d is Map) {
      m = _stringKeyedMap(d);
      continue;
    }
    break;
  }
  return null;
}

/// Wraps decoded GET body so [listParkedGuilgeeniiTuukh] / [listGuilgeeniiTuukh] always see a Map.
Map<String, dynamic> _guilgeeTuukhRootAsMap(dynamic decoded) {
  if (decoded is List) {
    return <String, dynamic>{'jagsaalt': decoded};
  }
  if (decoded is Map) {
    return _stringKeyedMap(decoded);
  }
  throw const FormatException(
    'guilgeeniiTuukh: expected JSON object or array',
  );
}

/// Lists `guilgeeniiTuukh` from the POS API (same collection as web `useGuilgeeniiTuukh`).
class GuilgeeService {
  GuilgeeService({ApiService? apiService}) : _api = apiService ?? posApiService;

  final ApiService _api;

  Future<GuilgeeListResult> listGuilgeeniiTuukh({
    required String baiguullagiinId,
    required String salbariinId,

    /// When set, only sales recorded with this employee (`ajiltan.id` on guilgee).
    String? ajiltanId,
    int page = 1,
    int pageSize = 100,
  }) async {
    final queryMap = <String, dynamic>{
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
      'tuluv': {r'$ne': 0},
      'tsutsalsanOgnoo': {r'$exists': false},
    };
    final aid = ajiltanId?.trim();
    if (aid != null && aid.isNotEmpty) {
      // Match web (`ajiltan.id`) and any legacy rows that used `_id` on the subdocument.
      queryMap[r'$or'] = [
        {'ajiltan.id': aid},
        {'ajiltan._id': aid},
      ];
    }

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/guilgeeniiTuukh',
        queryParams: {
          'query': jsonEncode(queryMap),
          'order': jsonEncode({'ognoo': -1}),
          'khuudasniiDugaar': page.toString(),
          'khuudasniiKhemjee': pageSize.toString(),
          'baiguullagiinId': baiguullagiinId,
        },
        parser: _guilgeeTuukhRootAsMap,
      );

      if (response.success && response.data != null) {
        final raw = _guilgeeListJagsaaltFromResponse(response.data!);
        final sales = raw
                ?.map((e) => completedSaleFromGuilgeeDoc(
                      e as Map<String, dynamic>,
                    ))
                .toList() ??
            [];
        return GuilgeeListResult.ok(sales);
      }

      return GuilgeeListResult.fail(
        response.message ?? 'Гүйлгээний түүх ачаалахад алдаа',
      );
    } catch (e) {
      return GuilgeeListResult.fail(e.toString());
    }
  }

  /// Parked / unpaid rows (`tuluv: 0`), same as web POS **Хүлээлгэ** tab (`useGuilgeeniiTuukh` + `tuluv: 0`).
  ///
  /// Web merges only `baiguullagiinId` + `{ tuluv: 0 }` — **no `salbariinId`** in the Mongo query,
  /// so parked sales from any branch of the org appear (same as `pos/pages/khyanalt/posSystem/index.js`).
  /// [salbariinId] is kept for call-site compatibility but is not sent unless [restrictToSalbar] is true.
  ///
  /// Query string matches browser Network tab, e.g.
  /// `GET …/guilgeeniiTuukh?query={"baiguullagiinId":"…","tuluv":0}&baiguullagiinId=…&khuudasniiDugaar=1&khuudasniiKhemjee=100`
  /// (no `order` param — web omits it when unset).
  Future<ParkedGuilgeeListResult> listParkedGuilgeeniiTuukh({
    required String baiguullagiinId,
    required String salbariinId,
    int page = 1,
    int pageSize = 100,
    bool restrictToSalbar = false,
  }) async {
    final bid = baiguullagiinId.trim();
    if (bid.isEmpty) {
      return ParkedGuilgeeListResult.fail('baiguullagiinId хоосон байна');
    }
    final queryMap = <String, dynamic>{
      'baiguullagiinId': bid,
      'tuluv': 0,
    };
    final sid = salbariinId.trim();
    if (restrictToSalbar && sid.isNotEmpty) {
      queryMap['salbariinId'] = sid;
    }

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/guilgeeniiTuukh',
        queryParams: {
          'query': jsonEncode(queryMap),
          'khuudasniiDugaar': page.toString(),
          'khuudasniiKhemjee': pageSize.toString(),
          'baiguullagiinId': bid,
        },
        parser: _guilgeeTuukhRootAsMap,
      );

      if (response.success && response.data != null) {
        final raw = _guilgeeListJagsaaltFromResponse(response.data!);
        final rows = <ParkedGuilgeeRow>[];
        if (raw != null) {
          for (final e in raw) {
            if (e is! Map) continue;
            final m = Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v)),
            );
            rows.add(ParkedGuilgeeRow(m));
          }
        }
        return ParkedGuilgeeListResult.ok(rows);
      }

      return ParkedGuilgeeListResult.fail(
        response.message ?? 'Хүлээлгэ ачаалахад алдаа',
      );
    } catch (e) {
      return ParkedGuilgeeListResult.fail(e.toString());
    }
  }

  /// Web `deleteMethod('guilgeeniiTuukh', …)` before loading a parked cart back.
  ///
  /// posBack / zevback may respond with plain `"Amjilttai"`, JSON `{ success: true }`,
  /// or an **empty body** on success — all are treated as success.
  Future<bool> deleteGuilgeeniiTuukhById(String mongoId) async {
    final id = mongoId.trim();
    if (id.isEmpty) return false;
    try {
      final response = await _api.delete<dynamic>(
        '/guilgeeniiTuukh/$id',
        parser: (d) => d,
      );
      if (!response.success) return false;
      final d = response.data;
      if (d == null) return true;
      if (d is bool && d) return true;
      if (d is String) {
        final t = d.trim();
        if (t.isEmpty) return true;
        if (t == 'Amjilttai' || t.toLowerCase() == 'amjilttai') return true;
      }
      if (d is Map) {
        final m = Map<String, dynamic>.from(
          d.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (m['success'] == true) return true;
        final inner = m['data'];
        if (inner is String && inner.trim() == 'Amjilttai') return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Parses `_id` from API docs (string or Mongo extended JSON `{ "\$oid": "…" }`).
String guilgeeDocMongoId(Map<String, dynamic> doc) {
  final raw = doc['_id'];
  if (raw == null) return '';
  if (raw is String) {
    final s = raw.trim();
    return s;
  }
  if (raw is Map) {
    final oid = raw[r'$oid'];
    if (oid != null) return oid.toString().trim();
  }
  return raw.toString().trim();
}

class GuilgeeListResult {
  GuilgeeListResult._({
    required this.success,
    required this.sales,
    this.error,
  });

  final bool success;
  final List<CompletedSale> sales;
  final String? error;

  factory GuilgeeListResult.ok(List<CompletedSale> sales) =>
      GuilgeeListResult._(
        success: true,
        sales: sales,
      );

  factory GuilgeeListResult.fail(String error) => GuilgeeListResult._(
        success: false,
        sales: [],
        error: error,
      );
}

/// One `guilgeeniiTuukh` document with `tuluv: 0` (parked sale).
class ParkedGuilgeeRow {
  ParkedGuilgeeRow(this.doc);

  final Map<String, dynamic> doc;

  String get mongoId => guilgeeDocMongoId(doc);

  String get guilgeeniiDugaar => doc['guilgeeniiDugaar']?.toString() ?? '';

  double get niitUne => _parseDouble(doc['niitUne']);

  DateTime get ognoo => _parseGuilgeeOgnoo(doc['ognoo'] ?? doc['createdAt']);

  int get lineCount {
    final b = doc['baraanuud'];
    if (b is! List) return 0;
    return b.length;
  }
}

class ParkedGuilgeeListResult {
  ParkedGuilgeeListResult._({
    required this.success,
    required this.rows,
    this.error,
  });

  final bool success;
  final List<ParkedGuilgeeRow> rows;
  final String? error;

  factory ParkedGuilgeeListResult.ok(List<ParkedGuilgeeRow> rows) =>
      ParkedGuilgeeListResult._(
        success: true,
        rows: rows,
      );

  factory ParkedGuilgeeListResult.fail(String error) =>
      ParkedGuilgeeListResult._(
        success: false,
        rows: [],
        error: error,
      );
}

/// Rebuilds cart lines from a parked `guilgeeniiTuukh` document (`baraanuud`), web `huleelgeesHudaldahruuZakhialgaKhiiy`.
List<SaleItem> saleItemsFromParkedGuilgeeDoc(Map<String, dynamic> doc) {
  final baraanuud = doc['baraanuud'] as List<dynamic>?;
  if (baraanuud == null) return const [];

  final out = <SaleItem>[];
  for (final raw in baraanuud) {
    if (raw is! Map) continue;
    final line = Map<String, dynamic>.from(raw);
    final baraaWrap = line['baraa'];
    if (baraaWrap is! Map) continue;
    final baraa = Map<String, dynamic>.from(baraaWrap);
    final product = Product.fromJson(baraa);

    final tooRaw = line['too'];
    final tooD = tooRaw is num
        ? tooRaw.toDouble()
        : double.tryParse(tooRaw?.toString() ?? '1') ?? 1.0;
    final lineNiit = _parseDouble(line['niitUne']);
    final promoId = baraa['uramshuulaliinId']?.toString().trim();
    final promo = promoId != null && promoId.isNotEmpty ? promoId : null;

    if (product.isBoxSaleUnit) {
      final negD =
          math.max(1, product.negKhairtsaganDahiShirhegiinToo ?? 1).toDouble();
      final boxes = tooD > 0 ? tooD : 1.0;
      final pieces = boxes * negD;
      final qBoxes = math.max(1, boxes.ceil());
      final perBox = lineNiit / boxes;
      final roundedBoxes = boxes == qBoxes.toDouble();
      out.add(SaleItem(
        product: product,
        unitPrice: perBox,
        retailUnitPrice: perBox,
        quantity: qBoxes,
        uramshuulaliinId: promo,
        forceRetailPricing: true,
        boxPiecesSold: roundedBoxes ? null : pieces,
      ));
    } else {
      final qty = math.max(1, tooD.round());
      final unit = tooD > 0.0001 ? lineNiit / tooD : lineNiit;
      out.add(SaleItem(
        product: product,
        unitPrice: unit,
        retailUnitPrice: unit,
        quantity: qty,
        uramshuulaliinId: promo,
        forceRetailPricing: true,
      ));
    }
  }
  return out;
}

String _paymentMethodFromTulbur(List<dynamic>? tulbur) {
  if (tulbur == null || tulbur.isEmpty) return PosPaymentCore.methodCash;
  final first = tulbur.first;
  if (first is! Map) return PosPaymentCore.methodCash;
  final turul = first['turul']?.toString().toLowerCase().trim() ?? '';

  // Order matters: match specific backend `turul` before generic / cash.
  // Web/app save account as `khariltsakh` (see [PosTransactionService.paymentMethodToTurul]).
  if (turul == 'kart' ||
      turul == 'cart' ||
      turul.contains('kart') ||
      turul.contains('карт')) {
    return PosPaymentCore.methodCard;
  }
  if (turul == 'qpay' || turul.contains('qpay')) {
    return PosPaymentCore.methodQpay;
  }
  if (turul == 'khariltsakh' ||
      turul.contains('khariltsakh') ||
      turul.contains('dans') ||
      turul.contains('account')) {
    return PosPaymentCore.methodAccount;
  }
  if (turul == 'zeel' ||
      turul.contains('zeel') ||
      turul.contains('credit') ||
      turul.contains('зээл')) {
    return PosPaymentCore.methodCredit;
  }
  if (turul.contains('mobile') || turul.contains('утас')) {
    return PosPaymentCore.methodMobile;
  }
  if (turul == 'belen' || turul.contains('бэлэн')) {
    return PosPaymentCore.methodCash;
  }
  return PosPaymentCore.methodCash;
}

Product _productFromBaraaMap(Map<String, dynamic>? baraa,
    {String? fallbackId}) {
  if (baraa == null) {
    return Product(
      id: fallbackId ?? '',
      name: 'Бараа',
      description: '',
      price: 0,
      category: '',
      imageUrl: '',
    );
  }
  final m = Map<String, dynamic>.from(baraa);
  final idStr = m['_id']?.toString() ?? m['id']?.toString() ?? '';
  if (idStr.isEmpty && fallbackId != null && fallbackId.isNotEmpty) {
    m['_id'] = fallbackId;
  }
  return Product.fromJson(m);
}

double _parseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

Map<String, dynamic>? _ajiltanFromDoc(dynamic raw) {
  if (raw == null) return null;
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(
    raw.map((k, v) => MapEntry(k.toString(), v)),
  );
}

/// Parses API `ognoo` / `createdAt` (ISO string, millis, or Mongo `$date` wrapper).
DateTime _parseGuilgeeOgnoo(dynamic ognoo) {
  DateTime? ts;
  if (ognoo is DateTime) {
    ts = ognoo;
  } else if (ognoo is int) {
    ts = DateTime.fromMillisecondsSinceEpoch(ognoo, isUtc: true);
  } else if (ognoo is String) {
    ts = DateTime.tryParse(ognoo);
  } else if (ognoo is Map) {
    final inner = ognoo[r'$date'];
    if (inner is String) {
      ts = DateTime.tryParse(inner);
    } else if (inner is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(inner, isUtc: true);
    }
  }
  return ts ?? DateTime.now();
}

CompletedSale completedSaleFromGuilgeeDoc(Map<String, dynamic> doc) {
  final id =
      doc['guilgeeniiDugaar']?.toString() ?? doc['_id']?.toString() ?? 'sale';
  final ts = _parseGuilgeeOgnoo(doc['ognoo'] ?? doc['createdAt']);

  final baraanuud = doc['baraanuud'] as List<dynamic>?;
  final items = <SaleItem>[];
  if (baraanuud != null) {
    for (final line in baraanuud) {
      if (line is! Map<String, dynamic>) continue;
      final baraaWrap = line['baraa'];
      Map<String, dynamic>? baraa;
      if (baraaWrap is Map<String, dynamic>) {
        baraa = baraaWrap;
      }
      final too = line['too'];
      final qty = too is int ? too : int.tryParse(too?.toString() ?? '1') ?? 1;
      final lineNiit = _parseDouble(line['niitUne']);
      final unit = qty > 0 ? lineNiit / qty : lineNiit;
      final p =
          _productFromBaraaMap(baraa, fallbackId: line['_id']?.toString());
      items.add(SaleItem(
        product: p,
        unitPrice: unit,
        retailUnitPrice: unit,
        quantity: qty,
        forceRetailPricing: true,
      ));
    }
  }

  final niitUne = _parseDouble(doc['niitUne']);
  final hungulsunDun = _parseDouble(doc['hungulsunDun']);
  final noatiinDun = _parseDouble(doc['noatiinDun']);
  final nhatiinDun = _parseDouble(doc['nhatiinDun']);
  final noatguiDun = _parseDouble(doc['noatguiDun']);
  final tulbur = doc['tulbur'] as List<dynamic>?;
  final subtotal =
      (niitUne - noatiinDun - nhatiinDun).clamp(0.0, double.infinity);

  return CompletedSale(
    id: id,
    items: items,
    subtotal: subtotal + hungulsunDun,
    tax: noatiinDun,
    total: niitUne,
    paymentMethod: _paymentMethodFromTulbur(tulbur),
    timestamp: ts,
    discount: hungulsunDun,
    nhhat: nhatiinDun,
    noatguiSum: noatguiDun,
    ajiltan: _ajiltanFromDoc(doc['ajiltan']),
    ebarimtAvsan: doc['ebarimtAvsanEsekh'] == true,
  );
}

final guilgeeService = GuilgeeService();
