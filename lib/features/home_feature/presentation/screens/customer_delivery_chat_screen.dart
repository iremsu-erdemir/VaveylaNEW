import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/delivery_chat_panel.dart';

/// Müşteri paneli — Sohbetler listesinden kurye teslimat sohbeti.
/// Üst çubuk ve renkler [RestaurantChatScreen] ile aynı çizgide.
class CustomerDeliveryChatScreen extends StatelessWidget {
  const CustomerDeliveryChatScreen({
    super.key,
    required this.orderId,
    required this.title,
  });

  final String orderId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      backgroundColor: colors.secondaryShade1,
      padding: EdgeInsets.zero,
      appBar: AppBar(
        backgroundColor: colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typography.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.primaryTint2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: DeliveryChatPanel(
          orderId: orderId,
          title: title,
          isEmbeddedPage: true,
        ),
      ),
    );
  }
}
