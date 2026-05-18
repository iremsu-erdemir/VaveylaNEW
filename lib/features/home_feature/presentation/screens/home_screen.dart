import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/widgets/tabs/cart_tab.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/widgets/tabs/orders_tab.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/widgets/tabs/profile_tab.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/widgets/tabs/chats_tab.dart';

import '../../../../core/gen/assets.gen.dart';
import '../bloc/bottom_navigation_cubit.dart';
import '../bloc/customer_orders_cubit.dart';
import '../bloc/home_products_cubit.dart';
import '../bloc/location_cubit.dart';
import '../../data/services/products_service.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/tabs/home_tab.dart';
import '../widgets/tabs/map_tab.dart';
import '../widgets/sweet_recommendation_fab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create:
              (context) =>
                  BottomNavigationCubit(initialIndex: initialTabIndex),
        ),
        BlocProvider(create: (context) => LocationCubit()),
        BlocProvider(
          create: (context) =>
              HomeProductsCubit(ProductsService())
                ..loadProducts()
                ..startPolling(),
        ),
        BlocProvider(
          create: (context) {
            final cubit = CustomerOrdersCubit(CustomerOrderService());
            cubit.startPolling();
            return cubit;
          },
        ),
      ],
      child: const _HomeScreen(),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  bool _permissionDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationCubit>().requestLocation();
      // Giriş sonrası sepeti yeniden yükle (restoran indirimi dahil)
      context.read<CartCubit>().loadCart();
      // Siparişler sekmesi (ve ödeme sonrası yeni Home) güncel liste görsün
      context.read<CustomerOrdersCubit>().loadOrders(showLoading: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<BottomNavigationCubit>();
    final read = context.read<BottomNavigationCubit>();
    final colors = context.theme.appColors;
    final List<Widget> tabs = [
      const HomeTab(),
      const CartTab(),
      const OrdersTab(),
      const ChatsTab(),
      const MapTab(),
      const ProfileTab(),
    ];
    return BlocListener<LocationCubit, LocationState>(
      listener: (context, state) {
        if (state.status == LocationStatus.denied && !_permissionDialogShown) {
          _permissionDialogShown = true;
          if (!mounted) {
            return;
          }
          AppConfirmDialog.show(
            context,
            title: context.tr('location_permission_required'),
            message: context.tr('location_permission_message'),
            confirmText: context.tr('ok'),
            showCancel: false,
          );
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppScaffold(
            appBar: watch.state.selectedIndex == 0 ? HomeAppBar() : null,
            body: tabs[watch.state.selectedIndex],
            padding: EdgeInsets.zero,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 3,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.only(top: 8, left: 8, right: 8),
              child: NavigationBar(
                selectedIndex: watch.state.selectedIndex,
                onDestinationSelected: (final int index) {
                  read.onItemTap(index: index);
                  // Sepet sekmesine geçildiğinde hesaplamayı yenile (restoran indirimi dahil)
                  if (index == 1) {
                    context.read<CartCubit>().loadCart();
                  }
                  // Siparişler sekmesi: yeni sipariş / durum güncellemesi için listeyi yenile
                  if (index == 2) {
                    context
                        .read<CustomerOrdersCubit>()
                        .loadOrders(showLoading: true);
                  }
                },
                destinations: [
                  NavigationDestination(
                    icon: AppSvgViewer(Assets.icons.home2),
                    selectedIcon: AppSvgViewer(
                      Assets.icons.home2,
                      color: colors.primary,
                    ),
                    label: context.tr('home'),
                  ),
                  NavigationDestination(
                    icon: AppSvgViewer(Assets.icons.shoppingCart),
                    selectedIcon: AppSvgViewer(
                      Assets.icons.shoppingCart,
                      color: colors.primary,
                    ),
                    label: context.tr('cart'),
                  ),
                  NavigationDestination(
                    icon: AppSvgViewer(Assets.icons.receipt),
                    selectedIcon: AppSvgViewer(
                      Assets.icons.receipt,
                      color: colors.primary,
                    ),
                    label: context.tr('orders'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    selectedIcon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: colors.primary,
                    ),
                    label: 'Sohbet',
                  ),
                  NavigationDestination(
                    icon: AppSvgViewer(Assets.icons.map1),
                    selectedIcon: AppSvgViewer(
                      Assets.icons.map1,
                      color: colors.primary,
                    ),
                    label: context.tr('map'),
                  ),
                  NavigationDestination(
                    icon: AppSvgViewer(Assets.icons.user),
                    selectedIcon: AppSvgViewer(
                      Assets.icons.user,
                      color: colors.primary,
                    ),
                    label: context.tr('profile'),
                  ),
                ],
              ),
            ),
          ),
          if (watch.state.selectedIndex == 0)
            Positioned(
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 84,
              child: SweetRecommendationFab(parentContext: context),
            ),
        ],
      ),
    );
  }
}
