import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Onayla',
    this.cancelText = 'Vazgeç',
    this.isDestructive = false,
    this.showCancel = true,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final bool showCancel;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Onayla',
    String cancelText = 'Vazgeç',
    bool isDestructive = false,
    bool showCancel = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmDialog(
            title: title,
            message: message,
            confirmText: confirmText,
            cancelText: cancelText,
            isDestructive: isDestructive,
            showCancel: showCancel,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final accent = isDestructive ? colors.error : colors.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(Dimens.extraLargePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDestructive ? Icons.delete_outline : Icons.info_outline,
                    size: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(width: Dimens.padding),
                Expanded(
                  child: Text(
                    title,
                    style: typography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.largePadding),
            Text(
              message,
              style: typography.bodyMedium.copyWith(color: colors.gray4),
            ),
            const SizedBox(height: Dimens.extraLargePadding),
            if (showCancel)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colors.gray.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Dimens.corners),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimens.padding,
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: typography.labelMedium.copyWith(
                          color: colors.gray4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.padding),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Dimens.corners),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimens.padding,
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: typography.labelMedium.copyWith(
                          color: colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Dimens.corners),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimens.padding,
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: typography.labelMedium.copyWith(color: colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
