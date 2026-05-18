import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/data/models/user_coupon_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/data/services/coupon_service.dart';

class CouponsListScreen extends StatefulWidget {
  const CouponsListScreen({super.key});

  @override
  State<CouponsListScreen> createState() => _CouponsListScreenState();
}

class _CouponsListScreenState extends State<CouponsListScreen> {
  final CouponService _couponService = CouponService();

  List<UserCouponModel> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await _couponService.getMyCoupons(customerUserId: userId);
      setState(() {
        _coupons = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;
    final userId = AppSession.userId;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Kuponlarım', showBackIcon: true),
      body: RefreshIndicator(
        onRefresh: _loadCoupons,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(Dimens.largePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Kuponlarım',
                      style: appTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: Dimens.padding),
                    if (userId.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Dimens.extraLargePadding,
                        ),
                        child: Text(
                          'Kuponlarınızı görmek için giriş yapın.',
                          style: appTypography.bodyMedium.copyWith(
                            color: appColors.gray4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_coupons.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Dimens.extraLargePadding,
                        ),
                        child: Text(
                          'Henüz kuponunuz yok. Admin tarafından size atanmış kuponlar burada görünecektir.',
                          style: appTypography.bodyMedium.copyWith(
                            color: appColors.gray4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._coupons.map((c) => _CouponCard(coupon: c)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final UserCouponModel coupon;

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;
    final isDisabled = !coupon.isUsable;

    return Padding(
      padding: EdgeInsets.only(bottom: Dimens.padding),
      child: Container(
        padding: EdgeInsets.all(Dimens.largePadding),
        decoration: BoxDecoration(
          color: isDisabled ? appColors.gray2.withValues(alpha: 0.2) : null,
          border: Border.all(
            color:
                isDisabled
                    ? appColors.gray2
                    : appColors.primary.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(Dimens.corners),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    coupon.discountText,
                    style: appTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDisabled ? appColors.gray4 : appColors.primary,
                    ),
                  ),
                ),
                if (coupon.isPending)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Dimens.padding,
                      vertical: Dimens.smallPadding,
                    ),
                    decoration: BoxDecoration(
                      color: appColors.warningLight,
                      borderRadius: BorderRadius.circular(Dimens.smallCorners),
                    ),
                    child: Text(
                      'Onay bekliyor',
                      style: appTypography.bodySmall.copyWith(
                        color: appColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (coupon.isUsed)
                  Text(
                    'Kullanıldı',
                    style: appTypography.bodySmall.copyWith(
                      color: appColors.gray4,
                    ),
                  )
                else if (coupon.isExpired)
                  Text(
                    'Süresi doldu',
                    style: appTypography.bodySmall.copyWith(
                      color: appColors.error,
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Dimens.padding,
                      vertical: Dimens.smallPadding,
                    ),
                    decoration: BoxDecoration(
                      color: appColors.successLight,
                      borderRadius: BorderRadius.circular(Dimens.smallCorners),
                    ),
                    child: Text(
                      'Kullanılabilir',
                      style: appTypography.bodySmall.copyWith(
                        color: appColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: Dimens.padding),
            Text(
              coupon.conditionsText,
              style: appTypography.bodySmall.copyWith(color: appColors.gray4),
            ),
          ],
        ),
      ),
    );
  }
}
