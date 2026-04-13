import 'package:flutter/foundation.dart';

enum ProductUnit { piece, kg, liter, meter, box }

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? costPrice;
  final String category;
  final String imageUrl;
  final String? barcode;
  final int stock;
  final int minStock;
  final bool isAvailable;
  final ProductUnit unit;
  final String? sku;

  // API specific fields
  final String? code;
  final String? barCode;
  final String? baiguullagiinId;
  final String? salbariinId;
  final String? angilal;
  final String? khemjikhNegj;
  final double? urtugUne;
  final bool? shirkheglekhEsekh;
  final bool? noatBodohEsekh;
  final bool? nhatBodohEsekh;
  final bool? ognooniiMedeelelBurtgekhEsekh;
  final int? uldegdel;
  final int? negKhairtsaganDahiShirhegiinToo;
  final double? niitUne;
  final double? noatiinDun;
  final double? nhatiinDun;
  final double? noatguiDun;
  final String? zurgiinId;
  final bool? orlogdsonEsekh;
  final bool? zarlagdsanEsekh;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? ajiltan;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.costPrice,
    required this.category,
    required this.imageUrl,
    this.barcode,
    this.stock = 100,
    this.minStock = 10,
    this.isAvailable = true,
    this.unit = ProductUnit.piece,
    this.sku,
    // API fields
    this.code,
    this.barCode,
    this.baiguullagiinId,
    this.salbariinId,
    this.angilal,
    this.khemjikhNegj,
    this.urtugUne,
    this.shirkheglekhEsekh,
    this.noatBodohEsekh,
    this.nhatBodohEsekh,
    this.ognooniiMedeelelBurtgekhEsekh,
    this.uldegdel,
    this.negKhairtsaganDahiShirhegiinToo,
    this.niitUne,
    this.noatiinDun,
    this.nhatiinDun,
    this.noatguiDun,
    this.zurgiinId,
    this.orlogdsonEsekh,
    this.zarlagdsanEsekh,
    this.createdAt,
    this.updatedAt,
    this.ajiltan,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      name: json['ner'] ?? '',
      description: json['ner'] ?? '',
      price: (json['niitUne'] ?? 0).toDouble(),
      costPrice: (json['urtugUne'] ?? 0).toDouble(),
      category: json['angilal'] ?? '',
      imageUrl: json['zurgiinId'] != null
          ? 'https://pos.zevtabs.mn/api/file?path=baraa/${json['zurgiinId']}'
          : 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&h=400&fit=crop',
      barcode: json['barCode'],
      stock: json['uldegdel'] ?? 0,
      minStock: 5,
      isAvailable: json['idevkhteiEsekh'] ?? true,
      unit: ProductUnit.piece,
      sku: json['code'],
      // API fields
      code: json['code'],
      barCode: json['barCode'],
      baiguullagiinId: json['baiguullagiinId'],
      salbariinId: json['salbariinId'],
      angilal: json['angilal'],
      khemjikhNegj: json['khemjikhNegj'],
      urtugUne: (json['urtugUne'] ?? 0).toDouble(),
      shirkheglekhEsekh: json['shirkheglekhEsekh'],
      noatBodohEsekh: json['noatBodohEsekh'],
      nhatBodohEsekh: json['nhatBodohEsekh'],
      ognooniiMedeelelBurtgekhEsekh: json['ognooniiMedeelelBurtgekhEsekh'],
      uldegdel: json['uldegdel'],
      negKhairtsaganDahiShirhegiinToo: json['negKhairtsaganDahiShirhegiinToo'],
      niitUne: (json['niitUne'] ?? 0).toDouble(),
      noatiinDun: (json['noatiinDun'] ?? 0).toDouble(),
      nhatiinDun: (json['nhatiinDun'] ?? 0).toDouble(),
      noatguiDun: (json['noatguiDun'] ?? 0).toDouble(),
      zurgiinId: json['zurgiinId'],
      orlogdsonEsekh: json['orlogdsonEsekh'],
      zarlagdsanEsekh: json['zarlagdsanEsekh'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? ''),
      ajiltan: json['ajiltan'],
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? costPrice,
    String? category,
    String? imageUrl,
    String? barcode,
    int? stock,
    int? minStock,
    bool? isAvailable,
    ProductUnit? unit,
    String? sku,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      isAvailable: isAvailable ?? this.isAvailable,
      unit: unit ?? this.unit,
      sku: sku ?? this.sku,
    );
  }

  String get unitLabel {
    switch (unit) {
      case ProductUnit.piece:
        return 'ш';
      case ProductUnit.kg:
        return 'кг';
      case ProductUnit.liter:
        return 'л';
      case ProductUnit.meter:
        return 'м';
      case ProductUnit.box:
        return 'хайрцаг';
    }
  }

  double? get profit => costPrice != null ? price - costPrice! : null;
  double? get profitMargin => costPrice != null && costPrice! > 0
      ? ((price - costPrice!) / costPrice!) * 100
      : null;

  /// Payload shape for POS API `baraa` (matches Next.js `tulburTuluhModal` / posBack).
  Map<String, dynamic> toBaraaDocument({required String fallbackSalbariinId}) {
    final map = <String, dynamic>{
      if (id.isNotEmpty) '_id': id,
      'ner': name,
      'code': code,
      'barCode': barCode,
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId ?? fallbackSalbariinId,
      'angilal': angilal ?? category,
      'khemjikhNegj': khemjikhNegj,
      'niitUne': niitUne ?? price,
      'urtugUne': urtugUne ?? costPrice,
      'uldegdel': uldegdel ?? stock,
      'idevkhteiEsekh': isAvailable,
      'zurgiinId': zurgiinId,
      'noatBodohEsekh': noatBodohEsekh,
      'nhatBodohEsekh': nhatBodohEsekh,
      'ognooniiMedeelelBurtgekhEsekh': ognooniiMedeelelBurtgekhEsekh,
      'noatiinDun': noatiinDun,
      'nhatiinDun': nhatiinDun,
      'noatguiDun': noatguiDun,
      'shirkheglekhEsekh': shirkheglekhEsekh,
      'negKhairtsaganDahiShirhegiinToo': negKhairtsaganDahiShirhegiinToo,
      'orlogdsonEsekh': orlogdsonEsekh,
      'zarlagdsanEsekh': zarlagdsanEsekh,
      'ajiltan': ajiltan,
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get total => product.price * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get uniqueItemCount => _items.length;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.total);
  double get tax => subtotal * 0.10; // 10% tax
  double get total => subtotal + tax;

  void addToCart(Product product) {
    final existingIndex =
        _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void incrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
        notifyListeners();
      } else {
        removeFromCart(productId);
      }
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
