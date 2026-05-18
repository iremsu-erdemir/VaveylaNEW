import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/widgets/sweet_recommendation_chat_sheet.dart';

/// Müşteri ana sayfası için sağ altta “Tatlı asistanı” sohbet girişi.
class SweetRecommendationFab extends StatelessWidget {
  const SweetRecommendationFab({super.key, required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(final BuildContext context) {
    final colors = context.theme.appColors;
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      color: colors.primary,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showSweetRecommendationChatSheet(parentContext: parentContext),
        child: const SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
