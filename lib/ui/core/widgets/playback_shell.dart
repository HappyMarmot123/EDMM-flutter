import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/audio/audio_controller.dart';
import '../../../domain/repositories/local_library_repository.dart';
import '../../../domain/telemetry/playback_telemetry.dart';
import '../../player/view_model/player_view_model.dart';
import '../../player/widgets/player_mini_bar.dart';
import '../../player/widgets/player_sheet.dart';

class PlaybackShell extends StatefulWidget {
  const PlaybackShell({
    super.key,
    required this.child,
    required this.audio,
    required this.localLibrary,
    required this.telemetry,
  });

  final Widget child;
  final AudioController audio;
  final LocalLibraryRepository localLibrary;
  final PlaybackTelemetrySink telemetry;

  @override
  State<PlaybackShell> createState() => _PlaybackShellState();
}

class _PlaybackShellState extends State<PlaybackShell> {
  late PlayerViewModel _miniPlayerViewModel = _createViewModel();
  PlayerViewModel? _sheetViewModel;
  final Set<PlayerViewModel> _retiredViewModels = <PlayerViewModel>{};
  final Set<PlayerViewModel> _disposedViewModels = <PlayerViewModel>{};

  PlayerViewModel _createViewModel() => PlayerViewModel(
    widget.audio,
    localLibrary: widget.localLibrary,
    telemetry: widget.telemetry,
  );

  @override
  void didUpdateWidget(covariant PlaybackShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.audio, widget.audio) ||
        !identical(oldWidget.localLibrary, widget.localLibrary) ||
        !identical(oldWidget.telemetry, widget.telemetry)) {
      final previous = _miniPlayerViewModel;
      _miniPlayerViewModel = _createViewModel();
      if (identical(previous, _sheetViewModel)) {
        _retiredViewModels.add(previous);
      } else {
        _disposeViewModel(previous);
      }
    }
  }

  @override
  void dispose() {
    _disposeViewModel(_miniPlayerViewModel);
    for (final viewModel in _retiredViewModels) {
      _disposeViewModel(viewModel);
    }
    super.dispose();
  }

  void _openPlayer() {
    if (_sheetViewModel != null) return;
    final viewModel = _miniPlayerViewModel;
    _sheetViewModel = viewModel;
    unawaited(
      showPlayerSheet(
        context,
        viewModel: viewModel,
        disposeViewModel: false,
      ).whenComplete(() {
        if (identical(_sheetViewModel, viewModel)) {
          _sheetViewModel = null;
        }
        if (!identical(_miniPlayerViewModel, viewModel)) {
          _retiredViewModels.remove(viewModel);
          _disposeViewModel(viewModel);
        }
      }),
    );
  }

  void _disposeViewModel(PlayerViewModel viewModel) {
    if (_disposedViewModels.add(viewModel)) {
      viewModel.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: PlayerMiniBar(
        viewModel: _miniPlayerViewModel,
        onOpenPlayer: _openPlayer,
      ),
    );
  }
}
