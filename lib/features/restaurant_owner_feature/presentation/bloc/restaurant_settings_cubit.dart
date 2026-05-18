import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/google_geocoding_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';

class RestaurantReview {
  const RestaurantReview({
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.date,
    required this.reviewId,
    this.ownerReply,
  });

  final String customerName;
  final double rating;
  final String comment;
  final String date;
  final String reviewId;
  final String? ownerReply;

  RestaurantReview copyWith({String? ownerReply}) {
    return RestaurantReview(
      customerName: customerName,
      rating: rating,
      comment: comment,
      date: date,
      reviewId: reviewId,
      ownerReply: ownerReply ?? this.ownerReply,
    );
  }

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    return RestaurantReview(
      reviewId: json['id']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      rating: _parseDouble(json['rating']),
      comment: json['comment']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      ownerReply: json['ownerReply']?.toString(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class RestaurantSettingsCubit extends Cubit<RestaurantSettingsState> {
  RestaurantSettingsCubit(
    this._service,
    this._ownerUserId, {
    GoogleGeocodingService? geocodingService,
  })
      : _geocodingService =
            geocodingService ?? GoogleGeocodingService(),
        super(const RestaurantSettingsState());

  final RestaurantOwnerService _service;
  final String _ownerUserId;
  final GoogleGeocodingService _geocodingService;

  Future<void> loadSettings() async {
    final settings = await _service.getSettings(ownerUserId: _ownerUserId);
    emit(settings);
  }

  Future<void> setOrderNotifications(bool value) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      orderNotifications: value,
    );
    emit(updated);
  }

  Future<void> setRestaurantName(String value) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      restaurantName: value,
    );
    emit(updated);
  }

  Future<void> setAddress(
    String value, {
    double? latitude,
    double? longitude,
  }) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      address: value,
      latitude: latitude,
      longitude: longitude,
    );
    emit(updated);
  }

  Future<String?> autoFillAddressFromGoogle({bool overwrite = false}) async {
    final current = state.address.trim();
    if (!overwrite &&
        current.isNotEmpty &&
        current != RestaurantSettingsState.placeholderAddress) {
      return null;
    }

    final position = await _getCurrentPosition();
    final address = await _geocodingService.reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final normalized = address?.trim() ?? '';
    if (normalized.isEmpty) {
      throw AddressAutoFillException('Adres bulunamadı.');
    }

    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      address: normalized,
    );
    emit(updated);
    return normalized;
  }

  Future<void> setPhone(String value) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      phone: value,
    );
    emit(updated);
  }

  Future<void> setWorkingHours(String value) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      workingHours: value,
    );
    emit(updated);
  }

  Future<void> setRestaurantType(String value) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      restaurantType: value,
    );
    emit(updated);
  }

  Future<void> setIsOpen(bool value) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      isOpen: value,
    );
    emit(updated);
  }

  Future<void> setRestaurantPhoto(String? path) async {
    final updated = await _service.updateSettings(
      ownerUserId: _ownerUserId,
      restaurantPhotoPath: path,
    );
    emit(updated);
  }

  Future<void> setRestaurantDiscountPercent(double? percent) async {
    // Özel indirim endpoint'i kullan - doğrudan veritabanına kaydeder
    final updated = await _service.updateDiscountPercent(
      ownerUserId: _ownerUserId,
      restaurantDiscountPercent: percent,
    );
    emit(updated);
  }

  /// Onaylı indirimi pasifleştir veya tekrar aktifleştir.
  Future<void> toggleDiscountActive(bool isActive) async {
    final updated = await _service.toggleDiscountActive(
      ownerUserId: _ownerUserId,
      isActive: isActive,
    );
    emit(updated);
  }

  Future<void> setReplyToReview(int index, String reply) async {
    if (index < 0 || index >= state.reviews.length) return;
    final reviewId = state.reviews[index].reviewId;
    await _service.updateReviewReply(
      ownerUserId: _ownerUserId,
      reviewId: reviewId,
      ownerReply: reply,
    );
    final updated = List<RestaurantReview>.from(state.reviews);
    updated[index] = updated[index].copyWith(ownerReply: reply);
    emit(state.copyWith(reviews: updated));
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw AddressAutoFillException(
        'Konum servisleri kapalı. Lütfen açıp tekrar deneyin.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw AddressAutoFillException(
        'Adresin otomatik dolması için konum izni gerekli.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) {
        throw AddressAutoFillException('Konum alınamadı. Lütfen tekrar deneyin.');
      }
      return lastKnown;
    }
  }
}

class RestaurantSettingsState {
  static const String placeholderAddress = 'Örnek Mah. Pastane Sok. No:1';

  const RestaurantSettingsState({
    this.restaurantId = '',
    this.restaurantName = 'Tatlı Köşem',
    this.restaurantType = 'Pastane & Kafe',
    this.address = placeholderAddress,
    this.phone = '+90 555 123 4567',
    this.workingHours = '09:00 - 22:00',
    this.orderNotifications = true,
    this.isOpen = true,
    this.rating = 4.8,
    this.reviewCount = 124,
    this.restaurantPhotoPath,
    this.restaurantDiscountPercent,
    this.restaurantDiscountApproved = false,
    this.restaurantDiscountIsActive = true,
    this.activeCampaignDisplayText,
    this.ratingDistribution = const {5: 56, 4: 38, 3: 18, 2: 8, 1: 4},
    this.reviews = _kSampleReviews,
  });

  static const _kSampleReviews = [
    RestaurantReview(
      customerName: 'Ayşe K.',
      rating: 5,
      comment: 'Tatlılar harika, servis çok hızlıydı. Kesinlikle tekrar geleceğim!',
      date: '2 gün önce',
      reviewId: 'sample_1',
    ),
    RestaurantReview(
      customerName: 'Mehmet Y.',
      rating: 4,
      comment: 'Güzel bir pastane, sadece biraz bekledik. Tavsiye ederim.',
      date: '5 gün önce',
      reviewId: 'sample_2',
    ),
    RestaurantReview(
      customerName: 'Zeynep A.',
      rating: 5,
      comment: 'Baklava enfesti! Fiyatlar da makul.',
      date: '1 hafta önce',
      reviewId: 'sample_3',
    ),
    RestaurantReview(
      customerName: 'Can D.',
      rating: 3,
      comment: 'Orta halli, bazı tatlılar taze değildi gibi geldi.',
      date: '2 hafta önce',
      reviewId: 'sample_4',
    ),
    RestaurantReview(
      customerName: 'Elif S.',
      rating: 5,
      comment: 'Doğum günü pastamı buradan aldım, herkes çok beğendi.',
      date: '3 hafta önce',
      ownerReply: 'Teşekkür ederiz! Sizi tekrar ağırlamaktan mutluluk duyarız.',
      reviewId: 'sample_5',
    ),
  ];

  final String restaurantId;
  final String restaurantName;
  final String restaurantType;
  final String address;
  final String phone;
  final String workingHours;
  final bool orderNotifications;
  final bool isOpen;
  final double rating;
  final int reviewCount;
  final String? restaurantPhotoPath;
  final double? restaurantDiscountPercent;
  final bool restaurantDiscountApproved;
  final bool restaurantDiscountIsActive;
  final String? activeCampaignDisplayText;
  final Map<int, int> ratingDistribution;
  final List<RestaurantReview> reviews;

  RestaurantSettingsState copyWith({
    String? restaurantId,
    String? restaurantName,
    String? restaurantType,
    String? address,
    String? phone,
    String? workingHours,
    bool? orderNotifications,
    bool? isOpen,
    double? rating,
    int? reviewCount,
    String? restaurantPhotoPath,
    double? restaurantDiscountPercent,
    bool? restaurantDiscountApproved,
    bool? restaurantDiscountIsActive,
    String? activeCampaignDisplayText,
    Map<int, int>? ratingDistribution,
    List<RestaurantReview>? reviews,
  }) {
    return RestaurantSettingsState(
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantType: restaurantType ?? this.restaurantType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      workingHours: workingHours ?? this.workingHours,
      orderNotifications: orderNotifications ?? this.orderNotifications,
      isOpen: isOpen ?? this.isOpen,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      restaurantPhotoPath: restaurantPhotoPath ?? this.restaurantPhotoPath,
      restaurantDiscountPercent: restaurantDiscountPercent ?? this.restaurantDiscountPercent,
      restaurantDiscountApproved: restaurantDiscountApproved ?? this.restaurantDiscountApproved,
      restaurantDiscountIsActive: restaurantDiscountIsActive ?? this.restaurantDiscountIsActive,
      activeCampaignDisplayText: activeCampaignDisplayText ?? this.activeCampaignDisplayText,
      ratingDistribution: ratingDistribution ?? this.ratingDistribution,
      reviews: reviews ?? this.reviews,
    );
  }

  factory RestaurantSettingsState.fromJson(Map<String, dynamic> json) {
    final ratingDistribution = <int, int>{};
    final rawDist = json['ratingDistribution'];
    if (rawDist is Map) {
      for (final entry in rawDist.entries) {
        final key = int.tryParse(entry.key.toString()) ?? 0;
        final value = _parseInt(entry.value);
        if (key > 0) {
          ratingDistribution[key] = value;
        }
      }
    }
    final reviews = <RestaurantReview>[];
    final rawReviews = json['reviews'];
    if (rawReviews is List) {
      for (final item in rawReviews) {
        if (item is Map<String, dynamic>) {
          reviews.add(RestaurantReview.fromJson(item));
        } else if (item is Map) {
          reviews.add(RestaurantReview.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return RestaurantSettingsState(
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? '',
      restaurantType: json['restaurantType']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      workingHours: json['workingHours']?.toString() ?? '',
      orderNotifications: json['orderNotifications'] == true ||
          json['orderNotifications'] == 1,
      isOpen: json['isOpen'] == true || json['isOpen'] == 1,
      rating: _parseDouble(json['rating']),
      reviewCount: _parseInt(json['reviewCount']),
      restaurantPhotoPath: json['restaurantPhotoPath']?.toString(),
      restaurantDiscountPercent: _parseDouble(json['restaurantDiscountPercent']),
      restaurantDiscountApproved: json['restaurantDiscountApproved'] == true,
      restaurantDiscountIsActive: json['restaurantDiscountIsActive'] != false,
      activeCampaignDisplayText: json['activeCampaignDisplayText']?.toString(),
      ratingDistribution:
          ratingDistribution.isEmpty ? const {5: 0} : ratingDistribution,
      reviews: reviews,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AddressAutoFillException implements Exception {
  AddressAutoFillException(this.message);

  final String message;

  @override
  String toString() => message;
}
