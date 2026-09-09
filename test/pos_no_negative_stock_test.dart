import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/inventory_model.dart';
import 'package:posease/models/sales_model.dart';

Product _box() => Product(
      id: 'b1', name: 'Жазз бөмбөр', description: '', price: 3500,
      category: '', imageUrl: '', code: '10157',
      khemjikhNegj: 'хайрцаг', shirkheglekhEsekh: true,
      negKhairtsaganDahiShirhegiinToo: 720,
      niitUne: 3500, uldegdel: 3,
    );

void main() {
  group('Үлдэгдэл хасах утга руу орохгүй', () {
    test('үлдэгдэл дуусмагц дахин зарахыг зөвшөөрөхгүй', () {
      final p = _box();
      final inv = InventoryModel()..addProduct(p, initialStock: 3);

      expect(inv.canSell(p.id), isTrue);
      inv.deductStock(p.id, 3);

      expect(inv.canSell(p.id), isFalse,
          reason: 'үлдэгдэл 0 болсон тул дахин зарж болохгүй');
    });

    test('сагсанд бараа байсан ч үлдэгдэл 0 бол нэмэхгүй', () {
      // Энэ нь ЯГ алдааны нөхцөл: өмнө нь "сагсанд байгаа" гэдэг шалтгаанаар
      // үлдэгдэл дууссан ч "+" ажилласаар байж, -15 хүртэл унадаг байв.
      final p = _box();
      final inv = InventoryModel()..addProduct(p, initialStock: 3);
      final sales = SalesModel();

      var adds = 0;
      for (var i = 0; i < 20; i++) {
        if (!inv.canSell(p.id)) continue;
        inv.deductStock(p.id, 1);
        sales.addToSale(p);
        adds++;
      }

      expect(adds, 3, reason: 'зөвхөн үлдэгдлийн хэрээр л нэмэгдэнэ');
      expect(inv.inventory.first.currentStock, 0);
      expect(inv.inventory.first.currentStock, isNonNegative);
    });

    test('"сагс + үлдэгдэл == анхны үлдэгдэл" тэнцэл хэвээр хадгалагдана', () {
      final p = _box();
      final inv = InventoryModel()..addProduct(p, initialStock: 3);
      final sales = SalesModel();
      for (var i = 0; i < 20; i++) {
        if (!inv.canSell(p.id)) continue;
        inv.deductStock(p.id, 1);
        sales.addToSale(p);
      }

      final inCart = sales.qtyForProduct(p);
      expect(inCart + inv.inventory.first.currentStock, 3);
    });

    test('устгасан/олдохгүй бараанд зарахыг зөвшөөрөхгүй', () {
      expect(InventoryModel().canSell('байхгүй'), isFalse);
    });
  });
}
