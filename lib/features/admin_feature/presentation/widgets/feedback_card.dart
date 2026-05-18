import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/colors.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/typography.dart';

/// Admin panel: tek geri bildirim kartı + ceza aksiyonları.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.feedbackId,
    required this.complainant,
    required this.targetDisplay,
    required this.orderNumberLabel,
    required this.orderTitle,
    required this.createdAtText,
    required this.message,
    required this.statusLabel,
    required this.onAction,
    this.busy = false,
  });

  final String feedbackId;
  final String complainant;
  final String targetDisplay;
  final String? orderNumberLabel;
  final String? orderTitle;
  final String createdAtText;
  final String message;
  final String statusLabel;
  final bool busy;

  /// [action] sunucu enum camelCase; askı için [suspendDays] 3 veya 7.
  final void Function(String action, {int? points, int? suspendDays}) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    final orderLine = _orderLine();

    return Card(
      margin: const EdgeInsets.only(bottom: Dimens.largePadding),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.corners),
        side: BorderSide(color: colors.gray.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Dimens.largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Şikayet Eden', complainant, typography, colors),
            const SizedBox(height: 8),
            _row('Şikayet Edilen', targetDisplay, typography, colors),
            if (orderLine != null) ...[
              const SizedBox(height: 8),
              _row('Sipariş', orderLine, typography, colors),
            ],
            const SizedBox(height: 8),
            _row('Tarih', createdAtText, typography, colors),
            const SizedBox(height: 8),
            _row('Mesaj', message, typography, colors),
            const SizedBox(height: 8),
            _row('Durum', statusLabel, typography, colors),
            const SizedBox(height: Dimens.largePadding),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PenaltyButton(
                  label: 'Uyarı ver',
                  busy: busy,
                  onPressed: () => onAction('warning'),
                ),
                _PenaltyButton(
                  label: 'Ceza puanı ekle',
                  busy: busy,
                  onPressed: () => _pickPoints(context),
                ),
                _PenaltyButton(
                  label: '3 gün askıya al',
                  busy: busy,
                  onPressed: () => onAction('suspendUser', suspendDays: 3),
                ),
                _PenaltyButton(
                  label: '7 gün askıya al',
                  busy: busy,
                  onPressed: () => onAction('suspendUser', suspendDays: 7),
                ),
                _PenaltyButton(
                  label: 'Kalıcı ban',
                  busy: busy,
                  onPressed: () => onAction('permanentBan'),
                ),
                _PenaltyButton(
                  label: 'Reddet',
                  busy: busy,
                  onPressed: () => onAction('rejectFeedback'),
                  tone: _PenaltyTone.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _orderLine() {
    final no = orderNumberLabel?.trim();
    final title = orderTitle?.trim();
    if ((no == null || no.isEmpty) && (title == null || title.isEmpty)) {
      return null;
    }
    if (no != null && no.isNotEmpty && title != null && title.isNotEmpty) {
      return '$no · $title';
    }
    return no ?? title;
  }

  Future<void> _pickPoints(BuildContext context) async {
    final pts = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('+10 puan'),
              onTap: () => Navigator.pop(ctx, 10),
            ),
            ListTile(
              title: const Text('+20 puan (varsayılan)'),
              onTap: () => Navigator.pop(ctx, 20),
            ),
            ListTile(
              title: const Text('+30 puan'),
              onTap: () => Navigator.pop(ctx, 30),
            ),
            ListTile(
              title: const Text('+50 puan'),
              onTap: () => Navigator.pop(ctx, 50),
            ),
          ],
        ),
      ),
    );
    if (pts != null) {
      onAction('addPenaltyPoints', points: pts);
    }
  }

  static Widget _row(
    String label,
    String value,
    AppTypography typography,
    AppColors colors,
  ) {
    return RichText(
      text: TextSpan(
        style: typography.bodyMedium.copyWith(color: colors.primaryTint2),
        children: [
          TextSpan(
            text: '$label: ',
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.gray4,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

enum _PenaltyTone { filled, outline }

class _PenaltyButton extends StatelessWidget {
  const _PenaltyButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.tone = _PenaltyTone.filled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;
  final _PenaltyTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    if (tone == _PenaltyTone.outline) {
      return OutlinedButton(
        onPressed: busy ? null : onPressed,
        child: Text(label),
      );
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: busy ? null : onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
