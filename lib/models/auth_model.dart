import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../auth/staff_screen_access.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/pos_settings_service.dart';
import '../services/socket_service.dart';
import '../services/terminal_session_store.dart';
import 'branch_option.dart';
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
  static const _bioUserKey = 'biometric_username';
  static const _bioPassKey = 'biometric_password';

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _requiresTwoFactor = false;
  String _pending2FAUsername = '';
  PosSession? _posSession;
  /// When [login] / [verifyTwoFactorCode] returns multiple `salbaruud`, user picks one here.
  List<BranchOption>? _pendingBranchOptions;
  List<BranchOption>? _allBranchOptions;
  StaffScreenAccess _staffAccess = StaffScreenAccess.denied;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get requiresTwoFactor => _requiresTwoFactor;
  String get pending2FAUsername => _pending2FAUsername;
  bool get isLoggedIn => _currentUser != null;

  StaffScreenAccess get staffAccess => _staffAccess;

  /// Set when [login] or [verifyTwoFactorCode] fails; cleared on success.
  String? _lastAuthError;
  String? get lastAuthError => _lastAuthError;

  /// Persists credentials for biometric login. Must not block login indefinitely
  /// (secure storage can hang on some devices / keystore states).
  Future<void> _saveBiometricLoginCredentials(
    String username,
    String password,
  ) async {
    try {
      await Future.wait([
        _secureStorage.write(key: _bioUserKey, value: username),
        _secureStorage.write(key: _bioPassKey, value: password),
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore — user can still use password login; biometric may be unavailable.
    }
  }

  /// Branch + org for `posBack` sale APIs (set on real API login).
  PosSession? get posSession => _posSession;

  /// More than one салбар on the account — show [BranchSelectScreen] before [PostLoginHome].
  bool get needsBranchSelection =>
      _pendingBranchOptions != null && _pendingBranchOptions!.length > 1;

  List<BranchOption>? get pendingBranchOptions => _pendingBranchOptions;

  /// Applies chosen салбар and clears [needsBranchSelection].
  void applySelectedBranch(String salbariinId) {
    if (_posSession == null) return;
    _posSession = PosSession(
      baiguullagiinId: _posSession!.baiguullagiinId,
      salbariinId: salbariinId,
      ajiltan: _posSession!.ajiltan,
    );
    _pendingBranchOptions = null;
    notifyListeners();
  }

  /// Branches available for switching (login options, employee salbaruud, or org branches).
  List<BranchOption> get branchSwitchOptions {
    if (_allBranchOptions != null && _allBranchOptions!.isNotEmpty) {
      return _allBranchOptions!;
    }
    if (_pendingBranchOptions != null && _pendingBranchOptions!.isNotEmpty) {
      return _pendingBranchOptions!;
    }
    return BranchOption.parseList(_posSession?.ajiltan['salbaruud']);
  }

  bool get canSwitchBranch =>
      branchSwitchOptions.length > 1 ||
      (_currentUser != null && _currentUser!.role == UserRole.admin) ||
      _staffAccess.allowsDashboard;

  /// Loads org branch list for admins / multi-branch users if not loaded yet.
  Future<void> ensureBranchOptionsLoaded() async {
    if (_allBranchOptions != null && _allBranchOptions!.length > 1) return;
    final session = _posSession;
    if (session == null) return;
    final bid = session.baiguullagiinId.trim();
    if (bid.isEmpty) return;
    try {
      final settings = PosSettingsService(api: posApiService);
      final orgRows = await settings.fetchSalbaruud(bid);
      final fromOrg = BranchOption.parseList(orgRows);
      if (fromOrg.isNotEmpty) {
        _allBranchOptions = fromOrg;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Label for the active `salbariinId` within [branchSwitchOptions], else raw id.
  String get activeSalbariinLabel {
    final id = _posSession?.salbariinId;
    if (id == null) return '';
    for (final b in branchSwitchOptions) {
      if (b.id == id) return b.label;
    }
    return id;
  }

  /// Display name of the active merchant / organization or branch.
  String get merchantDisplayName {
    final s = _posSession;
    if (s == null) return '';
    final a = s.ajiltan;
    final bgn = a['baiguullagiinNer'] ?? a['baiguullagaNer'] ?? a['merchantName'] ?? a['ner'] ?? a['name'];
    if (bgn != null && bgn.toString().trim().isNotEmpty) {
      return bgn.toString().trim();
    }
    if (a['baiguullaga'] is Map) {
      final bName = a['baiguullaga']['ner'] ?? a['baiguullaga']['name'];
      if (bName != null && bName.toString().trim().isNotEmpty) {
        return bName.toString().trim();
      }
    }
    if (a['salbar'] is Map) {
      final sName = a['salbar']['ner'] ?? a['salbar']['name'];
      if (sName != null && sName.toString().trim().isNotEmpty) {
        return sName.toString().trim();
      }
    }
    final label = activeSalbariinLabel;
    if (label.isNotEmpty) return label;
    return '';
  }

  /// When true, checkout submits to the same backend as Next.js `pos`.
  bool get canSubmitPosSales =>
      _posSession != null &&
      (posApiService.token != null && posApiService.token!.isNotEmpty);

  /// Restores a terminal auto-login session persisted by [TerminalSessionStore]
  /// (written on terminal login, see [AuthService.login]/[AuthService.verifyTwoFactor]).
  /// Called once at cold start (`main.dart`), before any UI/socket depends on
  /// [posSession] — lets a process restarted by `BackgroundWatchdogService` or a
  /// device reboot land straight on [CashierMainScreen] with no human input.
  /// Returns false (no-op) on a phone install or a terminal that never logged in.
  Future<bool> tryRestoreTerminalSession() async {
    final saved = await TerminalSessionStore.instance.restore();
    if (saved == null) {
      debugPrint('>>> [AuthModel] tryRestoreTerminalSession: nothing persisted');
      return false;
    }

    final token = saved['token']?.toString();
    final baiguullagiinId = saved['baiguullagiinId']?.toString();
    final salbariinId = saved['salbariinId']?.toString();
    final ajiltanRaw = saved['ajiltan'];
    if (token == null ||
        token.isEmpty ||
        baiguullagiinId == null ||
        baiguullagiinId.isEmpty ||
        salbariinId == null ||
        salbariinId.isEmpty ||
        ajiltanRaw is! Map) {
      debugPrint('>>> [AuthModel] tryRestoreTerminalSession: persisted session malformed');
      return false;
    }
    final ajiltan = Map<String, dynamic>.from(ajiltanRaw);

    posApiService.setToken(token);

    final staffAccess = StaffScreenAccess.fromAjiltan(ajiltan);
    _currentUser = User(
      id: ajiltan['_id'] ?? ajiltan['id'] ?? '',
      username: ajiltan['burtgeliinDugaar'] ?? '',
      name: ajiltan['ner'] ?? ajiltan['name'] ?? '',
      email: ajiltan['mail']?.toString() ?? ajiltan['email']?.toString(),
      phone: ajiltan['utas'] ?? ajiltan['phone'],
      isTwoFactorEnabled: ajiltan['isTwoFactorEnabled'] ?? false,
      isBiometricEnabled: ajiltan['isBiometricEnabled'] ?? false,
      createdAt: DateTime.tryParse(
              ajiltan['burtgesenOgnoo'] ?? ajiltan['createdAt'] ?? '') ??
          DateTime.now(),
      role: roleHintFromAccess(staffAccess),
    );
    _posSession = PosSession(
      baiguullagiinId: baiguullagiinId,
      salbariinId: salbariinId,
      ajiltan: ajiltan,
    );
    _staffAccess = staffAccess;
    _isAuthenticated = true;
    _lastAuthError = null;
    debugPrint('>>> [AuthModel] tryRestoreTerminalSession: restored salbariinId=$salbariinId');
    notifyListeners();
    return true;
  }

  Future<bool> login(String username, String password) async {
    // Call real API
    final result = await authService.login(
      username: username.trim(),
      password: password,
    );

    if (result.success) {
      _lastAuthError = null;
      // Save credentials for future biometric login.
      // (Stored encrypted by OS via flutter_secure_storage).
      await _saveBiometricLoginCredentials(username.trim(), password);
      _staffAccess = result.staffAccess ?? StaffScreenAccess.denied;
      if (result.requiresTwoFactor) {
        _requiresTwoFactor = true;
        _pending2FAUsername = username.trim();
        _posSession = result.posSession;
        _pendingBranchOptions = result.branchOptions;
        notifyListeners();
        return true;
      }

      _currentUser = result.user;
      _posSession = result.posSession;
      _pendingBranchOptions = result.branchOptions;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }

    _lastAuthError = result.error;
    notifyListeners();
    return false;
  }

  Future<bool> verifyTwoFactorCode(String code) async {
    // Call real API for 2FA verification
    final result = await authService.verifyTwoFactor(
      username: _pending2FAUsername,
      code: code,
    );

    if (result.success) {
      _lastAuthError = null;
      if (result.staffAccess != null) {
        _staffAccess = result.staffAccess!;
      }
      _currentUser = result.user ?? _currentUser;
      _posSession = result.posSession ?? _posSession;
      _pendingBranchOptions = result.branchOptions;
      _isAuthenticated = true;
      _requiresTwoFactor = false;
      _pending2FAUsername = '';
      notifyListeners();
      return true;
    }

    _lastAuthError = result.error;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithBiometric() async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      final username = await _secureStorage.read(key: _bioUserKey);
      final password = await _secureStorage.read(key: _bioPassKey);
      if (username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        return false;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'Нэвтрэхийн тулд биометр баталгаажуулалт хийнэ үү',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (!ok) return false;
      return login(username, password);
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final types = await _localAuth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await authService.logout();
    } catch (_) {
      // Offline or /garah failure — still end the session locally.
    }
    SocketService.instance.disconnect();
    await TerminalSessionStore.instance.clear();
    _currentUser = null;
    _posSession = null;
    _pendingBranchOptions = null;
    _staffAccess = StaffScreenAccess.denied;
    _lastAuthError = null;
    _isAuthenticated = false;
    _requiresTwoFactor = false;
    _pending2FAUsername = '';
    notifyListeners();
  }

  Future<bool> resetPassword(String phone) async {
    return await authService.requestPasswordReset(phone.trim());
  }

  Future<bool> confirmPasswordReset(String phone, String code, String newPassword) async {
    return await authService.resetPassword(
      phone: phone.trim(),
      code: code.trim(),
      newPassword: newPassword,
    );
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

  /// After `PUT /ajiltan/:id` (хувийн мэдээлэл), keep [posSession.ajiltan] in sync.
  void mergePosSessionAjiltan(Map<String, dynamic> fields) {
    if (_posSession == null) return;
    final m = Map<String, dynamic>.from(_posSession!.ajiltan);
    fields.forEach((k, v) {
      m[k] = v;
    });
    _posSession = PosSession(
      baiguullagiinId: _posSession!.baiguullagiinId,
      salbariinId: _posSession!.salbariinId,
      ajiltan: m,
    );
    final ner = m['ner']?.toString();
    if (_currentUser != null && ner != null && ner.isNotEmpty) {
      _currentUser = _currentUser!.copyWith(
        name: ner,
        phone: m['utas']?.toString(),
      );
    }
    notifyListeners();
  }
}
