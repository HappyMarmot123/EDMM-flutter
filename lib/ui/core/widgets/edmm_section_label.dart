import 'package:flutter/material.dart';

import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';

class EdmmSectionLabel extends StatelessWidget {
  const EdmmSectionLabel({
    super.key,
    required this.label,
    this.isHeader = false,
    this.textAlign,
  });

  final String label;
  final bool isHeader;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: textAlign,
      softWrap: true,
      style: EdmmTypography.utilityLabel.copyWith(
        color: Theme.of(context).edmm.brand,
      ),
    );

    if (!isHeader) {
      return text;
    }
    return Semantics(header: true, child: text);
  }
}
