import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/menu_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_menu_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/utils/image_picker_helper.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

const _kCategoryOptions = [
  'Pastalar',
  'Kapkek',
  'Donut',
  'Hamur işi',
  'Tatlı',
  'Kurabiye',
  'İçecek',
];

class RestaurantOwnerMenuScreen extends StatefulWidget {
  const RestaurantOwnerMenuScreen({super.key});

  @override
  State<RestaurantOwnerMenuScreen> createState() =>
      _RestaurantOwnerMenuScreenState();
}

class _RestaurantOwnerMenuScreenState extends State<RestaurantOwnerMenuScreen> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Menü Yönetimi',
        showBackIcon: false,
        actions: [
          IconButton(
            onPressed: () => _showAddProductSheet(context),
            icon: Icon(Icons.add_circle, color: colors.primary, size: 28),
          ),
          const SizedBox(width: Dimens.padding),
        ],
      ),
      body: BlocBuilder<RestaurantMenuCubit, List<MenuItemModel>>(
        builder: (context, menuItems) {
          final categories = _buildCategories(menuItems);
          if (_selectedCategoryIndex >= categories.length) {
            _selectedCategoryIndex = 0;
          }
          final selected = categories[_selectedCategoryIndex];
          final filtered =
              selected.categoryName == null
                  ? menuItems
                  : menuItems
                      .where((item) => _matchesCategory(item, selected))
                      .toList();
          if (menuItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: colors.gray4),
                  const SizedBox(height: Dimens.largePadding),
                  Text(
                    'Henüz ürün yok',
                    style: context.theme.appTypography.bodyLarge.copyWith(
                      color: colors.gray4,
                    ),
                  ),
                  const SizedBox(height: Dimens.largePadding),
                  AppButton(
                    title: 'Ürün Ekle',
                    onPressed: () => _showAddProductSheet(context),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (categories.length > 1)
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.largePadding,
                      vertical: Dimens.padding,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder:
                        (_, __) => const SizedBox(width: Dimens.padding),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = index == _selectedCategoryIndex;
                      return ChoiceChip(
                        label: Text(category.label),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedCategoryIndex = index);
                        },
                        selectedColor: colors.primary.withValues(alpha: 0.16),
                        backgroundColor: colors.gray.withValues(alpha: 0.1),
                        labelStyle: context.theme.appTypography.labelSmall
                            .copyWith(
                              color: isSelected ? colors.primary : colors.gray4,
                              fontWeight: FontWeight.w600,
                            ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(Dimens.largePadding),
                  itemCount: filtered.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: Dimens.largePadding),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _MenuItemCard(
                      item: item,
                      onEdit: () => _showEditProductSheet(context, item),
                      onToggle: () {
                        context
                            .read<RestaurantMenuCubit>()
                            .toggleAvailabilityRemote(
                              item.id,
                              item.isAvailable,
                            );
                        context.showSuccessMessage(
                          item.isAvailable
                              ? '"${item.name}" pasife alındı'
                              : '"${item.name}" aktife alındı',
                        );
                      },
                      onDelete: () => _confirmDeleteItem(context, item),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_MenuCategory> _buildCategories(List<MenuItemModel> items) {
    const all = _MenuCategory(label: 'Tümü', categoryName: null);
    final usedCategories = items
        .where((item) => item.categoryName != null && item.categoryName!.isNotEmpty)
        .map((item) => item.categoryName!)
        .toSet();
    final categoryList = [
      all,
      ..._kCategoryOptions
          .where((c) => usedCategories.contains(c))
          .map((c) => _MenuCategory(label: c, categoryName: c)),
    ];
    return categoryList.length > 1 ? categoryList : [all];
  }

  bool _matchesCategory(MenuItemModel item, _MenuCategory category) {
    if (category.categoryName == null) return true;
    return item.categoryName?.toLowerCase() == category.categoryName?.toLowerCase();
  }

  void _showAddProductSheet(BuildContext context) {
    final screenContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (modalContext) => _ProductFormSheet(
            title: 'Yeni Ürün Ekle',
            onSave: (name, price, imagePath, categoryName, isFeatured, saleUnit) async {
              final cubit = screenContext.read<RestaurantMenuCubit>();
              await cubit.addMenuItem(
                name: name,
                price: price,
                imagePath: imagePath ?? _kPhotoRemoved,
                categoryName: categoryName,
                isFeatured: isFeatured,
                saleUnit: saleUnit,
              );
            },
          ),
    );
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    MenuItemModel item,
  ) async {
    final shouldDelete = await AppConfirmDialog.show(
      context,
      title: 'Urunu Sil',
      message: '"${item.name}" urununu silmek istediginize emin misiniz?',
      cancelText: 'Iptal',
      confirmText: 'Sil',
      isDestructive: true,
    );
    if (shouldDelete == true && context.mounted) {
      context.read<RestaurantMenuCubit>().deleteMenuItemRemote(item.id);
    }
  }

  void _showEditProductSheet(BuildContext context, MenuItemModel item) {
    final screenContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (modalContext) => _ProductFormSheet(
            title: 'Ürünü Düzenle',
            initialName: item.name,
            initialPrice: item.price,
            initialImagePath: item.imagePath,
            initialCategoryName: item.categoryName,
            initialIsFeatured: item.isFeatured,
            initialSaleUnit: item.saleUnit,
            onSave: (name, price, imagePath, categoryName, isFeatured, saleUnit) async {
              await screenContext.read<RestaurantMenuCubit>().updateMenuItemRemote(
                item.id,
                name: name,
                price: price,
                imagePath: imagePath,
                categoryName: categoryName,
                isFeatured: isFeatured,
                saleUnit: saleUnit,
              );
            },
          ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final accent = item.isAvailable ? colors.success : colors.error;
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(Dimens.corners),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.corners),
            child: buildProductImage(item.imagePath, 82, 82),
          ),
          const SizedBox(width: Dimens.largePadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: typography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: item.isAvailable ? colors.black : colors.gray4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isFeatured) ...[
                      const SizedBox(width: Dimens.smallPadding),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimens.smallPadding,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 12, color: colors.secondary),
                            const SizedBox(width: 4),
                            Text(
                              'Öne Çıkan',
                              style: typography.labelSmall.copyWith(
                                color: colors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Dimens.smallPadding),
                Row(
                  children: [
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
                        formatPrice(item.price),
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimens.smallPadding),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimens.padding,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.gray2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.saleUnit == 1 ? 'Dilim' : 'Kilo',
                        style: typography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.gray4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.padding,
                      vertical: Dimens.smallPadding,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.isAvailable ? 'Aktif' : 'Pasif',
                          style: typography.labelSmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.isAvailable) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.circle, size: 7, color: accent),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'İşlemler',
                    splashRadius: 18,
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                        return;
                      }
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: colors.gray4,
                                ),
                                const SizedBox(width: 8),
                                const Text('Düzenle'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sil',
                                  style: TextStyle(color: colors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                    icon: Icon(Icons.more_horiz, color: colors.gray4),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.padding),
              Transform.scale(
                scale: 0.8,
                child: CupertinoSwitch(
                  value: item.isAvailable,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: colors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuCategory {
  const _MenuCategory({required this.label, required this.categoryName});

  final String label;
  final String? categoryName;
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({
    required this.title,
    required this.onSave,
    this.initialName,
    this.initialPrice,
    this.initialImagePath,
    this.initialCategoryName,
    this.initialIsFeatured = false,
    this.initialSaleUnit = 0,
  });

  final String title;
  final Future<void> Function(
    String name,
    int price,
    String? imagePath,
    String? categoryName,
    bool isFeatured,
    int saleUnit,
  )
  onSave;
  final String? initialName;
  final int? initialPrice;
  final String? initialImagePath;
  final String? initialCategoryName;
  final bool initialIsFeatured;
  final int initialSaleUnit;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

/// Boş string = kullanıcı fotoğrafı kaldırdı, null = değişmedi
const String _kPhotoRemoved = '';

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  String? _pickedImagePath;
  String? _selectedCategory;
  bool _isFeatured = false;
  int _saleUnit = 0;
  bool _isSaving = false;
  late final RestaurantOwnerService _service;
  late final String _ownerUserId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _priceController = TextEditingController(
      text: widget.initialPrice?.toString() ?? '',
    );
    _pickedImagePath = widget.initialImagePath;
    _selectedCategory = widget.initialCategoryName;
    _isFeatured = widget.initialIsFeatured;
    _saleUnit = widget.initialSaleUnit == 1 ? 1 : 0;
    _ownerUserId = AppSession.userId;
    _service = RestaurantOwnerService(authService: AuthService());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await pickAndSaveImage(source);
      if (file != null && mounted) {
        final uploaded = await _service.uploadMenuImage(
          ownerUserId: _ownerUserId,
          filePath: file.path,
          fileBytes: await file.readAsBytes(),
          fileName: file.name,
        );
        setState(() {
          _pickedImagePath = uploaded;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showErrorMessage('Fotoğraf yüklenemedi: $e');
      }
    }
  }

  /// Virgül veya nokta ile ondalıklı girişi kabul eder, kuruşa yuvarlar.
  static int? _parsePriceTry(String raw) {
    final t = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null || d <= 0) return null;
    return d.round().clamp(1, 99999999);
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    final price = _parsePriceTry(_priceController.text);
    if (name.isEmpty) {
      if (mounted) {
        context.showErrorMessage('Ürün adı gerekli.');
      }
      return;
    }
    if (price == null) {
      if (mounted) {
        context.showErrorMessage('Geçerli bir fiyat girin (örn. 50 veya 99,90).');
      }
      return;
    }
    final imagePath =
        _pickedImagePath == _kPhotoRemoved ? _kPhotoRemoved : _pickedImagePath;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        name,
        price,
        imagePath,
        _selectedCategory,
        _isFeatured,
        _saleUnit,
      );
      if (!mounted) return;
      context.showSuccessMessage(
        widget.title.contains('Düzenle') ? 'Ürün güncellendi.' : 'Ürün eklendi.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        var msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.substring(11).trim();
        }
        context.showErrorMessage(msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.extraLargePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.gray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Dimens.extraLargePadding),
              Text(
                widget.title,
                style: typography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Dimens.extraLargePadding),
              Text(
                'Ürün Fotoğrafı',
                style: typography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Dimens.padding),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder:
                        (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Galeriden seç'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickImage(ImageSource.gallery);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Kamera ile çek'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickImage(ImageSource.camera);
                                },
                              ),
                            ],
                          ),
                        ),
                  );
                },
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: colors.gray.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(Dimens.corners),
                    border: Border.all(color: colors.gray),
                  ),
                  child:
                      _pickedImagePath != null &&
                              _pickedImagePath != _kPhotoRemoved
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(Dimens.corners),
                            child: buildProductImage(
                              _pickedImagePath!,
                              double.infinity,
                              140,
                            ),
                          )
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: colors.gray4,
                              ),
                              const SizedBox(height: Dimens.padding),
                              Text(
                                'Fotoğraf eklemek için dokunun',
                                style: typography.bodySmall.copyWith(
                                  color: colors.gray4,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
              if (_pickedImagePath != null &&
                  _pickedImagePath != _kPhotoRemoved)
                Padding(
                  padding: const EdgeInsets.only(top: Dimens.padding),
                  child: TextButton.icon(
                    onPressed:
                        () => setState(() => _pickedImagePath = _kPhotoRemoved),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: colors.error,
                    ),
                    label: Text(
                      'Fotoğrafı kaldır',
                      style: TextStyle(color: colors.error, fontSize: 14),
                    ),
                  ),
                ),
              const SizedBox(height: Dimens.largePadding),
              Text(
                'Kategori',
                style: typography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Dimens.smallPadding),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                  ),
                ),
                hint: const Text('Kategori seçin (örn: Pastalar)'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Kategori yok'),
                  ),
                  ..._kCategoryOptions
                      .map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          )),
                ],
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: Dimens.largePadding),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Ürün Adı',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                  ),
                ),
              ),
              const SizedBox(height: Dimens.largePadding),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Fiyat (₺)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                  ),
                ),
              ),
              const SizedBox(height: Dimens.largePadding),
              Text(
                'Satış birimi',
                style: typography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Dimens.smallPadding),
              Text(
                'Fiyatın kg başına mı, dilim başına mı olduğunu seçin.',
                style: typography.bodySmall.copyWith(color: colors.gray4),
              ),
              const SizedBox(height: Dimens.padding),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Kilogram'),
                      selected: _saleUnit == 0,
                      onSelected: (_) => setState(() => _saleUnit = 0),
                      selectedColor: colors.primary.withValues(alpha: 0.2),
                      labelStyle: typography.labelLarge.copyWith(
                        color: _saleUnit == 0 ? colors.primary : colors.gray4,
                        fontWeight:
                            _saleUnit == 0 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.padding),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Dilim'),
                      selected: _saleUnit == 1,
                      onSelected: (_) => setState(() => _saleUnit = 1),
                      selectedColor: colors.primary.withValues(alpha: 0.2),
                      labelStyle: typography.labelLarge.copyWith(
                        color: _saleUnit == 1 ? colors.primary : colors.gray4,
                        fontWeight:
                            _saleUnit == 1 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.largePadding),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.largePadding,
                  vertical: Dimens.padding,
                ),
                decoration: BoxDecoration(
                  color: colors.gray.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Dimens.corners),
                  border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: colors.secondary, size: 18),
                    const SizedBox(width: Dimens.padding),
                    Expanded(
                      child: Text(
                        'Öne çıkar',
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                      inactiveThumbColor: colors.secondary,
                      activeTrackColor: colors.secondary.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Dimens.extraLargePadding),
              AppButton(
                title: _isSaving ? 'Kaydediliyor...' : 'Kaydet',
                onPressed: _isSaving ? null : () => _handleSave(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
