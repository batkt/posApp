import '../models/cart_model.dart';
import 'api_service.dart';

/// Нэг барааны орлогын мөр (тоо / өртөг / зарах үнэ).
class OrlogoMur {
  OrlogoMur({
    required this.product,
    required this.too,
    required this.urtugUne,
    required this.zarakhUne,
  });

  final Product product;
  double too;
  double urtugUne;
  double zarakhUne;

  double get dun => too * urtugUne;

  /// posBack `/baraaOrlogodyo` → `baraanuud[]` (вэб `baraaOrlogokh`-той ижил).
  Map<String, dynamic> toJson(String salbariinId) => {
        if (product.id.isNotEmpty) '_id': product.id,
        'code': product.code ?? product.sku ?? '',
        'barCode': product.barCode ?? '',
        'ner': product.name,
        'too': too,
        'urtugUne': urtugUne,
        'zarakhUne': zarakhUne,
        'shirkheglekhEsekh': product.shirkheglekhEsekh,
        'negKhairtsaganDahiShirhegiinToo':
            product.negKhairtsaganDahiShirhegiinToo,
        'ognooniiMedeelelBurtgekhEsekh': product.ognooniiMedeelelBurtgekhEsekh,
        'salbariinId': salbariinId,
        'orlogdsonSalbariinId': salbariinId,
      };
}

class OrlogoResult {
  const OrlogoResult._(this.success, this.error);
  factory OrlogoResult.ok() => const OrlogoResult._(true, null);
  factory OrlogoResult.fail(String e) => OrlogoResult._(false, e);
  final bool success;
  final String? error;
}

/// Барааны орлого (худалдан авалт) — вэб `POST /baraaOrlogodyo`.
/// Сервер үлдэгдлийг нэмэгдүүлж, орлогын түүх, өртгийн түүх, зээлээр бол
/// нийлүүлэгчийн өглөгийг бүртгэнэ.
class OrlogoService {
  OrlogoService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  Future<OrlogoResult> baraaOrlogodyo({
    required String baiguullagiinId,
    required String salbariinId,
    required Map<String, dynamic> ajiltan,
    required String khariltsagchiinId,
    required String khariltsagchiinNer,
    required String khelber, // belen | zeel
    required List<OrlogoMur> muruud,
  }) async {
    final niitDun = muruud.fold<double>(0, (a, m) => a + m.dun);
    final body = <String, dynamic>{
      // Анхаар: вэбийн хуудас `baiguullagiinId`-г салбарын id-аар дарж
      // явуулдаг алдаатай — энд жинхэнэ байгууллагын id-г явуулна.
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
      'ajiltan': {'id': ajiltan['id'], 'ner': ajiltan['ner']},
      'khariltsagchiinId': khariltsagchiinId,
      'khariltsagchiinNer': khariltsagchiinNer,
      'khelber': khelber,
      'niitDun': double.parse(niitDun.toStringAsFixed(2)),
      'baraanuud': muruud.map((m) => m.toJson(salbariinId)).toList(),
    };
    try {
      final response = await _api.post<dynamic>(
        '/baraaOrlogodyo',
        body: body,
        parser: (d) => d,
      );
      if (response.success &&
          response.data?.toString().contains('Amjilttai') == true) {
        return OrlogoResult.ok();
      }
      return OrlogoResult.fail(
        response.message ?? response.data?.toString() ?? 'Орлого бүртгэхэд алдаа',
      );
    } catch (e) {
      return OrlogoResult.fail(e.toString());
    }
  }
}
