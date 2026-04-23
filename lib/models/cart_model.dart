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

  /// Буцаалт/зарлагын тоо — зөвхөн API-аас ирвэл (жишээ нь tailan/toollogo мөр).
  final int? butsaaltToo;

  /// Бөөний үнэ (тоо ширхэгийн түвшин).
  final bool? buuniiUneEsekh;
  final List<Map<String, dynamic>> buuniiUneJagsaalt;

  /// Урамшууллын цонхнууд (вэб `aguulakh.uramshuulal`).
  final List<Map<String, dynamic>> uramshuulal;

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
    this.butsaaltToo,
    this.buuniiUneEsekh,
    this.buuniiUneJagsaalt = const [],
    this.uramshuulal = const [],
  });

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final n = num.tryParse(v);
      if (n != null) return n.toInt();
    }
    return fallback;
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final n = num.tryParse(v);
      if (n != null) return n.toInt();
    }
    return null;
  }

  /// Excel / legacy rows may send `"Тийм"` / `"1"` (same as posBack `excel.js`).
  static bool? _asNullableBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'true' ||
        s == '1' ||
        s == 'yes' ||
        s == 'тийм' ||
        s == 'y') {
      return true;
    }
    if (s == 'false' ||
        s == '0' ||
        s == 'no' ||
        s == 'үгүй' ||
        s == 'ugui' ||
        s == 'n') {
      return false;
    }
    return null;
  }

  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Bar codes / codes often arrive as JSON numbers; scanners return strings.
  static String? _asOptionalString(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    if (v is num) return v.toString();
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final codeStr = _asOptionalString(json['code']);
    final barCodeStr = _asOptionalString(json['barCode']);
    return Product(
      id: json['_id'] ?? '',
      name: json['ner'] ?? '',
      description: json['ner'] ?? '',
      price: _asDouble(json['niitUne']),
      costPrice: _asDouble(json['urtugUne']),
      category: json['angilal'] ?? '',
      imageUrl: json['zurgiinId'] != null
          ? 'https://pos.zevtabs.mn/api/file?path=baraa/${json['zurgiinId']}'
          : 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&h=400&fit=crop',
      barcode: barCodeStr,
      stock: _asInt(json['uldegdel']),
      minStock: 5,
      isAvailable: json['idevkhteiEsekh'] ?? true,
      unit: ProductUnit.piece,
      sku: codeStr,
      // API fields
      code: codeStr,
      barCode: barCodeStr,
      baiguullagiinId: json['baiguullagiinId'],
      salbariinId: json['salbariinId'],
      angilal: json['angilal'],
      khemjikhNegj: _asOptionalString(json['khemjikhNegj']),
      urtugUne: _asDouble(json['urtugUne']),
      shirkheglekhEsekh: _asNullableBool(json['shirkheglekhEsekh']),
      noatBodohEsekh: json['noatBodohEsekh'],
      nhatBodohEsekh: json['nhatBodohEsekh'],
      ognooniiMedeelelBurtgekhEsekh: json['ognooniiMedeelelBurtgekhEsekh'],
      uldegdel: _asNullableInt(json['uldegdel']),
      negKhairtsaganDahiShirhegiinToo:
          _asNullableInt(json['negKhairtsaganDahiShirhegiinToo']),
      niitUne: _asDouble(json['niitUne']),
      noatiinDun: _asDouble(json['noatiinDun']),
      nhatiinDun: _asDouble(json['nhatiinDun']),
      noatguiDun: _asDouble(json['noatguiDun']),
      zurgiinId: json['zurgiinId'],
      orlogdsonEsekh: json['orlogdsonEsekh'],
      zarlagdsanEsekh: json['zarlagdsanEsekh'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? ''),
      ajiltan: json['ajiltan'],
      butsaaltToo: _firstInt([
        json['butsaaltiinTooKhemjee'],
        json['butsaaltiinToo'],
        json['bufsaalt'],
        json['butsaalt'],
        json['zarlagiinTooKhemjee'],
      ]),
      buuniiUneEsekh:
          json['buuniiUneEsekh'] is bool ? json['buuniiUneEsekh'] as bool : null,
      buuniiUneJagsaalt: _deepMapList(json['buuniiUneJagsaalt']),
      uramshuulal: _deepMapList(json['uramshuulal']),
    );
  }

  static List<Map<String, dynamic>> _deepMapList(dynamic v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static int? _firstInt(List<dynamic> candidates) {
    for (final v in candidates) {
      final n = _asNullableInt(v);
      if (n != null) return n;
    }
    return null;
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

  /// Web `aguulakh.shirkheglekhEsekh`: `uldegdel` and sale `too` are **boxes**, not pieces.
  bool get isBoxSaleUnit => shirkheglekhEsekh == true;

  /// Suffix after stock / quantity on POS (web `posSystem`: "хайрцаг" vs "ш").
  String get posStockQuantitySuffix {
    if (isBoxSaleUnit) return 'хайрцаг';
    final k = khemjikhNegj?.trim();
    if (k != null && k.isNotEmpty) return k;
    return unitLabel;
  }

  /// Web tooltip "Нэг хайрцаг дахь ширхэг: Nш".
  String? get boxPiecesPerBoxHint {
    if (!isBoxSaleUnit) return null;
    final n = negKhairtsaganDahiShirhegiinToo;
    if (n == null || n < 1) return null;
    return '1 хайрцагт $n ш';
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
      'buuniiUneEsekh': buuniiUneEsekh,
      'buuniiUneJagsaalt': buuniiUneJagsaalt,
      'uramshuulal': uramshuulal,
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
