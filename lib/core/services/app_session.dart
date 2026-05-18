import '../models/auth_response.dart';

class AppSession {
  static AuthResponse? _auth;

  static void setAuth(AuthResponse auth) {
    _auth = auth;
  }

  static String get userId => _auth?.userId ?? '';
  static int get roleId => _auth?.roleId ?? 0;
  static String get fullName => _auth?.fullName ?? '';
  static String get token => _auth?.token ?? '';

  /// Bildirimler kapalıysa yerel önizleme / anlık bildirim gösterilmez.
  static bool get notificationEnabled => _auth?.notificationEnabled ?? true;

  static void updateFullName(String fullName) {
    final auth = _auth;
    if (auth == null) return;
    _auth = AuthResponse(
      userId: auth.userId,
      roleId: auth.roleId,
      fullName: fullName,
      token: auth.token,
      isSuspended: auth.isSuspended,
      suspendedUntilUtc: auth.suspendedUntilUtc,
      notificationEnabled: auth.notificationEnabled,
    );
  }

  static void updateNotificationEnabled(bool notificationEnabled) {
    final auth = _auth;
    if (auth == null) return;
    _auth = AuthResponse(
      userId: auth.userId,
      roleId: auth.roleId,
      fullName: auth.fullName,
      token: auth.token,
      isSuspended: auth.isSuspended,
      suspendedUntilUtc: auth.suspendedUntilUtc,
      notificationEnabled: notificationEnabled,
    );
  }

  static void clear() {
    _auth = null;
  }
}
