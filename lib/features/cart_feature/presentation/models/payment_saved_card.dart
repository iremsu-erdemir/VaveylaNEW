class PaymentSavedCard {
  const PaymentSavedCard({
    this.paymentCardId,
    required this.cardholderName,
    required this.cardNumber,
    required this.expiration,
    required this.cvc,
    required this.bankName,
    required this.cardAlias,
  });

  final String? paymentCardId;
  final String cardholderName;
  final String cardNumber;
  final String expiration;
  final String cvc;
  final String bankName;
  final String cardAlias;

  factory PaymentSavedCard.fromJson(Map<String, dynamic> json) {
    return PaymentSavedCard(
      paymentCardId: _normalizeField(json['paymentCardId']),
      cardholderName: _normalizeField(json['cardholderName']) ?? '',
      cardNumber: _normalizeField(json['cardNumber']) ?? '',
      expiration: _normalizeField(json['expiration']) ?? '',
      cvc: _normalizeField(json['cvc'] ?? json['CVC'] ?? json['cvv']) ?? '',
      bankName: _normalizeField(json['bankName']) ?? 'BANK NAME',
      cardAlias: _normalizeField(json['cardAlias']) ?? '',
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'cardholderName': _normalizeField(cardholderName) ?? '',
      'cardNumber': _normalizeField(cardNumber) ?? '',
      'expiration': _normalizeField(expiration) ?? '',
      'cvc': _normalizeField(cvc) ?? '',
      'bankName': _normalizeField(bankName) ?? 'BANK NAME',
      'cardAlias': _normalizeField(cardAlias) ?? '',
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
  }

  PaymentSavedCard copyWith({
    String? paymentCardId,
    String? cardholderName,
    String? cardNumber,
    String? expiration,
    String? cvc,
    String? bankName,
    String? cardAlias,
  }) {
    return PaymentSavedCard(
      paymentCardId: paymentCardId ?? this.paymentCardId,
      cardholderName: cardholderName ?? this.cardholderName,
      cardNumber: cardNumber ?? this.cardNumber,
      expiration: expiration ?? this.expiration,
      cvc: cvc ?? this.cvc,
      bankName: bankName ?? this.bankName,
      cardAlias: cardAlias ?? this.cardAlias,
    );
  }

  static String? _normalizeField(dynamic value) {
    if (value == null) {
      return null;
    }

    var text = value.toString().trim();
    if (text.isEmpty) {
      return text;
    }

    // Unwrap values accidentally persisted as quoted JSON strings.
    for (var i = 0; i < 2; i++) {
      final wrappedInQuotes = text.startsWith('"') && text.endsWith('"');
      if (!wrappedInQuotes) {
        break;
      }
      text = text.substring(1, text.length - 1).trim();
    }

    return text.replaceAll(r'\"', '"').trim();
  }
}
