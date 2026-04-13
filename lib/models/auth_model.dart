import 'package:flutter/foundation.dart';
import '../auth/staff_screen_access.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'pos_session.dart';

enum UserRole { admin, manager, cashier }

class User {
  final String id;
  final String username;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final bool isTwoFactorEnabled;
  final bool isBiometricEnabled;
  final DateTime createdAt;
  final UserRole role;

  User({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.isTwoFactorEnabled = false,
    this.isBiometricEnabled = false,
    required this.createdAt,
    this.role = UserRole.admin,
  });

  bool get isCashier => role == UserRole.cashier;

  User copyWith({
    String? id,
    String? username,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    bool? isTwoFactorEnabled,
    bool? isBiometricEnabled,
    DateTime? createdAt,
    UserRole? role,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isTwoFactorEnabled: isTwoFactorEnabled ?? this.isTwoFactorEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
    );
  }
}

class AuthModel extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _requiresTwoFactor = false;
  String _pending2FAUsername = '';
  PosSession? _posSession;
  StaffScreenAccess _staffAccess = StaffScreenAccess.denied;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get requiresTwoFactor => _requiresTwoFactor;
  String get pending2FAUsername => _pending2FAUsername;
  bool get isLoggedIn => _currentUser != null;

  StaffScreenAccess get staffAccess => _staffAccess;

  /// Branch + org for `posBack` sale APIs (set on real API login).
  PosSession? get posSession => _posSession;

  /// When true, checkout submits to the same backend as Next.js `pos`.
  bool get canSubmitPosSales =>
      _posSession != null &&
      (posApiService.token != null && posApiService.token!.isNotEmpty);

  Future<bool> login(String username, String password) async {
    // Call real API
    final result = await authService.login(
      username: username.trim(),
      password: password,
    );

    if (result.success) {
      _staffAccess = result.staffAccess ?? StaffScreenAccess.denied;
      if (result.requiresTwoFactor) {
        _requiresTwoFactor = true;
        _pending2FAUsername = username.trim();
        _posSession = result.posSession;
        notifyListeners();
        return true;
      }

      _currentUser = result.user;
      _posSession = result.posSession;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> verifyTwoFactorCode(String code) async {
    // Call real API for 2FA verification
    final result = await authService.verifyTwoFactor(
      username: _pending2FAUsername,
      code: code,
    );

    if (result.success) {
      if (result.staffAccess != null) {
        _staffAccess = result.staffAccess!;
      }
      _currentUser = result.user ?? _currentUser;
      _posSession = result.posSession ?? _posSession;
      _isAuthenticated = true;
      _requiresTwoFactor = false;
      _pending2FAUsername = '';
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> loginWithBiometric() async {
    return false;
  }

  Future<bool> isBiometricAvailable() async {
    return false;
  }

  Future<void> logout() async {
    await authService.logout();
    _currentUser = null;
    _posSession = null;
    _staffAccess = StaffScreenAccess.denied;
    _isAuthenticated = false;
    _requiresTwoFactor = false;
    _pending2FAUsername = '';
    notifyListeners();
  }

  Future<bool> resetPassword(String username) async {
    return await authService.requestPasswordReset(username.trim());
  }

  Future<bool> updatePassword(
      String currentPassword, String newPassword) async {
    return await authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  void updateUser({
    String? name,
    String? phone,
    String? avatarUrl,
    bool? isTwoFactorEnabled,
    bool? isBiometricEnabled,
  }) {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      name: name,
      phone: phone,
      avatarUrl: avatarUrl,
      isTwoFactorEnabled: isTwoFactorEnabled,
      isBiometricEnabled: isBiometricEnabled,
    );

    notifyListeners();
  }
}
