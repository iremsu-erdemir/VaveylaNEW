import 'package:flutter_bloc/flutter_bloc.dart';

class RestaurantOwnerNavCubit extends Cubit<int> {
  RestaurantOwnerNavCubit() : super(0);

  void onItemTap(int index) {
    emit(index);
  }
}
