import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/courier_account_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_orders_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/utils/image_picker_helper.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

Future<String?> showRejectionReasonDialog(
  BuildContext context, {
  required String orderId,
}) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = dialogContext.theme.appColors;
        final typography = dialogContext.theme.appTypography;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: Dimens.largePadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Dimens.extraLargePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reddetme nedeni',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Dimens.smallPadding),
                Text(
                  'Sipariş #$orderId için müşteriye iletilecek sebebi yazın.',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
                const SizedBox(height: Dimens.largePadding),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Örn: Stokta yok / Teslimat gecikecek',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(Dimens.corners),
                    ),
                  ),
                ),
                const SizedBox(height: Dimens.extraLargePadding),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(null),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colors.gray.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: Dimens.padding,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Dimens.corners),
                          ),
                        ),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: Dimens.padding),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            dialogContext.showErrorMessage(
                              'Lütfen reddetme nedeni girin.',
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop(text);
                        },
                        child: const Text('Reddet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Future<void> showCourierAssignmentSheet(
  BuildContext context, {
  required RestaurantOrderModel order,
}) async {
  if (!order.canAssignCourier) {
    if (context.mounted) {
      context.showErrorMessage(
        'Bu aşamada kurye atanamaz veya değiştirilemez (ör. teslim tamamlandı).',
      );
    }
    return;
  }
  final ownerUserId = AppSession.userId;
  final service = RestaurantOwnerService(authService: AuthService());
  late final List<CourierAccountModel> couriers;
  try {
    couriers = await service.getCourierAccounts(ownerUserId: ownerUserId);
  } catch (e) {
    if (context.mounted) {
      context.showErrorMessage(e.toString());
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  if (couriers.isEmpty) {
    context.showErrorMessage(
      'Kayıtlı kurye hesabı yok. Kurye rolünde kullanıcı oluşturun.',
    );
    return;
  }

  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: Dimens.extraLargePadding,
            right: Dimens.extraLargePadding,
            top: Dimens.extraLargePadding,
            bottom:
                Dimens.extraLargePadding +
                MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _CourierPickerBody(order: order, couriers: couriers),
        ),
      );
    },
  );

  if (picked == null || !context.mounted) {
    return;
  }

  try {
    await context.read<RestaurantOrdersCubit>().assignCourier(
      orderId: order.id,
      courierUserId: picked,
    );
    if (context.mounted) {
      context.showSuccessMessage(
        'Kurye atandı; seçilen hesaba bildirim gider.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      context.showErrorMessage(e.toString());
    }
  }
}

class RestaurantOwnerOrdersScreen extends StatefulWidget {
  const RestaurantOwnerOrdersScreen({super.key});

  @override
  State<RestaurantOwnerOrdersScreen> createState() =>
      _RestaurantOwnerOrdersScreenState();
}

class _RestaurantOwnerOrdersScreenState
    extends State<RestaurantOwnerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Sipariş Yönetimi',
        showBackIcon: false,
        actions: [
          IconButton(
            onPressed: () => _showAddOrderSheet(context),
            icon: Icon(Icons.add_circle, color: colors.primary, size: 28),
            tooltip: 'Manuel sipariş ekle',
          ),
          const SizedBox(width: Dimens.padding),
        ],
        height: AppBar().preferredSize.height + 56,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: BlocBuilder<RestaurantOrdersCubit, List<RestaurantOrderModel>>(
            builder: (context, orders) {
              final pending = orders
                  .where((o) => o.status == RestaurantOrderStatus.pending)
                  .length;
              final preparing = orders
                  .where((o) => o.status == RestaurantOrderStatus.preparing)
                  .length;
              final completed = orders
                  .where((o) => o.status == RestaurantOrderStatus.completed)
                  .length;
              final rejected = orders
                  .where((o) => o.status == RestaurantOrderStatus.rejected)
                  .length;
              return TabBar(
                controller: _tabController,
                isScrollable: true,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                dividerColor: colors.gray,
                labelColor: colors.primary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                unselectedLabelColor: colors.black,
                indicatorColor: colors.primary,
                tabs: [
                  Tab(child: _TabWithBadge(label: 'Bekleyen', count: pending)),
                  Tab(child: _TabWithBadge(label: 'Hazırlanıyor', count: preparing)),
                  Tab(child: _TabWithBadge(label: 'Tamamlanan', count: completed)),
                  Tab(child: _TabWithBadge(label: 'Reddedilenler', count: rejected)),
                ],
              );
            },
          ),
        ),
      ),
      body: BlocBuilder<RestaurantOrdersCubit, List<RestaurantOrderModel>>(
        builder: (context, orders) {
          return TabBarView(
            controller: _tabController,
            children: [
              _OrdersList(
                orders: orders
                    .where((o) => o.status == RestaurantOrderStatus.pending)
                    .toList(),
                status: RestaurantOrderStatus.pending,
                tabController: _tabController,
              ),
              _OrdersList(
                orders: orders
                    .where((o) => o.status == RestaurantOrderStatus.preparing)
                    .toList(),
                status: RestaurantOrderStatus.preparing,
                tabController: _tabController,
              ),
              _OrdersList(
                orders: orders
                    .where((o) => o.status == RestaurantOrderStatus.completed)
                    .toList(),
                status: RestaurantOrderStatus.completed,
                tabController: _tabController,
              ),
              _OrdersList(
                orders: orders
                    .where((o) => o.status == RestaurantOrderStatus.rejected)
                    .toList(),
                status: RestaurantOrderStatus.rejected,
                tabController: _tabController,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddOrderSheet(BuildContext context) {
    final screenContext = context;
    final tabController = _tabController;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AddOrderSheet(
          onSave: (
            items,
            total,
            imagePath,
            preparationMinutes,
            status,
            createdAt,
          ) async {
            final cubit = screenContext.read<RestaurantOrdersCubit>();
            await cubit.addOrder(
              items,
              total,
              imagePath: imagePath,
              preparationMinutes: preparationMinutes,
              status: status,
              createdAt: createdAt,
            );
            Navigator.pop(ctx);
            tabController.animateTo(
              status == RestaurantOrderStatus.pending
                  ? 0
                  : status == RestaurantOrderStatus.preparing
                  ? 1
                  : status == RestaurantOrderStatus.rejected
                  ? 3
                  : 2,
            );
            screenContext.showSuccessMessage('Sipariş eklendi');
          },
        ),
      ),
    );
  }
}

class _AddOrderSheet extends StatefulWidget {
  const _AddOrderSheet({required this.onSave});

  final Future<void> Function(
    String items,
    int total,
    String? imagePath,
    int? preparationMinutes,
    RestaurantOrderStatus status,
    DateTime createdAt,
  ) onSave;

  @override
  State<_AddOrderSheet> createState() => _AddOrderSheetState();
}

class _AddOrderSheetState extends State<_AddOrderSheet> {
  final _itemsController = TextEditingController();
  final _totalController = TextEditingController();
  final _preparationMinutesController = TextEditingController();
  late final RestaurantOwnerService _service;
  late final String _ownerUserId;
  String? _selectedImagePath;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  RestaurantOrderStatus _selectedStatus = RestaurantOrderStatus.pending;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _ownerUserId = AppSession.userId;
    _service = RestaurantOwnerService(authService: AuthService());
  }

  @override
  void dispose() {
    _itemsController.dispose();
    _totalController.dispose();
    _preparationMinutesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }
    final items = _itemsController.text.trim();
    final total = int.tryParse(_totalController.text.trim()) ?? 0;
    final prepText = _preparationMinutesController.text.trim();
    final prepMinutes = prepText.isEmpty ? null : int.tryParse(prepText);
    if (items.isEmpty) return;
    if (total <= 0) return;
    if (prepText.isNotEmpty && (prepMinutes == null || prepMinutes <= 0)) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        items,
        total,
        _selectedImagePath,
        prepMinutes,
        _selectedStatus,
        _selectedDateTime,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  DateTime get _selectedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  String get _dateLabel {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final year = _selectedDate.year.toString();
    return '$day.$month.$year';
  }

  String get _timeLabel {
    final hour = _selectedTime.hour.toString().padLeft(2, '0');
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _statusLabel(RestaurantOrderStatus status) {
    switch (status) {
      case RestaurantOrderStatus.pending:
        return 'Bekliyor';
      case RestaurantOrderStatus.preparing:
        return 'Hazırlanıyor';
      case RestaurantOrderStatus.completed:
        return 'Tamamlandı';
      case RestaurantOrderStatus.rejected:
        return 'Reddedildi';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final file = await pickAndSaveImage(source);
      if (file == null || !mounted) {
        return;
      }
      setState(() => _isUploadingImage = true);
      final uploaded = await _service.uploadMenuImage(
        ownerUserId: _ownerUserId,
        filePath: file.path,
        fileBytes: await file.readAsBytes(),
        fileName: file.name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedImagePath = uploaded;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showErrorMessage('Fotoğraf yüklenemedi: $error');
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera ile çek'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.extraLargePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            'Manuel Sipariş Ekle',
            style: typography.titleLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimens.largePadding),
          TextField(
            controller: _itemsController,
            decoration: InputDecoration(
              labelText: 'Sipariş içeriği',
              hintText: 'Örn: 2x Donut, 1x Kahve',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimens.corners),
              ),
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          GestureDetector(
            onTap: _isUploadingImage ? null : _showImageSourcePicker,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: colors.gray.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(Dimens.corners),
                border: Border.all(color: colors.gray.withValues(alpha: 0.5)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isUploadingImage
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedImagePath == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 18,
                          color: colors.gray4,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sipariş görseli ekle',
                          style: typography.bodyMedium.copyWith(
                            color: colors.gray4,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        buildProductImage(_selectedImagePath!, double.infinity, 100),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          TextField(
            controller: _totalController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Toplam tutar (₺)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimens.corners),
              ),
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          TextField(
            controller: _preparationMinutesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Hazırlanma süresi (dk)',
              hintText: 'Örn: 25',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimens.corners),
              ),
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          DropdownButtonFormField<RestaurantOrderStatus>(
            value: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Durum',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimens.corners),
              ),
            ),
            items: RestaurantOrderStatus.values
                .map(
                  (status) => DropdownMenuItem<RestaurantOrderStatus>(
                    value: status,
                    child: Text(_statusLabel(status)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedStatus = value);
              }
            },
          ),
          const SizedBox(height: Dimens.largePadding),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('Tarih: $_dateLabel'),
                ),
              ),
              const SizedBox(width: Dimens.padding),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time_outlined, size: 18),
                  label: Text('Saat: $_timeLabel'),
                ),
              ),
            ],
          ),
            const SizedBox(height: Dimens.extraLargePadding),
            FilledButton(
              onPressed: _isSaving ? null : _handleSave,
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Sipariş Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  const _TabWithBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.theme.appColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.status,
    required this.tabController,
  });

  final List<RestaurantOrderModel> orders;
  final RestaurantOrderStatus status;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    final emptyTitle = status == RestaurantOrderStatus.rejected
        ? 'Henüz reddedilen sipariş yok'
        : 'Henüz sipariş yok';

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<RestaurantOrdersCubit>().loadOrders(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Icon(Icons.receipt_long_outlined, size: 64, color: colors.gray4),
            const SizedBox(height: Dimens.largePadding),
            Center(
              child: Text(
                emptyTitle,
                style: typography.bodyLarge.copyWith(color: colors.gray4),
              ),
            ),
            const SizedBox(height: Dimens.padding),
            Center(
              child: Text(
                'Aşağı çekerek yenileyin',
                style: typography.bodySmall.copyWith(color: colors.gray4),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<RestaurantOrdersCubit>().loadOrders(),
      child: ListView.separated(
      padding: const EdgeInsets.all(Dimens.largePadding),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: Dimens.largePadding),
      itemBuilder: (context, index) {
        final order = orders[index];
        final accent = _statusColor(status);
        return Container(
          padding: const EdgeInsets.all(Dimens.largePadding),
          decoration: BoxDecoration(
            color: colors.white,
            borderRadius: BorderRadius.circular(Dimens.corners),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Dimens.corners),
                child: order.imagePath.isNotEmpty
                    ? Image.network(
                        order.imagePath,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      )
                    : Assets.images.logo.image(
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: Dimens.largePadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            order.items,
                            style: typography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Dimens.padding),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimens.padding,
                            vertical: Dimens.smallPadding,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            formatPrice(order.total),
                            style: typography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimens.padding),
                    Row(
                      children: [
                        _EtaChip(
                          status: status,
                          preparationMinutes: order.preparationMinutes,
                        ),
                        const SizedBox(width: Dimens.padding),
                        _ProgressChip(status: status),
                      ],
                    ),
                    if (status == RestaurantOrderStatus.rejected &&
                        (order.rejectionReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: Dimens.padding),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Dimens.padding),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(Dimens.corners),
                          border: Border.all(
                            color: colors.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reddetme nedeni',
                              style: typography.labelSmall.copyWith(
                                color: colors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.rejectionReason!,
                              style: typography.bodySmall.copyWith(
                                color: colors.gray4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (status == RestaurantOrderStatus.completed) ...[
                      const SizedBox(height: Dimens.padding),
                      _CourierAssignmentBlock(order: order),
                    ],
                    if (status != RestaurantOrderStatus.completed &&
                        status != RestaurantOrderStatus.rejected) ...[
                      const SizedBox(height: Dimens.padding),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 320;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  spacing: Dimens.padding,
                                  runSpacing: Dimens.padding,
                                  children: _buildActionButtons(
                                    context,
                                    order,
                                    status,
                                    tabController,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Wrap(
                            spacing: Dimens.padding,
                            runSpacing: Dimens.padding,
                            alignment: WrapAlignment.end,
                            children: _buildActionButtons(
                              context,
                              order,
                              status,
                              tabController,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: Dimens.padding),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.time,
                                style: typography.bodySmall.copyWith(
                                  color: colors.gray4,
                                ),
                              ),
                              if (order.date.isNotEmpty)
                                Text(
                                  order.date,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.gray4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          _statusText(order, status),
                          style: typography.labelSmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    RestaurantOrderModel order,
    RestaurantOrderStatus status,
    TabController tabController,
  ) {
    final colors = context.theme.appColors;
    final buttonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.largePadding,
        vertical: Dimens.padding,
      ),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (status == RestaurantOrderStatus.pending) {
      return [
        FilledButton(
          onPressed: () {
            context.read<RestaurantOrdersCubit>().acceptOrder(order.id);
            tabController.animateTo(1);
            context.showSuccessMessage('Sipariş #${order.id} kabul edildi');
          },
          style: buttonStyle.copyWith(
            backgroundColor: WidgetStateProperty.all(colors.success),
          ),
          child: const Text('Kabul'),
        ),
        FilledButton(
          onPressed: () async {
            final reason = await showRejectionReasonDialog(
              context,
              orderId: order.id,
            );
            if (reason == null || reason.trim().isEmpty) {
              return;
            }

            await context.read<RestaurantOrdersCubit>().rejectOrderWithReason(
              order.id,
              rejectionReason: reason,
            );
            if (!context.mounted) {
              return;
            }
            tabController.animateTo(3);
            context.showSuccessMessage(
              'Sipariş #${order.id} reddedildi; Reddedilenler sekmesinde listelenir.',
            );
          },
          style: buttonStyle.copyWith(
            backgroundColor: WidgetStateProperty.all(colors.error),
          ),
          child: const Text('Reddet'),
        ),
      ];
    }
    if (status == RestaurantOrderStatus.preparing) {
      return [
        FilledButton(
          onPressed: () {
            context.read<RestaurantOrdersCubit>().markReady(order.id);
            tabController.animateTo(2);
            context.showSuccessMessage('Sipariş #${order.id} hazır');
          },
          style: buttonStyle,
          child: const Text('Hazır'),
        ),
      ];
    }
    return [];
  }

  Color _statusColor(RestaurantOrderStatus s) {
    switch (s) {
      case RestaurantOrderStatus.pending:
        return const Color(0xFFFFA726);
      case RestaurantOrderStatus.preparing:
        return const Color(0xFF42A5F5);
      case RestaurantOrderStatus.completed:
        return const Color(0xFF66BB6A);
      case RestaurantOrderStatus.rejected:
        return const Color(0xFFEF5350);
    }
  }

  String _statusText(RestaurantOrderModel order, RestaurantOrderStatus s) {
    final fs = order.fulfillmentStatus?.toLowerCase();
    if (s == RestaurantOrderStatus.completed && fs != null && fs.isNotEmpty) {
      switch (fs) {
        case 'delivered':
          return 'Teslim edildi';
        case 'intransit':
        case 'in_transit':
          return 'Kurye yolda';
        case 'assigned':
          return 'Teslimata hazır';
        case 'awaitingcourierreassignment':
        case 'awaiting_courier_reassignment':
          return 'Yeni kurye bekleniyor';
        case 'preparing':
          return 'Hazırlanıyor';
        case 'pending':
          return 'Bekliyor';
        case 'cancelled':
          return 'İptal';
      }
    }
    switch (s) {
      case RestaurantOrderStatus.pending:
        return 'Bekliyor';
      case RestaurantOrderStatus.preparing:
        return 'Hazırlanıyor';
      case RestaurantOrderStatus.completed:
        return 'Tamamlandı';
      case RestaurantOrderStatus.rejected:
        return 'Reddedildi';
    }
  }
}

class _EtaChip extends StatelessWidget {
  const _EtaChip({required this.status, this.preparationMinutes});

  final RestaurantOrderStatus status;
  final int? preparationMinutes;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final eta = preparationMinutes ?? _estimateMinutes(status);
    if (eta == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.padding,
        vertical: Dimens.smallPadding,
      ),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Tahmini $eta dk',
        style: typography.labelSmall.copyWith(
          color: colors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  int? _estimateMinutes(RestaurantOrderStatus status) {
    switch (status) {
      case RestaurantOrderStatus.pending:
        return 25;
      case RestaurantOrderStatus.preparing:
        return 15;
      case RestaurantOrderStatus.completed:
      case RestaurantOrderStatus.rejected:
        return null;
    }
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.status});

  final RestaurantOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final percent = _progressFor(status);
    if (percent == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.padding,
        vertical: Dimens.smallPadding,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Hazırlanıyor %$percent',
        style: typography.labelSmall.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  int? _progressFor(RestaurantOrderStatus status) {
    switch (status) {
      case RestaurantOrderStatus.pending:
        return 20;
      case RestaurantOrderStatus.preparing:
        return 70;
      case RestaurantOrderStatus.completed:
      case RestaurantOrderStatus.rejected:
        return null;
    }
  }
}

class _CourierAssignmentBlock extends StatelessWidget {
  const _CourierAssignmentBlock({required this.order});

  final RestaurantOrderModel order;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final hasCourier = (order.assignedCourierUserId ?? '').isNotEmpty;
    final subtitle = order.assignedCourierName ??
        (hasCourier && order.assignedCourierUserId!.length >= 8
            ? 'Kurye #${order.assignedCourierUserId!.substring(0, 8)}'
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.courierReassignmentRequired) ...[
          Container(
            padding: const EdgeInsets.all(Dimens.padding),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Dimens.corners),
              border: Border.all(
                color: colors.error.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: colors.error, size: 24),
                const SizedBox(width: Dimens.padding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kurye iptal etti, yeni kurye atayın',
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.error,
                        ),
                      ),
                      if ((order.courierReleaseReason ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          order.courierReleaseReason!.trim(),
                          style: typography.bodySmall.copyWith(color: colors.gray4),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimens.padding),
        ],
        if (hasCourier && subtitle != null)
          Container(
            padding: const EdgeInsets.all(Dimens.padding),
            decoration: BoxDecoration(
              color: colors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimens.corners),
              border: Border.all(
                color: colors.secondary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.delivery_dining_outlined,
                  color: colors.secondary,
                  size: 24,
                ),
                const SizedBox(width: Dimens.padding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atanan kurye',
                        style: typography.labelSmall.copyWith(
                          color: colors.gray4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            order.canAssignCourier
                ? 'Teslimat için kurye seçin.'
                : 'Bu sipariş için kurye ataması kapalı.',
            style: typography.bodySmall.copyWith(color: colors.gray4),
          ),
        if (!order.canAssignCourier &&
            (order.fulfillmentStatus?.toLowerCase() == 'delivered')) ...[
          const SizedBox(height: Dimens.smallPadding),
          Text(
            'Teslim tamamlandığı için kurye değiştirilemez.',
            style: typography.bodySmall.copyWith(
              color: colors.gray4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (!order.canAssignCourier &&
            (order.fulfillmentStatus?.toLowerCase() == 'intransit')) ...[
          const SizedBox(height: Dimens.smallPadding),
          Text(
            'Sipariş yoldayken kurye değiştirilemez.',
            style: typography.bodySmall.copyWith(
              color: colors.gray4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (order.canAssignCourier) ...[
          const SizedBox(height: Dimens.padding),
          OutlinedButton.icon(
            onPressed: () => showCourierAssignmentSheet(context, order: order),
            icon: const Icon(Icons.local_shipping_outlined, size: 20),
            label: Text(hasCourier ? 'Kuryeyi değiştir' : 'Kurye ata'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.largePadding,
                vertical: Dimens.padding,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CourierPickerBody extends StatefulWidget {
  const _CourierPickerBody({
    required this.order,
    required this.couriers,
  });

  final RestaurantOrderModel order;
  final List<CourierAccountModel> couriers;

  @override
  State<_CourierPickerBody> createState() => _CourierPickerBodyState();
}

class _CourierPickerBodyState extends State<_CourierPickerBody> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    final existing = widget.order.assignedCourierUserId;
    if (existing != null &&
        widget.couriers.any((c) => c.id == existing)) {
      _selectedId = existing;
    } else if (widget.couriers.isNotEmpty) {
      _selectedId = widget.couriers.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;
    final listHeight = MediaQuery.of(context).size.height * 0.42;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kurye seçin',
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Dimens.smallPadding),
          Text(
            'Sipariş #${widget.order.id} hangi kurye hesabına teslim edilecek?',
            style: typography.bodySmall.copyWith(color: colors.gray4),
          ),
          const SizedBox(height: Dimens.largePadding),
          SizedBox(
            height: listHeight,
            child: ListView(
              children: widget.couriers.map((c) {
                return RadioListTile<String>(
                  value: c.id,
                  groupValue: _selectedId,
                  onChanged: (v) => setState(() => _selectedId = v),
                  title: Text(c.fullName),
                  subtitle:
                      (c.phone != null && c.phone!.trim().isNotEmpty)
                          ? Text(c.phone!)
                          : (c.email != null && c.email!.trim().isNotEmpty)
                          ? Text(c.email!)
                          : null,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç'),
                ),
              ),
              const SizedBox(width: Dimens.padding),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedId == null
                      ? null
                      : () => Navigator.pop(context, _selectedId),
                  child: const Text('Ata'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
