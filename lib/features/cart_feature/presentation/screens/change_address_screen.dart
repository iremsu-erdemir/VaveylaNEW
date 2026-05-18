import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/user_address.dart'
    show AddressLabelType, UserAddress;
import 'package:flutter_sweet_shop_app_ui/core/utils/guid_utils.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/user_address_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_divider.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/address_with_coords.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/location_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/screens/address_search_screen.dart';

import '../../../../core/gen/assets.gen.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_svg_viewer.dart';

class ChangeAddressScreen extends StatefulWidget {
  const ChangeAddressScreen({super.key});

  @override
  State<ChangeAddressScreen> createState() => _ChangeAddressScreenState();
}

class _ChangeAddressScreenState extends State<ChangeAddressScreen> {
  final UserAddressService _addressService = UserAddressService();
  final List<UserAddress> _savedAddresses = [];
  bool _isLoading = true;
  bool _isSaving = false;

  AddressSearchScreen _addressSearchScreenWithHomeBias() {
    double? lat;
    double? lng;
    try {
      final s = context.read<LocationCubit>().state;
      if (s.status == LocationStatus.success &&
          s.latitude != null &&
          s.longitude != null) {
        lat = s.latitude;
        lng = s.longitude;
      }
    } catch (_) {}
    return AddressSearchScreen(
      biasLatitude: lat,
      biasLongitude: lng,
    );
  }

  String? get _selectedAddressId {
    for (final address in _savedAddresses) {
      if (address.isSelected) {
        return address.addressId;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final userId = AppSession.userId;
    if (userId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses.clear();
        _isLoading = false;
      });
      return;
    }

    try {
      final addresses = await _addressService.getAddresses(userId: userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses
          ..clear()
          ..addAll(
            addresses
                .map((a) {
                  final id = tryExtractUuid(a.addressId);
                  if (id == null) return null;
                  return a.copyWith(addressId: id);
                })
                .whereType<UserAddress>(),
          );
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ChangeAddressScreen _loadAddresses: $error');
        debugPrint('$stackTrace');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _selectAddress(UserAddress address) async {
    if (_isSaving || address.isSelected) {
      return;
    }
    final addressGuid = tryExtractUuid(address.addressId);
    if (addressGuid == null) {
      _showMessage(
        'Adres kimliği geçersiz. Liste yenileniyor.',
        context.theme.appColors.error,
      );
      await _loadAddresses(showLoader: false);
      return;
    }
    _markSelectedLocally(addressGuid);
    final success = await _updateAddress(
      address: address,
      label: address.label,
      addressLine: address.addressLine,
      addressDetail: address.addressDetail ?? '',
      isSelected: true,
    );
    if (!success) {
      await _loadAddresses(showLoader: false);
    }
  }

  AddressLabelType _labelTypeFromTitle(String title) {
    final t = title.toLowerCase();
    if (t == 'ev' || t == 'aile evi') return AddressLabelType.home;
    if (t == 'ofis' || t == 'iş') return AddressLabelType.work;
    return AddressLabelType.other;
  }

  Future<void> _addNewAddress(
    String address, {
    double? latitude,
    double? longitude,
  }) async {
    final details = await _showAddressDetailsBottomSheet(
      selectedAddress: address,
      actionTitle: 'Adresi Kaydet',
    );
    if (details == null || !mounted) {
      return;
    }

    final userId = AppSession.userId;
    if (userId.isEmpty) {
      _showMessage(
        'Adres kaydetmek icin giris yapmalisiniz.',
        context.theme.appColors.error,
      );
      return;
    }

    final created = await _runSaving(() async {
      return await _addressService.createAddress(
        userId: userId,
        label: details.title,
        addressLine: address,
        addressDetail: details.addressDetail,
        labelType: _labelTypeFromTitle(details.title),
        floor: details.floor,
        apartment: details.apartment,
        directionsNote: details.directionsNote,
        latitude: latitude,
        longitude: longitude,
        isSelected: true,
      );
    });
    if (created != null && mounted) {
      setState(() => _applyCreatedAddress(created));
      await _loadAddresses(showLoader: false);
      if (mounted) {
        final createdId = tryExtractUuid(created.addressId);
        if (createdId != null &&
            !_savedAddresses.any((a) => a.addressId == createdId)) {
          setState(() => _applyCreatedAddress(created));
        }
        _showMessage(
          '${details.title} adresi eklendi',
          context.theme.appColors.success,
        );
      }
    } else if (mounted) {
      _showMessage(
        'Adres kaydedilemedi. Lütfen tekrar deneyin.',
        context.theme.appColors.error,
      );
    }
  }

  /// Yeni oluşturulan adresi seçili olacak şekilde listeye ekler (yoksa).
  void _applyCreatedAddress(UserAddress created) {
    final createdId = tryExtractUuid(created.addressId);
    if (createdId == null) return;

    final sanitized = created.copyWith(addressId: createdId);
    for (var i = 0; i < _savedAddresses.length; i++) {
      _savedAddresses[i] = _savedAddresses[i].copyWith(isSelected: false);
    }
    final index = _savedAddresses.indexWhere((a) => a.addressId == createdId);
    if (index >= 0) {
      _savedAddresses[index] = sanitized;
    } else {
      _savedAddresses.add(sanitized);
    }
  }

  Future<void> _startEditAddressFlow(UserAddress address) async {
    final result = await Navigator.of(context).push<AddressWithCoords>(
      MaterialPageRoute(builder: (_) => _addressSearchScreenWithHomeBias()),
    );
    if (!mounted) {
      return;
    }

    final addressStr = result?.address.trim() ?? '';
    final normalizedAddress =
        addressStr.isNotEmpty ? addressStr : address.addressLine;
    final details = await _showAddressDetailsBottomSheet(
      selectedAddress: normalizedAddress,
      initialTitle: address.label,
      initialAddressDetail: address.addressDetail ?? '',
      actionTitle: 'Adresi Guncelle',
    );
    if (details == null || !mounted) {
      return;
    }

    final success = await _updateAddress(
      address: address,
      label: details.title,
      addressLine: normalizedAddress,
      addressDetail: details.addressDetail,
      isSelected: address.isSelected,
    );

    if (success && mounted) {
      _showMessage('Adres guncellendi.', context.theme.appColors.success);
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    final shouldDelete = await AppConfirmDialog.show(
      context,
      title: 'Adresi Sil',
      message: '${address.label} adresini silmek istiyor musunuz?',
      cancelText: 'Vazgeç',
      confirmText: 'Sil',
      isDestructive: true,
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final userId = AppSession.userId;
    if (userId.isEmpty) {
      _showMessage(
        'Adres silmek icin giris yapmalisiniz.',
        context.theme.appColors.error,
      );
      return;
    }

    final removed = await _runSaving(() async {
      await _addressService.deleteAddress(
        userId: userId,
        addressId: address.addressId,
      );
      return true;
    });
    if (removed == true && mounted) {
      setState(() {
        _savedAddresses.removeWhere((x) => x.addressId == address.addressId);
        if (_savedAddresses.isNotEmpty &&
            _savedAddresses.every((x) => !x.isSelected)) {
          _savedAddresses[0] = _savedAddresses[0].copyWith(isSelected: true);
        }
      });
      _showMessage('Adres silindi.', context.theme.appColors.success);
    }
  }

  Future<bool> _updateAddress({
    required UserAddress address,
    required String label,
    required String addressLine,
    required String addressDetail,
    required bool isSelected,
  }) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      _showMessage(
        'Adres guncellemek icin giris yapmalisiniz.',
        context.theme.appColors.error,
      );
      return false;
    }

    final addressGuid = tryExtractUuid(address.addressId);
    if (addressGuid == null) {
      _showMessage(
        'Adres kimliği geçersiz.',
        context.theme.appColors.error,
      );
      return false;
    }

    final updated = await _runSaving(() async {
      return await _addressService.updateAddress(
        userId: userId,
        addressId: addressGuid,
        label: label,
        addressLine: addressLine,
        addressDetail: addressDetail.isEmpty ? null : addressDetail,
        isSelected: isSelected,
      );
    });
    if (updated == null || !mounted) {
      return false;
    }
    final updatedId = tryExtractUuid(updated.addressId);
    if (updatedId == null) {
      return false;
    }
    final sanitized = updated.copyWith(addressId: updatedId);
    setState(() {
      if (sanitized.isSelected) {
        _markSelectedLocally(updatedId);
      }
      final index = _savedAddresses.indexWhere(
        (x) => x.addressId == updatedId,
      );
      if (index != -1) {
        _savedAddresses[index] = sanitized;
      }
    });
    return true;
  }

  Future<T?> _runSaving<T>(Future<T> Function() action) async {
    if (_isSaving) {
      return null;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      return await action();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ChangeAddressScreen _runSaving: $error');
        debugPrint('$stackTrace');
      }
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        final friendly =
            message.contains('invalid characters') ||
                    message.contains('Invalid argument')
                ? 'Adres kaydedilemedi. Lütfen tekrar deneyin.'
                : message;
        _showMessage(friendly, context.theme.appColors.error);
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _markSelectedLocally(String selectedId) {
    for (var i = 0; i < _savedAddresses.length; i++) {
      final item = _savedAddresses[i];
      _savedAddresses[i] = item.copyWith(
        isSelected: item.addressId == selectedId,
      );
    }
  }

  Future<void> _startAddAddressFlow() async {
    final result = await Navigator.of(context).push<AddressWithCoords>(
      MaterialPageRoute(builder: (_) => _addressSearchScreenWithHomeBias()),
    );

    final addressStr = result?.address.trim() ?? '';
    if (addressStr.isEmpty || !mounted) {
      return;
    }

    await _addNewAddress(
      addressStr,
      latitude: result?.latitude,
      longitude: result?.longitude,
    );
  }

  Future<_NewAddressDetails?> _showAddressDetailsBottomSheet({
    required String selectedAddress,
    required String actionTitle,
    String initialTitle = 'Ev',
    String initialAddressDetail = '',
  }) async {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final detailController = TextEditingController(text: initialAddressDetail);
    final floorController = TextEditingController();
    final apartmentController = TextEditingController();
    final directionsController = TextEditingController();
    String selectedTitle = initialTitle;
    String customTitle = initialTitle;
    final titleOptions = ['Ev', 'Ofis', 'Aile Evi', 'Diger'];
    final customTitleController = TextEditingController(
      text: titleOptions.contains(initialTitle) ? '' : initialTitle,
    );
    if (!titleOptions.contains(initialTitle)) {
      selectedTitle = 'Diger';
    } else if (selectedTitle != 'Diger') {
      customTitle = '';
    }

    final result = await showModalBottomSheet<_NewAddressDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                Dimens.largePadding,
                Dimens.largePadding,
                Dimens.largePadding,
                Dimens.largePadding + bottomInset,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adres Bilgileri',
                      style: typography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Dimens.padding),
                    Text(
                      selectedAddress,
                      style: typography.bodySmall.copyWith(color: colors.gray4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    Text(
                      'Adres Başlığı',
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Dimens.smallPadding),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          titleOptions.map((option) {
                            return ChoiceChip(
                              label: Text(option),
                              selected: selectedTitle == option,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedTitle = option;
                                  if (option != 'Diger') {
                                    customTitle = '';
                                    customTitleController.clear();
                                  } else {
                                    customTitleController.text = customTitle;
                                  }
                                });
                              },
                              selectedColor: colors.primary.withValues(
                                alpha: 0.15,
                              ),
                              labelStyle: typography.bodySmall.copyWith(
                                color:
                                    selectedTitle == option
                                        ? colors.primary
                                        : colors.primaryTint2,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList(),
                    ),
                    if (selectedTitle == 'Diger') ...[
                      const SizedBox(height: Dimens.padding),
                      TextField(
                        controller: customTitleController,
                        onChanged: (value) => customTitle = value.trim(),
                        decoration: InputDecoration(
                          hintText: 'Baslik girin (Orn: Yazlik)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Dimens.largePadding),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: floorController,
                            decoration: InputDecoration(
                              labelText: 'Kat',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: apartmentController,
                            decoration: InputDecoration(
                              labelText: 'Daire',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimens.padding),
                    TextField(
                      controller: directionsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Tarif (opsiyonel)',
                        hintText: 'Kapı zili, landmark vb.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimens.padding),
                    TextField(
                      controller: detailController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Ek not',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    AppButton(
                      title: actionTitle,
                      margin: EdgeInsets.zero,
                      borderRadius: 16,
                      onPressed: () {
                        final normalizedTitle =
                            selectedTitle == 'Diger'
                                ? customTitle.trim()
                                : selectedTitle;
                        if (normalizedTitle.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Lutfen bir adres basligi girin.',
                              ),
                              backgroundColor: colors.error,
                            ),
                          );
                          return;
                        }
                        Navigator.of(bottomSheetContext).pop(
                          _NewAddressDetails(
                            title: normalizedTitle,
                            addressDetail: detailController.text.trim(),
                            floor: floorController.text.trim(),
                            apartment: apartmentController.text.trim(),
                            directionsNote: directionsController.text.trim(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    detailController.dispose();
    floorController.dispose();
    apartmentController.dispose();
    directionsController.dispose();
    customTitleController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appTypography = context.theme.appTypography;
    final appColors = context.theme.appColors;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Adres Değiştir',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Dimens.padding),
            child: Material(
              color: appColors.primary,
              shape: const CircleBorder(),
              elevation: 1,
              shadowColor: appColors.primary.withValues(alpha: 0.25),
              child: InkWell(
                onTap: _startAddAddressFlow,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.add, color: appColors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(Dimens.largePadding),
                child: CircularProgressIndicator(),
              )
            else if (_savedAddresses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Dimens.largePadding),
                child: Text(
                  'Kayitli adres bulunamadi. + butonundan yeni adres ekleyin.',
                  style: appTypography.bodyMedium.copyWith(
                    color: appColors.gray4,
                  ),
                ),
              )
            else
              ListView.separated(
                itemCount: _savedAddresses.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final address = _savedAddresses[index];
                  return InkWell(
                    onTap: () => _selectAddress(address),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AppSvgViewer(
                            Assets.icons.location,
                            color: appColors.primary,
                          ),
                          title: Text(
                            address.label,
                            style: appTypography.bodyLarge,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _startEditAddressFlow(address);
                                    return;
                                  }
                                  _deleteAddress(address);
                                },
                                itemBuilder:
                                    (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Duzenle'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Sil'),
                                      ),
                                    ],
                              ),
                              Radio<String>(
                                value: address.addressId,
                                groupValue: _selectedAddressId,
                                onChanged: (_) => _selectAddress(address),
                                activeColor: appColors.primary,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 42,
                            right: Dimens.largePadding,
                            bottom: Dimens.largePadding,
                          ),
                          child: Text(
                            address.addressLine,
                            style: appTypography.bodySmall.copyWith(
                              color: appColors.gray4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (address.addressDetail != null &&
                            address.addressDetail!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 42,
                              right: Dimens.largePadding,
                              bottom: Dimens.largePadding,
                            ),
                            child: Text(
                              address.addressDetail!,
                              style: appTypography.bodySmall.copyWith(
                                color: appColors.gray4,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) => const AppDivider(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(
          left: Dimens.largePadding,
          right: Dimens.largePadding,
          bottom: Dimens.padding,
        ),
        child: AppButton(
          onPressed:
              _savedAddresses.isEmpty || _isSaving
                  ? null
                  : () {
                    final selectedAddress = _savedAddresses.firstWhere(
                      (addr) => addr.isSelected,
                      orElse: () => _savedAddresses.first,
                    );

                    Navigator.of(context).pop(selectedAddress.addressLine);
                  },
          title: 'Uygula',
          textStyle: appTypography.bodyLarge,
          borderRadius: Dimens.corners,
          margin: const EdgeInsets.symmetric(vertical: Dimens.largePadding),
        ),
      ),
    );
  }
}

class _NewAddressDetails {
  const _NewAddressDetails({
    required this.title,
    required this.addressDetail,
    this.floor = '',
    this.apartment = '',
    this.directionsNote = '',
  });

  final String title;
  final String addressDetail;
  final String floor;
  final String apartment;
  final String directionsNote;
}
