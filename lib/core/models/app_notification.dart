class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.userId,
    required this.userRole,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAtUtc,
    this.readAtUtc,
    this.relatedOrderId,
  });

  final String notificationId;
  final String userId;
  final String userRole;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;
  final String? relatedOrderId;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: (json['notificationId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userRole: (json['userRole'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      isRead: json['isRead'] as bool? ?? false,
      createdAtUtc: _parseBackendUtc((json['createdAtUtc'] ?? '').toString()),
      readAtUtc: _parseBackendUtcNullable(json['readAtUtc']?.toString()),
      relatedOrderId: json['relatedOrderId']?.toString(),
    );
  }

  static DateTime _parseBackendUtc(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return DateTime.now().toUtc();
    }

    final normalized = _normalizeIsoAsUtc(value);
    return DateTime.tryParse(normalized)?.toUtc() ?? DateTime.now().toUtc();
  }

  static DateTime? _parseBackendUtcNullable(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final normalized = _normalizeIsoAsUtc(raw.trim());
    return DateTime.tryParse(normalized)?.toUtc();
  }

  static String _normalizeIsoAsUtc(String value) {
    final hasTimezone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value);
    if (hasTimezone) {
      return value;
    }
    return '${value}Z';
  }
}
