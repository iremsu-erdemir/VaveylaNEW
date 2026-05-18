class CourierAccountModel {
  CourierAccountModel({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;

  factory CourierAccountModel.fromJson(Map<String, dynamic> json) {
    final name = json['fullName']?.toString().trim() ?? '';
    return CourierAccountModel(
      id: json['id']?.toString() ?? '',
      fullName: name.isEmpty ? 'Kurye' : name,
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}
