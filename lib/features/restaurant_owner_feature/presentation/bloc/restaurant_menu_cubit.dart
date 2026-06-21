import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/menu_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';

class RestaurantMenuCubit extends Cubit<List<MenuItemModel>> {
  RestaurantMenuCubit(this._service, this._ownerUserId) : super(const []);

  final RestaurantOwnerService _service;
  final String _ownerUserId;

  Future<void> loadMenu() async {
    final items = await _service.getMenu(ownerUserId: _ownerUserId);
    emit(items);
  }

  void addItem(MenuItemModel item) {
    emit([...state, item]);
  }

  void updateItem(
    String id, {
    String? name,
    int? price,
    String? imagePath,
    String? categoryName,
    bool? isAvailable,
    bool? isFeatured,
  }) {
    emit(state.map((item) {
      if (item.id != id) return item;
      final newImagePath = imagePath != null ? imagePath : item.imagePath;
      return item.copyWith(
        name: name ?? item.name,
        price: price ?? item.price,
        imagePath: newImagePath,
        categoryName: categoryName ?? item.categoryName,
        isAvailable: isAvailable ?? item.isAvailable,
        isFeatured: isFeatured ?? item.isFeatured,
      );
    }).toList());
  }

  void removeItem(String id) {
    emit(state.where((item) => item.id != id).toList());
  }

  void toggleAvailability(String id) {
    emit(state.map((item) {
      if (item.id != id) return item;
      return item.copyWith(isAvailable: !item.isAvailable);
    }).toList());
  }

  Future<void> addMenuItem({
    required String name,
    required int price,
    required String imagePath,
    String? categoryName,
    required bool isFeatured,
    int saleUnit = 0,
  }) async {
    final created = await _service.createMenuItem(
      ownerUserId: _ownerUserId,
      name: name,
      price: price,
      imagePath: imagePath,
      categoryName: categoryName,
      isAvailable: true,
      isFeatured: isFeatured,
      saleUnit: saleUnit,
    );
    emit([...state, created]);
  }

  Future<void> updateMenuItemRemote(
    String id, {
    String? name,
    int? price,
    String? imagePath,
    String? categoryName,
    bool? isAvailable,
    bool? isFeatured,
    int? saleUnit,
  }) async {
    final updated = await _service.updateMenuItem(
      ownerUserId: _ownerUserId,
      id: id,
      name: name,
      price: price,
      imagePath: imagePath,
      categoryName: categoryName,
      isAvailable: isAvailable,
      isFeatured: isFeatured,
      saleUnit: saleUnit,
    );
    emit(state.map((item) => item.id == id ? updated : item).toList());
  }

  Future<void> deleteMenuItemRemote(String id) async {
    await _service.deleteMenuItem(ownerUserId: _ownerUserId, id: id);
    emit(state.where((item) => item.id != id).toList());
  }

  Future<void> toggleAvailabilityRemote(String id, bool current) async {
    final updated = await _service.updateMenuItem(
      ownerUserId: _ownerUserId,
      id: id,
      isAvailable: !current,
    );
    emit(state.map((item) => item.id == id ? updated : item).toList());
  }
}
