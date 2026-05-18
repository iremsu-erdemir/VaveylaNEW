class DeliveryChatMessageModel {
  const DeliveryChatMessageModel({
    required this.id,
    required this.orderId,
    required this.senderUserId,
    required this.message,
    required this.createdAtUtc,
    this.editedAtUtc,
  });

  final String id;
  final String orderId;
  final String senderUserId;
  final String message;
  final DateTime createdAtUtc;
  final DateTime? editedAtUtc;

  factory DeliveryChatMessageModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAtUtc']?.toString();
    final editedRaw = json['editedAtUtc']?.toString();
    return DeliveryChatMessageModel(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      senderUserId: json['senderUserId']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(createdRaw ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      editedAtUtc: editedRaw != null && editedRaw.isNotEmpty
          ? DateTime.tryParse(editedRaw)?.toUtc()
          : null,
    );
  }
}
