import 'package:flutter/material.dart';

import '../themes/edmm_theme_tokens.dart';

class EdmmFilterPill extends StatelessWidget {
  const EdmmFilterPill({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
    this.showCount = true,
    this.focusNode,
    this.autofocus = false,
  }) : assert(count >= 0, 'EdmmFilterPill count cannot be negative.');

  final String label;
  final int count;
  final bool selected;
  final VoidCallback? onPressed;
  final bool showCount;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    assert(label.trim().isNotEmpty, 'EdmmFilterPill requires a label.');
    final visibleLabel = showCount ? '$label ($count)' : label;

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: visibleLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: EdmmSizes.minTouchTarget,
          ),
          child: ChoiceChip(
            focusNode: focusNode,
            autofocus: autofocus,
            selected: selected,
            onSelected: onPressed == null ? null : (_) => onPressed!(),
            label: Text(
              visibleLabel,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }
}
