class AuthResponse {
  const AuthResponse({
    required this.userId,
    required this.roleId,
    required this.fullName,
    this.token,
    this.isSuspended = false,
    this.suspendedUntilUtc,
    this.notificationEnabled = true,
  });

  final String userId;
  final int roleId;
  final String fullName;
  final String? token;

  /// Backend: hesap askıda (JWT yine döner; sipariş uçları 403 verir).
  final bool isSuspended;
  final DateTime? suspendedUntilUtc;

  /// Sunucudaki bildirim tercihi (push / uygulama içi / SignalR).
  final bool notificationEnabled;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    DateTime? until;
    final rawUntil = json['suspendedUntilUtc'];
    if (rawUntil is String && rawUntil.isNotEmpty) {
      until = DateTime.tryParse(rawUntil);
    }
    return AuthResponse(
      userId: json['userId']?.toString() ?? '',
      roleId: _parseRoleId(json['role'] ?? json['roleId']),
      fullName: json['fullName']?.toString() ?? '',
      token: json['token']?.toString(),
      isSuspended: json['isSuspended'] == true,
      suspendedUntilUtc: until,
      notificationEnabled: _parseNotificationEnabled(json['notificationEnabled']),
    );
  }

  static bool _parseNotificationEnabled(dynamic value) {
    if (value == null) {
      return true;
    }
    if (value is bool) {
      return value;
    }
    final s = value.toString().trim().toLowerCase();
    if (s == 'false' || s == '0') {
      return false;
    }
    if (s == 'true' || s == '1') {
      return true;
    }
    return true;
  }

  static int _parseRoleId(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return 0;
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    switch (s.toLowerCase()) {
      case 'restaurantowner':
      case 'restaurant_owner':
        return 1;
      case 'customer':
        return 2;
      case 'courier':
        return 3;
      case 'admin':
        return 4;
      default:
        return 0;
    }
  }
}
