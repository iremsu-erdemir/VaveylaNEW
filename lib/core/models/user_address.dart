import '../utils/guid_utils.dart';

enum AddressLabelType { home, work, other }

AddressLabelType addressLabelTypeFromApi(dynamic value) {
  if (value == null) return AddressLabelType.other;
  if (value is int) {
    switch (value) {
      case 1:
        return AddressLabelType.home;
      case 2:
        return AddressLabelType.work;
      default:
        return AddressLabelType.other;
    }
  }
  final s = value.toString().toLowerCase();
  if (s == 'home') return AddressLabelType.home;
  if (s == 'work') return AddressLabelType.work;
  return AddressLabelType.other;
}

int addressLabelTypeToApi(AddressLabelType type) {
  switch (type) {
    case AddressLabelType.home:
      return 1;
    case AddressLabelType.work:
      return 2;
    case AddressLabelType.other:
      return 3;
  }
}

String addressLabelTypeDisplay(AddressLabelType type) {
  switch (type) {
    case AddressLabelType.home:
      return 'Ev';
    case AddressLabelType.work:
      return 'İş';
    case AddressLabelType.other:
      return 'Diğer';
  }
}

class UserAddress {
  const UserAddress({
    required this.addressId,
    required this.label,
    required this.addressLine,
    required this.isSelected,
    required this.createdAtUtc,
    this.labelType = AddressLabelType.other,
    this.addressDetail,
    this.floor,
    this.apartment,
    this.directionsNote,
    this.latitude,
    this.longitude,
  });

  final String addressId;
  final String label;
  final AddressLabelType labelType;
  final String addressLine;
  final String? addressDetail;
  final String? floor;
  final String? apartment;
  final String? directionsNote;
  final double? latitude;
  final double? longitude;
  final bool isSelected;
  final DateTime createdAtUtc;

  String get fullDetailLine {
    final parts = <String>[
      if (floor != null && floor!.isNotEmpty) 'Kat: $floor',
      if (apartment != null && apartment!.isNotEmpty) 'Daire: $apartment',
      if (directionsNote != null && directionsNote!.isNotEmpty) directionsNote!,
      if (addressDetail != null && addressDetail!.isNotEmpty) addressDetail!,
    ];
    return parts.join(' · ');
  }

  UserAddress copyWith({
    String? addressId,
    String? label,
    AddressLabelType? labelType,
    String? addressLine,
    String? addressDetail,
    String? floor,
    String? apartment,
    String? directionsNote,
    double? latitude,
    double? longitude,
    bool? isSelected,
    DateTime? createdAtUtc,
  }) {
    return UserAddress(
      addressId: addressId ?? this.addressId,
      label: label ?? this.label,
      labelType: labelType ?? this.labelType,
      addressLine: addressLine ?? this.addressLine,
      addressDetail: addressDetail ?? this.addressDetail,
      floor: floor ?? this.floor,
      apartment: apartment ?? this.apartment,
      directionsNote: directionsNote ?? this.directionsNote,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isSelected: isSelected ?? this.isSelected,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    String str(String camel, String pascal) {
      final v = json[camel] ?? json[pascal];
      return v?.toString() ?? '';
    }

    String? strNullable(String camel, String pascal) {
      final v = json[camel] ?? json[pascal];
      if (v == null) {
        return null;
      }
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    bool readBool(Object? v) {
      if (v is bool) {
        return v;
      }
      if (v is String) {
        return v.toLowerCase() == 'true';
      }
      return false;
    }

    final createdRaw =
        (json['createdAtUtc'] ?? json['CreatedAtUtc'])?.toString() ?? '';

    final rawId = json['addressId'] ?? json['AddressId'];
    final addressId = tryExtractUuid(rawId) ?? '';

    return UserAddress(
      addressId: addressId,
      label: str('label', 'Label'),
      labelType: addressLabelTypeFromApi(json['labelType'] ?? json['LabelType']),
      addressLine: str('addressLine', 'AddressLine'),
      addressDetail: strNullable('addressDetail', 'AddressDetail'),
      floor: strNullable('floor', 'Floor'),
      apartment: strNullable('apartment', 'Apartment'),
      directionsNote: strNullable('directionsNote', 'DirectionsNote'),
      latitude: parseDouble(json['latitude'] ?? json['Latitude']),
      longitude: parseDouble(json['longitude'] ?? json['Longitude']),
      isSelected: readBool(json['isSelected'] ?? json['IsSelected']),
      createdAtUtc:
          DateTime.tryParse(createdRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
