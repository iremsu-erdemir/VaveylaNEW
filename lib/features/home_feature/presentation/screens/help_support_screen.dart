import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : colors.white;
    final itemColor = isDark ? const Color(0xFF242424) : colors.white;
    final questionColor = isDark ? colors.primaryShade2 : colors.primaryTint2;
    final answerColor = isDark ? colors.gray2 : colors.gray4;

    final faqItems = [
      (
        question: context.tr('faq_what_is_vaveyla_question'),
        answer: context.tr('faq_what_is_vaveyla_answer'),
      ),
      (
        question: context.tr('faq_how_to_join_volunteer_question'),
        answer: context.tr('faq_how_to_join_volunteer_answer'),
      ),
      (
        question: context.tr('faq_volunteer_tasks_question'),
        answer: context.tr('faq_volunteer_tasks_answer'),
      ),
      (
        question: context.tr('faq_services_free_question'),
        answer: context.tr('faq_services_free_answer'),
      ),
      (
        question: context.tr('faq_contact_volunteer_question'),
        answer: context.tr('faq_contact_volunteer_answer'),
      ),
      (
        question: context.tr('faq_fee_question'),
        answer: context.tr('faq_fee_answer'),
      ),
      (
        question: context.tr('faq_more_volunteers_question'),
        answer: context.tr('faq_more_volunteers_answer'),
      ),
      (
        question: context.tr('faq_cities_question'),
        answer: context.tr('faq_cities_answer'),
      ),
    ];

    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaTop: false,
      backgroundColor: colors.secondaryShade1,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.45),
              colors.secondary.withValues(alpha: 0.30),
              colors.secondaryShade1,
            ],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top + 6),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.largePadding,
                vertical: Dimens.padding,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: colors.white),
                  ),
                  Expanded(
                    child: Text(
                      context.tr('help_support_faq_title'),
                      textAlign: TextAlign.center,
                      style: typography.titleLarge.copyWith(
                        color: colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                  Dimens.largePadding,
                  Dimens.largePadding,
                  Dimens.largePadding,
                  Dimens.extraLargePadding,
                ),
                padding: const EdgeInsets.all(Dimens.largePadding),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ListView.separated(
                  itemCount: faqItems.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: Dimens.mediumPadding),
                  itemBuilder: (context, index) {
                    final item = faqItems[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: Dimens.largePadding,
                            vertical: Dimens.smallPadding,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            Dimens.largePadding,
                            0,
                            Dimens.largePadding,
                            Dimens.largePadding,
                          ),
                          collapsedIconColor: questionColor,
                          iconColor: questionColor,
                          title: Text(
                            item.question,
                            style: typography.titleSmall.copyWith(
                              color: questionColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          children: [
                            Text(
                              item.answer,
                              style: typography.bodyMedium.copyWith(
                                color: answerColor,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
