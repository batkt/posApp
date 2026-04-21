import 'api_service.dart';
import '../auth/staff_screen_access.dart';
import '../models/auth_model.dart';
import '../models/pos_session.dart';

UserRole _roleHintFromAccess(StaffScreenAccess access) {
  if (access.hasFullAccess) return UserRole.admin;
  final narrowStaff = !access.allowsPosSystem &&
      !access.allowsAguulakh &&
      !access.allowsKhariltsagch;
  if (access.allowsKiosk && narrowStaff) {
    return UserRole.cashier;
  }
  if (access.allowsMobile &&
      !access.allowsKiosk &&
      narrowStaff) {
    return UserRole.cashier;
  }
  return UserRole.manager;
}

class AuthService {
  final ApiService _apiService;

  AuthService({ApiService? apiService})
      : _apiService = apiService ?? posApiService;

  /// Login with username and password
  /// Corresponds to: newterya(khereglech: { burtgeliinDugaar, nuutsUg, namaigsana })
  Future<AuthResult> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/ajiltanNevtrey',
        body: {
          'burtgeliinDugaar': username,
          'nuutsUg': password,
          'namaigsana': rememberMe,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final token = response.data!['token'] as String?;
        final userData = response.data!['result'] as Map<String, dynamic>?;
        final organizations =
            response.data!['baiguullagiinJagsaalt'] as List<dynamic>?;

        if (token != null) {
          final requires2fa = response.data!['requires2FA'] == true;
          // When 2FA is pending, `result` may be omitted until verification — enforce
          // permission map there; otherwise check on this response.
          final skipPermissionCheck = requires2fa && userData == null;
          if (!skipPermissionCheck &&
              StaffScreenAccess.isPermissionConfigurationMissing(userData)) {
            return AuthResult.error('Эрхийн тохиргоо хийгдээгүй байна.');
          }

          // Set token for future requests
          _apiService.setToken(token);
          posApiService.setToken(token);

          final staffAccess = StaffScreenAccess.fromAjiltan(userData);
          final user = User(
            id: userData?['_id'] ?? userData?['id'] ?? '',
            username: userData?['burtgeliinDugaar'] ?? username,
            name: userData?['ner'] ?? userData?['name'] ?? '',
            email: userData?['mail']?.toString() ?? userData?['email']?.toString(),
            phone: userData?['utas'] ?? userData?['phone'],
            isTwoFactorEnabled: userData?['isTwoFactorEnabled'] ?? false,
            isBiometricEnabled: userData?['isBiometricEnabled'] ?? false,
            createdAt: DateTime.tryParse(userData?['burtgesenOgnoo'] ??
                    userData?['createdAt'] ??
                    '') ??
                DateTime.now(),
            role: _roleHintFromAccess(staffAccess),
          );

          final posSession = PosSession.tryParse(userData);

          return AuthResult.success(
            user: user,
            token: token,
            requiresTwoFactor: response.data!['requires2FA'] ?? false,
            organizations: organizations?.cast<Map<String, dynamic>>(),
            posSession: posSession,
            staffAccess: staffAccess,
          );
        }
      }

      return AuthResult.error(response.message ?? 'Login failed');
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error('Unexpected error: $e');
    }
  }

  /// Verify 2FA code
  /// Corresponds to: 2FA verification step
  Future<AuthResult> verifyTwoFactor({
    required String username,
    required String code,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/batalgaajuulalt2FA',
        body: {
          'burtgeliinDugaar': username,
          'code': code,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final token = response.data!['token'] as String?;

        if (token != null) {
          final userData = response.data!['result'] as Map<String, dynamic>?;
          if (StaffScreenAccess.isPermissionConfigurationMissing(userData)) {
            return AuthResult.error('Эрхийн тохиргоо хийгдээгүй байна.');
          }

          _apiService.setToken(token);
          posApiService.setToken(token);

          final staffAccess = StaffScreenAccess.fromAjiltan(userData);
          final user = userData != null
              ? User(
                  id: userData['_id'] ?? userData['id'] ?? '',
                  username: userData['burtgeliinDugaar'] ?? '',
                  name: userData['ner'] ?? userData['name'] ?? '',
                  email: userData['mail']?.toString() ??
                      userData['email']?.toString(),
                  phone: userData['utas'] ?? userData['phone'],
                  isTwoFactorEnabled:
                      userData['isTwoFactorEnabled'] ?? false,
                  isBiometricEnabled:
                      userData['isBiometricEnabled'] ?? false,
                  createdAt: DateTime.tryParse(userData['burtgesenOgnoo'] ??
                          userData['createdAt'] ??
                          '') ??
                      DateTime.now(),
                  role: _roleHintFromAccess(staffAccess),
                )
              : null;
          final posSession = PosSession.tryParse(userData);

          return AuthResult.success(
            user: user,
            token: token,
            posSession: posSession,
            staffAccess: staffAccess,
          );
        }
      }

      return AuthResult.error(response.message ?? '2FA verification failed');
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error('Unexpected error: $e');
    }
  }

  /// Logout
  /// Corresponds to: garya()
  Future<void> logout() async {
    try {
      await _apiService.post(
        '/garah',
        body: {},
      );
    } finally {
      _apiService.clearToken();
      posApiService.clearToken();
    }
  }

  /// Get user permissions
  /// Corresponds to: baiguulgiinErkhiinJagsaalt
  Future<List<String>> getPermissions(String organizationId) async {
    try {
      final response = await _apiService.get<List<dynamic>>(
        '/erkh/$organizationId',
        parser: (data) => data as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!.cast<String>();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Check if token is valid
  Future<bool> validateToken() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/batalgaajuulahToken',
        parser: (data) => data as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/profile',
        body: updates,
        parser: (data) => data as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/nuutsUgShinechleh',
        body: {
          'odoogiinNuutsUg': currentPassword,
          'shineNuutsUg': newPassword,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String username) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/nuutsUgMartasan',
        body: {
          'burtgeliinDugaar': username,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Reset password with code
  Future<bool> resetPassword({
    required String username,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/nuutsUgShinechlehKod',
        body: {
          'burtgeliinDugaar': username,
          'batalgaajuulakhKod': code,
          'shineNuutsUg': newPassword,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      return false;
    }
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? token;
  final String? error;
  final bool requiresTwoFactor;
  final List<Map<String, dynamic>>? organizations;
  final PosSession? posSession;
  final StaffScreenAccess? staffAccess;

  const AuthResult._({
    required this.success,
    this.user,
    this.token,
    this.error,
    this.requiresTwoFactor = false,
    this.organizations,
    this.posSession,
    this.staffAccess,
  });

  factory AuthResult.success({
    User? user,
    required String token,
    bool requiresTwoFactor = false,
    List<Map<String, dynamic>>? organizations,
    PosSession? posSession,
    StaffScreenAccess? staffAccess,
  }) =>
      AuthResult._(
        success: true,
        user: user,
        token: token,
        requiresTwoFactor: requiresTwoFactor,
        organizations: organizations,
        posSession: posSession,
        staffAccess: staffAccess,
      );

  factory AuthResult.error(String error) => AuthResult._(
        success: false,
        error: error,
      );
}

final authService = AuthService();
