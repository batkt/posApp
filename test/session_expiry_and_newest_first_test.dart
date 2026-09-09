import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/inventory_model.dart';
import 'package:posease/services/api_service.dart';

Product _product({
  required String id,
  required String name,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Product(
    id: id,
    name: name,
    description: name,
    price: 1000,
    category: 'test',
    imageUrl: '',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

InventoryItem _item({
  required String id,
  required String name,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastRestocked,
}) {
  return InventoryItem(
    product: _product(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
    currentStock: 5,
    lastRestocked: lastRestocked,
  );
}

void main() {
  group('Хамгийн сүүлд бүртгэсэн бараа эхэнд', () {
    test('sortNewestFirst эрэмбэлэхдээ createdAt-ыг буурахаар тавина', () {
      final list = [
        _item(id: 'a', name: 'Хуучин', createdAt: DateTime(2024, 1, 1)),
        _item(id: 'b', name: 'Шинэ', createdAt: DateTime(2026, 9, 1)),
        _item(id: 'c', name: 'Дунд', createdAt: DateTime(2025, 5, 5)),
      ];

      InventoryModel.sortNewestFirst(list);

      expect(list.map((i) => i.product.id), ['b', 'c', 'a']);
    });

    test('засварласан хуучин бараа шинэ бүртгэлийн дээр гарахгүй', () {
      // Хуучин бараа саяхан ЗАССАН (updatedAt шинэ) ч бүртгэсэн нь эрт.
      final edited = _item(
        id: 'old',
        name: 'Хуучин',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2026, 9, 9),
      );
      final justAdded = _item(
        id: 'new',
        name: 'Шинэ',
        createdAt: DateTime(2026, 9, 8),
      );

      final list = [edited, justAdded];
      InventoryModel.sortNewestFirst(list);

      expect(list.first.product.id, 'new');
    });

    test('createdAt байхгүй бол updatedAt, дараа нь lastRestocked-руу шилжинэ', () {
      final byUpdated = _item(
        id: 'u',
        name: 'U',
        updatedAt: DateTime(2026, 3, 3),
      );
      final byRestock = _item(
        id: 'r',
        name: 'R',
        lastRestocked: DateTime(2026, 1, 1),
      );
      final none = _item(id: 'n', name: 'N');

      expect(byUpdated.registeredAt, DateTime(2026, 3, 3));
      expect(byRestock.registeredAt, DateTime(2026, 1, 1));
      expect(none.registeredAt, isNull);
      expect(none.registeredAtKey, 0);

      final list = [none, byRestock, byUpdated];
      InventoryModel.sortNewestFirst(list);
      expect(list.map((i) => i.product.id), ['u', 'r', 'n']);
    });

    test('огноо ижил үед нэрээр тогтвортой эрэмбэлнэ', () {
      final at = DateTime(2026, 2, 2);
      final list = [
        _item(id: '1', name: 'Ямаа', createdAt: at),
        _item(id: '2', name: 'Адуу', createdAt: at),
      ];

      InventoryModel.sortNewestFirst(list);

      expect(list.map((i) => i.product.name), ['Адуу', 'Ямаа']);
    });

    test('Product.fromJson нь createdAt-ыг олон хэлбэрээр уншина', () {
      expect(
        Product.fromJson({'createdAt': '2026-09-08T10:00:00.000Z'}).createdAt,
        DateTime.parse('2026-09-08T10:00:00.000Z'),
      );
      expect(
        Product.fromJson({
          'createdAt': {r'$date': '2026-09-08T10:00:00.000Z'}
        }).createdAt,
        DateTime.parse('2026-09-08T10:00:00.000Z'),
      );
      // Буруу төрөл ирэхэд алдаа шидэхгүй.
      expect(Product.fromJson({'createdAt': true}).createdAt, isNull);
      expect(Product.fromJson({}).createdAt, isNull);
    });
  });

  group('jwt expired илрүүлэлт', () {
    test('серверийн токен алдааг таньна', () {
      expect(ApiService.isSessionExpiredMessage('jwt expired'), isTrue);
      expect(ApiService.isSessionExpiredMessage('JWT EXPIRED'), isTrue);
      expect(ApiService.isSessionExpiredMessage('jwt malformed'), isTrue);
      expect(ApiService.isSessionExpiredMessage('invalid token'), isTrue);
      expect(ApiService.isSessionExpiredMessage('invalid signature'), isTrue);
      expect(
        ApiService.isSessionExpiredMessage('jwt must be provided'),
        isTrue,
      );
      expect(
        ApiService.isSessionExpiredMessage('TokenExpiredError: jwt expired'),
        isTrue,
      );
    });

    test('ердийн бизнес алдааг гаралт гэж андуурахгүй', () {
      expect(ApiService.isSessionExpiredMessage(null), isFalse);
      expect(ApiService.isSessionExpiredMessage(''), isFalse);
      expect(
        ApiService.isSessionExpiredMessage('Үлдэгдэл хүрэлцэхгүй байна'),
        isFalse,
      );
      expect(
        ApiService.isSessionExpiredMessage('Нэвтрэх нэр давхардаж байна!'),
        isFalse,
      );
      expect(ApiService.isSessionExpiredMessage('Server error'), isFalse);
    });
  });
}
