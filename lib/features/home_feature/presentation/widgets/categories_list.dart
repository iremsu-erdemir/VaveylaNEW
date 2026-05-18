import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/home_products_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/data_source/local/sample_data.dart';

class CategoriesList extends StatelessWidget {
  const CategoriesList({super.key, required this.onCategoryTap});

  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return BlocBuilder<HomeProductsCubit, HomeProductsState>(
      builder: (context, state) {
        final products = [
          ...state.allProducts,
        ];
        final categories = products
            .map((x) => x.categoryName?.trim() ?? '')
            .where((x) => x.isNotEmpty)
            .toSet()
            .toList();
        if (categories.isEmpty) {
          categories.addAll(titlesOfCategories.take(4));
        }

        return SizedBox(
          height: 120,
          child: ListView.builder(
            itemCount: categories.length,
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemBuilder: (final context, final index) {
              final category = categories[index];
              final imagePath = imagesOfCategories[index % imagesOfCategories.length];
              return InkWell(
                onTap: () => onCategoryTap(category),
                borderRadius: BorderRadius.circular(100),
                child: Column(
                  spacing: Dimens.padding,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: context.theme.scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(Dimens.largePadding),
                      margin: EdgeInsets.symmetric(
                        horizontal:
                            index == 0 ? Dimens.largePadding : Dimens.padding,
                      ),
                      child: Center(child: Image.asset(imagePath)),
                    ),
                    Text(category),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
