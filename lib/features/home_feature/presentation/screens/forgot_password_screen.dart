import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';

enum _ForgotPasswordStep { email, code, newPassword, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Giriş ekranından gelirken önceden doldurulur (kayıtlı adresle aynı olması için).
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final RegExp _hasUpperCase = RegExp(r'[A-ZÇĞİÖŞÜ]');
  final RegExp _hasLowerCase = RegExp(r'[a-zçğıöşü]');
  final RegExp _hasDigit = RegExp(r'[0-9]');
  final RegExp _hasSpecial = RegExp(r"[!@#$%^&*(),.?{}|<>_\-+=;'\[\]\\\/`~]");
  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  bool _isSubmitting = false;
  _ForgotPasswordStep _step = _ForgotPasswordStep.email;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEmail?.trim();
    if (initial != null && initial.isNotEmpty) {
      _emailController.text = initial;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage({required String message, required Color backgroundColor}) {
    final colors = context.theme.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  String _mapRequestCodeError(Object error, String email) {
    if (error is AuthException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('404') || raw.contains('bulunamad')) {
      return 'Bu e-posta ile kayıtlı hesap bulunamadı. Kayıt olurken kullandığınız '
          'adresi girin: $email';
    }
    if (raw.contains('400') || raw.contains('geçerli')) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    if (raw.contains('503') ||
        raw.contains('500') ||
        raw.contains('smtp') ||
        raw.contains('gonderilemedi') ||
        raw.contains('gönderilemedi')) {
      return 'E-posta gönderilemedi. SMTP ayarlarını kontrol edin veya daha sonra tekrar deneyin.';
    }
    if (raw.contains('bağlan') || raw.contains('baglan') || raw.contains('sunucu')) {
      return 'Sunucuya bağlanılamadı. API\'nin çalıştığından emin olun.';
    }
    return 'Kod gönderimi başarısız oldu. Lütfen tekrar deneyin.';
  }

  String? _validatePassword(String password) {
    if (password.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    if (!_hasUpperCase.hasMatch(password)) {
      return 'Şifre en az bir büyük harf içermelidir.';
    }
    if (!_hasLowerCase.hasMatch(password)) {
      return 'Şifre en az bir küçük harf içermelidir.';
    }
    if (!_hasDigit.hasMatch(password)) {
      return 'Şifre en az bir rakam içermelidir.';
    }
    if (!_hasSpecial.hasMatch(password)) {
      return 'Şifre en az bir özel karakter içermelidir.';
    }
    return null;
  }

  Future<void> _requestCode() async {
    if (_isSubmitting) {
      return;
    }
    final colors = context.theme.appColors;
    final email = _emailController.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      _showMessage(
        message: 'Geçerli bir e-posta adresi girin.',
        backgroundColor: colors.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final message = await _authService.requestPasswordResetCode(email: email);
      if (!mounted) {
        return;
      }
      _showMessage(message: message, backgroundColor: colors.success);
      setState(() => _step = _ForgotPasswordStep.code);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _mapRequestCodeError(error, email);
      _showMessage(message: message, backgroundColor: colors.error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_isSubmitting) {
      return;
    }
    final colors = context.theme.appColors;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showMessage(
        message: 'Doğrulama kodu 6 haneli olmalıdır.',
        backgroundColor: colors.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final message = await _authService.verifyPasswordResetCode(
        email: email,
        code: code,
      );
      if (!mounted) {
        return;
      }
      _showMessage(message: message, backgroundColor: colors.success);
      setState(() => _step = _ForgotPasswordStep.newPassword);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error is AuthException
              ? error.message
              : 'Kod doğrulama başarısız oldu. Lütfen tekrar deneyin.';
      _showMessage(message: message, backgroundColor: colors.error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_isSubmitting) {
      return;
    }
    final colors = context.theme.appColors;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final passwordError = _validatePassword(newPassword);
    if (passwordError != null) {
      _showMessage(message: passwordError, backgroundColor: colors.error);
      return;
    }
    if (newPassword != confirmPassword) {
      _showMessage(
        message: 'Şifreler eşleşmiyor.',
        backgroundColor: colors.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final message = await _authService.resetPasswordWithCode(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      if (!mounted) {
        return;
      }
      _showMessage(message: message, backgroundColor: colors.success);
      setState(() => _step = _ForgotPasswordStep.done);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error is AuthException
              ? error.message
              : 'Şifre güncelleme başarısız oldu. Lütfen tekrar deneyin.';
      _showMessage(message: message, backgroundColor: colors.error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.secondaryShade2, colors.primaryShade2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.padding,
                  vertical: Dimens.smallPadding,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, color: colors.white),
                    ),
                    const SizedBox(width: Dimens.smallPadding),
                    Text(
                      'Şifreyi Sıfırla',
                      style: typography.titleLarge.copyWith(
                        color: colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Dimens.largePadding),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.all(Dimens.largePadding),
                        decoration: BoxDecoration(
                          color: colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primaryTint5.withValues(alpha: 0.16),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _buildStepContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    switch (_step) {
      case _ForgotPasswordStep.email:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_reset_rounded, size: 54, color: colors.primary),
            const SizedBox(height: Dimens.largePadding),
            Text(
              'E-posta adresini gir, şifre değiştirme bağlantısı/kodu gönderelim.',
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(color: colors.gray4),
            ),
            const SizedBox(height: Dimens.largePadding),
            _ForgotPasswordInputField(
              hintText: 'E-posta adresi',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
            ),
            const SizedBox(height: Dimens.largePadding),
            AppButton(
              title: _isSubmitting ? 'Gönderiliyor...' : 'Doğrulama Kodu Gönder',
              onPressed: _isSubmitting ? null : _requestCode,
              margin: EdgeInsets.zero,
              borderRadius: 14,
              textStyle: typography.titleMedium.copyWith(
                color: colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _ForgotPasswordStep.code:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 54, color: colors.primary),
            const SizedBox(height: Dimens.largePadding),
            Text(
              '${_emailController.text.trim()} adresine gelen doğrulama kodunu gir.',
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(color: colors.gray4),
            ),
            const SizedBox(height: Dimens.padding),
            Text(
              'Kod gelmiyorsa Spam ve Tanıtımlar klasörlerine bakın. '
              'Kod, hesabınızda kayıtlı e-posta adresinize gönderilir.',
              textAlign: TextAlign.center,
              style: typography.bodySmall.copyWith(
                color: colors.gray4.withValues(alpha: 0.92),
                height: 1.35,
              ),
            ),
            const SizedBox(height: Dimens.largePadding),
            _ForgotPasswordInputField(
              hintText: 'Doğrulama kodu',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              controller: _codeController,
            ),
            const SizedBox(height: Dimens.largePadding),
            AppButton(
              title: _isSubmitting ? 'Doğrulanıyor...' : 'Kodu Doğrula',
              onPressed: _isSubmitting ? null : _verifyCode,
              margin: EdgeInsets.zero,
              borderRadius: 14,
              textStyle: typography.titleMedium.copyWith(
                color: colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _isSubmitting ? null : _requestCode,
              child: const Text('Kodu tekrar gönder'),
            ),
          ],
        );
      case _ForgotPasswordStep.newPassword:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.password_rounded, size: 54, color: colors.primary),
            const SizedBox(height: Dimens.largePadding),
            Text(
              'Yeni şifreni belirle.',
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(color: colors.gray4),
            ),
            const SizedBox(height: Dimens.largePadding),
            _ForgotPasswordInputField(
              hintText: 'Yeni şifre',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              controller: _newPasswordController,
            ),
            const SizedBox(height: Dimens.padding),
            _ForgotPasswordInputField(
              hintText: 'Yeni şifre (tekrar)',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              controller: _confirmPasswordController,
            ),
            const SizedBox(height: Dimens.largePadding),
            AppButton(
              title: _isSubmitting ? 'Güncelleniyor...' : 'Şifreyi Güncelle',
              onPressed: _isSubmitting ? null : _resetPassword,
              margin: EdgeInsets.zero,
              borderRadius: 14,
              textStyle: typography.titleMedium.copyWith(
                color: colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _ForgotPasswordStep.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 60, color: colors.success),
            const SizedBox(height: Dimens.largePadding),
            Text(
              'Şifren başarıyla güncellendi.',
              textAlign: TextAlign.center,
              style: typography.titleMedium.copyWith(
                color: colors.primaryTint2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Dimens.padding),
            Text(
              'Giriş ekranına dönüp yeni şifrenle oturum açabilirsin.',
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(color: colors.gray4),
            ),
            const SizedBox(height: Dimens.extraLargePadding),
            AppButton(
              title: 'Girişe Dön',
              onPressed: () => Navigator.of(context).maybePop(),
              margin: EdgeInsets.zero,
              borderRadius: 14,
              textStyle: typography.titleMedium.copyWith(
                color: colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }
  }
}

class _ForgotPasswordInputField extends StatelessWidget {
  const _ForgotPasswordInputField({
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
  });

  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.gray2.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        obscureText: obscureText,
        keyboardType: keyboardType,
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: typography.bodySmall.copyWith(color: colors.gray4),
          prefixIcon: Icon(icon, color: colors.primary),
          contentPadding: const EdgeInsets.symmetric(
            vertical: Dimens.mediumPadding,
          ),
        ),
        style: typography.bodySmall.copyWith(
          color: colors.primaryTint2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
