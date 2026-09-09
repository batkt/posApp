import 'dart:async';

import 'package:flutter/widgets.dart';

import 'cart_model.dart';
import '../services/product_service.dart';
import '../services/socket_service.dart';
import 'pos_session.dart';

class InventoryItem {
  final Product product;
  int currentStock;
  int minStockLevel;
  int? reorderPoint;
  String? supplier;
  double? costPrice;
  DateTime? lastRestocked;

  InventoryItem({
    required this.product,
    required this.currentStock,
    this.minStockLevel = 10,
    this.reorderPoint,
    this.supplier,
    this.costPrice,
    this.lastRestocked,
  });

  /// Цөөн үлдсэн: үлдэгдэл 1…[minStockLevel] (жишээ нь 1–10 нь `minStockLevel == 10` үед).
  /// 0 үлдэгдэлтэй барааг энд оруулахгүй — тэдгээр нь [isOutOfStock].
  bool get isLowStock =>
      currentStock > 0 &&
      minStockLevel > 0 &&
      currentStock <= minStockLevel;

  bool get isOutOfStock => currentStock <= 0;

  double get stockValue => (costPrice ?? product.price * 0.6) * currentStock;

  /// Барааг БҮРТГЭСЭН мөч — "хамгийн сүүлд бүртгэсэн нь дээр" эрэмбийн түлхүүр.
  ///
  /// `updatedAt`-г ЗОРИУДААР эхэнд тавихгүй: хуучин барааны үнэ/үлдэгдлийг
  /// засахад л тэр нь шинэчлэгддэг тул засварласан хуучин бараа шинэ
  /// бүртгэлийн дээр гарч ирдэг байв.
  DateTime? get registeredAt =>
      product.createdAt ?? product.updatedAt ?? lastRestocked;

  int get registeredAtKey => registeredAt?.millisecondsSinceEpoch ?? 0;

  InventoryItem copyWith({
    Product? product,
    int? currentStock,
    int? minStockLevel,
    int? reorderPoint,
    String? supplier,
    double? costPrice,
    DateTime? lastRestocked,
  }) {
    return InventoryItem(
      product: product ?? this.product,
      currentStock: currentStock ?? this.currentStock,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      supplier: supplier ?? this.supplier,
      costPrice: costPrice ?? this.costPrice,
      lastRestocked: lastRestocked ?? this.lastRestocked,
    );
  }
}

class InventoryModel extends ChangeNotifier {
  final List<InventoryItem> _inventory = [];
  String _searchQuery = '';
  String _selectedCategory = 'Бүгд';
  final ProductService _productService;
  bool _isLoading = false;
  String? _error;
  String? _baiguullagiinId;
  String? _salbariinId;
  StreamSubscription<void>? _uldegdelSub;
  String? _socketBranchKey;

  /// Давтамжит "аюулгүйн" шинэчлэлт. Socket.IO нь ЦОРЫН ГАНЦ шинэчлэх зам
  /// байсан тул холболт тасарсан/хаагдсан үед (терминал NAT, proxy, эсвэл
  /// `/api/socket.io` зам блоклогдсон) үлдэгдэл нь бүхэл сешний турш
  /// хөлдөж, тооллого/вебийн хөдөлгөөн/буцаалт/зарлага огт тусдаггүй байв.
  Timer? _pollTimer;

  /// Апп нүүр рүү эргэж ирэхэд шинэчлэх ажиглагч.
  _InventoryLifecycleObserver? _lifecycleObserver;

  /// Хамгийн сүүлд серверээс ачаалсан мөч — хэт ойрхон давтахаас сэргийлнэ.
  DateTime? _lastLoadedAt;

  /// Сагсанд барьцаалсан тоог буцаах эх сурвалж ([SalesModel]).
  ///
  /// Серверээс дахин ачаалсны ДАРАА эдгээрийг хасна — эс тэгвээс сагстай
  /// байхад ирсэн шинэчлэлт нь барьцааг арчина.
  Map<String, int> Function()? reservedQtyResolver;

  /// Давтамжит шинэчлэлтийн зай.
  static const Duration pollInterval = Duration(seconds: 90);

  /// Хоёр ачаалалтын хоорондох хамгийн бага зай.
  static const Duration _minReloadGap = Duration(seconds: 5);

  InventoryModel({
    ProductService? productService,
  }) : _productService = productService ?? ProductService();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _uldegdelSub?.cancel();
    _detachLifecycle();
    super.dispose();
  }

  void _onAppResumed() {
    unawaited(refreshInventory());
  }

  /// Ажиглагчийг ЗӨВХӨН идэвхтэй сешнтэй үед бүртгэнэ. Конструктор дотор
  /// хийвэл `WidgetsBinding` эхлээгүй орчинд (unit тест) шидэж унана.
  void _attachLifecycle() {
    if (_lifecycleObserver != null) return;
    final obs = _InventoryLifecycleObserver(_onAppResumed);
    _lifecycleObserver = obs;
    WidgetsBinding.instance.addObserver(obs);
  }

  void _detachLifecycle() {
    final obs = _lifecycleObserver;
    if (obs == null) return;
    _lifecycleObserver = null;
    WidgetsBinding.instance.removeObserver(obs);
  }

  void _restartPolling(bool active) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!active) {
      _detachLifecycle();
      return;
    }
    _attachLifecycle();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(refreshInventory());
    });
  }

  /// Сагсны барьцааг серверийн үлдэгдэл дээр дахин тусгана.
  void _applyReservations() {
    final reserved = reservedQtyResolver?.call();
    if (reserved == null || reserved.isEmpty) return;
    for (final e in reserved.entries) {
      if (e.value <= 0) continue;
      final i = _inventory.indexWhere((x) => x.product.id == e.key);
      if (i < 0) continue;
      _inventory[i] = _inventory[i].copyWith(
        currentStock: _inventory[i].currentStock - e.value,
      );
    }
  }

  /// Called from [ChangeNotifierProxyProvider] when [PosSession] changes after login.
  void syncSession(PosSession? session) {
    final org = session?.baiguullagiinId;
    final branch = session?.salbariinId;

    SocketService.instance.syncPosSession(session);

    final branchKey =
        (org != null && branch != null && org.isNotEmpty && branch.isNotEmpty)
            ? '$org|$branch'
            : null;
    if (branchKey != _socketBranchKey) {
      _socketBranchKey = branchKey;
      _uldegdelSub?.cancel();
      _uldegdelSub = null;
      if (branchKey != null) {
        _uldegdelSub =
            SocketService.instance.uldegdelChanged.listen((_) {
          unawaited(_loadInventoryFromAPI());
        });
      }
      // Сокет нь ганцаараа найдвартай биш тул давтамжит шинэчлэлтийг
      // салбар солигдох бүрд дахин тохируулна.
      _restartPolling(branchKey != null);
    }

    if (org == _baiguullagiinId && branch == _salbariinId) {
      return;
    }
    _baiguullagiinId = org;
    _salbariinId = branch;
    if (org != null &&
        org.isNotEmpty &&
        branch != null &&
        branch.isNotEmpty) {
      _loadInventoryFromAPI();
    } else {
      _inventory.clear();
      _error = null;
      notifyListeners();
    }
  }

  Future<void> _loadInventoryFromAPI() async {
    final org = _baiguullagiinId;
    final branch = _salbariinId;
    if (org == null ||
        org.isEmpty ||
        branch == null ||
        branch.isEmpty) {
      _inventory.clear();
      _error = 'Салбарын мэдээлэл байхгүй';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final productResult = await _productService.getAllProductsForBranch(
        baiguullagiinId: org,
        salbariinId: branch,
      );

      if (productResult.success) {
        _inventory.clear();
        _inventory.addAll(productResult.products.map((product) => InventoryItem(
              product: product,
              currentStock: product.uldegdel ?? product.stock,
              minStockLevel: 10,
              costPrice: product.urtugUne,
              lastRestocked: product.createdAt,
            )));
        // Сагсанд аль хэдийн авсан барааг серверийн үлдэгдлээс дахин хасна.
        _applyReservations();
        _lastLoadedAt = DateTime.now();
        _error = null;
      } else {
        _inventory.clear();
        _error = productResult.error ?? 'Бараа ачаалахад алдаа';
      }
    } catch (e) {
      _inventory.clear();
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Гараар / давтамжаар / апп сэргэхэд дуудагдана.
  ///
  /// [force] нь хэрэглэгчийн шууд үйлдэл (доош чирэх г.м) — хугацааны
  /// хязгаарлалтыг үл харгалзана.
  Future<void> refreshInventory({bool force = false}) async {
    if (_isLoading) return;
    if (!force) {
      final last = _lastLoadedAt;
      if (last != null && DateTime.now().difference(last) < _minReloadGap) {
        return;
      }
    }
    await _loadInventoryFromAPI();
  }

  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Хамгийн СҮҮЛД бүртгэсэн бараа эхэнд.
  ///
  /// Сервер `/aguulakh`-г `createdAt: -1`-ээр буцаадаг ч хуудас хуудсаар нь
  /// нийлүүлдэг тул энд тодорхой эрэмбэлж баталгаажуулна.
  static void sortNewestFirst(List<InventoryItem> list) {
    list.sort((a, b) {
      final byDate = b.registeredAtKey.compareTo(a.registeredAtKey);
      if (byDate != 0) return byDate;
      return a.product.name.compareTo(b.product.name);
    });
  }

  List<InventoryItem> get filteredInventory {
    final showAll =
        _selectedCategory == 'Бүгд' || _selectedCategory == 'All';
    final list = _inventory.where((item) {
      final p = item.product;
      final matchesCategory = showAll ||
          p.category == _selectedCategory ||
          p.angilal == _selectedCategory ||
          (p.angilal?.contains(_selectedCategory) == true);
      final matchesSearch = _searchQuery.isEmpty ||
          item.product.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item.product.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.product.code
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ==
              true ||
          item.product.barCode
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ==
              true;
      return matchesCategory && matchesSearch;
    }).toList();
    sortNewestFirst(list);
    return list;
  }

  List<InventoryItem> get lowStockItems {
    return _inventory.where((item) => item.isLowStock).toList();
  }

  List<InventoryItem> get outOfStockItems {
    return _inventory.where((item) => item.isOutOfStock).toList();
  }

  List<String> get categories {
    final names = <String>{};
    for (final i in _inventory) {
      final c = i.product.category.trim();
      if (c.isNotEmpty) names.add(c);
      final a = i.product.angilal?.trim();
      if (a != null && a.isNotEmpty) names.add(a);
    }
    final sorted = names.toList()..sort();
    return ['Бүгд', ...sorted];
  }

  /// Out-of-stock rows for the current branch, newest first; optional category + name/code search.
  List<InventoryItem> outOfStockItemsFiltered({
    required String category,
    required String searchQuery,
  }) {
    final showAll = category == 'Бүгд' || category == 'All';
    final q = searchQuery.trim().toLowerCase();

    bool matchesCategory(InventoryItem item) {
      if (showAll) return true;
      final p = item.product;
      return p.category == category ||
          p.angilal == category ||
          (p.angilal?.contains(category) == true);
    }

    bool matchesSearch(InventoryItem item) {
      if (q.isEmpty) return true;
      final p = item.product;
      return p.name.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          (p.code?.toLowerCase().contains(q) == true) ||
          (p.barCode?.toLowerCase().contains(q) == true) ||
          p.olonBarCodeJagsaalt.any((b) => b.toLowerCase().contains(q));
    }

    final list = _inventory
        .where((i) => i.isOutOfStock)
        .where(matchesCategory)
        .where(matchesSearch)
        .toList();

    int sortKey(InventoryItem i) {
      final t = i.product.createdAt ??
          i.product.updatedAt ??
          i.lastRestocked ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return t.millisecondsSinceEpoch;
    }

    list.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
    return list;
  }

  /// Low-stock rows for the current branch, newest first; optional category + name/code search.
  List<InventoryItem> lowStockItemsFiltered({
    required String category,
    required String searchQuery,
  }) {
    final showAll = category == 'Бүгд' || category == 'All';
    final q = searchQuery.trim().toLowerCase();

    bool matchesCategory(InventoryItem item) {
      if (showAll) return true;
      final p = item.product;
      return p.category == category ||
          p.angilal == category ||
          (p.angilal?.contains(category) == true);
    }

    bool matchesSearch(InventoryItem item) {
      if (q.isEmpty) return true;
      final p = item.product;
      return p.name.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          (p.code?.toLowerCase().contains(q) == true) ||
          (p.barCode?.toLowerCase().contains(q) == true) ||
          p.olonBarCodeJagsaalt.any((b) => b.toLowerCase().contains(q));
    }

    final list = _inventory
        .where((i) => i.isLowStock)
        .where(matchesCategory)
        .where(matchesSearch)
        .toList();

    int sortKey(InventoryItem i) {
      final t = i.product.createdAt ??
          i.product.updatedAt ??
          i.lastRestocked ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return t.millisecondsSinceEpoch;
    }

    list.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
    return list;
  }

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  int get totalStockCount =>
      _inventory.fold(0, (sum, item) => sum + item.currentStock);
  double get totalInventoryValue =>
      _inventory.fold(0, (sum, item) => sum + item.stockValue);
  int get lowStockCount => lowStockItems.length;

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void addProduct(Product product,
      {int initialStock = 0, double? costPrice, int? minStockLevel}) {
    final existingIndex =
        _inventory.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _inventory[existingIndex] = _inventory[existingIndex].copyWith(
        currentStock: _inventory[existingIndex].currentStock + initialStock,
        costPrice: costPrice ?? _inventory[existingIndex].costPrice,
        minStockLevel: minStockLevel ?? _inventory[existingIndex].minStockLevel,
        lastRestocked: DateTime.now(),
      );
    } else {
      _inventory.add(InventoryItem(
        product: product,
        currentStock: initialStock,
        costPrice: costPrice,
        minStockLevel: minStockLevel ?? 10,
        lastRestocked: initialStock > 0 ? DateTime.now() : null,
      ));
    }
    notifyListeners();
  }

  void updateStock(String productId, int newStock) {
    final index = _inventory.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _inventory[index] = _inventory[index].copyWith(
        currentStock: newStock,
        lastRestocked: newStock > _inventory[index].currentStock
            ? DateTime.now()
            : _inventory[index].lastRestocked,
      );
      notifyListeners();
    }
  }

  void restock(String productId, int amount) {
    final index = _inventory.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _inventory[index] = _inventory[index].copyWith(
        currentStock: _inventory[index].currentStock + amount,
        lastRestocked: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Үлдэгдлээс [amount]-ыг хасна. Бараа олдвол `true`.
  ///
  /// Энэ нь [restock]-ийн ЯГ эсрэг үйлдэл байх ЁСТОЙ: хасалт нь 0 дээр
  /// таслагдвал (нэмэлт нь дээд хязгааргүй тул) "+"-г үлдэгдлээс илүү
  /// дараад "−" дарах бүрд үлдэгдэл нь анхныхаасаа өсдөг байв. Тиймээс
  /// үлдэгдэл ХАСАХ утга руу орохыг зөвшөөрнө — кассчинд "хэдээр илүү
  /// зарсныг" шууд харуулах бөгөөд сагс ба үлдэгдэл хэзээ ч салахгүй:
  ///
  ///     үлдэгдэл + сагсан дахь тоо == анхны үлдэгдэл
  ///
  /// Үлдэгдэлгүй барааг сагсанд огт оруулахгүй байх шийдвэрийг дуудагч
  /// (дэлгэц) гаргана — энд хориглодоггүй.
  /// [amount]-ыг зарж болох эсэх — үлдэгдэл хүрэлцэхгүй бол `false`.
  ///
  /// [deductStock] нь ЗОРИУДААР хасах утга руу оруулдаг (дээрх тэнцлийг
  /// хадгалахын тулд), тиймээс "үлдэгдлээс илүү зарахгүй" шийдвэрийг ЭНД,
  /// дуудагчийн талд гаргана. Дэлгэц "+"-ийг үүгээр хаана.
  bool canSell(String productId, [int amount = 1]) {
    if (amount <= 0) return false;
    final index = _inventory.indexWhere((item) => item.product.id == productId);
    if (index < 0) return false;
    return _inventory[index].currentStock >= amount;
  }

  bool deductStock(String productId, int amount) {
    if (amount <= 0) return true;
    final index = _inventory.indexWhere((item) => item.product.id == productId);
    if (index < 0) return false;
    _inventory[index] = _inventory[index].copyWith(
      currentStock: _inventory[index].currentStock - amount,
    );
    notifyListeners();
    return true;
  }

  void updateProduct(Product updatedProduct) {
    final index =
        _inventory.indexWhere((item) => item.product.id == updatedProduct.id);
    if (index >= 0) {
      _inventory[index] = _inventory[index].copyWith(product: updatedProduct);
      notifyListeners();
    }
  }

  Future<({bool success, String? error})> deleteProduct(String productId) async {
    final result = await _productService.deleteAguulakh(productId);
    if (result.success) {
      _inventory.removeWhere((item) => item.product.id == productId);
      notifyListeners();
    }
    return result;
  }

  InventoryItem? getInventoryItem(String productId) {
    try {
      return _inventory.firstWhere((item) => item.product.id == productId);
    } catch (_) {
      return null;
    }
  }
}


/// Апп нүүр рүү эргэж ирэхэд үлдэгдлийг шинэчлэх ажиглагч.
class _InventoryLifecycleObserver with WidgetsBindingObserver {
  _InventoryLifecycleObserver(this.onResumed);

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
