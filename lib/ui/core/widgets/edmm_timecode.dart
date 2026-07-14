import 'package:flutter/material.dart';

import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';

String formatEdmmTimecode(Duration value) {
  final duration = value.isNegative ? Duration.zero : value;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours}:$minutes:$seconds';
  }
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class EdmmTimecode extends StatelessWidget {
  const EdmmTimecode({
    super.key,
    required this.value,
    this.semanticLabel,
    this.textAlign,
  });

  final Duration value;
  final String? semanticLabel;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final formatted = formatEdmmTimecode(value);
    return Semantics(
      label: semanticLabel ?? formatted,
      child: ExcludeSemantics(
        child: Text(
          formatted,
          textAlign: textAlign,
          style: EdmmTypography.timeData.copyWith(
            color: Theme.of(context).edmm.textMuted,
          ),
        ),
      ),
    );
  }
}
