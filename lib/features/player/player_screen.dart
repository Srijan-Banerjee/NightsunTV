import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/catalog.dart' show CatalogCountry;
import '../../data/models/channel.dart';
import '../../data/models/stream_source.dart';
import '../../state/library_controller.dart';
import '../../state/prefs.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../epg/epg_guide_sheet.dart';

/// Screen aspect ratio and sizing modes for live video streams.
enum VideoFitMode {
  contain(
    label: 'Contain',
    description: 'Original aspect ratio with letterboxing',
    icon: Icons.fit_screen_rounded,
    badge: 'FIT',
  ),
  cover(
    label: 'Cover',
    description: 'Zoom and fill entire screen (no black bars)',
    icon: Icons.crop_free_rounded,
    badge: 'CROP',
  ),
  stretch(
    label: 'Stretch',
    description: 'Stretch full screen to display edges',
    icon: Icons.fullscreen_rounded,
    badge: 'STRETCH',
  );

  const VideoFitMode({
    required this.label,
    required this.description,
    required this.icon,
    required this.badge,
  });

  final String label;
  final String description;
  final IconData icon;
  final String badge;

  VideoFitMode get next => switch (this) {
    VideoFitMode.contain => VideoFitMode.cover,
    VideoFitMode.cover => VideoFitMode.stretch,
    VideoFitMode.stretch => VideoFitMode.contain,
  };
}

/// Full-screen live TV player with automatic mirror fallback, channel zapping,
/// gesture brightness/volume, PiP and a sleep timer.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.queue,
    this.initialIndex = 0,
    this.preferredSourceUrl,
  });

  final List<Channel> queue;
  final int initialIndex;
  final String? preferredSourceUrl;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  late int _index = widget.initialIndex.clamp(0, widget.queue.length - 1);
  Channel get _channel => widget.queue[_index];

  VideoPlayerController? _controller;
  List<StreamSource> _sources = const [];
  int _sourceIndex = 0;
  String? _preferredSourceUrl;
  bool _initializing = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _recordedPlayback = false;
  bool _switching = false;
  bool _handlingFailure = false;
  int _generation = 0;
  String? _error;
  String _status = 'Starting stream…';

  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _watchdog;
  Timer? _fallbackTimer;
  Timer? _hudTimer;
  String? _hudText;
  double? _hudValue;
  IconData? _hudIcon;

  DateTime? _sleepAt;
  Timer? _sleepTicker;
  final ValueNotifier<Duration?> _sleepRemaining = ValueNotifier(null);

  SimplePip? _pip;
  bool _pipAvailable = false;
  bool _inPip = false;

  double _brightness = 1;
  double _volume = .5;
  _GestureAxis? _gestureAxis;

  bool _wakeLockHeld = false;
  VideoFitMode _fitMode = VideoFitMode.contain;

  @override
  void initState() {
    super.initState();
    final savedFit = ref.read(sharedPreferencesProvider).getString('player_video_fit_mode');
    if (savedFit != null) {
      for (final mode in VideoFitMode.values) {
        if (mode.name == savedFit) {
          _fitMode = mode;
          break;
        }
      }
    }
    WidgetsBinding.instance.addObserver(this);
    _preferredSourceUrl = widget.preferredSourceUrl;
    unawaited(_enterImmersive());
    _pip = SimplePip(
      onPipEntered: () {
        _inPip = true;
        if (mounted) setState(() => _controlsVisible = false);
      },
      onPipExited: () {
        _inPip = false;
        if (mounted) {
          setState(() => _controlsVisible = true);
          _scheduleHide();
        }
      },
    );
    unawaited(_preparePip());
    unawaited(_prepareHardware());
    _loadChannel();
  }

  Future<void> _enterImmersive() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _preparePip() async {
    try {
      final available = await SimplePip.isPipAvailable;
      final inPip = await SimplePip.isPipActivated;
      if (!mounted) return;
      setState(() {
        _pipAvailable = available;
        _inPip = inPip;
      });
      if (available) {
        await _pip?.setPipActionsLayout(PipActionsLayout.mediaOnlyPause);
      }
    } catch (_) {
      // PiP is optional; a missing native implementation must never block TV.
    }
  }

  Future<void> _prepareHardware() async {
    try {
      _brightness = await ScreenBrightness.instance.application;
    } catch (_) {
      _brightness = 1;
    }
    try {
      _volume = await VolumeController.instance.getVolume();
      VolumeController.instance.showSystemUI = false;
    } catch (_) {
      _volume = .5;
    }
    await _syncWakeLock();
  }

  Future<void> _syncWakeLock() async {
    final keepOn = ref.read(settingsProvider).keepScreenOn;
    try {
      if (keepOn && !_wakeLockHeld) {
        await WakelockPlus.enable();
        _wakeLockHeld = true;
      } else if (!keepOn && _wakeLockHeld) {
        await WakelockPlus.disable();
        _wakeLockHeld = false;
      }
    } catch (_) {
      // Wake lock is a comfort feature, never a hard dependency.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _watchdog?.cancel();
    _fallbackTimer?.cancel();
    _hudTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepRemaining.dispose();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onVideoValue);
    unawaited(controller?.dispose());
    if (_wakeLockHeld) {
      unawaited(WakelockPlus.disable());
    }
    VolumeController.instance.showSystemUI = true;
    unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    unawaited(SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncWakeLock());
    } else if (state == AppLifecycleState.paused && !_inPip) {
      unawaited(_controller?.pause());
    }
  }

  // ---------------------------------------------------------------- sources

  List<StreamSource> _orderedSourcesFor(Channel channel) {
    final settings = ref.read(settingsProvider);
    final lastGood = ref.read(libraryProvider).lastGoodSources[channel.id];
    final indexed = channel.sources.asMap().entries.toList(growable: false);
    indexed.sort((a, b) {
      final aUrl = a.value.url;
      final bUrl = b.value.url;
      final aPreferred = _preferredSourceUrl != null && aUrl == _preferredSourceUrl;
      final bPreferred = _preferredSourceUrl != null && bUrl == _preferredSourceUrl;
      if (aPreferred != bPreferred) return aPreferred ? -1 : 1;
      final aGood = lastGood != null && aUrl == lastGood;
      final bGood = lastGood != null && bUrl == lastGood;
      if (aGood != bGood) return aGood ? -1 : 1;
      if (settings.preferHighestQuality) {
        final byQuality = b.value.qualityRank.compareTo(a.value.qualityRank);
        if (byQuality != 0) return byQuality;
      }
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  Future<void> _loadChannel() async {
    _generation++;
    _fallbackTimer?.cancel();
    _watchdog?.cancel();
    _recordedPlayback = false;
    _handlingFailure = false;
    _sources = _orderedSourcesFor(_channel);
    _sourceIndex = 0;
    _error = null;
    if (_sources.isEmpty) {
      setState(() {
        _initializing = false;
        _isPlaying = false;
        _error = 'This channel has no listed streams right now.';
        _controlsVisible = true;
      });
      return;
    }
    await _openSource(0);
  }

  Future<void> _openSource(int index) async {
    if (!mounted) return;
    if (index < 0 || index >= _sources.length) {
      setState(() {
        _initializing = false;
        _isPlaying = false;
        _error =
            'Every listed source failed to open. The channel may be offline or '
            'blocked in your region.';
        _controlsVisible = true;
      });
      _showControls();
      return;
    }

    final generation = ++_generation;
    _watchdog?.cancel();
    _fallbackTimer?.cancel();
    _recordedPlayback = false;
    _handlingFailure = false;
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      previous.removeListener(_onVideoValue);
      unawaited(previous.dispose());
    }

    final isReloadingLive = _sourceIndex == index && previous != null;
    setState(() {
      _switching = true;
      _initializing = true;
      _isPlaying = false;
      _isBuffering = false;
      _sourceIndex = index;
      _error = null;
      _controlsVisible = true;
      _status = isReloadingLive
          ? 'Syncing to current live segment…'
          : 'Connecting to source ${index + 1} of ${_sources.length}…';
    });
    _hideTimer?.cancel();

    final source = _sources[index];
    final uri = Uri.tryParse(source.url);
    if (uri == null || !uri.hasScheme) {
      _handleSourceFailure(generation, 'This stream address is not valid.');
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: source.requestHeaders,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: true,
        preventsDisplaySleepDuringVideoPlayback: true,
        backBufferDurationMs: 0,
      ),
    );
    controller.addListener(_onVideoValue);
    _controller = controller;

    try {
      await controller.initialize().timeout(const Duration(seconds: 22));
      if (!mounted || generation != _generation) {
        controller.removeListener(_onVideoValue);
        await controller.dispose();
        return;
      }
      await controller.setVolume(1);
      final autoplay = ref.read(settingsProvider).autoplay;
      if (autoplay) {
        await controller.play();
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _switching = false;
        _initializing = false;
        _isBuffering = controller.value.isBuffering;
        _isPlaying = controller.value.isPlaying;
        _controlsVisible = true;
      });
      if (autoplay) _startWatchdog(generation);
      _scheduleHide();
    } on TimeoutException {
      _handleSourceFailure(
        generation,
        'This source did not respond in time.',
      );
    } catch (error) {
      _handleSourceFailure(
        generation,
        'This source could not be opened on this network.',
      );
    }
  }

  void _handleSourceFailure(int generation, String reason) {
    if (!mounted || generation != _generation) return;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onVideoValue);
    unawaited(controller?.dispose());
    _watchdog?.cancel();
    _switching = false;
    _onStreamFailed(reason);
  }

  void _startWatchdog(int generation) {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 20), () {
      if (!mounted || generation != _generation) return;
      if (_isPlaying || _recordedPlayback) return;
      _onStreamFailed('The stream connected but never started playing.');
    });
  }

  void _onVideoValue() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      if (_switching || _handlingFailure) return;
      _watchdog?.cancel();
      _onStreamFailed(
        'This stream stopped responding. It may be offline or geoblocked.',
      );
      return;
    }
    if (value.isPlaying && !_recordedPlayback) {
      _recordedPlayback = true;
      _watchdog?.cancel();
      final source = _sources[_sourceIndex];
      ref.read(libraryProvider.notifier).recordWatch(
            _channel.id,
            sourceUrl: source.url,
          );
      if (_controlsVisible) _scheduleHide();
    }
    if (value.isPlaying != _isPlaying || value.isBuffering != _isBuffering) {
      if (!mounted) return;
      setState(() {
        _isPlaying = value.isPlaying;
        _isBuffering = value.isBuffering;
        if (value.isPlaying) _error = null;
      });
      if (value.isPlaying) _scheduleHide();
    }
  }

  void _onStreamFailed(String reason) {
    if (!mounted || _handlingFailure) return;
    _handlingFailure = true;
    _switching = false;
    final settings = ref.read(settingsProvider);
    _fallbackTimer?.cancel();
    if (settings.autoFallback && _sourceIndex + 1 < _sources.length) {
      setState(() {
        _initializing = true;
        _isPlaying = false;
        _error = null;
        _status = 'Source ${_sourceIndex + 1} failed · trying backup…';
        _controlsVisible = true;
      });
      _fallbackTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && !_switching) {
          _openSource(_sourceIndex + 1);
        }
      });
      return;
    }
    setState(() {
      _initializing = false;
      _switching = false;
      _isPlaying = false;
      _error = reason;
      _controlsVisible = true;
    });
    _showControls();
  }

  Future<void> _retry({bool fromStart = false}) async {
    _fallbackTimer?.cancel();
    if (fromStart) _sourceIndex = 0;
    _recordedPlayback = false;
    await _openSource(fromStart ? 0 : _sourceIndex);
  }

  Future<void> _switchSource(int index) async {
    if (index == _sourceIndex && !_initializing && _error == null) return;
    await _openSource(index);
  }

  Future<void> _zap(int delta) async {
    if (widget.queue.length < 2) {
      _showHud(Icons.swap_horiz_rounded, 'No other channels queued');
      return;
    }
    if (AppHaptics.enabled) HapticFeedback.selectionClick();
    _generation++;
    _index = (_index + delta + widget.queue.length) % widget.queue.length;
    _preferredSourceUrl = null;
    _fallbackTimer?.cancel();
    _watchdog?.cancel();
    setState(() {
      _initializing = true;
      _isPlaying = false;
      _isBuffering = false;
      _error = null;
      _controlsVisible = true;
    });
    _showHud(
      delta > 0 ? Icons.skip_next_rounded : Icons.skip_previous_rounded,
      _channel.name,
    );
    await _loadChannel();
  }

  // ---------------------------------------------------------------- controls

  void _showControls() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_isPlaying || _error != null || _initializing) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _syncToLive() async {
    if (_sources.isEmpty) return;
    HapticFeedback.lightImpact();
    _showHud(Icons.sensors_rounded, 'Syncing to live segment…');
    await _openSource(_sourceIndex);
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) {
      await _retry();
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      _showControls();
    } else {
      await controller.play();
      _showControls();
    }
    if (mounted) setState(() {});
  }

  Future<void> _enterPip() async {
    if (!_pipAvailable || _pip == null) {
      _showHud(Icons.picture_in_picture_alt_rounded, 'Picture-in-picture unavailable');
      return;
    }
    try {
      setState(() => _controlsVisible = false);
      final entered = await _pip!.enterPipMode(
        aspectRatio: (16, 9),
        seamlessResize: true,
      );
      if (!entered && mounted) {
        setState(() => _controlsVisible = true);
        _showHud(
          Icons.picture_in_picture_alt_rounded,
          'Could not enter picture-in-picture',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _controlsVisible = true);
      }
    }
  }

  void _showHud(IconData icon, String text, [double? value]) {
    _hudTimer?.cancel();
    setState(() {
      _hudIcon = icon;
      _hudText = text;
      _hudValue = value;
    });
    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _hudIcon = null;
          _hudText = null;
          _hudValue = null;
        });
      }
    });
  }

  // ---------------------------------------------------------------- gestures

  void _onVerticalStart(DragStartDetails details) async {
    final width = MediaQuery.sizeOf(context).width;
    _gestureAxis = details.localPosition.dx < width / 2
        ? _GestureAxis.brightness
        : _GestureAxis.volume;
    if (_gestureAxis == _GestureAxis.brightness) {
      try {
        _brightness = await ScreenBrightness.instance.application;
      } catch (_) {}
    } else {
      try {
        _volume = await VolumeController.instance.getVolume();
      } catch (_) {}
    }
  }

  void _onVerticalUpdate(DragUpdateDetails details) {
    final axis = _gestureAxis;
    if (axis == null) return;
    final height = MediaQuery.sizeOf(context).height;
    final delta = -details.delta.dy / math.max(1, height);
    if (axis == _GestureAxis.brightness) {
      _brightness = (_brightness + delta).clamp(0.05, 1.0);
      unawaited(ScreenBrightness.instance
          .setApplicationScreenBrightness(_brightness));
      _showHud(
        _brightness < .4
            ? Icons.brightness_low_rounded
            : Icons.brightness_high_rounded,
        'Brightness ${(_brightness * 100).round()}%',
        _brightness,
      );
    } else {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      unawaited(VolumeController.instance.setVolume(_volume));
      _showHud(
        _volume == 0
            ? Icons.volume_off_rounded
            : _volume < .5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
        'Volume ${(_volume * 100).round()}%',
        _volume,
      );
    }
  }

  void _onVerticalEnd(DragEndDetails details) {
    _gestureAxis = null;
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _hudIcon = null;
          _hudText = null;
          _hudValue = null;
        });
      }
    });
  }

  // ---------------------------------------------------------------- sleep

  Future<void> _showSleepSheet() async {
    _hideTimer?.cancel();
    final result = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _SleepSheet(active: _sleepAt != null),
    );
    if (!mounted || result == null) {
      _scheduleHide();
      return;
    }
    _setSleep(result == Duration.zero ? null : result);
  }

  void _setSleep(Duration? duration) {
    _sleepTicker?.cancel();
    if (duration == null) {
      _sleepAt = null;
      _sleepRemaining.value = null;
      _showHud(Icons.timer_off_rounded, 'Sleep timer off');
      _scheduleHide();
      return;
    }
    _sleepAt = DateTime.now().add(duration);
    _sleepRemaining.value = duration;
    _showHud(
      Icons.bedtime_rounded,
      'Sleep timer · ${duration.inMinutes} min',
    );
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final at = _sleepAt;
      if (at == null) {
        timer.cancel();
        return;
      }
      final remaining = at.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        timer.cancel();
        _sleepAt = null;
        _sleepRemaining.value = null;
        unawaited(_controller?.pause());
        if (mounted) {
          setState(() => _controlsVisible = true);
          _showHud(Icons.bedtime_rounded, 'Sleep timer ended — playback paused');
        }
        return;
      }
      _sleepRemaining.value = remaining;
    });
    _scheduleHide();
  }

  // ---------------------------------------------------------------- source sheet

  Future<void> _showSources() async {
    _hideTimer?.cancel();
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _SourceSheet(
        channel: _channel,
        sources: _sources,
        selectedIndex: _sourceIndex,
        lastGoodUrl: ref.read(libraryProvider).lastGoodSources[_channel.id],
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      await _switchSource(selected);
    } else {
      _scheduleHide();
    }
  }

  // ---------------------------------------------------------------- screen fit

  void _setFitMode(VideoFitMode mode) {
    if (_fitMode == mode) return;
    setState(() => _fitMode = mode);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString('player_video_fit_mode', mode.name),
    );
    _showHud(
      mode.icon,
      'Aspect fit: ${mode.label} · ${mode.description}',
    );
    HapticFeedback.selectionClick();
  }

  void _cycleFitMode() {
    _setFitMode(_fitMode.next);
  }

  Future<void> _showFitModeSheet() async {
    _hideTimer?.cancel();
    final palette = context.palette;
    final colors = context.colors;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Screen Size & Aspect Fit',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how the live broadcast conforms to your display',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: .6),
                  ),
                ),
                const SizedBox(height: 16),
                for (final mode in VideoFitMode.values) ...[
                  Material(
                    color: _fitMode == mode
                        ? palette.primary.withValues(alpha: .15)
                        : Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).pop();
                        _setFitMode(mode);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _fitMode == mode
                                    ? palette.primary.withValues(alpha: .22)
                                    : Colors.white.withValues(alpha: .08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                mode.icon,
                                size: 20,
                                color: _fitMode == mode
                                    ? palette.primary
                                    : Colors.white.withValues(alpha: .8),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        mode.label,
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _fitMode == mode
                                              ? palette.primary
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: .08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          mode.badge,
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withValues(alpha: .75),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mode.description,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: .55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_fitMode == mode)
                              Icon(
                                Icons.check_circle_rounded,
                                color: palette.primary,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (mounted) _scheduleHide();
  }

  Widget _buildVideoSurface(VideoPlayerController controller) {
    final size = controller.value.size;
    final width = size.width > 0 ? size.width : 16.0;
    final height = size.height > 0 ? size.height : 9.0;
    final ar = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : (width / height);

    switch (_fitMode) {
      case VideoFitMode.contain:
        return Center(
          child: AspectRatio(
            aspectRatio: ar,
            child: VideoPlayer(controller),
          ),
        );
      case VideoFitMode.cover:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      case VideoFitMode.stretch:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(controller),
            ),
          ),
        );
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final favorite = ref.watch(
      libraryProvider.select((library) => library.isFavorite(_channel.id)),
    );
    final catalog = ref.watch(catalogProvider).value;
    final catalogCountry = catalog?.countryOf(_channel) ??
        const CatalogCountry(
          code: 'ZZ',
          name: 'International',
          flag: '🌐',
          languages: [],
        );
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A1120), Color(0xFF000000)],
              ),
            ),
          ),
          if (controller != null && controller.value.isInitialized)
            _buildVideoSurface(controller)
          else if (!_initializing && _error == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChannelLogo(
                      channel: _channel,
                      width: 92,
                      height: 92,
                      radius: 22,
                      padding: 12,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _channel.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${catalogCountry.flag} ${catalogCountry.name}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: .55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTap: _cycleFitMode,
              onVerticalDragStart: _onVerticalStart,
              onVerticalDragUpdate: _onVerticalUpdate,
              onVerticalDragEnd: _onVerticalEnd,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -280) {
                  _zap(1);
                } else if (velocity > 280) {
                  _zap(-1);
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
          if (_isBuffering && !_initializing && _error == null)
            Positioned(
              top: 26,
              right: 26,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .68),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: .15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Buffering live stream…',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: .9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_hudText != null) _buildHud(),
          // Controls are intentionally last so buttons take priority over the
          // gesture surface beneath them.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: .72),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: .84),
                            ],
                            stops: const [0, .26, .6, 1],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      minimum: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          _buildTopBar(favorite),
                          Expanded(child: _buildCenter()),
                          if (!_initializing && _error == null) ...[
                            Builder(
                              builder: (context) {
                                final activeProgram =
                                    ref.watch(currentProgramProvider(_channel));
                                if (activeProgram == null ||
                                    activeProgram.isEstimated) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: EpgPlayerOverlayBar(
                                    channel: _channel,
                                    onTapGuide: () => showEpgGuideSheet(
                                      context,
                                      channel: _channel,
                                    ),
                                    onSyncToLive: _syncToLive,
                                  ),
                                );
                              },
                            ),
                          ],
                          _buildBottomBar(favorite),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHud() {
    final palette = context.palette;
    return Positioned(
      top: MediaQuery.sizeOf(context).height * .18,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 150, maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hudIcon ?? Icons.info_outline_rounded,
                      size: 17,
                      color: palette.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _hudText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_hudValue != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _hudValue,
                      minHeight: 3.5,
                      backgroundColor: Colors.white.withValues(alpha: .15),
                      valueColor: AlwaysStoppedAnimation(palette.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool favorite) {
    final colors = context.colors;
    final palette = context.palette;
    final currentProgram = ref.watch(currentProgramProvider(_channel));
    return Row(
      children: [
        _RoundButton(
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: 'Close player',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
        ChannelLogo(
          channel: _channel,
          width: 32,
          height: 32,
          radius: 8,
          padding: 4,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                (currentProgram != null && !currentProgram.isEstimated)
                    ? 'NOW: ${currentProgram.title}${currentProgram.remainingLabel().isNotEmpty ? ' (${currentProgram.remainingLabel()})' : ''}'
                    : (_sources.isEmpty ? 'Live TV' : _sourceSummary()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: (currentProgram != null && !currentProgram.isEstimated)
                      ? palette.primary.withValues(alpha: .95)
                      : Colors.white.withValues(alpha: .55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<Duration?>(
          valueListenable: _sleepRemaining,
          builder: (context, remaining, _) {
            return _RoundButton(
              icon: remaining == null
                  ? Icons.bedtime_outlined
                  : Icons.bedtime_rounded,
              tooltip: 'Sleep timer',
              active: remaining != null,
              label: remaining == null
                  ? null
                  : '${math.max(1, remaining.inMinutes + (remaining.inSeconds % 60 > 0 ? 1 : 0))}m',
              onTap: _showSleepSheet,
            );
          },
        ),
        if (_pipAvailable) ...[
          const SizedBox(width: 6),
          _RoundButton(
            icon: Icons.picture_in_picture_alt_rounded,
            tooltip: 'Picture-in-picture',
            onTap: _enterPip,
          ),
        ],
        const SizedBox(width: 6),
        _RoundButton(
          icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          tooltip: favorite ? 'Remove favourite' : 'Add favourite',
          color: favorite ? palette.primary : null,
          onTap: () => ref
              .read(libraryProvider.notifier)
              .toggleFavorite(_channel.id),
        ),
        const SizedBox(width: 6),
        _RoundButton(
          icon: Icons.layers_rounded,
          tooltip: 'Choose source',
          onTap: _showSources,
        ),
        const SizedBox(width: 6),
        _RoundButton(
          icon: _fitMode.icon,
          tooltip: 'Screen fit: ${_fitMode.label} (Tap to change, hold for options)',
          label: _fitMode.badge,
          active: _fitMode != VideoFitMode.contain,
          onTap: _cycleFitMode,
          onLongPress: _showFitModeSheet,
        ),
        const SizedBox(width: 2),
        Tooltip(
          message: 'Jump to current live segment (tap to reload mirror)',
          child: Pressable(
            onTap: _syncToLive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _isPlaying
                    ? colors.success.withValues(alpha: .14)
                    : Colors.black.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: _isPlaying
                      ? colors.success.withValues(alpha: .4)
                      : Colors.white.withValues(alpha: .12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _isPlaying ? colors.success : colors.faint,
                      shape: BoxShape.circle,
                      boxShadow: _isPlaying
                          ? [
                              BoxShadow(
                                color: colors.success.withValues(alpha: .8),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isPlaying ? 'LIVE' : 'PAUSED',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                      color: _isPlaying ? Colors.white : colors.faint,
                    ),
                  ),
                  if (_isPlaying) ...[
                    const SizedBox(width: 3.5),
                    Icon(
                      Icons.refresh_rounded,
                      size: 9.5,
                      color: colors.success,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _sourceSummary() {
    if (_sources.isEmpty) return 'Live TV';
    final source = _sources[_sourceIndex.clamp(0, _sources.length - 1)];
    return '${source.displayQuality} · ${source.formatLabel} · '
        '${source.hostLabel}';
  }

  Widget _buildCenter() {
    final catalog = ref.watch(catalogProvider).value;
    final catalogCountry = catalog?.countryOf(_channel);
    if (_initializing) {
      return StreamLoadingView(
        channel: _channel,
        status: _status,
        flag: catalogCountry?.flag,
        countryName: catalogCountry?.name,
        hasMultipleSources: _sources.length > 1,
        onSkipSource: () => _openSource(
          (_sourceIndex + 1) % _sources.length,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .66),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                  size: 26, color: context.colors.error),
              const SizedBox(height: 9),
              const Text(
                'Stream unavailable',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: .65),
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                alignment: WrapAlignment.center,
                children: [
                  _SmallAction(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onTap: _retry,
                  ),
                  if (_sources.length > 1)
                    _SmallAction(
                      label: 'Restart sources',
                      icon: Icons.replay_rounded,
                      onTap: () => _retry(fromStart: true),
                    ),
                  _SmallAction(
                    label: 'Pick source',
                    icon: Icons.layers_rounded,
                    onTap: _showSources,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: .38),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool favorite) {
    final palette = context.palette;
    final source = _sources.isEmpty
        ? null
        : _sources[_sourceIndex.clamp(0, _sources.length - 1)];
    return Row(
      children: [
        _RoundButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Previous channel',
          onTap: widget.queue.length > 1 ? () => _zap(-1) : null,
        ),
        const SizedBox(width: 6),
        _RoundButton(
          icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: _isPlaying ? 'Pause' : 'Play',
          large: true,
          onTap: _togglePlay,
        ),
        const SizedBox(width: 6),
        _RoundButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Next channel',
          onTap: widget.queue.length > 1 ? () => _zap(1) : null,
        ),
        const SizedBox(width: 11),
        Container(width: 1, height: 24, color: Colors.white.withValues(alpha: .14)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                source == null
                    ? 'Live stream'
                    : '${source.displayQuality} · ${source.formatLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                source == null
                    ? 'No source selected'
                    : (source.userAgent != null || source.referrer != null
                        ? 'Authenticated source · ${source.hostLabel}'
                        : source.hostLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: .5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (widget.queue.length > 1)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '${_index + 1} / ${widget.queue.length}',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: .45),
              ),
            ),
          ),
        _RoundButton(
          icon: _fitMode.icon,
          tooltip: 'Screen fit: ${_fitMode.label}',
          active: _fitMode != VideoFitMode.contain,
          onTap: _cycleFitMode,
          onLongPress: _showFitModeSheet,
        ),
        if (ref.watch(channelScheduleProvider(_channel)).hasRealPrograms) ...[
          const SizedBox(width: 4),
          _RoundButton(
            icon: Icons.view_timeline_rounded,
            tooltip: 'TV Guide (EPG)',
            onTap: () => showEpgGuideSheet(context, channel: _channel),
          ),
        ],
        const SizedBox(width: 4),
        _RoundButton(
          icon: favorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          tooltip: 'Favourite',
          color: favorite ? palette.primary : null,
          onTap: () =>
              ref.read(libraryProvider.notifier).toggleFavorite(_channel.id),
        ),
        const SizedBox(width: 4),
        _RoundButton(
          icon: Icons.swap_horiz_rounded,
          tooltip: 'Channel zapping',
          onTap: widget.queue.length > 1
              ? () => _showHud(
                    Icons.swipe_rounded,
                    'Swipe left or right · or use the arrows',
                  )
              : null,
        ),
      ],
    );
  }
}

enum _GestureAxis { brightness, volume }

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    this.tooltip,
    this.onTap,
    this.onLongPress,
    this.color,
    this.active = false,
    this.large = false,
    this.label,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final bool active;
  final bool large;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final size = large ? 42.0 : 34.0;
    final button = Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Material(
        color: active
            ? context.palette.primary.withValues(alpha: .18)
            : Colors.black.withValues(alpha: .32),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: label == null ? size : size + 16,
            height: size,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: large ? 21 : 17,
                  color: color ??
                      (active
                          ? context.palette.primary
                          : Colors.white.withValues(alpha: .88)),
                ),
                if (label != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: context.palette.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: .8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepSheet extends StatelessWidget {
  const _SleepSheet({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    const options = [
      (Duration.zero, 'Off', Icons.timer_off_rounded),
      (Duration(minutes: 15), '15 minutes', Icons.timer_outlined),
      (Duration(minutes: 30), '30 minutes', Icons.timer_outlined),
      (Duration(minutes: 45), '45 minutes', Icons.timer_outlined),
      (Duration(minutes: 60), '1 hour', Icons.bedtime_outlined),
      (Duration(minutes: 90), '1½ hours', Icons.bedtime_outlined),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.bedtime_rounded, size: 19, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'Sleep timer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            active
                ? 'A timer is running. Choose another time or turn it off.'
                : 'Playback pauses automatically when the timer ends.',
            style: TextStyle(
              fontSize: 11,
              color: colors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          for (final option in options)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(option.$1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Row(
                    children: [
                      Icon(option.$3, size: 16, color: colors.muted),
                      const SizedBox(width: 10),
                      Text(
                        option.$2,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 15, color: colors.faint),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({
    required this.channel,
    required this.sources,
    required this.selectedIndex,
    required this.lastGoodUrl,
  });

  final Channel channel;
  final List<StreamSource> sources;
  final int selectedIndex;
  final String? lastGoodUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .72,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 9),
            child: Row(
              children: [
                ChannelLogo(
                  channel: channel,
                  width: 38,
                  height: 38,
                  radius: 10,
                  padding: 5,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a source',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${sources.length} listed for ${channel.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: colors.faint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                final selected = index == selectedIndex;
                final lastGood = lastGoodUrl != null && source.url == lastGoodUrl;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: selected
                        ? palette.primary.withValues(alpha: .1)
                        : colors.surfaceAlt.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(13),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: selected
                                    ? palette.primary.withValues(alpha: .14)
                                    : colors.surface,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? palette.primary : colors.faint,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        source.displayQuality == 'Auto'
                                            ? 'Auto quality'
                                            : source.displayQuality,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: colors.text,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        source.formatLabel,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w600,
                                          color: colors.faint,
                                        ),
                                      ),
                                      if (lastGood) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          'LAST WORKED',
                                          style: TextStyle(
                                            fontSize: 6.5,
                                            letterSpacing: .4,
                                            fontWeight: FontWeight.w800,
                                            color: palette.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    source.hostLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: colors.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 19,
                              color: selected ? palette.primary : colors.faint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
