import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/colors.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/typography.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_coupon_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/widgets/admin_list_card.dart';

/// Admin panelinde atanmış kuponları listeler. "Kullanıldı" etiketi ile gösterir.
class AdminCouponsListScreen extends StatefulWidget {
  const AdminCouponsListScreen({super.key});

  @override
  State<AdminCouponsListScreen> createState() => _AdminCouponsListScreenState();
}

class _AdminCouponsListScreenState extends State<AdminCouponsListScreen> {
  final AdminCouponService _service = AdminCouponService();
  List<CouponAssignmentDto> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getCouponAssignments();
      if (mounted) setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Kupon Listesi',
        showBackIcon: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'Henüz atanmış kupon yok.',
                    style: appTypography.bodyLarge.copyWith(color: appColors.gray4),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.all(Dimens.largePadding),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return _CouponAssignmentCard(
                        assignment: item,
                        appColors: appColors,
                        appTypography: appTypography,
                      );
                    },
                  ),
                ),
    );
  }
}

class _CouponAssignmentCard extends StatelessWidget {
  const _CouponAssignmentCard({
    required this.assignment,
    required this.appColors,
    required this.appTypography,
  });

  final CouponAssignmentDto assignment;
  final AppColors appColors;
  final AppTypography appTypography;

  @override
  Widget build(BuildContext context) {
    return AdminListCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Dimens.padding),
                decoration: BoxDecoration(
                  color: appColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard_outlined,
                  color: appColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: Dimens.padding),
              Expanded(
                child: Text(
                  assignment.code,
                  style: appTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusBadge(
                assignment: assignment,
                appColors: appColors,
                appTypography: appTypography,
              ),
            ],
          ),
          SizedBox(height: Dimens.padding),
          Text(
            'Müşteri: ${assignment.userFullName ?? assignment.userEmail ?? "-"}',
            style: appTypography.bodyMedium.copyWith(color: appColors.gray4),
          ),
          const SizedBox(height: 4),
          Text(
            assignment.discountType == 1
                ? '%${assignment.discountValue.toInt()} indirim'
                : '${assignment.discountValue.toInt()} ₺ indirim',
            style: appTypography.bodySmall.copyWith(color: appColors.gray4),
          ),
          if (assignment.isUsed && assignment.usedAtUtc != null)
            Padding(
              padding: EdgeInsets.only(top: Dimens.smallPadding),
              child: Text(
                'Kullanım: ${_formatDate(assignment.usedAtUtc!)}',
                style: appTypography.bodySmall.copyWith(
                  color: appColors.gray4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.assignment,
    required this.appColors,
    required this.appTypography,
  });

  final CouponAssignmentDto assignment;
  final AppColors appColors;
  final AppTypography appTypography;

  @override
  Widget build(BuildContext context) {
    final (String label, Color bgColor, Color textColor) = switch (assignment.status) {
      'used' => ('Kullanıldı', appColors.gray2.withValues(alpha: 0.3), appColors.gray4),
      'expired' => ('Süresi Doldu', appColors.error.withValues(alpha: 0.15), appColors.error),
      'pending' => ('Onay Bekliyor', appColors.warning.withValues(alpha: 0.15), appColors.warning),
      'approved' => ('Kullanılabilir', appColors.success.withValues(alpha: 0.15), appColors.success),
      _ => ('-', appColors.gray2, appColors.gray4),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Dimens.padding,
        vertical: Dimens.smallPadding,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Dimens.smallCorners),
      ),
      child: Text(
        label,
        style: appTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
