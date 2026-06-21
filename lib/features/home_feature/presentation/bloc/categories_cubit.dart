import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';

class CategoriesState {
  const CategoriesState({
    this.productsByCategory = const {},
    this.isLoading = false,
    this.error,
  });

  final Map<String, List<ProductModel>> productsByCategory;
  final bool isLoading;
  final String? error;

  List<ProductModel> productsForCategory(String category) {
    return productsByCategory[category] ?? [];
  }

  CategoriesState copyWith({
    Map<String, List<ProductModel>>? productsByCategory,
    bool? isLoading,
    String? error,
  }) {
    return CategoriesState(
      productsByCategory: productsByCategory ?? this.productsByCategory,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._service) : super(const CategoriesState());

  final ProductsService _service;

  Future<void> loadProducts() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final all = await _service.getProducts();
      final byCategory = <String, List<ProductModel>>{};
      for (final p in all) {
        final cat = p.categoryName?.trim() ?? 'Diğer';
        byCategory.putIfAbsent(cat, () => []).add(p);
      }
      emit(CategoriesState(
        productsByCategory: byCategory,
        isLoading: false,
      ));
    } catch (e) {
      emit(CategoriesState(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
