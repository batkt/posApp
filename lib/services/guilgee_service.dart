import 'dart:convert';

import 'api_service.dart';
import '../models/cart_model.dart';
import '../models/sales_model.dart';
import '../payment/pos_payment_core.dart';

/// Lists `guilgeeniiTuukh` from the POS API (same collection as web `useGuilgeeniiTuukh`).
class GuilgeeService {
  GuilgeeService({ApiService? apiService})
      : _api = apiService ?? posApiService;

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
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final raw = response.data!['jagsaalt'] as List<dynamic>?;
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

  factory GuilgeeListResult.ok(List<CompletedSale> sales) => GuilgeeListResult._(
        success: true,
        sales: sales,
      );

  factory GuilgeeListResult.fail(String error) => GuilgeeListResult._(
        success: false,
        sales: [],
        error: error,
      );
}

String _paymentMethodFromTulbur(List<dynamic>? tulbur) {
  if (tulbur == null || tulbur.isEmpty) return PosPaymentCore.methodCash;
  final first = tulbur.first;
  if (first is! Map) return PosPaymentCore.methodCash;
  final turul = first['turul']?.toString().toLowerCase() ?? '';
  if (turul.contains('kart') || turul == 'kart') {
    return PosPaymentCore.methodCard;
  }
  if (turul == 'belen' || turul.contains('бэлэн')) {
    return PosPaymentCore.methodCash;
  }
  if (turul.contains('danс') || turul.contains('account')) {
    return PosPaymentCore.methodAccount;
  }
  if (turul.contains('credit') || turul.contains('зээл')) {
    return PosPaymentCore.methodCredit;
  }
  if (turul.contains('mobile') || turul.contains('утас')) {
    return PosPaymentCore.methodMobile;
  }
  if (turul == 'qpay' || turul.contains('qpay')) {
    return PosPaymentCore.methodQpay;
  }
  return PosPaymentCore.methodCash;
}

Product _productFromBaraaMap(Map<String, dynamic>? baraa, {String? fallbackId}) {
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
  final id = baraa['_id']?.toString() ?? baraa['id']?.toString() ?? fallbackId ?? '';
  final name = baraa['ner']?.toString() ?? baraa['name']?.toString() ?? 'Бараа';
  final une = _parseDouble(baraa['niitUne'] ?? baraa['zarakhUne'] ?? baraa['une']);
  final img = baraa['zurag']?.toString() ?? '';
  return Product(
    id: id,
    name: name,
    description: '',
    price: une,
    category: baraa['angilal']?.toString() ?? '',
    imageUrl: img,
    code: baraa['code']?.toString(),
    barCode: baraa['barCode']?.toString(),
  );
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

CompletedSale completedSaleFromGuilgeeDoc(Map<String, dynamic> doc) {
  final id = doc['guilgeeniiDugaar']?.toString() ??
      doc['_id']?.toString() ??
      'sale';
  final ognoo = doc['ognoo'] ?? doc['createdAt'];
  DateTime ts;
  if (ognoo is String) {
    ts = DateTime.tryParse(ognoo) ?? DateTime.now();
  } else {
    ts = DateTime.now();
  }

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
      final qty = too is int
          ? too
          : int.tryParse(too?.toString() ?? '1') ?? 1;
      final lineNiit = _parseDouble(line['niitUne']);
      final unit = qty > 0 ? lineNiit / qty : lineNiit;
      final p = _productFromBaraaMap(baraa, fallbackId: line['_id']?.toString());
      items.add(SaleItem(
        product: p,
        unitPrice: unit,
        quantity: qty,
      ));
    }
  }

  final niitUne = _parseDouble(doc['niitUne']);
  final hungulsunDun = _parseDouble(doc['hungulsunDun']);
  final noatiinDun = _parseDouble(doc['noatiinDun']);
  final nhatiinDun = _parseDouble(doc['nhatiinDun']);
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
    ajiltan: _ajiltanFromDoc(doc['ajiltan']),
  );
}

final guilgeeService = GuilgeeService();
