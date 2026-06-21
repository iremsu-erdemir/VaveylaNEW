import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';

class CategoryProductsState {
  const CategoryProductsState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ProductModel> products;
  final bool isLoading;
  final String? error;
}

class CategoryProductsCubit extends Cubit<CategoryProductsState> {
  CategoryProductsCubit(this._service) : super(const CategoryProductsState());

  final ProductsService _service;

  Future<void> loadProducts(String category) async {
    emit(const CategoryProductsState(isLoading: true));
    try {
      final products = await _service.getProducts(category: category);
      emit(CategoryProductsState(products: products, isLoading: false));
    } catch (e) {
      emit(CategoryProductsState(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
