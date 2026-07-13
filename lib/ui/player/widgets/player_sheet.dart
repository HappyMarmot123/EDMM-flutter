import 'package:flutter/material.dart';

import '../view_model/player_view_model.dart';
import 'player_screen.dart';

/// Presents the full player as a draggable modal sheet over the catalog list.
///
/// Because it is a modal (not a pushed route), the catalog list stays mounted
/// and shows through the scrim behind the sheet; dragging the sheet down follows
/// the finger and dismisses it. [viewModel] is owned by the sheet — the embedded
/// [PlayerScreen] disposes it when the sheet closes unless [disposeViewModel]
/// is false for a view model shared with the persistent mini player.
Future<void> showPlayerSheet(
  BuildContext context, {
  required PlayerViewModel viewModel,
  bool disposeViewModel = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final height = MediaQuery.of(sheetContext).size.height;
      return SizedBox(
        height: height * 0.9,
        child: PlayerScreen(
          viewModel: viewModel,
          disposeViewModel: disposeViewModel,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      );
    },
  );
}
