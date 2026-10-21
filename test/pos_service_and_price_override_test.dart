import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/inventory_model.dart';
import 'package:posease/services/pos_transaction_service.dart';

void main() {
  group('Ажил үйлчилгээний бараа (Service products)', () {
    test('Product.fromJson parses ajilUilchilgeeEsekh correctly', () {
      final p1 = Product.fromJson({
        '_id': 'srv1',
        'ner': 'Машин угаалга',
        'niitUne': 15000,
        'uldegdel': 0,
        'ajilUilchilgeeEsekh': true,
      });
      expect(p1.ajilUilchilgeeEsekh, isTrue);
      expect(p1.isService, isTrue);

      final p2 = Product.fromJson({
        '_id': 'prod1',
        'ner': 'Ундаа',
        'niitUne': 2500,
        'uldegdel': 10,
        'ajilUilchilgeeEsekh': false,
      });
      expect(p2.ajilUilchilgeeEsekh, isFalse);
      expect(p2.isService, isFalse);
    });

    test('InventoryItem does not mark service as low stock or out of stock even with 0 stock', () {
      final serviceProduct = Product.fromJson({
        '_id': 'srv1',
        'ner': 'Машин угаалга',
        'niitUne': 15000,
        'uldegdel': 0,
        'ajilUilchilgeeEsekh': true,
      });
      final item = InventoryItem(
        product: serviceProduct,
        currentStock: 0,
        minStockLevel: 10,
      );

      expect(item.isOutOfStock, isFalse);
      expect(item.isLowStock, isFalse);
    });

    test('InventoryModel canSell and deductStock always allow service without decrementing stock', () {
      final inventory = InventoryModel();
      final serviceProduct = Product.fromJson({
        '_id': 'srv1',
        'ner': 'Засвар үйлчилгээ',
        'niitUne': 20000,
        'uldegdel': 0,
        'ajilUilchilgeeEsekh': true,
      });

      inventory.addProduct(serviceProduct, initialStock: 0);

      // Even with 0 stock, service can be sold
      expect(inventory.canSell(serviceProduct.id), isTrue);

      // Deducting stock should succeed and NOT decrement stock
      expect(inventory.deductStock(serviceProduct.id, 1), isTrue);
      final itemAfterDeduct = inventory.getInventoryItem(serviceProduct.id);
      expect(itemAfterDeduct?.currentStock, 0);

      // Restocking service does not alter stock
      inventory.restock(serviceProduct.id, 1);
      final itemAfterRestock = inventory.getInventoryItem(serviceProduct.id);
      expect(itemAfterRestock?.currentStock, 0);
    });
  });

  group('Үндсэн үнэ болон зарах үнэ (Base price vs custom sale price)', () {
    test('Transaction service preserves base price in niitUne while sending custom price in zarakhUne', () {
      final product = Product.fromJson({
        '_id': 'item1',
        'ner': 'Шоколад',
        'niitUne': 5000.0,
        'uldegdel': 10,
        'ajilUilchilgeeEsekh': false,
      });

      final service = PosTransactionService();
      final saleBaraa = service.buildSaleBaraaForTest(
        product: product,
        fallbackSalbariinId: 'branch1',
        unitPrice: 4500.0, // Modified sale price
        lineTotal: 9000.0,
        lineQuantity: 2.0,
      );

      // niitUne must be the base catalog price (5000₮), not the modified price
      expect(saleBaraa['niitUne'], 5000.0);
      // zarakhUne must be the custom selling price for this sale (4500₮)
      expect(saleBaraa['zarakhUne'], 4500.0);
    });
  });
}
