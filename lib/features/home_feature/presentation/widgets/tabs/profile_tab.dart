import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/user_profile.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_logout.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/user_profile_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/check_theme_status.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/change_address_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/payment_methods_screen.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/splash_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/favorites_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/feedback_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/help_support_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/presentation/screens/coupons_list_screen.dart';

import '../../../../../core/gen/assets.gen.dart';
import '../../../../../core/theme/dimens.dart';
import '../../../../../core/widgets/app_list_tile.dart';
import '../../../../../core/widgets/app_svg_viewer.dart';
import '../../../../../core/widgets/user_profile_image_widget.dart';
import '../../../../restaurant_owner_feature/utils/image_picker_helper.dart';
import '../../bloc/theme_cubit.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final NotificationService _notificationService = NotificationService.instance;
  final UserProfileService _profileService = UserProfileService();
  UserProfile? _profile;
  bool _isLoadingProfile = true;
  bool _isUploadingPhoto = false;
  bool _isSavingProfile = false;
  bool _notificationsEnabled = true;

  String _localeLabel(Locale locale) {
    if (locale.languageCode == 'tr') {
      return context.tr('turkish');
    }
    if (locale.languageCode == 'en') {
      return context.tr('english');
    }
    final country = locale.countryCode;
    if (country == null || country.isEmpty) {
      return locale.languageCode.toUpperCase();
    }
    return '${locale.languageCode.toUpperCase()}-$country';
  }

  bool _isSameLocale(Locale a, Locale b) {
    return a.languageCode == b.languageCode && a.countryCode == b.countryCode;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final userId = AppSession.userId.trim();
    if (userId.isEmpty) {
      if (mounted) {
        context.showErrorMessage(context.tr('profile_info_fetch_failed'));
      }
      return;
    }

    try {
      if (value) {
        await _notificationService.initialize();
        final granted = await _notificationService.requestOsPermission();
        if (!granted) {
          try {
            await _profileService.patchUserSettings(
              userId: userId,
              notificationEnabled: false,
            );
          } catch (_) {}
          AppSession.updateNotificationEnabled(false);
          await _notificationService.syncLocalCacheFromServer(false);
          if (!mounted) {
            return;
          }
          setState(() {
            _notificationsEnabled = false;
          });
          context.showErrorMessage('Bildirim izni verilmedi.');
          return;
        }
        await _notificationService.setLocalPreferencesEnabled(true);
        final profile = await _profileService.patchUserSettings(
          userId: userId,
          notificationEnabled: true,
        );
        if (!mounted) {
          return;
        }
        AppSession.updateNotificationEnabled(profile.notificationEnabled);
        setState(() {
          _profile = profile;
          _notificationsEnabled = profile.notificationEnabled;
        });
        await _notificationService.showOptionalEnabledBanner();
        if (!mounted) {
          return;
        }
        context.showSuccessMessage('Bildirimler acildi.');
      } else {
        await _notificationService.setLocalPreferencesEnabled(false);
        final profile = await _profileService.patchUserSettings(
          userId: userId,
          notificationEnabled: false,
        );
        if (!mounted) {
          return;
        }
        AppSession.updateNotificationEnabled(profile.notificationEnabled);
        setState(() {
          _profile = profile;
          _notificationsEnabled = profile.notificationEnabled;
        });
        context.showSuccessMessage('Bildirimler kapatildi.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      context.showErrorMessage(
        e is AuthException
            ? e.message
            : context.tr('profile_info_fetch_failed'),
      );
    }
  }

  Future<void> _loadProfile() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingProfile = false;
      });
      return;
    }

    try {
      final profile = await _profileService.getProfile(userId: userId);
      if (!mounted) {
        return;
      }
      AppSession.updateNotificationEnabled(profile.notificationEnabled);
      await _notificationService.syncLocalCacheFromServer(
        profile.notificationEnabled,
      );
      setState(() {
        _profile = profile;
        _notificationsEnabled = profile.notificationEnabled;
      });
    } catch (_) {
      if (mounted) {
        context.showErrorMessage(context.tr('profile_info_fetch_failed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _showLanguageSelector() async {
    final selectedLocale = context.locale;
    final locales = context.supportedLocales;
    final locale = await showModalBottomSheet<Locale>(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    bottomSheetContext.tr('language_selection'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children:
                        locales
                            .map(
                              (supportedLocale) => ListTile(
                                leading:
                                    _isSameLocale(
                                          selectedLocale,
                                          supportedLocale,
                                        )
                                        ? const Icon(Icons.check)
                                        : const SizedBox.shrink(),
                                title: Text(_localeLabel(supportedLocale)),
                                onTap:
                                    () => Navigator.of(
                                      bottomSheetContext,
                                    ).pop(supportedLocale),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (locale == null || !mounted) {
      return;
    }

    await context.setLocale(locale);
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_isUploadingPhoto || AppSession.userId.isEmpty) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.tr('gallery_pick')),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(context.tr('camera_take')),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final picked = await pickAndSaveImage(source);
    if (picked == null) {
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final uploadedProfile = await _profileService.uploadProfilePhoto(
        userId: AppSession.userId,
        filePath: picked.path,
        fileBytes: kIsWeb ? await picked.readAsBytes() : null,
        fileName: picked.name,
      );
      await _refreshProfileAfterUpload(uploadedProfile);
      if (!mounted) {
        return;
      }
      context.showSuccessMessage(context.tr('profile_photo_updated'));
    } catch (error) {
      if (mounted && error is AuthException) {
        context.showErrorMessage(error.message);
        return;
      }
      // Some clients can fail on immediate upload parsing even when backend save succeeds.
      // We re-fetch profile once before showing an error.
      final refreshed = await _refreshProfileAfterUpload();
      if (mounted && !refreshed) {
        context.showErrorMessage(
          '${context.tr('profile_photo_upload_failed')} ${error.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<bool> _refreshProfileAfterUpload([
    UserProfile? uploadedProfile,
  ]) async {
    try {
      final profile =
          uploadedProfile ??
          await _profileService.getProfile(userId: AppSession.userId);
      if (!mounted) {
        return false;
      }
      setState(() {
        _profile = profile;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showEditProfileDialog() async {
    if (_isSavingProfile || AppSession.userId.isEmpty) {
      return;
    }

    final currentName = _profile?.fullName ?? AppSession.fullName;
    final currentEmail = _profile?.email ?? '';
    final nameController = TextEditingController(text: currentName);
    final emailController = TextEditingController(text: currentEmail);

    final payload = await showDialog<(String fullName, String email)>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('profile')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta'),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop((
                  nameController.text.trim(),
                  emailController.text.trim(),
                ));
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    if (payload == null || !mounted) {
      return;
    }

    final fullName = payload.$1.trim();
    final email = payload.$2.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (fullName.isEmpty) {
      context.showErrorMessage('Ad soyad bos olamaz.');
      return;
    }
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      context.showErrorMessage('Gecerli bir e-posta girin.');
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });
    try {
      final updated = await _profileService.updateProfile(
        userId: AppSession.userId,
        fullName: fullName,
        email: email,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = updated;
      });
      AppSession.updateFullName(updated.fullName);
      context.showSuccessMessage('Profil bilgileri guncellendi.');
    } catch (error) {
      if (mounted) {
        context.showErrorMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await AppConfirmDialog.show(
      context,
      title: context.tr('logout_title'),
      message: context.tr('logout_message'),
      cancelText: context.tr('cancel'),
      confirmText: context.tr('logout'),
      isDestructive: true,
    );
    if (shouldLogout != true || !mounted) {
      return;
    }

    await performAuthLogout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;
    final displayName =
        _profile?.fullName.trim().isNotEmpty == true
            ? _profile!.fullName
            : (AppSession.fullName.isNotEmpty
                ? AppSession.fullName
                : context.tr('default_user'));
    final displayEmail =
        _profile?.email.trim().isNotEmpty == true
            ? _profile!.email
            : context.tr('email_not_found');
    final selectedLanguage = _localeLabel(context.locale);

    return AppScaffold(
      appBar: GeneralAppBar(title: context.tr('profile'), showBackIcon: false),
      body: SingleChildScrollView(
        child: Column(
          spacing: Dimens.largePadding,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BorderedContainer(
              child: ListTile(
                leading: UserProfileImageWidget(
                  width: 56,
                  height: 56,
                  imageUrl: _profile?.photoUrl,
                  onTap: _pickAndUploadProfilePhoto,
                ),
                title: Text(displayName, style: appTypography.bodyLarge),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: Dimens.padding),
                  child: Text(
                    _isLoadingProfile ? context.tr('loading') : displayEmail,
                    style: appTypography.bodySmall.copyWith(
                      color:
                          checkDarkMode(context)
                              ? appColors.white
                              : appColors.gray4,
                    ),
                  ),
                ),
                trailing:
                    _isUploadingPhoto || _isSavingProfile
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: appColors.primary,
                          ),
                        )
                        : GestureDetector(
                          onTap: _showEditProfileDialog,
                          child: AppSvgViewer(
                            Assets.icons.edit,
                            width: 19,
                            color:
                                checkDarkMode(context)
                                    ? appColors.white
                                    : appColors.gray4,
                          ),
                        ),
              ),
            ),
            Text(
              context.tr('general'),
              style: appTypography.bodyLarge.copyWith(fontSize: 20),
            ),
            BorderedContainer(
              child: Column(
                spacing: Dimens.largePadding,
                children: [
                  AppListTile(
                    onTap: () {
                      appPush(context, const PaymentMethodsScreen());
                    },
                    title: context.tr('payment_method'),
                    leadingIconPath: Assets.icons.cardPos,
                    padding: EdgeInsets.zero,
                  ),
                  AppListTile(
                    onTap: () {
                      appPush(context, const ChangeAddressScreen());
                    },
                    title: context.tr('addresses'),
                    leadingIconPath: Assets.icons.location,
                    padding: EdgeInsets.zero,
                  ),
                  AppListTile(
                    onTap: _showLanguageSelector,
                    title: context.tr('language'),
                    leadingIconPath: Assets.icons.languageSquare,
                    trailing: Text(
                      selectedLanguage,
                      style: appTypography.bodySmall.copyWith(
                        color:
                            checkDarkMode(context)
                                ? appColors.white
                                : appColors.gray4,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  AppListTile(
                    onTap: () {
                      appPush(context, const FavoritesScreen());
                    },
                    title: 'Favoriler',
                    leadingIconPath: Assets.icons.heart,
                    padding: EdgeInsets.zero,
                  ),
                  AppListTile(
                    onTap: () {
                      appPush(context, const CouponsListScreen());
                    },
                    title: 'Kuponlarım',
                    leadingIconPath: Assets.icons.ticketDiscount,
                    padding: EdgeInsets.zero,
                  ),
                  AppListTile(
                    onTap: () {},
                    title: context.tr('notifications'),
                    leadingIconPath: Assets.icons.notification,
                    trailing: Transform.scale(
                      scale: 0.7,
                      child: CupertinoSwitch(
                        value: _notificationsEnabled,
                        onChanged: _setNotificationsEnabled,
                        activeTrackColor: appColors.primary,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  AppListTile(
                    onTap: () {
                      context.read<ThemeCubit>().toggleTheme();
                    },
                    title: context.tr('dark_theme'),
                    leadingIconPath: Assets.icons.moon,
                    trailing: Transform.scale(
                      scale: 0.7,
                      child: CupertinoSwitch(
                        value: checkDarkMode(context),
                        onChanged: (final value) {
                          context.read<ThemeCubit>().toggleTheme();
                        },
                        activeTrackColor: appColors.primary,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  SizedBox.shrink(),
                ],
              ),
            ),
            Text(
              context.tr('support'),
              style: appTypography.bodyLarge.copyWith(fontSize: 20),
            ),
            BorderedContainer(
              child: Column(
                spacing: Dimens.largePadding,
                children: [
                  AppListTile(
                    onTap: () {
                      appPush(context, const FeedbackScreen());
                    },
                    title: context.tr('feedback'),
                    leadingIconPath: Assets.icons.noteText,
                    padding: EdgeInsets.zero,
                  ),
                  AppListTile(
                    onTap: () {
                      appPush(context, const HelpSupportScreen());
                    },
                    title: context.tr('help_support'),
                    leadingIconPath: Assets.icons.infoCircle,
                    padding: EdgeInsets.zero,
                  ),
                  SizedBox.shrink(),
                ],
              ),
            ),
            BorderedContainer(
              child: AppListTile(
                onTap: _handleLogout,
                title: context.tr('logout_action'),
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
