import 'package:flutter_bloc/flutter_bloc.dart';

class CourierNavCubit extends Cubit<int> {
  CourierNavCubit() : super(0);

  void onItemTap(int index) {
    emit(index);
  }
}
