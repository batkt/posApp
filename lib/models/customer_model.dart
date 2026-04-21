import 'dart:async';

import 'package:flutter/foundation.dart';

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
    );
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

    return Customer(
      id: id.isNotEmpty ? id : 'unknown',
      name: displayName,
      phone: phone.isNotEmpty ? phone : '—',
      email: mail?.trim().isNotEmpty == true ? mail!.trim() : null,
      address: khayag?.trim().isNotEmpty == true ? khayag!.trim() : null,
      type: type,
      createdAt: createdAt,
      totalPurchases: 0,
      totalSpent: 0,
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
      _customers
        ..clear()
        ..addAll(result.rows.map(Customer.fromKhariltsagch));
      _error = null;
    } else {
      _customers.clear();
      _error = result.error;
    }

    _loading = false;
    notifyListeners();
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
