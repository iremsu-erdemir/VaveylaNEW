import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/address_with_coords.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/google_places_service.dart';

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({
    super.key,
    this.biasLatitude,
    this.biasLongitude,
    this.biasRadiusMeters = 50000,
  });

  /// Ana sayfa / app bar konumu; Google önerilerini bu noktaya yakın sonuçlara öncelik verir.
  final double? biasLatitude;
  final double? biasLongitude;
  final int biasRadiusMeters;

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _searchController = TextEditingController();
  final _placesService = GooglePlacesService();
  final _focusNode = FocusNode();

  List<PlacePrediction> _predictions = [];
  bool _isSearching = false;
  ParsedAddress? _selectedAddress;
  PlaceDetails? _selectedDetails;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _searchPlaces(query);
    } else {
      setState(() {
        _predictions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      final results = await _placesService.searchPlaces(
        query,
        biasLatitude: widget.biasLatitude,
        biasLongitude: widget.biasLongitude,
        biasRadiusMeters: widget.biasRadiusMeters,
      );
      if (mounted) {
        setState(() {
          _predictions = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictions = [];
          _isSearching = false;
        });
        _showError('Adres arama hatası: $e');
      }
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    setState(() => _isSearching = true);

    try {
      final details = await _placesService.getPlaceDetails(prediction.placeId);
      final parsedAddress = details.parseAddress();

      setState(() {
        _selectedAddress = parsedAddress;
        _selectedDetails = details;
        _searchController.text = prediction.description;
        _predictions = [];
        _isSearching = false;
      });

      _focusNode.unfocus();
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showError('Adres detayları alınamadı: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.theme.appColors.error,
      ),
    );
  }

  void _confirmAddress() {
    if (_selectedAddress == null) {
      _showError('Lütfen bir adres seçin');
      return;
    }

    final address = _selectedAddress!.fullAddress;
    final lat = _selectedDetails?.latitude;
    final lng = _selectedDetails?.longitude;
    Navigator.of(context).pop(
      AddressWithCoords(
        address: address,
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Adres Seç',
        actions: [
          if (_selectedAddress != null)
            TextButton(
              onPressed: _confirmAddress,
              child: Text(
                'Onayla',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Input Container
              Container(
                margin: const EdgeInsets.all(Dimens.largePadding),
                child: Column(
                  children: [
                    // Search Input
                    Container(
                      decoration: BoxDecoration(
                        color: colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: colors.gray.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Konum ara',
                          hintStyle: typography.bodyMedium.copyWith(
                            color: colors.gray4,
                          ),
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            color: colors.gray4,
                            size: 20,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSearching)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              if (_searchController.text.isNotEmpty && !_isSearching)
                                IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _predictions = [];
                                      _selectedAddress = null;
                                    });
                                  },
                                  icon: Icon(Icons.clear, color: colors.gray4, size: 20),
                                ),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Selected Address Details
              if (_selectedAddress != null) ...[
                const SizedBox(height: Dimens.padding),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
                  padding: const EdgeInsets.all(Dimens.largePadding),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: colors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Seçilen Adres',
                            style: typography.titleSmall.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Dimens.padding),
                      _AddressDetailRow(
                        label: 'Sokak',
                        value: _selectedAddress!.street,
                        colors: colors,
                        typography: typography,
                      ),
                      _AddressDetailRow(
                        label: 'İlçe',
                        value: _selectedAddress!.district,
                        colors: colors,
                        typography: typography,
                      ),
                      _AddressDetailRow(
                        label: 'Şehir',
                        value: _selectedAddress!.city,
                        colors: colors,
                        typography: typography,
                      ),
                      _AddressDetailRow(
                        label: 'Posta Kodu',
                        value: _selectedAddress!.postalCode,
                        colors: colors,
                        typography: typography,
                      ),
                    ],
                  ),
                ),
              ],

              // Empty space
              if (_selectedAddress == null && _predictions.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'Adres aramak için yazmaya başlayın',
                      style: typography.bodyMedium.copyWith(
                        color: colors.gray4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              
              if (_selectedAddress == null && _predictions.isNotEmpty)
                const SizedBox(height: Dimens.padding),
            ],
          ),

          // Google-style Dropdown Suggestions
          if (_predictions.isNotEmpty && _selectedAddress == null)
            Positioned(
              top: 80, // Position below search input
              left: Dimens.largePadding,
              right: Dimens.largePadding,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.gray.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _predictions.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: colors.gray.withValues(alpha: 0.2),
                          ),
                          itemBuilder: (context, index) {
                            final prediction = _predictions[index];
                            return _GoogleStylePredictionTile(
                              prediction: prediction,
                              onTap: () => _selectPlace(prediction),
                              colors: colors,
                              typography: typography,
                            );
                          },
                        ),
                      ),
                      // "Powered by Google" footer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.gray.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'powered by ',
                              style: typography.bodySmall.copyWith(
                                color: colors.gray4,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Google',
                              style: typography.bodySmall.copyWith(
                                color: colors.gray4,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoogleStylePredictionTile extends StatelessWidget {
  const _GoogleStylePredictionTile({
    required this.prediction,
    required this.onTap,
    required this.colors,
    required this.typography,
  });

  final PlacePrediction prediction;
  final VoidCallback onTap;
  final dynamic colors;
  final dynamic typography;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: colors.gray4,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.mainText,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (prediction.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      prediction.secondaryText,
                      style: typography.bodySmall.copyWith(
                        color: colors.gray4,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AddressDetailRow extends StatelessWidget {
  const _AddressDetailRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
  });

  final String label;
  final String value;
  final dynamic colors;
  final dynamic typography;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: typography.bodySmall.copyWith(
                color: colors.gray4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: typography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}