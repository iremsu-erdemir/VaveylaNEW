import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/product_stats_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';

enum TopProductsPeriod { all, weekly, monthly }

extension TopProductsPeriodX on TopProductsPeriod {
  String get apiValue {
    switch (this) {
      case TopProductsPeriod.all:
        return 'all';
      case TopProductsPeriod.weekly:
        return 'weekly';
      case TopProductsPeriod.monthly:
        return 'monthly';
    }
  }
}

class RestaurantTopProductsState {
  const RestaurantTopProductsState({
    this.isLoading = false,
    this.stats,
    this.error,
    this.period = TopProductsPeriod.all,
  });

  final bool isLoading;
  final ProductStats? stats;
  final String? error;
  final TopProductsPeriod period;

  RestaurantTopProductsState copyWith({
    bool? isLoading,
    ProductStats? stats,
    String? error,
    TopProductsPeriod? period,
  }) {
    return RestaurantTopProductsState(
      isLoading: isLoading ?? this.isLoading,
      stats: stats ?? this.stats,
      error: error,
      period: period ?? this.period,
    );
  }
}

class RestaurantTopProductsCubit extends Cubit<RestaurantTopProductsState> {
  RestaurantTopProductsCubit(
    this._service,
    this._ownerUserId,
  ) : super(const RestaurantTopProductsState());

  final RestaurantOwnerService _service;
  final String _ownerUserId;

  Future<void> load() async {
    if (_ownerUserId.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Owner user id bulunamadı.',
          stats: null,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final settings = await _service.getSettings(ownerUserId: _ownerUserId);
      final restaurantId = settings.restaurantId;
      if (restaurantId.isEmpty) {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Restoran bilgisi bulunamadı.',
            stats: null,
          ),
        );
        return;
      }

      final stats = await _service.getTopProducts(
        restaurantId: restaurantId,
        period: state.period.apiValue,
      );

      emit(
        state.copyWith(
          isLoading: false,
          stats: stats,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: e.toString(),
          stats: null,
        ),
      );
    }
  }

  Future<void> setPeriod(TopProductsPeriod period) async {
    if (period == state.period) {
      return;
    }
    emit(state.copyWith(period: period));
    await load();
  }
}

