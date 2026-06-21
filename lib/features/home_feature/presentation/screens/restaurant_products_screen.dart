import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/customer_review_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/customer_review_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/all_products_cubit.dart';
import 'product_details_screen.dart';
import '../widgets/product_card.dart';

class RestaurantProductsScreen extends StatelessWidget {
  static const _closedRestaurantMessage =
      'Bu pastane şu anda hizmet verememektedir.';

  const RestaurantProductsScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  final String restaurantId;
  final String restaurantName;

  Future<void> _showRestaurantReviewSheet(BuildContext context) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      context.showErrorMessage('Yorum için giriş yapmalısınız.');
      return;
    }

    final service = CustomerReviewService();
    final commentController = TextEditingController();
    var rating = 5;
    var existingReviews = <CustomerReviewModel>[];
    try {
      final loaded = await service.getReviews(
        targetType: 'restaurant',
        targetId: restaurantId,
        restaurantId: restaurantId,
        page: 1,
        pageSize: 5,
      );
      existingReviews = loaded.items;
    } catch (_) {}

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: Dimens.largePadding,
            right: Dimens.largePadding,
            top: Dimens.largePadding,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom +
                Dimens.largePadding,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pastaneyi Değerlendir',
                    style: context.theme.appTypography.titleMedium,
                  ),
                  const SizedBox(height: Dimens.padding),
                  Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        icon: Icon(
                          star <= rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => setSheetState(() => rating = star),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Yorumunuz'),
                  ),
                  if (existingReviews.isNotEmpty) ...[
                    const SizedBox(height: Dimens.padding),
                    Text(
                      'Mevcut Yorumlar',
                      style: context.theme.appTypography.titleSmall,
                    ),
                    const SizedBox(height: Dimens.smallPadding),
                    ...existingReviews.map((review) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: Dimens.smallPadding,
                        ),
                        child: Text(
                          '${review.customerName}: ${review.comment}',
                          style: context.theme.appTypography.bodySmall,
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: Dimens.padding),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      title: 'Gönder',
                      margin: EdgeInsets.zero,
                      onPressed: () async {
                        final comment = commentController.text.trim();
                        if (comment.isEmpty) return;
                        try {
                          await service.createReview(
                            customerUserId: userId,
                            restaurantId: restaurantId,
                            targetType: 'restaurant',
                            targetId: restaurantId,
                            rating: rating,
                            comment: comment,
                            customerName: AppSession.fullName,
                          );
                          if (!context.mounted) return;
                          Navigator.of(sheetContext).pop();
                          context.showSuccessMessage(
                            'Pastane yorumu kaydedildi.',
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          context.showErrorMessage(error);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              AllProductsCubit(ProductsService())
                ..loadProducts(restaurantId: restaurantId)
                ..startPolling(),
      child: AppScaffold(
        appBar: GeneralAppBar(
          title: restaurantName,
          actions: [
            IconButton(
              tooltip: 'Pastaneyi değerlendir',
              icon: const Icon(Icons.star_rate_rounded),
              onPressed: () => _showRestaurantReviewSheet(context),
            ),
          ],
        ),
        body: BlocBuilder<AllProductsCubit, AllProductsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.products.isEmpty) {
              return const Center(child: Text('Bu pastanede ürün yok.'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(Dimens.largePadding),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Dimens.largePadding,
                crossAxisSpacing: Dimens.largePadding,
                childAspectRatio: 0.65,
              ),
              itemCount: state.products.length,
              itemBuilder: (context, index) {
                final product = state.products[index];
                final isRestaurantOpen = product.restaurantIsOpen;
                return InkWell(
                  onTap: () {
                    if (!isRestaurantOpen) {
                      context.showErrorMessage(_closedRestaurantMessage);
                      return;
                    }
                    appPush(context, ProductDetailsScreen(product: product));
                  },
                  borderRadius: BorderRadius.circular(Dimens.corners),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProductCard(product: product),
                      if (!isRestaurantOpen)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.grey.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: Dimens.padding,
                        right: Dimens.padding,
                        child: Visibility(
                          visible: !isRestaurantOpen,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimens.smallPadding,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(
                                Dimens.smallCorners,
                              ),
                            ),
                            child: Text(
                              'Kapalı',
                              style: context.theme.appTypography.labelSmall
                                  .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
