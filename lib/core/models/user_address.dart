final RegExp _userAddressUuid = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

String _normalizeAddressIdFromJson(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return raw;
  }
  final match = _userAddressUuid.firstMatch(raw);
  if (match != null) {
    return match.group(0)!.toLowerCase();
  }
  return raw;
}

class UserAddress {
  const UserAddress({
    required this.addressId,
    required this.label,
    required this.addressLine,
    required this.isSelected,
    required this.createdAtUtc,
    this.addressDetail,
  });

  final String addressId;
  final String label;
  final String addressLine;
  final String? addressDetail;
  final bool isSelected;
  final DateTime createdAtUtc;

  UserAddress copyWith({
    String? addressId,
    String? label,
    String? addressLine,
    String? addressDetail,
    bool? isSelected,
    DateTime? createdAtUtc,
  }) {
    return UserAddress(
      addressId: addressId ?? this.addressId,
      label: label ?? this.label,
      addressLine: addressLine ?? this.addressLine,
      addressDetail: addressDetail ?? this.addressDetail,
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

    return UserAddress(
      addressId: _normalizeAddressIdFromJson(
        json['addressId'] ?? json['AddressId'],
      ),
      label: str('label', 'Label'),
      addressLine: str('addressLine', 'AddressLine'),
      addressDetail: strNullable('addressDetail', 'AddressDetail'),
      isSelected: readBool(json['isSelected'] ?? json['IsSelected']),
      createdAtUtc:
          DateTime.tryParse(createdRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
