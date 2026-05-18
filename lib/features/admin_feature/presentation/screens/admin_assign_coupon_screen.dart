import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_coupon_service.dart';

class AdminAssignCouponScreen extends StatefulWidget {
  const AdminAssignCouponScreen({super.key});

  @override
  State<AdminAssignCouponScreen> createState() => _AdminAssignCouponScreenState();
}

class _AdminAssignCouponScreenState extends State<AdminAssignCouponScreen> {
  final AdminCouponService _service = AdminCouponService();
  List<CouponOption> _coupons = [];
  List<CustomerOption> _customers = [];
  String? _selectedCouponId;
  String? _selectedCustomerId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getCoupons(),
        _service.getCustomers(),
      ]);
      if (mounted) setState(() {
        _coupons = results[0] as List<CouponOption>;
        _customers = results[1] as List<CustomerOption>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedCouponId == null || _selectedCustomerId == null) {
      context.showErrorMessage('Kupon ve müşteri seçin.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.assignCouponToCustomer(_selectedCouponId!, _selectedCustomerId!);
      if (mounted) {
        context.showSuccessMessage('Kupon müşteriye atandı.');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Kupon Ata', showBackIcon: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(Dimens.largePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Kupon seçin', style: appTypography.titleSmall),
                  const SizedBox(height: Dimens.padding),
                  DropdownButtonFormField<String>(
                    value: _selectedCouponId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Dimens.smallCorners),
                      ),
                    ),
                    items: _coupons
                        .map((c) => DropdownMenuItem(
                              value: c.couponId,
                              child: Text('${c.code} - ${c.discountType == 1 ? "%${c.discountValue.toInt()}" : "${c.discountValue.toInt()} ₺"}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCouponId = v),
                  ),
                  SizedBox(height: Dimens.extraLargePadding),
                  Text('Müşteri seçin', style: appTypography.titleSmall),
                  const SizedBox(height: Dimens.padding),
                  DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Dimens.smallCorners),
                      ),
                    ),
                    items: _customers
                        .map((c) => DropdownMenuItem(
                              value: c.userId,
                              child: Text('${c.fullName} (${c.email})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCustomerId = v),
                  ),
                  SizedBox(height: Dimens.extraLargePadding),
                  AppButton(
                    title: 'Ata',
                    onPressed: _submitting ? null : _submit,
                    textStyle: appTypography.bodyLarge,
                    borderRadius: Dimens.corners,
                  ),
                ],
              ),
            ),
    );
  }
}
