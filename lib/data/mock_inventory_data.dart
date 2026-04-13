import '../models/cart_model.dart';
import '../models/inventory_model.dart';

/// Demo shelf stock when the warehouse API is offline or returns no rows.
abstract final class MockInventoryData {
  MockInventoryData._();

  static List<InventoryItem> get items => [
        InventoryItem(
          product: Product(
            id: 'mock-001',
            name: 'Кофе Latte 350мл',
            description: 'Дуртай кофе',
            price: 8500,
            category: 'Уух зүйл',
            imageUrl:
                'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&h=400&fit=crop',
            stock: 50,
            code: 'CF001',
            barCode: '8659123000101',
            angilal: 'Уух зүйл',
            uldegdel: 50,
          ),
          currentStock: 50,
          minStockLevel: 5,
        ),
        InventoryItem(
          product: Product(
            id: 'mock-002',
            name: 'Талх аарцтай',
            description: 'Шинэхэн талх',
            price: 3200,
            category: 'Амттан',
            imageUrl:
                'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&h=400&fit=crop',
            stock: 30,
            code: 'BR002',
            barCode: '8659123000102',
            angilal: 'Амттан',
            uldegdel: 30,
          ),
          currentStock: 30,
          minStockLevel: 5,
        ),
        InventoryItem(
          product: Product(
            id: 'mock-003',
            name: 'Ундаа Cola 500мл',
            description: 'Хүйтэн ундаа',
            price: 2800,
            category: 'Уух зүйл',
            imageUrl:
                'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400&h=400&fit=crop',
            stock: 80,
            code: 'DK003',
            barCode: '8659123000103',
            angilal: 'Уух зүйл',
            uldegdel: 80,
          ),
          currentStock: 80,
          minStockLevel: 8,
        ),
        InventoryItem(
          product: Product(
            id: 'mock-004',
            name: 'Сүү 1л',
            description: 'Шинэ сүү',
            price: 4200,
            category: 'Хүнсний нэмэлт',
            imageUrl:
                'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400&h=400&fit=crop',
            stock: 25,
            code: 'ML004',
            barCode: '8659123000104',
            angilal: 'Хүнсний нэмэлт',
            uldegdel: 25,
          ),
          currentStock: 25,
          minStockLevel: 5,
        ),
        InventoryItem(
          product: Product(
            id: 'mock-005',
            name: 'Чихэр Snickers',
            description: 'Амттан',
            price: 2500,
            category: 'Амттан',
            imageUrl:
                'https://images.unsplash.com/photo-1582058091505-f87a2e55a40f?w=400&h=400&fit=crop',
            stock: 60,
            code: 'SN005',
            barCode: '8659123000105',
            angilal: 'Амттан',
            uldegdel: 60,
          ),
          currentStock: 60,
          minStockLevel: 10,
        ),
        InventoryItem(
          product: Product(
            id: 'mock-006',
            name: 'Жимсний шүүс 1л',
            description: 'Жүрж',
            price: 6800,
            category: 'Уух зүйл',
            imageUrl:
                'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400&h=400&fit=crop',
            stock: 20,
            code: 'JC006',
            barCode: '8659123000106',
            angilal: 'Уух зүйл',
            uldegdel: 20,
          ),
          currentStock: 20,
          minStockLevel: 4,
        ),
      ];
}
