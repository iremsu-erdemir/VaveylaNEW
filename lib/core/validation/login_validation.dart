/// Giriş formu doğrulama mantığı.
///
/// Modüler yapı sayesinde validation kuralları tek yerde toplanır ve
/// yeniden kullanılabilir.
class LoginValidation {
  LoginValidation._();

  static const String _emailEmpty = 'Lütfen e-posta adresinizi giriniz.';
  static const String _passwordEmpty = 'Lütfen şifrenizi giriniz.';
  static const String _emailInvalid = 'Geçerli bir e-posta adresi giriniz.';
  static const String _bothEmpty = 'E-posta ve şifre alanları zorunludur.';

  /// Basit e-posta format kontrolü (@ içermeli, geçerli yapıda olmalı).
  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.contains('@')) return false;
    final parts = trimmed.split('@');
    if (parts.length != 2) return false;
    if (parts[0].isEmpty || parts[1].isEmpty) return false;
    if (!parts[1].contains('.')) return false;
    return true;
  }

  /// E-posta ve şifre ile giriş doğrulaması yapar.
  ///
  /// Kurallar:
  /// - Her iki alan boşsa: genel mesaj
  /// - Sadece e-posta boşsa: e-posta mesajı
  /// - Sadece şifre boşsa: şifre mesajı
  /// - E-posta formatı geçersizse: format mesajı
  static LoginValidationResult validate(String email, String password) {
    final emailTrimmed = email.trim();
    final passwordTrimmed = password.trim();
    final emailEmpty = emailTrimmed.isEmpty;
    final passwordEmpty = passwordTrimmed.isEmpty;

    if (emailEmpty && passwordEmpty) {
      return LoginValidationResult(
        emailError: null,
        passwordError: null,
        generalError: _bothEmpty,
        isValid: false,
      );
    }

    String? emailError;
    if (emailEmpty) {
      emailError = _emailEmpty;
    } else if (!isValidEmail(emailTrimmed)) {
      emailError = _emailInvalid;
    }

    String? passwordError;
    if (passwordEmpty) {
      passwordError = _passwordEmpty;
    }

    return LoginValidationResult(
      emailError: emailError,
      passwordError: passwordError,
      generalError: (emailError != null || passwordError != null)
          ? _buildGeneralMessage(emailError, passwordError)
          : null,
      isValid: emailError == null && passwordError == null,
    );
  }

  static String _buildGeneralMessage(String? emailError, String? passwordError) {
    if (emailError != null && passwordError != null) {
      return _bothEmpty;
    }
    return emailError ?? passwordError ?? '';
  }
}

/// Giriş doğrulama sonucu.
class LoginValidationResult {
  const LoginValidationResult({
    this.emailError,
    this.passwordError,
    this.generalError,
    required this.isValid,
  });

  final String? emailError;
  final String? passwordError;
  final String? generalError;
  final bool isValid;
}
