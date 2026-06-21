import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/address_with_coords.dart';
import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/check_theme_status.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_list_tile.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/theme_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/splash_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_settings_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/user_profile_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/penalty_points_summary_card.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/utils/image_picker_helper.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/screens/address_search_screen.dart';

class RestaurantOwnerSettingsScreen extends StatefulWidget {
  const RestaurantOwnerSettingsScreen({super.key});

  @override
  State<RestaurantOwnerSettingsScreen> createState() =>
      _RestaurantOwnerSettingsScreenState();
}

class _RestaurantOwnerSettingsScreenState
    extends State<RestaurantOwnerSettingsScreen> {
  bool _didAutoFill = false;
  int? _accountPenaltyPoints;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccountPenaltyPoints());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didAutoFill) return;
      _didAutoFill = true;
      _autoFillAddressIfNeeded();
    });
  }

  Future<void> _autoFillAddressIfNeeded() async {
    final cubit = context.read<RestaurantSettingsCubit>();
    try {
      await cubit.autoFillAddressFromGoogle();
      if (!mounted) return;
      // Don't show success message here - let user manually select address
    } catch (e) {
      if (!mounted) return;
      // Only show error if it's a critical failure, otherwise let user select manually
      if (kDebugMode) {
        print('Auto-fill failed: $e');
      }
    }
  }

  Future<void> _loadAccountPenaltyPoints() async {
    final uid = AppSession.userId;
    if (uid.isEmpty) {
      return;
    }
    try {
      final profile = await UserProfileService().getProfile(userId: uid);
      if (!mounted) {
        return;
      }
      AppSession.updateNotificationEnabled(profile.notificationEnabled);
      await NotificationService.instance.syncLocalCacheFromServer(
        profile.notificationEnabled,
      );
      setState(() => _accountPenaltyPoints = profile.totalPenaltyPoints);
    } catch (_) {
      // Profil uçları kapalıysa veya ağ hatası: ceza kartını göstermeyiz.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return BlocBuilder<RestaurantSettingsCubit, RestaurantSettingsState>(
      builder: (context, settings) {
        return AppScaffold(
          appBar: GeneralAppBar(title: 'Pastane Ayarları', showBackIcon: false),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Dimens.largePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(Dimens.largePadding),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.18),
                        colors.secondary.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _RestaurantPhotoPicker(
                        photoPath: settings.restaurantPhotoPath,
                        onPhotoChanged: (path) async {
                          try {
                            await context
                                .read<RestaurantSettingsCubit>()
                                .setRestaurantPhoto(path);
                            if (!context.mounted) return;
                            _showSuccess(
                              context,
                              path != null && path.isNotEmpty
                                  ? 'Pastane fotoğrafı güncellendi'
                                  : 'Pastane fotoğrafı kaldırıldı',
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            _showError(context, e.toString());
                          }
                        },
                      ),
                      const SizedBox(width: Dimens.largePadding),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              settings.restaurantName,
                              style: typography.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: Dimens.smallPadding),
                            Text(
                              settings.restaurantType,
                              style: typography.bodySmall.copyWith(
                                color: colors.gray4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: Dimens.padding),
                            _StarRatingDisplay(
                              rating: settings.rating,
                              reviewCount: settings.reviewCount,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_accountPenaltyPoints != null) ...[
                  const SizedBox(height: Dimens.largePadding),
                  PenaltyPointsSummaryCard(points: _accountPenaltyPoints!),
                ],
                const SizedBox(height: Dimens.extraLargePadding),
                _SectionHeader(
                  title: 'Pastane Bilgileri',
                  subtitle: 'Görünür bilgilerinizi düzenleyin',
                ),
                const SizedBox(height: Dimens.largePadding),
                BorderedContainer(
                  child: Column(
                    children: [
                      _SettingsListTile(
                        title: 'Pastane adı',
                        value: settings.restaurantName,
                        iconPath: Assets.icons.shop,
                        onTap:
                            () => _showEditFieldSheet(
                              context,
                              'Pastane adı',
                              settings.restaurantName,
                              (v) async {
                                await context
                                    .read<RestaurantSettingsCubit>()
                                    .setRestaurantName(v);
                                if (!context.mounted) return;
                                _showSuccess(
                                  context,
                                  'Pastane adı güncellendi',
                                );
                              },
                            ),
                      ),
                      _SettingsListTile(
                        title: 'Pastane türü',
                        value: settings.restaurantType,
                        iconPath: Assets.icons.category,
                        onTap:
                            () => _showEditFieldSheet(
                              context,
                              'Pastane türü',
                              settings.restaurantType,
                              (v) async {
                                await context
                                    .read<RestaurantSettingsCubit>()
                                    .setRestaurantType(v);
                                if (!context.mounted) return;
                                _showSuccess(
                                  context,
                                  'Pastane türü güncellendi',
                                );
                              },
                            ),
                      ),
                      _SettingsListTile(
                        title: 'Adres',
                        value: settings.address,
                        iconPath: Assets.icons.location,
                        onTap: () => _showAddressSearchSheet(context),
                      ),
                      _SettingsListTile(
                        title: 'Telefon',
                        value: settings.phone,
                        iconPath: Assets.icons.call,
                        onTap:
                            () => _showEditPhoneSheet(context, settings.phone),
                      ),
                      _SettingsListTile(
                        title: 'Çalışma saatleri',
                        value: settings.workingHours,
                        iconPath: Assets.icons.clock,
                        onTap:
                            () => _showEditFieldSheet(
                              context,
                              'Çalışma saatleri',
                              settings.workingHours,
                              (v) async {
                                await context
                                    .read<RestaurantSettingsCubit>()
                                    .setWorkingHours(v);
                                if (!context.mounted) return;
                                _showSuccess(
                                  context,
                                  'Çalışma saatleri güncellendi',
                                );
                              },
                            ),
                      ),
                      _SettingsListTile(
                        title: 'Değerlendirmeler',
                        value:
                            '${settings.rating} ⭐ · ${settings.reviewCount} yorum',
                        iconPath: Assets.icons.star,
                        onTap: () => _showReviewsSheet(context, settings),
                      ),
                      const SizedBox(height: Dimens.smallPadding),
                    ],
                  ),
                ),
                const SizedBox(height: Dimens.extraLargePadding),
                _SectionHeader(
                  title: 'Bildirimler',
                  subtitle: 'Siparişleri anlık takip edin',
                ),
                const SizedBox(height: Dimens.largePadding),
                BorderedContainer(
                  child: Column(
                    children: [
                      AppListTile(
                        onTap: () {
                          context.read<RestaurantSettingsCubit>().setIsOpen(
                            !settings.isOpen,
                          );
                          _showSuccess(
                            context,
                            settings.isOpen
                                ? 'Pastane kapalı olarak işaretlendi'
                                : 'Pastane açıldı',
                          );
                        },
                        title: 'Pastane durumu',
                        leadingIconPath: Assets.icons.shop,
                        trailing: Transform.scale(
                          scale: 0.7,
                          child: CupertinoSwitch(
                            value: settings.isOpen,
                            onChanged: (v) {
                              context.read<RestaurantSettingsCubit>().setIsOpen(
                                v,
                              );
                              _showSuccess(
                                context,
                                v
                                    ? 'Pastane açıldı'
                                    : 'Pastane kapalı olarak işaretlendi',
                              );
                            },
                            activeTrackColor: colors.primary,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: Dimens.smallPadding),
                      AppListTile(
                        onTap: () {
                          context
                              .read<RestaurantSettingsCubit>()
                              .setOrderNotifications(
                                !settings.orderNotifications,
                              );
                          _showSuccess(
                            context,
                            settings.orderNotifications
                                ? 'Sipariş bildirimleri kapatıldı'
                                : 'Sipariş bildirimleri açıldı',
                          );
                        },
                        title: 'Sipariş bildirimleri',
                        leadingIconPath: Assets.icons.notification,
                        trailing: Transform.scale(
                          scale: 0.7,
                          child: CupertinoSwitch(
                            value: settings.orderNotifications,
                            onChanged: (v) {
                              context
                                  .read<RestaurantSettingsCubit>()
                                  .setOrderNotifications(v);
                              _showSuccess(
                                context,
                                v
                                    ? 'Sipariş bildirimleri açıldı'
                                    : 'Sipariş bildirimleri kapatıldı',
                              );
                            },
                            activeTrackColor: colors.primary,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: Dimens.smallPadding),
                      AppListTile(
                        onTap: () => _showDiscountDialog(context, settings),
                        title: 'Kampanya / İndirim',
                        leadingIconPath: Assets.icons.percentageSquare,
                        trailing:
                            (settings.activeCampaignDisplayText != null &&
                                        settings
                                            .activeCampaignDisplayText!
                                            .isNotEmpty) ||
                                    settings.restaurantDiscountPercent != null
                                ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      settings.activeCampaignDisplayText ??
                                          '%${settings.restaurantDiscountPercent!.toInt()} (${settings.restaurantDiscountApproved ? (settings.restaurantDiscountIsActive ? 'Aktif' : 'Pasif') : 'Onay bekliyor'})',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.gray4,
                                      ),
                                    ),
                                    if (settings
                                        .restaurantDiscountApproved) ...[
                                      const SizedBox(width: 8),
                                      Transform.scale(
                                        scale: 0.8,
                                        child: CupertinoSwitch(
                                          value:
                                              settings
                                                  .restaurantDiscountIsActive,
                                          onChanged: (v) async {
                                            try {
                                              await context
                                                  .read<
                                                    RestaurantSettingsCubit
                                                  >()
                                                  .toggleDiscountActive(v);
                                              if (context.mounted) {
                                                _showSuccess(
                                                  context,
                                                  v
                                                      ? 'İndirim aktifleştirildi.'
                                                      : 'İndirim pasifleştirildi.',
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                _showError(
                                                  context,
                                                  e.toString(),
                                                );
                                              }
                                            }
                                          },
                                          activeTrackColor: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                                : Text(
                                  'Yok',
                                  style: typography.bodySmall.copyWith(
                                    color: colors.gray4,
                                  ),
                                ),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: Dimens.smallPadding),
                    ],
                  ),
                ),
                const SizedBox(height: Dimens.extraLargePadding),
                _SectionHeader(
                  title: 'Görünüm',
                  subtitle: 'Paneli dilediğiniz gibi kullanın',
                ),
                const SizedBox(height: Dimens.largePadding),
                BorderedContainer(
                  child: Column(
                    children: [
                      AppListTile(
                        onTap: () {
                          context.read<ThemeCubit>().toggleTheme();
                        },
                        title: 'Koyu tema',
                        leadingIconPath: Assets.icons.moon,
                        trailing: Transform.scale(
                          scale: 0.7,
                          child: CupertinoSwitch(
                            value: checkDarkMode(context),
                            onChanged: (_) {
                              context.read<ThemeCubit>().toggleTheme();
                            },
                            activeTrackColor: colors.primary,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: Dimens.smallPadding),
                    ],
                  ),
                ),
                const SizedBox(height: Dimens.extraLargePadding),
                _SectionHeader(title: 'Hesap', subtitle: 'Güvenli çıkış yapın'),
                const SizedBox(height: Dimens.largePadding),
                BorderedContainer(
                  child: AppListTile(
                    onTap: () => _handleLogout(context),
                    title: 'Çıkış yap',
                    leadingIconPath: Assets.icons.logout,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.theme.appColors.success,
      ),
    );
  }

  Future<void> _showDiscountDialog(
    BuildContext context,
    RestaurantSettingsState settings,
  ) async {
    final controller = TextEditingController(
      text: settings.restaurantDiscountPercent?.toInt().toString() ?? '',
    );
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Yüzde indirim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tüm ürünlerinize uygulanacak yüzde indirim (0-100). Admin onayından sonra müşterilere yansır.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'İndirim oranı (%)',
                  hintText: 'Örn: 10',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(-1),
              child: const Text('Kaldır'),
            ),
            FilledButton(
              onPressed: () {
                final p = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(p);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    double? value;
    if (result == -1) {
      value = null;
    } else if (result >= 0 && result <= 100) {
      value = result.toDouble();
    } else {
      if (context.mounted)
        _showError(context, 'Geçerli bir oran girin (0-100).');
      return;
    }
    try {
      await context
          .read<RestaurantSettingsCubit>()
          .setRestaurantDiscountPercent(value);
      if (context.mounted) {
        _showSuccess(
          context,
          value != null
              ? '%${value.toInt()} indirim kaydedildi. Admin onayından sonra yansır.'
              : 'İndirim kaldırıldı.',
        );
      }
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.theme.appColors.error,
      ),
    );
  }

  Future<void> _showAddressSearchSheet(BuildContext context) async {
    final selectedAddress = await Navigator.of(context).push<AddressWithCoords>(
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );

    if (!context.mounted) {
      return;
    }

    if (selectedAddress != null && selectedAddress.address.trim().isNotEmpty) {
      try {
        await context.read<RestaurantSettingsCubit>().setAddress(
          selectedAddress.address,
          latitude: selectedAddress.latitude,
          longitude: selectedAddress.longitude,
        );
        if (!context.mounted) return;
        _showSuccess(context, 'Adres başarıyla seçildi ve kaydedildi');
      } catch (e) {
        if (!context.mounted) return;
        _showError(context, e.toString());
      }
    }
  }

  void _showEditFieldSheet(
    BuildContext context,
    String title,
    String initialValue,
    Future<void> Function(String) onSave,
  ) {
    final controller = TextEditingController(text: initialValue);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Dimens.extraLargePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: context.theme.appTypography.titleLarge),
                  const SizedBox(height: Dimens.largePadding),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Dimens.corners),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimens.largePadding),
                  AppButton(
                    title: 'Kaydet',
                    onPressed: () async {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$title boş olamaz'),
                            backgroundColor: context.theme.appColors.error,
                          ),
                        );
                        return;
                      }
                      try {
                        await onSave(value);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        if (!context.mounted) return;
                        _showError(context, e.toString());
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showEditPhoneSheet(BuildContext context, String initialValue) {
    final localDigitsController = TextEditingController(
      text: _extractLocalTurkishPhoneDigits(initialValue),
    );
    String? validationMessage;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (sheetContext, setModalState) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Dimens.extraLargePadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Telefon',
                          style: sheetContext.theme.appTypography.titleLarge,
                        ),
                        const SizedBox(height: Dimens.largePadding),
                        TextField(
                          controller: localDigitsController,
                          autofocus: true,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (_) {
                            if (validationMessage != null) {
                              setModalState(() => validationMessage = null);
                            }
                          },
                          decoration: InputDecoration(
                            prefixText: '+90 ',
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                Dimens.corners,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Dimens.largePadding),
                        AppButton(
                          title: 'Kaydet',
                          onPressed: () async {
                            final localDigits =
                                localDigitsController.text.trim();
                            if (localDigits.isEmpty) {
                              setModalState(
                                () =>
                                    validationMessage =
                                        'Bu alan boş bırakılamaz',
                              );
                              return;
                            }

                            if (localDigits.length < 10) {
                              setModalState(
                                () => validationMessage = 'Eksik girdiniz',
                              );
                              return;
                            }

                            final fullPhone = '+90$localDigits';
                            try {
                              await context
                                  .read<RestaurantSettingsCubit>()
                                  .setPhone(fullPhone);
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              if (!context.mounted) return;
                              _showSuccess(context, 'Telefon güncellendi');
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              setModalState(
                                () => validationMessage = e.toString(),
                              );
                            }
                          },
                        ),
                        if (validationMessage != null) ...[
                          const SizedBox(height: Dimens.padding),
                          Text(
                            validationMessage!,
                            textAlign: TextAlign.center,
                            style: sheetContext.theme.appTypography.bodySmall
                                .copyWith(
                                  color: sheetContext.theme.appColors.error,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  String _extractLocalTurkishPhoneDigits(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '';
    }
    if (digits.length >= 12 && digits.startsWith('90')) {
      return digits.substring(2, 12);
    }
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  void _showReviewsSheet(
    BuildContext context,
    RestaurantSettingsState settings,
  ) {
    final cubit = context.read<RestaurantSettingsCubit>();
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (modalContext) => BlocProvider.value(
            value: cubit,
            child: DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder:
                  (_, scrollController) => BlocBuilder<
                    RestaurantSettingsCubit,
                    RestaurantSettingsState
                  >(
                    builder:
                        (ctx, state) => _ReviewsSheetContent(
                          settings: state,
                          scrollController: scrollController,
                          onReplyTap:
                              (index, initialReply) => _showReplySheet(
                                parentContext,
                                modalContext,
                                cubit,
                                index,
                                initialReply,
                              ),
                        ),
                  ),
            ),
          ),
    );
  }

  void _showReplySheet(
    BuildContext parentContext,
    BuildContext modalContext,
    RestaurantSettingsCubit cubit,
    int reviewIndex,
    String? initialReply,
  ) {
    final controller = TextEditingController(text: initialReply ?? '');
    showModalBottomSheet(
      context: modalContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Dimens.extraLargePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Yanıt yaz',
                    style: parentContext.theme.appTypography.titleLarge,
                  ),
                  const SizedBox(height: Dimens.largePadding),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Müşteriye yanıtınızı yazın...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Dimens.corners),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimens.largePadding),
                  AppButton(
                    title: 'Gönder',
                    onPressed: () {
                      final reply = controller.text.trim();
                      cubit.setReplyToReview(reviewIndex, reply);
                      Navigator.pop(ctx);
                      _showSuccess(parentContext, 'Yanıtınız gönderildi');
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await AppConfirmDialog.show(
      context,
      title: 'Çıkış Yap',
      message: 'Çıkış yapmak istediginize emin misiniz?',
      cancelText: 'Vazgeç',
      confirmText: 'Çıkış',
      isDestructive: true,
    );
    if (shouldLogout == true && context.mounted) {
      appPushReplacement(context, const SplashScreen());
    }
  }
}

class _RestaurantPhotoPicker extends StatefulWidget {
  const _RestaurantPhotoPicker({
    required this.photoPath,
    required this.onPhotoChanged,
  });

  final String? photoPath;
  final Future<void> Function(String? path) onPhotoChanged;

  @override
  State<_RestaurantPhotoPicker> createState() => _RestaurantPhotoPickerState();
}

class _RestaurantPhotoPickerState extends State<_RestaurantPhotoPicker> {
  late final RestaurantOwnerService _service;
  late final String _ownerUserId;

  @override
  void initState() {
    super.initState();
    _ownerUserId = AppSession.userId;
    _service = RestaurantOwnerService(authService: AuthService());
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await pickAndSaveImage(source);
      if (file != null && mounted) {
        final uploaded = await _service.uploadRestaurantPhoto(
          ownerUserId: _ownerUserId,
          filePath: file.path,
          fileBytes: await file.readAsBytes(),
          fileName: file.name,
        );
        await widget.onPhotoChanged(uploaded);
      }
    } catch (e) {
      if (mounted) {
        final message =
            e is AuthException ? e.message : 'Fotoğraf yüklenemedi: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final hasPhoto = widget.photoPath != null && widget.photoPath!.isNotEmpty;

    return GestureDetector(
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
                    if (hasPhoto)
                      ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: colors.error,
                        ),
                        title: Text(
                          'Fotoğrafı kaldır',
                          style: TextStyle(color: colors.error),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await widget.onPhotoChanged('');
                        },
                      ),
                  ],
                ),
              ),
        );
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.corners),
            child: SizedBox(
              width: 80,
              height: 80,
              child:
                  hasPhoto
                      ? buildProductImage(widget.photoPath!, 80, 80)
                      : Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.gray.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.camera_alt, color: colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRatingDisplay extends StatelessWidget {
  const _StarRatingDisplay({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Row(
      children: [
        ...List.generate(5, (i) {
          final starValue = i + 1.0;
          final filled = rating >= starValue;
          final half = rating >= starValue - 0.5 && rating < starValue;
          return Icon(
            filled ? Icons.star : (half ? Icons.star_half : Icons.star_border),
            color: colors.primary,
            size: 18,
          );
        }),
        const SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(1)} ($reviewCount değerlendirme)',
          style: typography.labelSmall.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ReviewsSheetContent extends StatelessWidget {
  const _ReviewsSheetContent({
    required this.settings,
    required this.scrollController,
    required this.onReplyTap,
  });

  final RestaurantSettingsState settings;
  final ScrollController scrollController;
  final void Function(int index, String? initialReply) onReplyTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final total = settings.ratingDistribution.values.fold<int>(
      0,
      (a, b) => a + b,
    );
    final maxCount =
        settings.ratingDistribution.values.isEmpty
            ? 1
            : settings.ratingDistribution.values.reduce(
              (a, b) => a > b ? a : b,
            );

    return Column(
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: Dimens.padding),
            decoration: BoxDecoration(
              color: colors.gray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Dimens.extraLargePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Değerlendirmeler',
                style: typography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Dimens.extraLargePadding),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Text(
                        settings.rating.toStringAsFixed(1),
                        style: typography.headlineLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) {
                          final starValue = i + 1.0;
                          final filled = settings.rating >= starValue;
                          final half =
                              settings.rating >= starValue - 0.5 &&
                              settings.rating < starValue;
                          return Icon(
                            filled
                                ? Icons.star
                                : (half ? Icons.star_half : Icons.star_border),
                            color: colors.primary,
                            size: 16,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total değerlendirme',
                        style: typography.bodySmall.copyWith(
                          color: colors.gray4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: Dimens.extraLargePadding),
                  Expanded(
                    child: Column(
                      children:
                          [5, 4, 3, 2, 1].map((star) {
                            final count =
                                settings.ratingDistribution[star] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                    '$star',
                                    style: typography.bodySmall.copyWith(
                                      color: colors.gray4,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value:
                                            maxCount > 0 ? count / maxCount : 0,
                                        minHeight: 6,
                                        backgroundColor: colors.gray.withValues(
                                          alpha: 0.3,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              colors.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$count',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.gray4,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.extraLargePadding),
              Text(
                'Son değerlendirmeler',
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Dimens.largePadding),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.extraLargePadding,
            ),
            itemCount: settings.reviews.length,
            separatorBuilder:
                (_, __) => const SizedBox(height: Dimens.largePadding),
            itemBuilder: (context, index) {
              final review = settings.reviews[index];
              return _ReviewCard(
                review: review,
                onReplyTap: () => onReplyTap(index, review.ownerReply),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReplyTap});

  final RestaurantReview review;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return BorderedContainer(
      padding: const EdgeInsets.all(Dimens.largePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primary.withValues(alpha: 0.2),
                child: Text(
                  review.customerName.isNotEmpty
                      ? review.customerName[0].toUpperCase()
                      : '?',
                  style: typography.labelMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: Dimens.padding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      review.date,
                      style: typography.bodySmall.copyWith(color: colors.gray4),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = review.rating >= (i + 1);
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: colors.primary,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: Dimens.padding),
          Text(
            review.comment,
            style: typography.bodyMedium.copyWith(color: colors.gray4),
          ),
          if (review.ownerReply != null && review.ownerReply!.isNotEmpty) ...[
            const SizedBox(height: Dimens.padding),
            Container(
              padding: const EdgeInsets.all(Dimens.padding),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Dimens.corners),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply, size: 16, color: colors.primary),
                  const SizedBox(width: Dimens.padding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yanıtınız',
                          style: typography.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.ownerReply!,
                          style: typography.bodySmall.copyWith(
                            color: colors.gray4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Dimens.padding),
          TextButton.icon(
            onPressed: onReplyTap,
            icon: Icon(
              review.ownerReply != null && review.ownerReply!.isNotEmpty
                  ? Icons.edit
                  : Icons.reply,
              size: 18,
              color: colors.primary,
            ),
            label: Text(
              review.ownerReply != null && review.ownerReply!.isNotEmpty
                  ? 'Yanıtı düzenle'
                  : 'Yanıt yaz',
              style: typography.labelMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    required this.title,
    required this.value,
    required this.iconPath,
    required this.onTap,
  });

  final String title;
  final String value;
  final String iconPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Dimens.largePadding),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              AppSvgViewer(iconPath, width: 22),
              const SizedBox(width: Dimens.largePadding),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      value,
                      style: typography.bodySmall.copyWith(color: colors.gray4),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSvgViewer(Assets.icons.arrowRight4, width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: typography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: typography.bodySmall.copyWith(color: colors.gray4),
        ),
      ],
    );
  }
}
