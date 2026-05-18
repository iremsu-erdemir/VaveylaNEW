class HomeMarketingBannerModel {
  HomeMarketingBannerModel({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.badgeText,
    this.bodyText,
    required this.sortOrder,
    required this.actionType,
    this.actionTarget,
    this.isActive,
    this.startsAtUtc,
    this.endsAtUtc,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? badgeText;
  final String? bodyText;
  final int sortOrder;
  final String actionType;
  final String? actionTarget;
  final bool? isActive;
  final DateTime? startsAtUtc;
  final DateTime? endsAtUtc;

  bool get hasTextOverlay =>
      (title != null && title!.trim().isNotEmpty) ||
      (subtitle != null && subtitle!.trim().isNotEmpty) ||
      (bodyText != null && bodyText!.trim().isNotEmpty) ||
      (badgeText != null && badgeText!.trim().isNotEmpty);

  factory HomeMarketingBannerModel.fromPublicJson(Map<String, dynamic> json) {
    return HomeMarketingBannerModel(
      id: json['id']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      badgeText: json['badgeText']?.toString(),
      bodyText: json['bodyText']?.toString(),
      sortOrder: _parseInt(json['sortOrder']) ?? 0,
      actionType: json['actionType']?.toString() ?? 'none',
      actionTarget: json['actionTarget']?.toString(),
    );
  }

  factory HomeMarketingBannerModel.fromAdminJson(Map<String, dynamic> json) {
    return HomeMarketingBannerModel(
      id: json['id']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      badgeText: json['badgeText']?.toString(),
      bodyText: json['bodyText']?.toString(),
      sortOrder: _parseInt(json['sortOrder']) ?? 0,
      actionType: json['actionType']?.toString() ?? 'none',
      actionTarget: json['actionTarget']?.toString(),
      isActive: json['isActive'] == true || json['isActive'] == 1,
      startsAtUtc: _parseDate(json['startsAtUtc']),
      endsAtUtc: _parseDate(json['endsAtUtc']),
    );
  }

  Map<String, dynamic> toUpsertBody() {
    return {
      'imageUrl': imageUrl.trim(),
      'title': _emptyToNull(title),
      'subtitle': _emptyToNull(subtitle),
      'badgeText': _emptyToNull(badgeText),
      'bodyText': _emptyToNull(bodyText),
      'sortOrder': sortOrder,
      'isActive': isActive ?? true,
      'actionType': actionType,
      'actionTarget': _emptyToNull(actionTarget),
      'startsAtUtc': startsAtUtc?.toUtc().toIso8601String(),
      'endsAtUtc': endsAtUtc?.toUtc().toIso8601String(),
    };
  }

  static String? _emptyToNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
