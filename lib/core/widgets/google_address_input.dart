import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/address_with_coords.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/location_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/screens/address_search_screen.dart';

/// A reusable widget for Google Places address input
/// Can be used throughout the app wherever address input is needed
class GoogleAddressInput extends StatefulWidget {
  const GoogleAddressInput({
    super.key,
    required this.onAddressSelected,
    this.initialAddress,
    this.hintText = 'Adres seçin',
    this.label,
    this.showLabel = true,
    this.clearAfterSelection = false,
  });

  final void Function(String address) onAddressSelected;
  final String? initialAddress;
  final String hintText;
  final String? label;
  final bool showLabel;
  final bool clearAfterSelection;

  @override
  State<GoogleAddressInput> createState() => _GoogleAddressInputState();
}

class _GoogleAddressInputState extends State<GoogleAddressInput> {
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.initialAddress;
  }

  Future<void> _openAddressSearch() async {
    double? biasLat;
    double? biasLng;
    try {
      final loc = context.read<LocationCubit>().state;
      if (loc.status == LocationStatus.success &&
          loc.latitude != null &&
          loc.longitude != null) {
        biasLat = loc.latitude;
        biasLng = loc.longitude;
      }
    } catch (_) {}

    final result = await Navigator.of(context).push<AddressWithCoords>(
      MaterialPageRoute(
        builder:
            (_) => AddressSearchScreen(
              biasLatitude: biasLat,
              biasLongitude: biasLng,
            ),
      ),
    );

    if (result != null &&
        result.address.trim().isNotEmpty &&
        mounted) {
      final addr = result.address.trim();
      setState(() {
        _selectedAddress = widget.clearAfterSelection ? null : addr;
      });
      widget.onAddressSelected(addr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel && widget.label != null) ...[
          Text(
            widget.label!,
            style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Dimens.padding),
        ],

        InkWell(
          onTap: _openAddressSearch,
          borderRadius: BorderRadius.circular(Dimens.corners),
          child: Container(
            padding: const EdgeInsets.all(Dimens.largePadding),
            decoration: BoxDecoration(
              border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(Dimens.corners),
              color: colors.white,
            ),
            child: Row(
              children: [
                AppSvgViewer(
                  Assets.icons.location,
                  width: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: Dimens.padding),

                Expanded(
                  child:
                      _selectedAddress != null && _selectedAddress!.isNotEmpty
                          ? Text(
                            _selectedAddress!,
                            style: typography.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                          : Text(
                            widget.hintText,
                            style: typography.bodyMedium.copyWith(
                              color: colors.gray4,
                            ),
                          ),
                ),

                const SizedBox(width: Dimens.padding),
                Icon(Icons.arrow_forward_ios, size: 16, color: colors.gray4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact version for smaller spaces
class CompactGoogleAddressInput extends StatelessWidget {
  const CompactGoogleAddressInput({
    super.key,
    required this.onAddressSelected,
    this.currentAddress,
    this.hintText = 'Adres seçin',
  });

  final void Function(String address) onAddressSelected;
  final String? currentAddress;
  final String hintText;

  Future<void> _openAddressSearch(BuildContext context) async {
    double? biasLat;
    double? biasLng;
    try {
      final loc = context.read<LocationCubit>().state;
      if (loc.status == LocationStatus.success &&
          loc.latitude != null &&
          loc.longitude != null) {
        biasLat = loc.latitude;
        biasLng = loc.longitude;
      }
    } catch (_) {}

    final result = await Navigator.of(context).push<AddressWithCoords>(
      MaterialPageRoute(
        builder:
            (_) => AddressSearchScreen(
              biasLatitude: biasLat,
              biasLongitude: biasLng,
            ),
      ),
    );

    if (result != null && result.address.trim().isNotEmpty) {
      onAddressSelected(result.address.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppSvgViewer(Assets.icons.location, color: colors.primary),
      title: Text(
        currentAddress?.isNotEmpty == true ? currentAddress! : hintText,
        style:
            currentAddress?.isNotEmpty == true
                ? typography.bodyMedium
                : typography.bodyMedium.copyWith(color: colors.gray4),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: colors.gray4, size: 16),
      onTap: () => _openAddressSearch(context),
    );
  }
}
