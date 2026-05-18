import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/data/models/user_coupon_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/data/services/coupon_service.dart';

class CouponSelectScreen extends StatefulWidget {
  const CouponSelectScreen({
    super.key,
    this.selectedUserCouponId,
  });

  final String? selectedUserCouponId;

  @override
  State<CouponSelectScreen> createState() => _CouponSelectScreenState();
}

class _CouponSelectScreenState extends State<CouponSelectScreen> {
  final CouponService _couponService = CouponService();

  List<UserCouponModel> _coupons = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedUserCouponId;
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Giriş yapın';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _couponService.getMyCoupons(customerUserId: userId);
      setState(() {
        _coupons = list;
        final sel = _selectedId;
        if (sel != null && sel.isNotEmpty) {
          final stillUsable = list.any(
            (c) => c.userCouponId == sel && c.isUsable,
          );
          if (!stillUsable) {
            _selectedId = null;
          }
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onSelect(UserCouponModel coupon) {
    if (!coupon.isUsable) return;
    setState(() {
      _selectedId = _selectedId == coupon.userCouponId ? null : coupon.userCouponId;
    });
  }

  void _confirm() {
    final id = _selectedId;
    if (id == null || id.isEmpty) {
      Navigator.of(context).pop('');
      return;
    }
    UserCouponModel? match;
    for (final c in _coupons) {
      if (c.userCouponId == id) {
        match = c;
        break;
      }
    }
    if (match == null || !match.isUsable) {
      Navigator.of(context).pop('');
      return;
    }
    Navigator.of(context).pop(id);
  }

  /// Kullanılabilirler önce, ardından pasif (kullanılmış / süresi dolmuş / onay bekleyen).
  List<UserCouponModel> get _couponsDisplayOrder {
    final usable = _coupons.where((c) => c.isUsable).toList();
    final passive = _coupons.where((c) => !c.isUsable).toList();
    return [...usable, ...passive];
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Kupon Seç',
        showBackIcon: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(Dimens.largePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: Dimens.padding),
                      child: Text(
                        _error!,
                        style: appTypography.bodySmall.copyWith(color: appColors.error),
                      ),
                    ),
                  Text(
                    'Kuponlarım',
                    style: appTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: Dimens.padding),
                  Builder(
                    builder: (context) {
                      if (_coupons.isEmpty) {
                        return Padding(
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
                        );
                      }
                      final usableCount =
                          _coupons.where((c) => c.isUsable).length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (usableCount == 0)
                            Padding(
                              padding: EdgeInsets.only(bottom: Dimens.padding),
                              child: Text(
                                'Kullanılabilir kuponunuz yok. Aşağıda pasif kuponlarınız listelenir.',
                                style: appTypography.bodySmall.copyWith(
                                  color: appColors.gray4,
                                ),
                              ),
                            ),
                          ..._couponsDisplayOrder.map(
                            (c) => _CouponTile(
                              coupon: c,
                              selected:
                                  c.isUsable && _selectedId == c.userCouponId,
                              onTap: () => _onSelect(c),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: Dimens.extraLargePadding),
                  Builder(
                    builder: (context) {
                      final canApply = _coupons.any((c) => c.isUsable) &&
                          _selectedId != null &&
                          _selectedId!.isNotEmpty &&
                          _coupons.any(
                            (c) =>
                                c.userCouponId == _selectedId && c.isUsable,
                          );
                      return AppButton(
                        title: 'Uygula',
                        onPressed: canApply ? _confirm : null,
                        textStyle: appTypography.bodyLarge,
                        borderRadius: Dimens.corners,
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({
    required this.coupon,
    required this.selected,
    required this.onTap,
  });

  final UserCouponModel coupon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;
    final isPassive = !coupon.isUsable;

    final borderColor = isPassive
        ? appColors.gray2.withValues(alpha: 0.55)
        : selected
            ? appColors.primary
            : appColors.gray2;
    final borderWidth = !isPassive && selected ? 2.0 : 1.0;

    final tile = Padding(
      padding: EdgeInsets.only(bottom: Dimens.padding),
      child: Material(
        color: isPassive
            ? appColors.gray2.withValues(alpha: 0.22)
            : appColors.white,
        borderRadius: BorderRadius.circular(Dimens.corners),
        child: InkWell(
          onTap: isPassive ? null : onTap,
          borderRadius: BorderRadius.circular(Dimens.corners),
          child: Container(
            padding: EdgeInsets.all(Dimens.largePadding),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
              borderRadius: BorderRadius.circular(Dimens.corners),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.discountText,
                        style: appTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isPassive
                              ? appColors.gray4
                              : appColors.primary,
                        ),
                      ),
                      SizedBox(height: Dimens.smallPadding),
                      Text(
                        coupon.conditionsText,
                        style: appTypography.bodySmall.copyWith(
                          color: isPassive
                              ? appColors.gray4.withValues(alpha: 0.85)
                              : appColors.gray4,
                        ),
                      ),
                      if (coupon.isPending)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Onay bekliyor · kullanılamaz',
                            style: appTypography.bodySmall.copyWith(
                              color: appColors.warning.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (coupon.isUsed)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Kullanıldı · tekrar seçilemez',
                            style: appTypography.bodySmall.copyWith(
                              color: appColors.gray4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (coupon.isExpired)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Süresi doldu · kullanılamaz',
                            style: appTypography.bodySmall.copyWith(
                              color: appColors.gray4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (coupon.isUsable)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? appColors.primary : appColors.gray4,
                      size: 26,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      Icons.block_rounded,
                      color: appColors.gray4.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isPassive) {
      return tile;
    }
    return Opacity(
      opacity: 0.72,
      child: tile,
    );
  }
}
