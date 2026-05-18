import 'package:flutter_bloc/flutter_bloc.dart';

/// Panelden Siparişler sekmesine geçerken hangi alt sekmeyi göstereceğini tutar:
/// 0 Bekleyen, 1 Yolda, 2 Teslim, 3 Reddedilenler.
class CourierOrdersTabCubit extends Cubit<int> {
  CourierOrdersTabCubit() : super(0);

  static const int maxTabIndex = 3;

  void selectTab(int index) {
    emit(index.clamp(0, maxTabIndex));
  }
}
