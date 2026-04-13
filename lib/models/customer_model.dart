import 'package:flutter/foundation.dart';

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
}

class CustomerModel extends ChangeNotifier {
  final List<Customer> _customers = [
    Customer(
      id: 'cust-001',
      name: 'Бат Эрдэнэ',
      phone: '99119933',
      email: 'bat@email.com',
      address: 'Улаанбаатар, Сүхбаатар дүүрэг',
      type: CustomerType.vip,
      createdAt: DateTime(2024, 1, 15),
      lastPurchase: DateTime(2024, 4, 8),
      totalPurchases: 45,
      totalSpent: 1250000,
    ),
    Customer(
      id: 'cust-002',
      name: 'Оюун Болд',
      phone: '99119944',
      type: CustomerType.individual,
      createdAt: DateTime(2024, 2, 20),
      lastPurchase: DateTime(2024, 4, 5),
      totalPurchases: 12,
      totalSpent: 280000,
    ),
    Customer(
      id: 'cust-003',
      name: 'Tech Solutions LLC',
      phone: '75112233',
      email: 'info@tech.mn',
      address: 'Улаанбаатар, Баянзүрх дүүрэг',
      type: CustomerType.corporate,
      creditLimit: 5000000,
      currentCredit: 1200000,
      createdAt: DateTime(2024, 3, 1),
      lastPurchase: DateTime(2024, 4, 9),
      totalPurchases: 8,
      totalSpent: 3500000,
    ),
  ];

  String _searchQuery = '';

  List<Customer> get customers => List.unmodifiable(_customers);

  List<Customer> get filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.phone.contains(_searchQuery);
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
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
}
