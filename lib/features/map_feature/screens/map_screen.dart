import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/flutter_map_widget.dart';
import '../../../core/widgets/general_app_bar.dart';
import '../data/services/map_shops_service.dart';
import '../models/sweet_shop.dart';
import '../widgets/stores_on_map_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _cardWidth = StoresOnMapScreen.cardWidth;
  static const double _cardLeftMargin = 16;
  static const LatLng _defaultCenter = LatLng(41.6757164, 26.5547864);
  late final MapController _mapController;
  late final ScrollController _storesScrollController;
  late final MapShopsService _shopsService;
  bool _isLoading = true;
  String? _error;
  List<SweetShop> _stores = const [];
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _storesScrollController = ScrollController();
    _shopsService = MapShopsService();
    _loadShops();
  }

  @override
  void dispose() {
    _storesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stores = await _shopsService.getShops();
      if (!mounted) return;
      if (stores.isEmpty) {
        setState(() {
          _stores = const [];
          _selectedStoreId = null;
          _isLoading = false;
        });
        return;
      }
      final selectedId = _selectedStoreId ?? stores.first.id;
      setState(() {
        _stores = stores;
        _selectedStoreId = selectedId;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToStoreCard(selectedId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Pastaneler yuklenemedi. Lutfen tekrar deneyin.';
        _isLoading = false;
      });
    }
  }

  void _onStoreSelected(SweetShop store, {bool scrollCard = true}) {
    setState(() {
      _selectedStoreId = store.id;
    });
    // Zoom only when card is explicitly tapped.
    _focusStore(store, zoom: 16.8, fromCardTap: true);
    if (scrollCard) {
      _scrollToStoreCard(store.id);
    }
  }

  void _onMarkerSelected(SweetShop store) {
    setState(() {
      _selectedStoreId = store.id;
    });
    _scrollToStoreCard(store.id);
  }

  void _focusStore(
    SweetShop store, {
    double zoom = 17.4,
    bool fromCardTap = false,
  }) {
    final point = store.location;
    if (point == null) {
      if (fromCardTap) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu pastane icin dogrulanmis konum bulunamadi.'),
          ),
        );
      }
      return;
    }
    _mapController.move(point, zoom);
  }

  void _scrollToStoreCard(String storeId) {
    if (!_storesScrollController.hasClients) return;
    final index = _stores.indexWhere((store) => store.id == storeId);
    if (index < 0) return;

    final itemExtent = _cardWidth + _cardLeftMargin;
    final itemStart = _cardLeftMargin + (index * itemExtent);
    final viewport = _storesScrollController.position.viewportDimension;
    final targetOffset = (itemStart - ((viewport - _cardWidth) / 2)).clamp(
      0.0,
      _storesScrollController.position.maxScrollExtent,
    );
    _storesScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  SweetShop? _findStoreById(String storeId) {
    for (final store in _stores) {
      if (store.id == storeId) return store;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final firstLocatedStore = _stores.cast<SweetShop?>().firstWhere(
      (store) => store?.location != null,
      orElse: () => null,
    );
    final fallbackCenter = firstLocatedStore?.location ?? _defaultCenter;

    return AppScaffold(
      appBar: GeneralAppBar(title: context.tr('map'), showBackIcon: false),
      padding: EdgeInsets.zero,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          FlutterMapWidget(
            latLng: fallbackCenter,
            initialZoom: 14.0,
            mapController: _mapController,
            markerItems: _stores
                .where((store) => store.location != null)
                .map(
                  (store) => MapMarkerItem(
                    id: store.id,
                    point: store.location!,
                    isSelected: _selectedStoreId == store.id,
                  ),
                )
                .toList(),
            onMarkerTap: (storeId) {
              final store = _findStoreById(storeId);
              if (store != null) {
                _onMarkerSelected(store);
              }
            },
          ),
          if (_isLoading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!)),
                      TextButton(onPressed: _loadShops, child: const Text('Tekrar Dene')),
                    ],
                  ),
                ),
              ),
            )
          else if (_stores.isNotEmpty)
            StoresOnMapScreen(
              stores: _stores,
              selectedStoreId: _selectedStoreId,
              scrollController: _storesScrollController,
              onStoreTap: (store) => _onStoreSelected(store, scrollCard: false),
            )
          else
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Gosterilecek pastane bulunamadi.')),
                      TextButton(onPressed: _loadShops, child: const Text('Yenile')),
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
