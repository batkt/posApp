import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/connectivity.dart';
import 'forgot_password_screen.dart';
import 'two_factor_auth_screen.dart';
import 'post_login_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final auth = context.read<AuthModel>();
    final available = await auth.isBiometricAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Check network connectivity
    final isOnline = await Connectivity.isOnline();
    if (!isOnline) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('no_internet')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;

    final username = _usernameController.text;
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    var success = false;
    final auth = context.read<AuthModel>();
    try {
      success = await auth.login(username, password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Нэвтрэхэд алдаа: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    if (success) {
      if (auth.requiresTwoFactor) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TwoFactorAuthScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PostLoginHome()),
        );
      }
    } else {
      final l10n = AppLocalizations.of(context);
      final err = auth.lastAuthError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? l10n.tr('invalid_username_or_password')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() => _isLoading = true);
    var success = false;
    try {
      final auth = context.read<AuthModel>();
      final isAvailable = await auth.isBiometricAvailable();

      if (!isAvailable) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.tr('biometric_unavailable')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      success = await auth.loginWithBiometric();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Биометр нэвтрэхэд алдаа: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PostLoginHome()),
      );
    } else {
      final auth = context.read<AuthModel>();
      final l10n = AppLocalizations.of(context);
      final msg = auth.lastAuthError ?? l10n.tr('biometric_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                // Header Logo
                SizedBox(
                  height: 180,
                  child: Image.asset(
                    'assets/images/poslogo.png',
                    fit: BoxFit.contain,
                    // Decode at display size to avoid heavy full-res decode
                    cacheWidth: 600,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store,
                              size: 80,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'POS System',
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Consumer<LocaleModel>(builder: (context, localeModel, child) {
                  final l10n = AppLocalizations(localeModel.locale);
                  return Column(
                    children: [
                      Text(
                        l10n.tr('login_title'),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.tr('username'),
                          hintText: l10n.tr('username_hint'),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.tr('invalid_username');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: l10n.tr('password'),
                          hintText: l10n.tr('password_hint'),
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.tr('invalid_password');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(l10n.tr('forgot_password')),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 32),

                // Login Button + Biometric
                Consumer<LocaleModel>(builder: (context, localeModel, child) {
                  final l10n = AppLocalizations(localeModel.locale);
                  return SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        // Login Button
                        Expanded(
                          child: FilledButton(
                            onPressed: _isLoading ? null : _login,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size.fromHeight(64),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    l10n.tr('login_button'),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                        if (_biometricAvailable) ...[
                          const SizedBox(width: 12),
                          // Biometric Button
                          Tooltip(
                            message: l10n.tr('biometric_login'),
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _loginWithBiometric,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(64, 64),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Icon(
                                Icons.fingerprint,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
