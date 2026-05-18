import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/models/payment_saved_card.dart';

class PaymentSavedCardStore {
  static final List<PaymentSavedCard> _cards = <PaymentSavedCard>[
    const PaymentSavedCard(
      cardholderName: 'Cengiz Demir',
      cardNumber: '5400310012344244',
      expiration: '02/2028',
      cvc: '123',
      bankName: 'BANK NAME',
      cardAlias: 'Nakit Kartim',
    ),
    const PaymentSavedCard(
      cardholderName: 'Irem Su Erdemir',
      cardNumber: '4532310099991048',
      expiration: '11/2029',
      cvc: '456',
      bankName: 'BANK NAME',
      cardAlias: 'Yedek Kartim',
    ),
  ];

  static List<PaymentSavedCard> getCards() =>
      List<PaymentSavedCard>.from(_cards);

  static void addCard(PaymentSavedCard card) {
    _cards.add(card);
  }

  static bool updateCardAt(int index, PaymentSavedCard card) {
    if (index < 0 || index >= _cards.length) {
      return false;
    }
    _cards[index] = card;
    return true;
  }

  static bool removeCardAt(int index) {
    if (index < 0 || index >= _cards.length) {
      return false;
    }
    _cards.removeAt(index);
    return true;
  }
}
