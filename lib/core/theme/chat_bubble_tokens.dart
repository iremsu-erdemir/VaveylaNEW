import 'package:flutter/material.dart';

/// Tüm müşteri / kurye / satıcı sohbet ekranlarında aynı baloncuk ölçüsü ve renkleri.
abstract final class ChatBubbleTokens {
  static const Color threadBackground = Color(0xFFFCE4E4);
  static const Color outgoingFill = Color(0xFFFDF2F2);
  static const Color incomingFill = Color(0xFFFFFFFF);

  static const double radius = 18;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );

  /// Uzun satırlar için üst sınır; [IntrinsicWidth] ile kısa mesaj dar kalır.
  static double maxWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 0.76;
}
