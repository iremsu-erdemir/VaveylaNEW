import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';

class AllProductsState {
  const AllProductsState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ProductModel> products;
  final bool isLoading;
  final String? error;
}

class AllProductsCubit extends Cubit<AllProductsState> {
  AllProductsCubit(this._service) : super(const AllProductsState());

  final ProductsService _service;
  Timer? _pollTimer;
  String? _lastCategory;
  String? _lastRestaurantId;
  String? _lastType;

  Future<void> loadProducts({
    String? category,
    String? restaurantId,
    String? type,
    bool showLoading = true,
  }) async {
    _lastCategory = category;
    _lastRestaurantId = restaurantId;
    _lastType = type;
    if (showLoading) {
      emit(AllProductsState(isLoading: true, error: null));
    }
    try {
      final products = await _service.getProducts(
        category: category,
        restaurantId: restaurantId,
        type: type,
      );
      emit(AllProductsState(products: products, isLoading: false, error: null));
    } catch (e) {
      emit(AllProductsState(isLoading: false, error: e.toString()));
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      loadProducts(
        category: _lastCategory,
        restaurantId: _lastRestaurantId,
        type: _lastType,
        showLoading: false,
      );
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
