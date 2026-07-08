import 'package:flutter/material.dart';

import '../../../domain/audio/audio_controller.dart';
import '../../../domain/logic/deep_link_track_loader.dart';
import '../../../domain/repositories/local_library_repository.dart';
import '../../../domain/repositories/track_repository.dart';
import '../../../domain/telemetry/playback_telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/player_view_model.dart';
import 'player_screen.dart';

class TrackDeepLinkScreen extends StatefulWidget {
  const TrackDeepLinkScreen({
    super.key,
    required this.trackId,
    required this.trackRepository,
    required this.localLibrary,
    required this.audio,
    required this.telemetry,
  });

  final String trackId;
  final TrackRepository trackRepository;
  final LocalLibraryRepository localLibrary;
  final AudioController audio;
  final PlaybackTelemetrySink telemetry;

  @override
  State<TrackDeepLinkScreen> createState() => _TrackDeepLinkScreenState();
}

class _TrackDeepLinkScreenState extends State<TrackDeepLinkScreen> {
  bool? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await loadDeepLinkedTrack(
      trackId: widget.trackId,
      trackRepository: widget.trackRepository,
      localLibrary: widget.localLibrary,
      audio: widget.audio,
    );
    if (!mounted) return;
    setState(() => _loaded = loaded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loaded = _loaded;

    if (loaded == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.nowPlaying)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.nowPlaying)),
        body: Center(child: Text(l10n.tracksLoadError)),
      );
    }

    return PlayerScreen(
      viewModel: PlayerViewModel(
        widget.audio,
        localLibrary: widget.localLibrary,
        telemetry: widget.telemetry,
      ),
    );
  }
}
