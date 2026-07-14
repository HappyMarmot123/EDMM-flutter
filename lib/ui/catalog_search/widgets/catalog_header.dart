import 'package:flutter/material.dart';

import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_filter_pill.dart';
import '../../core/widgets/edmm_section_label.dart';

class CatalogHeader extends StatelessWidget {
  const CatalogHeader({
    super.key,
    required this.appTitle,
    required this.screenTitle,
    required this.searchLabel,
    required this.searchController,
    required this.onQueryChanged,
    required this.popLabel,
    required this.popCount,
    required this.popSelected,
    required this.onPopSelected,
    required this.edmLabel,
    required this.edmCount,
    required this.edmSelected,
    required this.onEdmSelected,
    required this.recentLabel,
    required this.recentCount,
    required this.recentSelected,
    required this.onRecentSelected,
  });

  final String appTitle;
  final String screenTitle;
  final String searchLabel;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final String popLabel;
  final int popCount;
  final bool popSelected;
  final VoidCallback onPopSelected;
  final String edmLabel;
  final int edmCount;
  final bool edmSelected;
  final VoidCallback onEdmSelected;
  final String recentLabel;
  final int recentCount;
  final bool recentSelected;
  final VoidCallback onRecentSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;

    return Padding(
      padding: const EdgeInsets.only(
        top: EdmmSpacing.lg,
        bottom: EdmmSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    appTitle,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: EdmmTypography.display.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EdmmSpacing.xxs),
          EdmmSectionLabel(label: screenTitle, isHeader: true),
          const SizedBox(height: EdmmSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: EdmmSizes.minTouchTarget,
            ),
            child: TextField(
              key: const Key('catalog-search-field'),
              controller: searchController,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: searchLabel,
                prefixIcon: const Icon(Icons.search),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: EdmmSizes.minTouchTarget,
                  minHeight: EdmmSizes.minTouchTarget,
                ),
              ),
            ),
          ),
          const SizedBox(height: EdmmSpacing.md),
          Wrap(
            key: const Key('catalog-filter-wrap'),
            spacing: EdmmSpacing.sm,
            runSpacing: EdmmSpacing.sm,
            children: <Widget>[
              EdmmFilterPill(
                key: const Key('catalog-tab-pop'),
                label: popLabel,
                count: popCount,
                selected: popSelected,
                onPressed: onPopSelected,
                showCount: popSelected,
              ),
              EdmmFilterPill(
                key: const Key('catalog-tab-edm'),
                label: edmLabel,
                count: edmCount,
                selected: edmSelected,
                onPressed: onEdmSelected,
                showCount: edmSelected,
              ),
              EdmmFilterPill(
                key: const Key('catalog-tab-recent'),
                label: recentLabel,
                count: recentCount,
                selected: recentSelected,
                onPressed: onRecentSelected,
                showCount: recentSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
