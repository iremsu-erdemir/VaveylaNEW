import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/check_theme_status.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/models/payment_saved_card.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/add_card_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/existing_cards_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/payment_completion_success_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/services/payment_card_service.dart';

import '../../../../core/gen/assets.gen.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_svg_viewer.dart';

enum _PaymentMethod { paypal, applePay, googlePay }

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, this.deliveryAddress = ''});

  final String deliveryAddress;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final PaymentCardService _paymentCardService = PaymentCardService();
  final CustomerOrderService _customerOrderService = CustomerOrderService();
  _PaymentMethod? _selectedMethod;
  PaymentSavedCard? _selectedCard;

  void _onSelect(_PaymentMethod method) {
    setState(() {
      _selectedMethod = _selectedMethod == method ? null : method;
      _selectedCard = null;
    });
  }

  bool get _isNextEnabled => _selectedMethod != null || _selectedCard != null;

  Future<void> _openAddCard() async {
    final result = await appPush(context, const AddCardScreen());
    if (result == true && mounted) {
      final userId = AppSession.userId;
      if (userId.isEmpty) {
        return;
      }
      try {
        final cards = await _paymentCardService.getCards(userId: userId);
        if (!mounted || cards.isEmpty) {
          return;
        }
        setState(() {
          _selectedCard = cards.first;
          _selectedMethod = null;
        });
      } catch (_) {}
    }
  }

  Future<void> _openExistingCards() async {
    final result = await appPush(
      context,
      const ExistingCardsScreen(selectionMode: true),
    );
    if (result is PaymentSavedCard && mounted) {
      setState(() {
        _selectedCard = result;
        _selectedMethod = null;
      });
    }
  }

  Future<void> _goNext() async {
    if (!_isNextEnabled) {
      return;
    }
    if (widget.deliveryAddress.isEmpty) {
      context.showSuccessMessage('Ödeme yöntemi seçildi.');
      Navigator.of(context).pop();
      return;
    }
    final cartState = context.read<CartCubit>().state;
    if (cartState is! CartLoaded || cartState.items.isEmpty) {
      context.showErrorMessage('Sepet boş.');
      return;
    }
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      context.showErrorMessage('Sipariş vermek için giriş yapın.');
      return;
    }
    final firstItem = cartState.items.first;
    final restaurantId = firstItem.product.restaurantId ?? '';
    if (restaurantId.isEmpty) {
      context.showErrorMessage('Ürün bilgisi eksik.');
      return;
    }
    final itemsStr = cartState.items
        .map((i) => '${i.quantity}x ${i.product.name} (${i.product.weight} kg)')
        .join(', ');
    final total = cartState.finalPrice.round();
    final selectedCouponId = cartState.selectedUserCouponId;
    String? createdOrderId;
    try {
      final createResult = await _customerOrderService.createOrder(
        customerUserId: userId,
        restaurantId: restaurantId,
        items: itemsStr,
        total: total,
        deliveryAddress: widget.deliveryAddress,
        customerName: AppSession.fullName,
        userCouponId: selectedCouponId,
      );
      createdOrderId = createResult['id']?.toString();
      await _waitUntilOrderVisible(
        userId: userId,
        createdOrderId: createdOrderId,
      );
    } catch (e) {
      if (mounted) {
        context.showErrorMessage('Sipariş oluşturulamadı: $e');
      }
      return;
    }
    if (!mounted) return;
    await context.read<CartCubit>().clearCart();
    await appPush(context, const PaymentCompletionSuccessScreen());
  }

  Future<void> _waitUntilOrderVisible({
    required String userId,
    required String? createdOrderId,
  }) async {
    final orderId = createdOrderId?.trim() ?? '';
    if (orderId.isEmpty) return;

    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final orders = await _customerOrderService.getOrders(customerUserId: userId);
      final found = orders.any((order) => order.id == orderId);
      if (found) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: context.tr('payment_methods_title')),
      body: SingleChildScrollView(
        child: Column(
          spacing: Dimens.largePadding,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('add_credit_card'), style: appTypography.bodyLarge),
            const SizedBox(height: Dimens.padding),
            BorderedContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _PaymentMethodTile(
                    title: context.tr('add_card'),
                    iconPath: Assets.icons.card,
                    selected: _selectedCard != null,
                    onTap: _openAddCard,
                    showRadio: false,
                    useBrandIconColors: false,
                  ),
                  Divider(height: 1, color: appColors.gray),
                  _PaymentMethodTile(
                    title: context.tr('select_existing_cards'),
                    iconPath: Assets.icons.cardReceive,
                    selected: _selectedCard != null,
                    onTap: _openExistingCards,
                    showRadio: false,
                    useBrandIconColors: false,
                  ),
                ],
              ),
            ),
            if (_selectedCard != null)
              Text(
                '${context.tr('selected_card')}: ${_selectedCard!.cardAlias}',
                style: appTypography.bodySmall.copyWith(color: appColors.gray4),
              ),
            const SizedBox(height: Dimens.padding),
            Text(
              context.tr('more_payment_options'),
              style: appTypography.bodyLarge,
            ),
            const SizedBox(height: Dimens.padding),
            BorderedContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _PaymentMethodTile(
                    title: 'PayPal',
                    logoPath:
                        checkDarkMode(context) ? null : Assets.icons.paypalLogo,
                    selected: _selectedMethod == _PaymentMethod.paypal,
                    onTap: () => _onSelect(_PaymentMethod.paypal),
                  ),
                  Divider(height: 1, color: appColors.gray),
                  _PaymentMethodTile(
                    title: 'Apple Pay',
                    logoPath:
                        checkDarkMode(context) ? null : Assets.icons.appleLogo,
                    selected: _selectedMethod == _PaymentMethod.applePay,
                    onTap: () => _onSelect(_PaymentMethod.applePay),
                  ),
                  Divider(height: 1, color: appColors.gray),
                  _PaymentMethodTile(
                    title: 'Google Pay',
                    logoPath:
                        checkDarkMode(context) ? null : Assets.icons.googleLogo,
                    selected: _selectedMethod == _PaymentMethod.googlePay,
                    onTap: () => _onSelect(_PaymentMethod.googlePay),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: Dimens.largePadding,
          right: Dimens.largePadding,
          bottom: Dimens.padding,
        ),
        child: AppButton(
          onPressed: _isNextEnabled ? _goNext : null,
          title: context.tr('next'),
          textStyle: appTypography.bodyLarge,
          borderRadius: Dimens.corners,
          margin: const EdgeInsets.only(top: Dimens.largePadding),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.title,
    this.iconPath,
    this.logoPath,
    required this.selected,
    required this.onTap,
    this.showRadio = true,
    this.useBrandIconColors = true,
  });

  final String title;
  final String? iconPath;
  final String? logoPath;
  final bool selected;
  final VoidCallback onTap;
  final bool showRadio;
  final bool useBrandIconColors;

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.largePadding,
          vertical: Dimens.padding,
        ),
        child: Row(
          children: [
            if (iconPath != null)
              Padding(
                padding: const EdgeInsets.only(right: Dimens.padding),
                child: AppSvgViewer(
                  iconPath!,
                  width: 18,
                  height: 18,
                  color: useBrandIconColors ? null : appColors.primary,
                ),
              ),
            if (logoPath != null)
              Padding(
                padding: const EdgeInsets.only(right: Dimens.padding),
                child: AppSvgViewer(logoPath!, width: 18, height: 18),
              ),
            Expanded(child: Text(title, style: appTypography.bodyMedium)),
            if (showRadio)
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? appColors.primary : appColors.gray2,
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child:
                    selected
                        ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: appColors.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
