import 'package:flutter/material.dart';

import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';

enum EdmmIconActionEmphasis { standard, prominent }

class EdmmIconAction extends StatelessWidget {
  const EdmmIconAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected,
    this.selectedIcon,
    this.emphasis = EdmmIconActionEmphasis.standard,
    this.actionKey,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool? selected;
  final IconData? selectedIcon;
  final EdmmIconActionEmphasis emphasis;
  final Key? actionKey;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    assert(label.trim().isNotEmpty, 'EdmmIconAction requires a label.');
    final colors = Theme.of(context).edmm;
    final dimension = emphasis == EdmmIconActionEmphasis.prominent
        ? EdmmSizes.prominentAction
        : EdmmSizes.minTouchTarget;
    final isSelected = selected == true;

    final backgroundColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return colors.surfaceRaised;
      }
      if (states.contains(WidgetState.focused) || isSelected) {
        return colors.surfaceRose;
      }
      if (emphasis == EdmmIconActionEmphasis.prominent) {
        return colors.brand;
      }
      return Colors.transparent;
    });
    final foregroundColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return colors.disabledContent;
      }
      if (states.contains(WidgetState.focused)) {
        return colors.textPrimary;
      }
      if (isSelected) {
        return colors.brand;
      }
      if (emphasis == EdmmIconActionEmphasis.prominent) {
        return colors.onBrand;
      }
      return colors.textPrimary;
    });
    final side = WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: colors.focusRing, width: 2);
      }
      return const BorderSide(color: Colors.transparent, width: 2);
    });
    final overlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return colors.brand.withValues(alpha: 0.16);
      }
      if (states.contains(WidgetState.hovered)) {
        return colors.brand.withValues(alpha: 0.08);
      }
      return Colors.transparent;
    });

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: IconButton(
          key: actionKey,
          tooltip: label,
          focusNode: focusNode,
          autofocus: autofocus,
          onPressed: onPressed,
          icon: Icon(isSelected ? selectedIcon ?? icon : icon),
          iconSize: emphasis == EdmmIconActionEmphasis.prominent ? 32 : 24,
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size.square(dimension)),
            fixedSize: WidgetStatePropertyAll(Size.square(dimension)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            overlayColor: overlayColor,
            side: side,
            shape: const WidgetStatePropertyAll(CircleBorder()),
          ),
        ),
      ),
    );
  }
}
