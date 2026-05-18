import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/check_theme_status.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';

import '../orders_list_widget.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    return AppScaffold(
      appBar: GeneralAppBar(
        title: context.tr('my_orders'),
        showBackIcon: false,
        height: AppBar().preferredSize.height + 56,
        bottom: TabBar(
          controller: _tabController,
          dividerColor: appColors.gray,
          labelColor: appColors.primary,
          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          unselectedLabelColor:
              checkDarkMode(context) ? appColors.white : appColors.black,
          indicatorColor: appColors.primary,
          tabs: [
            Tab(child: Text(context.tr('active'))),
            Tab(child: Text(context.tr('completed'))),
            Tab(child: Text(context.tr('canceled'))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OrdersListWidget(orderType: OrderType.active),
          OrdersListWidget(orderType: OrderType.completed),
          OrdersListWidget(orderType: OrderType.canceled),
        ],
      ),
    );
  }
}
