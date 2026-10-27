import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/pos_session.dart';
import 'package:posease/models/sales_model.dart';
import 'package:posease/services/offline/offline_guilgee_queue.dart';
import 'package:posease/services/offline/online_tuluv.dart';
import 'package:posease/services/pos_transaction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Product кэш JSON-оор буцааж уншихад үнэ, үлдэгдэл, баркод хадгалагдана', () {
    final p = Product.fromJson({
      '_id': 'abc123',
      'ner': 'Сүү',
      'code': 'C1',
      'barCode': '8650000000017',
      'niitUne': 3500,
      'urtugUne': 2800,
      'uldegdel': 12.5,
      'angilal': 'Хүнс',
      'noatBodohEsekh': true,
      'idevkhteiEsekh': true,
      'khemjikhNegj': 'ш',
      'olonBarCodeJagsaalt': [
        {'barCode': '111'}
      ],
      'createdAt': '2026-10-01T00:00:00.000Z',
    });
    final back = Product.fromJson(p.toCacheJson());
    expect(back.id, 'abc123');
    expect(back.name, 'Сүү');
    expect(back.price, 3500);
    expect(back.barCode, '8650000000017');
    expect(back.uldegdelBodit, 12.5);
    expect(back.sellableStock, 13);
    expect(back.noatBodohEsekh, true);
    expect(back.olonBarCodeJagsaalt, ['111']);
    expect(back.createdAt, p.createdAt);
  });

  test('Офлайн баримтын дугаар: ОФ + огноо + төхөөрөмж + дараалал, давхцахгүй', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await OfflineGuilgeeQueue.offlineDugaarUusgekh();
    final b = await OfflineGuilgeeQueue.offlineDugaarUusgekh();
    expect(RegExp(r'^ОФ\d{6}\d{4}\d{3,}$').hasMatch(a), isTrue, reason: a);
    expect(a.contains('-'), isFalse);
    expect(a == b, isFalse);
    expect(a.substring(0, a.length - 3), b.substring(0, b.length - 3));
  });

  test('clientGuilgeeniiId давтагдашгүй', () {
    final ids = List.generate(500, (_) => OfflineGuilgeeQueue.clientIdUusgekh());
    expect(ids.toSet().length, 500);
  });

  test('Борлуулалтын payload-д clientGuilgeeniiId орно', () {
    final sales = SalesModel();
    sales.addToSale(Product.fromJson({
      '_id': 'p1',
      'ner': 'Талх',
      'code': 'T1',
      'niitUne': 2000,
      'uldegdel': 10,
    }));
    final body = PosTransactionService().buildGuilgeeniiTuukhBody(
      session: const PosSession(
        baiguullagiinId: 'org',
        salbariinId: 'br',
        ajiltan: {'_id': 'a1', 'ner': 'Кассчин'},
      ),
      sales: sales,
      paymentTurul: 'belen',
      niitUne: 2000,
      tulsunDun: 5000,
      hariult: 3000,
      hungulsunDun: 0,
      noatiinDun: 0,
      noatguiDun: 2000,
      nhatiinDun: 0,
      guilgeeniiDugaar: 'ОФ2610271234001',
      clientGuilgeeniiId: 'cid-1',
    );
    expect(body['clientGuilgeeniiId'], 'cid-1');
    expect(body['guilgeeniiDugaar'], 'ОФ2610271234001');
    expect((body['tulbur'] as List).first['une'], 2000);
    expect((body['baraanuud'] as List).length, 1);
  });

  test('"nan" агуулсан барааны нэр "0" болохгүй, харин NaN утга засагдана', () {
    final sales = SalesModel();
    sales.addToSale(Product.fromJson({
      '_id': 'p2',
      'ner': 'Banana',
      'code': 'B1',
      'niitUne': 1500,
      'uldegdel': 5,
    }));
    final body = PosTransactionService().buildGuilgeeniiTuukhBody(
      session: const PosSession(
        baiguullagiinId: 'org',
        salbariinId: 'br',
        ajiltan: {'_id': 'a1', 'ner': 'Nana'},
      ),
      sales: sales,
      paymentTurul: 'belen',
      niitUne: 1500,
      tulsunDun: 1500,
      hariult: 0,
      hungulsunDun: double.nan,
      noatiinDun: 0,
      noatguiDun: 1500,
      nhatiinDun: 0,
      guilgeeniiDugaar: 'БД2610271',
    );
    final baraa = (body['baraanuud'] as List).first['baraa'] as Map;
    expect(baraa['ner'], 'Banana');
    expect((body['ajiltan'] as Map)['ner'], 'Nana');
    expect(body['hungulsunDun'], 0);
  });

  test('Сүлжээний алдааг сервер алдаанаас ялгана', () {
    expect(OnlineTuluv.holboltiinAldaaEsekh('SocketException: Failed host lookup'), isTrue);
    expect(OnlineTuluv.holboltiinAldaaEsekh(PosTransactionException('Үлдэгдэл хүрэлцэхгүй', statusCode: 500)), isFalse);
  });
}
