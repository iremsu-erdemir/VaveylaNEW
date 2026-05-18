import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/validation/login_validation.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/shaded_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_realtime_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/home_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/forgot_password_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/screens/restaurant_owner_dashboard_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_dashboard_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/screens/courier_dashboard_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/register_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onEmailChanged() {
    if (_emailError != null) {
      setState(() {
        _emailError = null;
        _generalError = _passwordError;
      });
    }
  }

  void _onPasswordChanged() {
    if (_passwordError != null) {
      setState(() {
        _passwordError = null;
        _generalError = _emailError;
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleLogin() async {
    if (_isSubmitting) {
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final colors = context.theme.appColors;
    final result = LoginValidation.validate(email, password);
    if (!result.isValid) {
      setState(() {
        _emailError = result.emailError;
        _passwordError = result.passwordError;
        _generalError = result.generalError;
      });
      _showMessage(
        message: result.generalError ?? 'Lütfen bilgilerinizi kontrol edin.',
        backgroundColor: colors.error,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _authService.login(email: email, password: password);
      AppSession.setAuth(result);
      await NotificationService.instance.initialize();
      await NotificationService.instance.syncLocalCacheFromServer(
        result.notificationEnabled,
      );
      await NotificationRealtimeService.instance.connectForUser(result.userId);
      if (!mounted) {
        return;
      }
      _showMessage(
        message: 'Giriş başarılı, yönlendiriliyorsunuz ${result.fullName}.',
        backgroundColor: colors.success,
      );
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) {
        return;
      }
      await appPushReplacement(
        context,
        result.roleId == 1
            ? const RestaurantOwnerDashboardScreen()
            : result.roleId == 3
            ? const CourierDashboardScreen()
            : result.roleId == 4
            ? const AdminDashboardScreen()
            : const HomeScreen(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error is AuthException
              ? error.message
              : 'Giriş başarısız. Lütfen tekrar deneyin.';
      _showMessage(message: message, backgroundColor: colors.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _openForgotPasswordScreen() {
    final email = _emailController.text.trim();
    final colors = context.theme.appColors;
    if (email.isEmpty) {
      setState(() {
        _emailError = 'Önce e-posta adresinizi giriniz.';
        _passwordError = null;
        _generalError = _emailError;
      });
      _showMessage(
        message: 'Önce e-posta adresinizi giriniz.',
        backgroundColor: colors.error,
      );
      return;
    }
    appPush(context, ForgotPasswordScreen(initialEmail: email));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return AppScaffold(
      backgroundColor: colors.secondaryShade1,
      padding: EdgeInsets.zero,
      safeAreaTop: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final isCompact = width < 360;
          // Width-based header height keeps the composition stable
          // across web and physical devices with different aspect ratios.
          final headerVisibleHeight = (width * 0.80).clamp(100.0, 800.0);
          final titleFontSize = (width * 0.085).clamp(26.0, 34.0);
          final inputHeight = isCompact ? 46.0 : 52.0;
          final horizontalPadding =
              width < Dimens.smallDeviceBreakPoint
                  ? Dimens.largePadding
                  : Dimens.extraLargePadding;
          final maxTopPadding = headerVisibleHeight * 0.82;
          // Keep form visible on short screens by capping top spacing with height.
          final contentTopPadding = (height * 0.42).clamp(160.0, maxTopPadding);
          final contentBottomPadding = Dimens.extraLargePadding;
          final contentMaxWidth = width > 520 ? 420.0 : width;
          final fieldSpacing = isCompact ? Dimens.padding : Dimens.largePadding;
          final sectionSpacing =
              isCompact ? Dimens.largePadding : Dimens.extraLargePadding;
          final logoTopOnHeader = headerVisibleHeight * 0.45;

          return Stack(
            children: [
              /// Arka Plan
              Positioned.fill(child: Container(color: colors.secondaryShade1)),

              /// ÜST HEADER
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: headerVisibleHeight,
                  width: width,
                  child: Image.asset(
                    'assets/images/splash header.png',
                    fit: BoxFit.fitWidth,
                    alignment: const Alignment(0, -1),
                  ),
                ),
              ),

              /// LOGO YAZISI
              Positioned(
                top: logoTopOnHeader,
                left: horizontalPadding,
                right: horizontalPadding,
                child: Text(
                  'VAVEYLA',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lobsterTwo(
                    color: colors.secondaryShade1,
                    fontWeight: FontWeight.w700,
                    fontSize: titleFontSize + 4,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              /// FORM ALANI
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    contentTopPadding,
                    horizontalPadding,
                    contentBottomPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: sectionSpacing),
                          if (_generalError != null) ...[
                            _ValidationBanner(message: _generalError!),
                            SizedBox(height: fieldSpacing),
                          ],
                          _LoginInputField(
                            hintText: 'E-posta',
                            icon: Icons.person,
                            keyboardType: TextInputType.emailAddress,
                            height: inputHeight,
                            controller: _emailController,
                            errorText: _emailError,
                          ),
                          SizedBox(height: fieldSpacing),
                          _LoginInputField(
                            hintText: '',
                            icon: Icons.lock,
                            obscureText: _obscurePassword,
                            height: inputHeight,
                            controller: _passwordController,
                            errorText: _passwordError,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              color: colors.gray4,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: fieldSpacing + Dimens.extraLargePadding,
                          ),
                          AppButton(
                            title: 'Giriş Yap',
                            onPressed: _handleLogin,
                            margin: EdgeInsets.zero,
                            borderRadius: 28,
                            textStyle: typography.titleMedium.copyWith(
                              color: colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: Dimens.padding),
                          TextButton(
                            onPressed: _openForgotPasswordScreen,
                            child: Text(
                              'Şifrenizi mi unuttunuz?',
                              style: typography.bodySmall.copyWith(
                                color: colors.gray4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: Dimens.smallPadding),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Hesabınız yok mu? ',
                                style: typography.bodySmall.copyWith(
                                  color: colors.gray4,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Kayıt ol',
                                  style: typography.bodySmall.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.padding,
        vertical: Dimens.mediumPadding,
      ),
      decoration: BoxDecoration(
        color: colors.errorExtraLight,
        borderRadius: BorderRadius.circular(Dimens.corners),
        border: Border.all(color: colors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error, size: 20),
          const SizedBox(width: Dimens.padding),
          Expanded(
            child: Text(
              message,
              style: typography.bodySmall.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginInputField extends StatelessWidget {
  const _LoginInputField({
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.height = 50,
    this.controller,
    this.errorText,
  });

  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final double height;
  final TextEditingController? controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadedContainer(
          height: height,
          borderRadius: 26,
          child: TextField(
            obscureText: obscureText,
            keyboardType: keyboardType,
            controller: controller,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: typography.bodySmall.copyWith(color: colors.gray4),
              prefixIcon: Icon(
                icon,
                color: hasError ? colors.error : colors.primary,
              ),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                vertical: Dimens.mediumPadding,
              ),
              enabledBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: colors.error, width: 1.5),
                    )
                  : InputBorder.none,
              focusedBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: colors.error, width: 1.5),
                    )
                  : InputBorder.none,
            ),
            style: typography.bodySmall.copyWith(
              color: colors.primaryTint2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(
              top: Dimens.smallPadding,
              left: Dimens.padding,
            ),
            child: Text(
              errorText!,
              style: typography.bodySmall.copyWith(
                color: colors.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
