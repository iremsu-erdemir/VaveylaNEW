import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';

class HomeProductsState {
  const HomeProductsState({
    this.allProducts = const [],
    this.featured = const [],
    this.newProducts = const [],
    this.popular = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ProductModel> allProducts;
  final List<ProductModel> featured;
  final List<ProductModel> newProducts;
  final List<ProductModel> popular;
  final bool isLoading;
  final String? error;

  HomeProductsState copyWith({
    List<ProductModel>? allProducts,
    List<ProductModel>? featured,
    List<ProductModel>? newProducts,
    List<ProductModel>? popular,
    bool? isLoading,
    String? error,
  }) {
    return HomeProductsState(
      allProducts: allProducts ?? this.allProducts,
      featured: featured ?? this.featured,
      newProducts: newProducts ?? this.newProducts,
      popular: popular ?? this.popular,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HomeProductsCubit extends Cubit<HomeProductsState> {
  HomeProductsCubit(this._service) : super(const HomeProductsState());

  final ProductsService _service;
  Timer? _pollTimer;
  bool _loadInFlight = false;

  Future<void> loadProducts({bool showLoading = true}) async {
    if (_loadInFlight) {
      return;
    }
    _loadInFlight = true;
    if (showLoading) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final results = await Future.wait([
        _service.getProducts(),
        _service.getFeatured(),
        _service.getNew(),
        _service.getPopular(),
      ]);
      emit(state.copyWith(
        allProducts: results[0],
        featured: results[1],
        newProducts: results[2],
        popular: results[3],
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    } finally {
      _loadInFlight = false;
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      loadProducts(showLoading: false);
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
