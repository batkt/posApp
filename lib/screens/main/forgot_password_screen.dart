import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/auth_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/password_reset_rules.dart';
import 'dart:async';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _obscurePassword = true;

  /// Дахин илгээх хүртэлх үлдсэн секунд — SMS ирээгүй үед хэрэглэгч гацахгүй.
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendResetRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthModel>();
    final success = await auth.resetPassword(_phoneController.text.trim());

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      setState(() => _codeSent = true);
      _startResendCountdown();
    } else {
      showAppSnackBar(context, 'Утасны дугаар олдсонгүй. Шалгаад дахин оролдоно уу.', variant: AppSnackVariant.error);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  /// Дугаараа буруу бичсэн бол эхний алхам руу буцах — өмнө нь дэлгэцээ бүхэлд
  /// нь хааж дахин нээхээс өөр арга байгаагүй.
  void _backToPhoneStep() {
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _resendIn = 0;
      _codeController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _verifyAndResetCode() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final auth = context.read<AuthModel>();
    final success = await auth.confirmPasswordReset(
      _phoneController.text.trim(),
      _codeController.text.trim(),
      _newPasswordController.text,
    );
    setState(() => _isLoading = false);
    
    if (!mounted) return;
    if (success) {
      showAppSnackBar(context, 'Нууц үг амжилттай солигдлоо. Шинэ нууц үгээрээ нэвтэрнэ үү.', variant: AppSnackVariant.success);
      Navigator.pop(context); // close forgot password screen
    } else {
      showAppSnackBar(context, 'Код буруу эсвэл алдаа гарлаа.', variant: AppSnackVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Буцах',
          onPressed: _isLoading
              ? null
              : () => _codeSent ? _backToPhoneStep() : Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepRail(currentStep: _codeSent ? 1 : 0),
                    const SizedBox(height: 36),
                    Text(
                      _codeSent ? 'Шинэ нууц үг тохируулах' : 'Нууц үгээ сэргээх',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeSent
                          ? '${_phoneController.text} дугаарт илгээсэн кодоо оруулаад шинэ нууц үгээ үүсгэнэ үү.'
                          : 'Бүртгэлтэй утасны дугаараа оруулаарай. Баталгаажуулах код SMS-ээр илгээнэ.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!_codeSent) ..._phoneStep(cs, tt) else ..._resetStep(cs, tt),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(ColorScheme cs, TextTheme tt) => [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofocus: true,
          maxLength: PasswordResetRules.phoneLength,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(PasswordResetRules.phoneLength),
          ],
          onFieldSubmitted: (_) => _sendResetRequest(),
          decoration: const InputDecoration(
            labelText: 'Утасны дугаар',
            hintText: '8811 2233',
            counterText: '',
            prefixIcon: Icon(Icons.smartphone_outlined),
          ),
          validator: PasswordResetRules.phoneError,
        ),
        const SizedBox(height: 24),
        _primaryButton(label: 'Код илгээх', onPressed: _sendResetRequest),
      ];

  List<Widget> _resetStep(ColorScheme cs, TextTheme tt) => [
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Баталгаажуулах код',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
          validator: PasswordResetRules.codeError,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Шинэ нууц үг',
            helperText:
                'Хамгийн багадаа ${PasswordResetRules.minPasswordLength} тэмдэгт',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Нууц үг харах' : 'Нууц үг нуух',
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: PasswordResetRules.passwordError,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _verifyAndResetCode(),
          decoration: const InputDecoration(
            labelText: 'Шинэ нууц үг давтах',
            prefixIcon: Icon(Icons.lock_reset_outlined),
          ),
          validator: (v) =>
              PasswordResetRules.confirmError(_newPasswordController.text, v),
        ),
        const SizedBox(height: 24),
        _primaryButton(label: 'Нууц үг солих', onPressed: _verifyAndResetCode),
        const SizedBox(height: 12),
        // SMS ирээгүй үед гарах зам — өмнө нь дэлгэцээ хааж дахин нээхээс
        // өөр сонголтгүй байв.
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _backToPhoneStep,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Дугаар засах'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed:
                    (_isLoading || _resendIn > 0) ? null : _sendResetRequest,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_resendIn > 0
                    ? 'Дахин илгээх ($_resendIn)'
                    : 'Дахин илгээх'),
              ),
            ),
          ],
        ),
      ];

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    // Үндсэн үйлдлийг БАРУУН талд — уншиж дуусаад хүрэх төгсгөлийн цэг.
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: _isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

/// Хоёр алхамт явцын заагч.
///
/// Дугаар → шинэ нууц үг гэсэн ЖИНХЭНЭ дараалал тул дугаарлалт нь чимэглэл
/// биш, мэдээлэл: түгжигдсэн хэрэглэгчид хэдэн алхам үлдснийг шууд хэлнэ.
class _StepRail extends StatelessWidget {
  const _StepRail({required this.currentStep});

  final int currentStep;

  static const List<String> _labels = ['Дугаар', 'Шинэ нууц үг'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                // Дугуйнуудын ТӨВД тааруулна (дугуй 28px өндөр).
                margin: const EdgeInsets.only(top: 13, left: 10, right: 10),
                decoration: BoxDecoration(
                  color: i <= currentStep
                      ? cs.primary
                      : cs.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          _Step(
            index: i,
            label: _labels[i],
            state: i < currentStep
                ? _StepState.done
                : i == currentStep
                    ? _StepState.current
                    : _StepState.upcoming,
            cs: cs,
            tt: tt,
          ),
        ],
      ],
    );
  }
}

enum _StepState { done, current, upcoming }

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.label,
    required this.state,
    required this.cs,
    required this.tt,
  });

  final int index;
  final String label;
  final _StepState state;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    // Дууссан алхмыг ялгаатай өнгөөр (хоёрдогч) тэмдэглэнэ — "дууссан" ба
    // "одоо хийж буй" хоёр нэг өнгөтэй бол явц уншигдахгүй.
    final (Color bg, Color fg, Color border) = switch (state) {
      _StepState.done => (AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, AppColors.secondaryContainer),
      _StepState.current => (cs.primary, cs.onPrimary, cs.primary),
      _StepState.upcoming => (
          Colors.transparent,
          cs.onSurfaceVariant,
          cs.outlineVariant
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
          child: state == _StepState.done
              ? Icon(Icons.check_rounded, size: 16, color: fg)
              : Text(
                  '${index + 1}',
                  style: tt.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: state == _StepState.upcoming
                ? cs.onSurfaceVariant
                : cs.onSurface,
            fontWeight:
                state == _StepState.current ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
