import 'package:flutter/material.dart';

import '../layout/edmm_breakpoints.dart';

enum EdmmContentWidth { standard, wide }

class EdmmContentLayout extends StatelessWidget {
  const EdmmContentLayout({
    super.key,
    required this.child,
    this.width = EdmmContentWidth.wide,
  });

  final Widget child;
  final EdmmContentWidth width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final gutter = EdmmBreakpoints.gutterFor(availableWidth);
        final maxWidth = switch (width) {
          EdmmContentWidth.standard => EdmmBreakpoints.standardContentMaxWidth,
          EdmmContentWidth.wide => EdmmBreakpoints.wideContentMaxWidth,
        };

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SizedBox(
                key: const Key('edmm-content-frame'),
                width: double.infinity,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
