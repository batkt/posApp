import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/khariltsagch_service.dart';
import 'pos_session.dart';

enum CustomerType { individual, corporate, vip }

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final CustomerType type;
  final double? creditLimit;
  final double? currentCredit;
  final DateTime createdAt;
  final DateTime? lastPurchase;
  final int totalPurchases;
  final double totalSpent;

  /// Вэбийн `khariltsagch.khunglukhEsekh` — хөнгөлөлт идэвхтэй эсэх.
  final bool discountEnabled;

  /// Вэбийн `khariltsagch.khunglukhTurul` — `Хувь` эсвэл `Мөнгөн дүн`.
  final String discountType;

  /// Вэбийн `khariltsagch.khunglukhDun` (`Мөнгөн дүн` төрөлд).
  final double discountAmount;

  /// Вэбийн `khariltsagch.khunglukhKhuvi` (`Хувь` төрөлд).
  final double discountPercent;

  static const String discountTypeAmount = 'Мөнгөн дүн';
  static const String discountTypePercent = 'Хувь';

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.type = CustomerType.individual,
    this.creditLimit,
    this.currentCredit,
    required this.createdAt,
    this.lastPurchase,
    this.totalPurchases = 0,
    this.totalSpent = 0.0,
    this.discountEnabled = false,
    this.discountType = discountTypeAmount,
    this.discountAmount = 0.0,
    this.discountPercent = 0.0,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    CustomerType? type,
    double? creditLimit,
    double? currentCredit,
    DateTime? createdAt,
    DateTime? lastPurchase,
    int? totalPurchases,
    double? totalSpent,
    bool? discountEnabled,
    String? discountType,
    double? discountAmount,
    double? discountPercent,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      type: type ?? this.type,
      creditLimit: creditLimit ?? this.creditLimit,
      currentCredit: currentCredit ?? this.currentCredit,
      createdAt: createdAt ?? this.createdAt,
      lastPurchase: lastPurchase ?? this.lastPurchase,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalSpent: totalSpent ?? this.totalSpent,
      discountEnabled: discountEnabled ?? this.discountEnabled,
      discountType: discountType ?? this.discountType,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  /// Хөнгөлөлтийг хүн уншихаар бичсэн тэмдэглэгээ ("15%" / "5,000₮" / "—").
  String get discountLabel {
    if (!discountEnabled) return '—';
    if (discountType == discountTypePercent) {
      final p = discountPercent;
      final txt = p == p.roundToDouble()
          ? p.toStringAsFixed(0)
          : p.toStringAsFixed(2);
      return '$txt%';
    }
    return '${discountAmount.toStringAsFixed(0)}₮';
  }

  String get typeLabel {
    switch (type) {
      case CustomerType.individual:
        return 'Хувь хүн';
      case CustomerType.corporate:
        return 'Байгууллага';
      case CustomerType.vip:
        return 'VIP';
    }
  }

  /// First letter for avatar (handles empty / whitespace).
  String get initialsLetter {
    for (final rune in name.runes) {
      final s = String.fromCharCode(rune);
      if (s.trim().isNotEmpty) {
        return s.toUpperCase();
      }
    }
    return '?';
  }

  static Customer fromKhariltsagch(Map<String, dynamic> m) {
    final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
    final ovog = (m['ovog'] as String?)?.trim() ?? '';
    final ner = (m['ner'] as String?)?.trim() ?? '';
    final nameParts = <String>[];
    if (ovog.isNotEmpty) nameParts.add(ovog);
    if (ner.isNotEmpty) nameParts.add(ner);
    final displayName =
        nameParts.isNotEmpty ? nameParts.join(' ') : (ner.isNotEmpty ? ner : '—');

    final utasRaw = m['utas'];
    var phone = '';
    if (utasRaw is List && utasRaw.isNotEmpty) {
      phone = utasRaw.first?.toString() ?? '';
    } else if (utasRaw is String) {
      phone = utasRaw;
    }

    final mail = m['mail'] as String?;
    final khayag = m['khayag'] as String?;

    final turul =
        '${m['khariltsagchiinTurul'] ?? ''} ${m['turul'] ?? ''}'.toLowerCase();
    CustomerType type = CustomerType.individual;
    if (turul.contains('аан') ||
        turul.contains('байгуул') ||
        turul.contains('корп')) {
      type = CustomerType.corporate;
    } else if (turul.contains('vip')) {
      type = CustomerType.vip;
    }

    DateTime createdAt = DateTime.now();
    final ca = m['createdAt'];
    if (ca is String) {
      createdAt = DateTime.tryParse(ca) ?? createdAt;
    }

    final purchases = (m['guilgeeniiToo'] as num?)?.toInt() ??
        (m['totalPurchases'] as num?)?.toInt() ??
        (m['too'] as num?)?.toInt() ??
        (m['borluulaltToo'] as num?)?.toInt() ??
        0;

    final spent = (m['niitDun'] as num?)?.toDouble() ??
        (m['totalSpent'] as num?)?.toDouble() ??
        (m['borluulaltiinDun'] as num?)?.toDouble() ??
        (m['borluulaltDun'] as num?)?.toDouble() ??
        (m['avlagaUldegdel'] as num?)?.toDouble() ??
        0.0;

    final khunglukhTurul = m['khunglukhTurul']?.toString().trim();

    return Customer(
      id: id.isNotEmpty ? id : 'unknown',
      name: displayName,
      phone: phone.isNotEmpty ? phone : '—',
      email: mail?.trim().isNotEmpty == true ? mail!.trim() : null,
      address: khayag?.trim().isNotEmpty == true ? khayag!.trim() : null,
      type: type,
      createdAt: createdAt,
      totalPurchases: purchases,
      totalSpent: spent,
      discountEnabled: m['khunglukhEsekh'] == true,
      discountType: khunglukhTurul == discountTypePercent
          ? discountTypePercent
          : discountTypeAmount,
      discountAmount: (m['khunglukhDun'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (m['khunglukhKhuvi'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomerModel extends ChangeNotifier {
  CustomerModel({KhariltsagchService? service})
      : _service = service ?? KhariltsagchService();

  final KhariltsagchService _service;

  final List<Customer> _customers = [];

  PosSession? _session;
  String _searchQuery = '';
  bool _loading = false;
  String? _error;
  Timer? _searchDebounce;

  bool get isLoading => _loading;
  String? get loadError => _error;

  List<Customer> get customers => List.unmodifiable(_customers);

  /// Server-side search (same `/khariltsagch` query as web).
  List<Customer> get filteredCustomers => List.unmodifiable(_customers);

  void syncSession(PosSession? session) {
    _session = session;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      refresh();
    });
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null) {
      _customers.clear();
      _error = 'Салбарын сесс олдсонгүй';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    final result = await _service.fetchList(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      search: _searchQuery,
    );

    if (result.success) {
      final list = result.rows.map(Customer.fromKhariltsagch).toList();

      try {
        // ⚠️ Урьд нь `/khariltsagchaarKHudaldanAvalt`-ыг дууддаг байв. Тэр нь
        // НИЙЛҮҮЛЭГЧЭЭС авсан худалдан авалтын (orlogo) тайлан бөгөөд
        // `tooShirkheg` нь захиалгын тоо биш ширхэгийн нийлбэр. Түүнээс гадна
        // `salbariinId`-г МӨРӨӨР (String) илгээдэг байсныг сервер `$in`-д
        // хийдэг тул Mongo алдаа өгч, дуудалт бүтэн ЧИМЭЭГҮЙ уначихдаг байсан
        // (`catch (_) {}`) — иймд "Захиалга" үргэлж 0 харагдана.
        final salesStatsRes = await posApiService.post<List<dynamic>>(
          '/khariltsagchiinBorluulaltiinTovchoo',
          body: {
            'baiguullagiinId': session.baiguullagiinId,
            'salbariinId': [session.salbariinId],
          },
          parser: (d) => d is List ? d : [],
        );

        if (salesStatsRes.success && salesStatsRes.data != null) {
          final statsMap = <String, Map<String, dynamic>>{};
          for (final item in salesStatsRes.data!) {
            if (item is Map) {
              final kid = item['_id']?.toString();
              if (kid != null && kid.isNotEmpty) {
                statsMap[kid] = Map<String, dynamic>.from(item);
              }
            }
          }

          if (statsMap.isNotEmpty) {
            for (var i = 0; i < list.length; i++) {
              final c = list[i];
              final stat = statsMap[c.id];
              if (stat != null) {
                final cnt =
                    (stat['guilgeeniiToo'] as num?)?.toInt() ??
                        c.totalPurchases;
                final amt =
                    (stat['niitDun'] as num?)?.toDouble() ?? c.totalSpent;
                list[i] = c.copyWith(
                  totalPurchases: cnt,
                  totalSpent: amt,
                );
              }
            }
          }
        }
      } catch (_) {}

      _customers
        ..clear()
        ..addAll(list);
      _error = null;
    } else {
      _customers.clear();
      _error = result.error;
    }

    _loading = false;
    notifyListeners();
  }

  /// `POST /khariltsagchBurtgeye` — same as web `khariltsagchNemekhModal`.
  /// [khariltsagchiinTurul] is `Иргэн` or `ААН`. [turul] is `Худалдан авагч` /
  /// `Нийлүүлэгч` or `Ажилтан`.
  Future<String?> registerCustomer({
    required String khariltsagchiinTurul,
    required String turul,
    String? ovog,
    required String ner,
    required String utas,
    String? register,
    String? mail,
    String? khayag,
    bool khunglukhEsekh = false,
    String khunglukhTurul = Customer.discountTypeAmount,
    double khunglukhDun = 0,
    double khunglukhKhuvi = 0,
  }) async {
    final session = _session;
    if (session == null) {
      return 'Салбарын сесс олдсонгүй';
    }
    final res = await _service.registerBurtgeye(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      khariltsagchiinTurul: khariltsagchiinTurul,
      turul: turul,
      ovog: ovog,
      ner: ner,
      utas: [utas],
      register: register,
      mail: mail,
      khayag: khayag,
      khunglukhEsekh: khunglukhEsekh,
      khunglukhTurul: khunglukhTurul,
      khunglukhDun: khunglukhDun,
      khunglukhKhuvi: khunglukhKhuvi,
    );
    if (res.success) {
      await refresh();
      return null;
    }
    return res.error ?? 'Бүртгэл амжилтгүй';
  }

  /// Байгаа харилцагчийн хөнгөлөлтийг өөрчилнө. Алдаагүй бол `null` буцаана.
  Future<String?> updateCustomerDiscount({
    required String khariltsagchiinId,
    required bool enabled,
    required String type,
    required double amount,
    required double percent,
  }) async {
    final res = await _service.updateKhunglult(
      khariltsagchiinId: khariltsagchiinId,
      khunglukhEsekh: enabled,
      khunglukhTurul: type,
      khunglukhDun: amount,
      khunglukhKhuvi: percent,
    );
    if (!res.success) return res.error ?? 'Хөнгөлөлт хадгалахад алдаа';

    // Сервер рүү амжилттай хадгалагдсан тул жагсаалтыг шууд шинэчилнэ —
    // бүтэн `refresh()` хийхээс өмнө хэрэглэгч өөрчлөлтөө шууд хардаг.
    final i = _customers.indexWhere((c) => c.id == khariltsagchiinId);
    if (i >= 0) {
      _customers[i] = _customers[i].copyWith(
        discountEnabled: enabled,
        discountType: type,
        discountAmount: enabled ? amount : 0,
        discountPercent: enabled ? percent : 0,
      );
      notifyListeners();
    }
    await refresh();
    return null;
  }

  void addCustomer(Customer customer) {
    _customers.add(customer);
    notifyListeners();
  }

  void updateCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index >= 0) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  void deleteCustomer(String id) {
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Customer? getCustomerById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
