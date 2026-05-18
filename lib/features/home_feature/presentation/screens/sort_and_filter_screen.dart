import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/general_app_bar.dart';
import '../models/products_filter.dart';

enum SortAndFilterMode { both, filterOnly, sortOnly }

class SortAndFilterScreen extends StatefulWidget {
  const SortAndFilterScreen({
    super.key,
    required this.categories,
    required this.initialSort,
    this.initialCategory,
    this.mode = SortAndFilterMode.both,
  });

  final List<String> categories;
  final ProductSortOption initialSort;
  final String? initialCategory;
  final SortAndFilterMode mode;

  @override
  State<SortAndFilterScreen> createState() => _SortAndFilterScreenState();
}

class _SortAndFilterScreenState extends State<SortAndFilterScreen> {
  late ProductSortOption _selectedSort;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSort;
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final appTypography = context.theme.appTypography;
    final allCategories = ['Tümü', ...widget.categories];
    final showSort =
        widget.mode == SortAndFilterMode.both ||
        widget.mode == SortAndFilterMode.sortOnly;
    final showFilter =
        widget.mode == SortAndFilterMode.both ||
        widget.mode == SortAndFilterMode.filterOnly;
    final title = switch (widget.mode) {
      SortAndFilterMode.filterOnly => 'Filtrele',
      SortAndFilterMode.sortOnly => 'Sırala',
      SortAndFilterMode.both => 'Sırala ve Filtrele',
    };
    return AppScaffold(
      appBar: GeneralAppBar(title: title),
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        child: Column(
          spacing: Dimens.largePadding,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox.shrink(),
            if (showSort) ...[
              _SectionTitle(title: 'Sırala'),
              _SelectableChipsRow<ProductSortOption>(
                values: ProductSortOption.values,
                selected: _selectedSort,
                labelBuilder: (x) => x.label,
                onSelected: (value) => setState(() => _selectedSort = value),
              ),
            ],
            if (showSort && showFilter)
              const Divider(
                indent: Dimens.largePadding,
                endIndent: Dimens.largePadding,
              ),
            if (showFilter) ...[
              _SectionTitle(title: 'Kategoriler'),
              _SelectableChipsRow<String>(
                values: allCategories,
                selected: _selectedCategory ?? 'Tümü',
                labelBuilder: (x) => x,
                onSelected: (value) {
                  setState(() {
                    _selectedCategory = value == 'Tümü' ? null : value;
                  });
                },
              ),
            ],
            if (showSort || showFilter)
              const Divider(
                indent: Dimens.largePadding,
                endIndent: Dimens.largePadding,
              ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: Dimens.largePadding,
          right: Dimens.largePadding,
          bottom: Dimens.padding,
        ),
        child: AppButton(
          onPressed: () {
            Navigator.of(context).pop(
              ProductsFilter(
                sort: _selectedSort,
                category: _selectedCategory,
              ),
            );
          },
          title: 'Filtreyi uygula',
          textStyle: appTypography.bodyLarge,
          borderRadius: Dimens.corners,
          margin: EdgeInsets.symmetric(vertical: Dimens.largePadding),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
      child: Text(
        title,
        style: context.theme.appTypography.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SelectableChipsRow<T> extends StatelessWidget {
  const _SelectableChipsRow({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
        separatorBuilder: (_, __) => const SizedBox(width: Dimens.padding),
        itemBuilder: (context, index) {
          final value = values[index];
          final isSelected = value == selected;
          return ChoiceChip(
            label: Text(labelBuilder(value)),
            selected: isSelected,
            onSelected: (_) => onSelected(value),
            selectedColor: colors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: isSelected ? colors.primary : colors.black,
            ),
            side: BorderSide(color: isSelected ? colors.primary : colors.gray2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimens.corners),
            ),
            showCheckmark: false,
            visualDensity: const VisualDensity(vertical: -2, horizontal: -2),
          );
        },
      ),
    );
  }
}
