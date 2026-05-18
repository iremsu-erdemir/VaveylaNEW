class UserProfile {
  const UserProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.address,
    this.photoUrl,
    this.totalPenaltyPoints,
    this.notificationEnabled = true,
  });

  final String userId;
  final String fullName;
  final String email;
  final String? phone;
  final String? address;
  final String? photoUrl;

  /// Sunucu yalnızca kurye / işletme sahibi kendi profilinde (JWT ile) döner.
  final int? totalPenaltyPoints;

  /// Sunucu kaynaklı bildirim tercihi.
  final bool notificationEnabled;

  UserProfile copyWith({
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? photoUrl,
    int? totalPenaltyPoints,
    bool? notificationEnabled,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      totalPenaltyPoints: totalPenaltyPoints ?? this.totalPenaltyPoints,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawPts = json['totalPenaltyPoints'];
    int? pts;
    if (rawPts is int) {
      pts = rawPts;
    } else if (rawPts is num) {
      pts = rawPts.toInt();
    }

    final rawNe = json['notificationEnabled'];
    var notificationEnabled = true;
    if (rawNe == false || rawNe == 0) {
      notificationEnabled = false;
    } else if (rawNe is String &&
        (rawNe == 'false' || rawNe == '0' || rawNe.toLowerCase() == 'false')) {
      notificationEnabled = false;
    }

    return UserProfile(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      totalPenaltyPoints: pts,
      notificationEnabled: notificationEnabled,
    );
  }
}
