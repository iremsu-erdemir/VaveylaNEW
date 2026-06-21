import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/profanity_validator.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/reviewable_order_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/customer_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/feedback_service.dart';

/// Müşteri geri bildirim ekranı. Ürün / sipariş / kurye hedefi seçilebilir.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    this.prefilledMenuItemId,
    this.prefilledOrderId,
    this.prefilledCourierUserId,
    this.initialTarget,
  });

  final String? prefilledMenuItemId;
  final String? prefilledOrderId;
  final String? prefilledCourierUserId;
  final CustomerFeedbackTargetType? initialTarget;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const int _customerRoleId = 2;

  final FeedbackService _feedbackService = FeedbackService();
  final CustomerOrderService _orderService = CustomerOrderService();
  final _messageController = TextEditingController();

  CustomerFeedbackTargetType _target = CustomerFeedbackTargetType.bakeryOrder;
  List<CustomerOrderModel> _orders = const [];
  List<ReviewableOrderItemModel> _purchasedProducts = const [];
  CustomerOrderModel? _selectedOrder;
  ReviewableOrderItemModel? _selectedProduct;
  bool _loadingOrders = false;
  bool _loadingProducts = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledMenuItemId != null && widget.prefilledMenuItemId!.isNotEmpty) {
      _target = CustomerFeedbackTargetType.bakeryProduct;
    }
    if (widget.initialTarget != null) {
      _target = widget.initialTarget!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
      _loadPurchasedProducts();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchasedProducts() async {
    final uid = AppSession.userId;
    if (uid.isEmpty) return;
    setState(() => _loadingProducts = true);
    try {
      final list = await _orderService.getPurchasedProducts(customerUserId: uid);
      if (!mounted) return;
      ReviewableOrderItemModel? selected;
      final prefilled = widget.prefilledMenuItemId?.trim();
      if (prefilled != null && prefilled.isNotEmpty) {
        for (final p in list) {
          if (p.id == prefilled) {
            selected = p;
            break;
          }
        }
      }
      setState(() {
        _purchasedProducts = list;
        _loadingProducts = false;
        _selectedProduct = selected ?? (list.isNotEmpty ? list.first : null);
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  /// Kurye şikayeti: yalnızca teslim edilmiş ve gerçek kurye atanmış siparişler.
  List<CustomerOrderModel> get _completedOrdersWithCourier => _orders
      .where(
        (o) =>
            o.status == CustomerOrderStatus.completed &&
            (o.assignedCourierUserId?.trim().isNotEmpty ?? false),
      )
      .toList();

  Future<void> _loadOrders() async {
    final uid = AppSession.userId;
    if (uid.isEmpty) return;
    setState(() => _loadingOrders = true);
    try {
      final list = await _orderService.getOrders(customerUserId: uid);
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loadingOrders = false;
        _syncSelectionFromPrefill();
        _ensureValidSelectionForTarget();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  void _syncSelectionFromPrefill() {
    CustomerOrderModel? match;
    if (widget.prefilledOrderId != null && widget.prefilledOrderId!.isNotEmpty) {
      for (final o in _orders) {
        if (o.id == widget.prefilledOrderId) {
          match = o;
          break;
        }
      }
    }
    _selectedOrder = match ?? (_orders.isNotEmpty ? _orders.first : null);
  }

  void _ensureValidSelectionForTarget() {
    if (_target == CustomerFeedbackTargetType.courier) {
      final list = _completedOrdersWithCourier;
      if (list.isEmpty) {
        _selectedOrder = null;
        return;
      }
      final current = _selectedOrder;
      if (current == null || !list.any((o) => o.id == current.id)) {
        _selectedOrder = list.first;
      }
    } else if (_target == CustomerFeedbackTargetType.bakeryOrder) {
      if (_selectedOrder != null && !_orders.any((o) => o.id == _selectedOrder!.id)) {
        _selectedOrder = _orders.isNotEmpty ? _orders.first : null;
      } else if (_selectedOrder == null && _orders.isNotEmpty) {
        _selectedOrder = _orders.first;
      }
    }
  }

  String _orderDropdownLabel(CustomerOrderModel o) {
    if (_target == CustomerFeedbackTargetType.courier) {
      final name = (o.courierName?.trim().isNotEmpty ?? false)
          ? o.courierName!.trim()
          : 'Kurye';
      final rest = o.restaurantName?.trim();
      if (rest != null && rest.isNotEmpty) {
        return '$name · $rest';
      }
      final items = o.items.trim();
      if (items.length > 42) {
        return '$name · ${items.substring(0, 39)}…';
      }
      return items.isEmpty ? name : '$name · $items';
    }
    return '${o.restaurantName ?? 'Pastane'} · ${o.items}';
  }

  List<CustomerOrderModel> _pickerOrdersForTarget() =>
      _target == CustomerFeedbackTargetType.courier
          ? _completedOrdersWithCourier
          : _orders;

  /// Dropdown `items` ile aynı referansı döndürür (SegmentedButton / yükleme sonrası senkron).
  CustomerOrderModel? _selectedOrderForDropdown() {
    final picker = _pickerOrdersForTarget();
    if (picker.isEmpty) return null;
    if (_selectedOrder != null) {
      for (final o in picker) {
        if (o.id == _selectedOrder!.id) return o;
      }
    }
    return picker.first;
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;

    if (AppSession.roleId != _customerRoleId) {
      context.showErrorMessage('Geri bildirim yalnızca müşteri hesabıyla gönderilebilir.');
      return;
    }

    final userId = AppSession.userId;
    if (userId.isEmpty) {
      context.showErrorMessage(context.tr('feedback_login_required'));
      return;
    }

    if (AppSession.token.isEmpty) {
      context.showErrorMessage('Oturum süreniz dolmuş olabilir. Lütfen tekrar giriş yapın.');
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      context.showErrorMessage(context.tr('feedback_form_validation'));
      return;
    }

    final profanityError = ProfanityValidator.validateOrNull(
      _messageController.text,
    );
    if (profanityError != null) {
      context.showErrorMessage(profanityError);
      return;
    }

    String targetEntityId;

    switch (_target) {
      case CustomerFeedbackTargetType.bakeryProduct:
        targetEntityId = _selectedProduct?.id ?? widget.prefilledMenuItemId ?? '';
        if (targetEntityId.isEmpty) {
          context.showErrorMessage(
            'Satın aldığınız bir ürün seçin. Henüz teslim edilmiş siparişiniz yoksa ürün geri bildirimi gönderemezsiniz.',
          );
          return;
        }
        break;
      case CustomerFeedbackTargetType.bakeryOrder:
        final orderId = _selectedOrder?.id ?? widget.prefilledOrderId;
        if (orderId == null || orderId.isEmpty) {
          context.showErrorMessage('Lütfen bir sipariş seçin.');
          return;
        }
        targetEntityId = orderId;
        break;
      case CustomerFeedbackTargetType.courier:
        final courierUserId =
            widget.prefilledCourierUserId?.trim().isNotEmpty == true
            ? widget.prefilledCourierUserId!.trim()
            : _selectedOrder?.assignedCourierUserId;
        if (courierUserId == null || courierUserId.isEmpty) {
          context.showErrorMessage(
            'Kurye şikayeti için atanmış kuryesi olan bir sipariş seçin.',
          );
          return;
        }
        targetEntityId = courierUserId;
        break;
    }

    setState(() => _isSubmitting = true);

    try {
      await _feedbackService.submitCustomerFeedback(
        targetType: _target,
        targetEntityId: targetEntityId,
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      context.showSuccessMessage(context.tr('feedback_sent_message'));
      _messageController.clear();
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : colors.white;
    final inputFill = isDark ? const Color(0xFF242424) : colors.gray;
    final hintColor = isDark ? colors.gray2 : colors.gray4;
    final titleColor = isDark ? colors.primaryTint1 : colors.primaryTint2;

    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: typography.bodyMedium.copyWith(color: hintColor),
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.largePadding,
        vertical: Dimens.mediumPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.gray2.withValues(alpha: 0.45)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.gray2.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.primary),
      ),
    );

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
              colors.secondary.withValues(alpha: 0.32),
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
                      context.tr('feedback'),
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
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                    Dimens.largePadding,
                    Dimens.largePadding,
                    Dimens.largePadding,
                    Dimens.extraLargePadding,
                  ),
                  padding: const EdgeInsets.all(Dimens.extraLargePadding),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('feedback_need_help_title'),
                        style: typography.titleMedium.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Dimens.padding),
                      Text(
                        context.tr('feedback_need_help_description'),
                        style: typography.bodyMedium.copyWith(
                          color: hintColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: Dimens.largePadding),
                      Text(
                        'Şikayet konusu',
                        style: typography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: Dimens.padding),
                      SegmentedButton<CustomerFeedbackTargetType>(
                        segments: const [
                          ButtonSegment(
                            value: CustomerFeedbackTargetType.bakeryProduct,
                            label: Text('Ürün'),
                          ),
                          ButtonSegment(
                            value: CustomerFeedbackTargetType.bakeryOrder,
                            label: Text('Sipariş'),
                          ),
                          ButtonSegment(
                            value: CustomerFeedbackTargetType.courier,
                            label: Text('Kurye'),
                          ),
                        ],
                        selected: {_target},
                        onSelectionChanged: (s) {
                          setState(() {
                            _target = s.first;
                            _ensureValidSelectionForTarget();
                            if (_target == CustomerFeedbackTargetType.bakeryProduct &&
                                _purchasedProducts.isEmpty) {
                              _loadPurchasedProducts();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: Dimens.largePadding),
                      if (_target == CustomerFeedbackTargetType.bakeryProduct) ...[
                        Text(
                          'Satın aldığınız ürün',
                          style: typography.labelLarge.copyWith(color: colors.gray4),
                        ),
                        const SizedBox(height: 6),
                        if (_loadingProducts)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_purchasedProducts.isEmpty)
                          Text(
                            'Teslim edilmiş siparişinizdeki ürün bulunamadı. '
                            'Ürün geri bildirimi için önce sipariş verip teslim almanız gerekir.',
                            style: typography.bodySmall.copyWith(color: hintColor),
                          )
                        else
                          InputDecorator(
                            decoration: deco('Ürün seçin'),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ReviewableOrderItemModel>(
                                isExpanded: true,
                                value: _selectedProduct,
                                items: _purchasedProducts
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedProduct = v),
                              ),
                            ),
                          ),
                      ],
                      if (_target == CustomerFeedbackTargetType.bakeryOrder ||
                          _target == CustomerFeedbackTargetType.courier) ...[
                        Text(
                          _target == CustomerFeedbackTargetType.courier
                              ? 'Kurye seçimi'
                              : 'Sipariş seçimi',
                          style: typography.labelLarge.copyWith(color: colors.gray4),
                        ),
                        if (_target == CustomerFeedbackTargetType.courier) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tamamlanan siparişlerdeki kuryeler listelenir.',
                            style: typography.bodySmall.copyWith(color: hintColor),
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (_loadingOrders)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          if (_target == CustomerFeedbackTargetType.bakeryOrder &&
                              _orders.isEmpty)
                            Text(
                              'Sipariş bulunamadı. Önce sipariş vermeniz gerekir.',
                              style: typography.bodySmall.copyWith(color: hintColor),
                            )
                          else if (_target == CustomerFeedbackTargetType.courier &&
                              _completedOrdersWithCourier.isEmpty)
                            Text(
                              'Tamamlanmış ve kuryesi kayıtlı sipariş yok. '
                              'Kurye şikayeti için önce teslim edilmiş bir siparişiniz olmalı.',
                              style: typography.bodySmall.copyWith(color: hintColor),
                            )
                          else
                            InputDecorator(
                              decoration: deco(
                                _target == CustomerFeedbackTargetType.courier
                                    ? 'Kurye (sipariş)'
                                    : 'Sipariş',
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<CustomerOrderModel>(
                                  isExpanded: true,
                                  value: _selectedOrderForDropdown(),
                                  hint: Text(
                                    _target == CustomerFeedbackTargetType.courier
                                        ? 'Kurye seçin'
                                        : 'Sipariş seçin',
                                  ),
                                  items: _pickerOrdersForTarget()
                                      .map(
                                        (o) => DropdownMenuItem(
                                          value: o,
                                          child: Text(
                                            _orderDropdownLabel(o),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedOrder = v),
                                ),
                              ),
                            ),
                        ],
                      ],
                      const SizedBox(height: Dimens.largePadding),
                      TextField(
                        controller: _messageController,
                        maxLines: 6,
                        style: typography.bodyMedium.copyWith(
                          color: isDark ? colors.white : colors.primaryTint2,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: deco(context.tr('feedback_message_hint')),
                      ),
                      const SizedBox(height: Dimens.extraLargePadding),
                      AppButton(
                        title: context.tr('send'),
                        onPressed: _isSubmitting ? null : _submitFeedback,
                        margin: EdgeInsets.zero,
                        borderRadius: 14,
                        textStyle: typography.titleMedium.copyWith(
                          color: colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
