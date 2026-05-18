import 'package:bloc/bloc.dart';

part 'bottom_navigation_state.dart';

class BottomNavigationCubit extends Cubit<BottomNavigationState> {
  BottomNavigationCubit({int initialIndex = 0})
    : super(BottomNavigationState(selectedIndex: initialIndex));

  void onItemTap({required final int index}) {
    emit(state.copyWith(selectedIndex: index));
  }
}
