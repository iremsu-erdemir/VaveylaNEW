import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/address_with_coords.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/user_profile.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_logout.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/user_profile_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/check_theme_status.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_list_tile.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/penalty_points_summary_card.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/user_profile_image_widget.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/theme_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/splash_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/screens/address_search_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/utils/image_picker_helper.dart';

class CourierSettingsScreen extends StatefulWidget {
  const CourierSettingsScreen({super.key});

  @override
  State<CourierSettingsScreen> createState() => _CourierSettingsScreenState();
}

class _CourierSettingsScreenState extends State<CourierSettingsScreen> {
  final UserProfileService _profileService = UserProfileService();
  UserProfile? _profile;
  bool _isLoadingProfile = true;
  bool _isUploadingPhoto = false;
  String _phone = '';
  String _address = '';

  /// Profil yüklenene kadar oturumdaki sunucu değeri; sonra [_profile].
  bool get _orderNotificationsFromServer =>
      _profile?.notificationEnabled ?? AppSession.notificationEnabled;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
      return;
    }
    try {
      final profile = await _profileService.getProfile(userId: userId);
      if (!mounted) return;
      AppSession.updateNotificationEnabled(profile.notificationEnabled);
      await NotificationService.instance.syncLocalCacheFromServer(
        profile.notificationEnabled,
      );
      setState(() {
        _profile = profile;
        _phone = profile.phone?.trim() ?? '';
        _address = profile.address?.trim() ?? '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _profile = null;
          _isLoadingProfile = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.theme.appColors.success,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.theme.appColors.error,
      ),
    );
  }

  Future<void> _onOrderNotificationsChanged(bool value) async {
    final userId = AppSession.userId.trim();
    if (userId.isEmpty) {
      _showError('Oturum bulunamadı.');
      return;
    }

    try {
      if (value) {
        await NotificationService.instance.initialize();
        final granted =
            await NotificationService.instance.requestOsPermission();
        if (!granted) {
          try {
            await _profileService.patchUserSettings(
              userId: userId,
              notificationEnabled: false,
            );
          } catch (_) {}
          AppSession.updateNotificationEnabled(false);
          await NotificationService.instance.syncLocalCacheFromServer(false);
          if (!mounted) {
            return;
          }
          setState(() {
            _profile = _profile?.copyWith(notificationEnabled: false);
          });
          _showError('Bildirim izni verilmedi.');
          return;
        }
        await NotificationService.instance.setLocalPreferencesEnabled(true);
        final profile = await _profileService.patchUserSettings(
          userId: userId,
          notificationEnabled: true,
        );
        if (!mounted) {
          return;
        }
        AppSession.updateNotificationEnabled(profile.notificationEnabled);
        await NotificationService.instance.syncLocalCacheFromServer(
          profile.notificationEnabled,
        );
        setState(() {
          _profile = profile;
        });
        await NotificationService.instance.showOptionalEnabledBanner();
        if (!mounted) {
          return;
        }
        _showSuccess('Sipariş bildirimleri açıldı');
      } else {
        await NotificationService.instance.setLocalPreferencesEnabled(false);
        final profile = await _profileService.patchUserSettings(
          userId: userId,
          notificationEnabled: false,
        );
        if (!mounted) {
          return;
        }
        AppSession.updateNotificationEnabled(profile.notificationEnabled);
        await NotificationService.instance.syncLocalCacheFromServer(false);
        setState(() {
          _profile = profile;
        });
        _showSuccess('Sipariş bildirimleri kapatıldı');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e is AuthException ? e.message : 'Ayar güncellenemedi.');
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_isUploadingPhoto || AppSession.userId.isEmpty) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Galeriden seç'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Kamera ile çek'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
    );
    if (source == null) return;
    final picked = await pickAndSaveImage(source);
    if (picked == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final uploaded = await _profileService.uploadProfilePhoto(
        userId: AppSession.userId,
        filePath: picked.path,
        fileBytes: kIsWeb ? await picked.readAsBytes() : null,
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _profile = uploaded;
        _phone = uploaded.phone?.trim() ?? _phone;
        _address = uploaded.address?.trim() ?? _address;
      });
      _showSuccess('Profil fotoğrafı güncellendi');
    } catch (e) {
      if (mounted) {
        final message =
            e is AuthException ? e.message : 'Fotoğraf yüklenemedi: $e';
        _showError(message);
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showEditFieldSheet(
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
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('$title boş olamaz'),
                            backgroundColor: context.theme.appColors.error,
                          ),
                        );
                        return;
                      }
                      try {
                        await onSave(value);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: ctx.theme.appColors.error,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showEditPhoneSheet() {
    final localDigitsController = TextEditingController(
      text: _extractLocalTurkishPhoneDigits(_phone),
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
                              await _saveProfileChanges(phone: fullPhone);
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              _showSuccess('Telefon güncellendi');
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
    if (digits.startsWith('90') && digits.length >= 12) {
      return digits.substring(2, 12);
    }
    if (digits.startsWith('0') && digits.length >= 11) {
      return digits.substring(1, 11);
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  Future<void> _showAddressSearch() async {
    final result = await Navigator.of(context).push<AddressWithCoords>(
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );
    if (!mounted) return;
    if (result != null && result.address.trim().isNotEmpty) {
      try {
        await _saveProfileChanges(address: result.address.trim());
        _showSuccess('Adres güncellendi');
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _saveProfileChanges({
    String? fullName,
    String? phone,
    String? address,
  }) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      throw Exception('Kullanıcı bilgisi bulunamadı.');
    }

    final currentName =
        _profile?.fullName.trim().isNotEmpty == true
            ? _profile!.fullName
            : (AppSession.fullName.isNotEmpty ? AppSession.fullName : 'Kurye');
    final currentEmail =
        _profile?.email.trim().isNotEmpty == true ? _profile!.email : '';
    if (currentEmail.trim().isEmpty) {
      throw Exception('E-posta bilgisi bulunamadı.');
    }

    final updated = await _profileService.updateProfile(
      userId: userId,
      fullName: (fullName ?? currentName).trim(),
      email: currentEmail.trim(),
      phone: (phone ?? _phone).trim(),
      address: (address ?? _address).trim(),
    );

    if (!mounted) return;
    setState(() {
      _profile = updated;
      _phone = updated.phone?.trim() ?? '';
      _address = updated.address?.trim() ?? '';
    });
    AppSession.updateFullName(updated.fullName);
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await AppConfirmDialog.show(
      context,
      title: 'Çıkış Yap',
      message: 'Çıkış yapmak istediğinize emin misiniz?',
      cancelText: 'Vazgeç',
      confirmText: 'Çıkış',
      isDestructive: true,
    );
    if (shouldLogout != true || !mounted) return;
    await performAuthLogout();
    if (!mounted) return;
    await appPushReplacement(context, const SplashScreen());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final displayName =
        _profile?.fullName.trim().isNotEmpty == true
            ? _profile!.fullName
            : (AppSession.fullName.isNotEmpty ? AppSession.fullName : 'Kurye');
    final displayEmail =
        _profile?.email.trim().isNotEmpty == true
            ? _profile!.email
            : 'E-posta yükleniyor...';

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Kurye Ayarları', showBackIcon: false),
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
                  UserProfileImageWidget(
                    width: 64,
                    height: 64,
                    imageUrl: _profile?.photoUrl,
                    onTap: _pickAndUploadProfilePhoto,
                  ),
                  const SizedBox(width: Dimens.largePadding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: typography.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Dimens.smallPadding),
                        Text(
                          _isLoadingProfile ? 'Yükleniyor...' : displayEmail,
                          style: typography.bodySmall.copyWith(
                            color: colors.gray4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_isUploadingPhoto)
                          Padding(
                            padding: const EdgeInsets.only(top: Dimens.padding),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _pickAndUploadProfilePhoto,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: Dimens.padding,
                              ),
                              child: Row(
                                children: [
                                  AppSvgViewer(
                                    Assets.icons.edit,
                                    width: 16,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Fotoğrafı değiştir',
                                    style: typography.labelSmall.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_profile?.totalPenaltyPoints != null) ...[
              const SizedBox(height: Dimens.largePadding),
              PenaltyPointsSummaryCard(points: _profile!.totalPenaltyPoints!),
            ],
            const SizedBox(height: Dimens.extraLargePadding),
            _SectionHeader(
              title: 'Kurye Bilgileri',
              subtitle: 'Profil bilgilerinizi düzenleyin',
            ),
            const SizedBox(height: Dimens.largePadding),
            BorderedContainer(
              child: Column(
                children: [
                  _SettingsListTile(
                    title: 'Ad Soyad',
                    value: displayName,
                    iconPath: Assets.icons.user,
                    onTap:
                        () => _showEditFieldSheet('Ad Soyad', displayName, (
                          v,
                        ) async {
                          await _saveProfileChanges(fullName: v);
                          _showSuccess('Ad soyad güncellendi');
                        }),
                  ),
                  _SettingsListTile(
                    title: 'Telefon',
                    value: _phone.isEmpty ? 'Belirtilmedi' : _phone,
                    iconPath: Assets.icons.call,
                    onTap: _showEditPhoneSheet,
                  ),
                  _SettingsListTile(
                    title: 'Adres',
                    value: _address.isEmpty ? 'Belirtilmedi' : _address,
                    iconPath: Assets.icons.location,
                    onTap: _showAddressSearch,
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
                    onTap:
                        () => _onOrderNotificationsChanged(
                          !_orderNotificationsFromServer,
                        ),
                    title: 'Sipariş bildirimleri',
                    leadingIconPath: Assets.icons.notification,
                    trailing: Transform.scale(
                      scale: 0.7,
                      child: CupertinoSwitch(
                        value: _orderNotificationsFromServer,
                        onChanged: _onOrderNotificationsChanged,
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
            _SectionHeader(
              title: 'Görünüm',
              subtitle: 'Paneli dilediğiniz gibi kullanın',
            ),
            const SizedBox(height: Dimens.largePadding),
            BorderedContainer(
              child: Column(
                children: [
                  AppListTile(
                    onTap: () => context.read<ThemeCubit>().toggleTheme(),
                    title: 'Koyu tema',
                    leadingIconPath: Assets.icons.moon,
                    trailing: Transform.scale(
                      scale: 0.7,
                      child: CupertinoSwitch(
                        value: checkDarkMode(context),
                        onChanged:
                            (_) => context.read<ThemeCubit>().toggleTheme(),
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
                onTap: _handleLogout,
                title: 'Çıkış yap',
                leadingIconPath: Assets.icons.logout,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
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
