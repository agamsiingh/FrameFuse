import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission_handler.dart';
import '../../../core/platform/native_media_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/aspect_ratio.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/library_controller.dart';
import '../../projects/presentation/project_sheet.dart';
import '../domain/camera_state.dart';
import '../domain/device_capabilities.dart';
import 'camera_controller.dart';
import 'camera_status_providers.dart';
import 'widgets/capture_controls.dart';
import 'widgets/crop_preview.dart';

/// The FrameFuse capture screen.
///
/// Stacked layout: live 9:16 card above a live 16:9 card (both are center
/// crops of the same camera stream, identical to the exported files).
/// Picture-in-picture layout: full 9:16 preview with a floating 16:9 window.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  static const _topBarHeight = 52.0;

  bool? _permissionGranted; // null while checking
  bool _routeActive = true; // false while another screen is pushed
  bool _navigating = false;
  late bool _pip;
  double _pinchBaseZoom = 1.0;
  final GlobalKey _recordKey = GlobalKey();
  Rect? _recordRect;
  late final CameraNotifier _camera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera = ref.read(cameraProvider.notifier);
    _pip = ref.read(settingsProvider).defaultPreviewMode == PreviewMode.portrait;
    SchedulerBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Screen removed (e.g. "Show intro again"): never leave the camera open.
    _camera.release();
    super.dispose();
  }

  // ── Lifecycle ──────────────────────────────────────────────────

  Future<void> _start() async {
    var result = await AppPermissionHandler.checkAll();
    if (!result.cameraReady) {
      result = await AppPermissionHandler.requestAllRequired();
    }
    if (!mounted) return;
    setState(() => _permissionGranted = result.cameraReady);
    if (result.cameraReady) {
      await ref.read(cameraProvider.notifier).initialize();
    }
  }

  Future<void> _waitForFrame() async {
    try {
      await SchedulerBinding.instance.endOfFrame;
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_permissionGranted == true) {
          ref
              .read(cameraProvider.notifier)
              .onAppPaused(beforeDispose: _waitForFrame)
              .then((take) {
            if (take != null && mounted) {
              _toast('Recording saved as ${take.label}');
            }
          });
        }
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _onResumed() async {
    final result = await AppPermissionHandler.checkAll();
    if (!mounted) return;
    if (result.cameraReady != _permissionGranted) {
      setState(() => _permissionGranted = result.cameraReady);
    }
    if (result.cameraReady && _routeActive) {
      await ref.read(cameraProvider.notifier).onAppResumed();
    }
  }

  /// Push another screen with the camera released (saves battery/heat and
  /// avoids competing with video playback), then reopen it on return.
  Future<void> _openRoute(String name, {Object? arguments}) async {
    if (_navigating) return;
    _navigating = true;
    try {
      final notifier = ref.read(cameraProvider.notifier);
      _routeActive = false;
      await notifier.release(beforeDispose: _waitForFrame);
      if (!mounted) return;
      await Navigator.of(context).pushNamed(name, arguments: arguments);
    } finally {
      _navigating = false;
      _routeActive = true;
      if (mounted && _permissionGranted == true) {
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
          unawaited(ref.read(cameraProvider.notifier).onAppResumed());
        }
      }
    }
  }

  // ── Actions ────────────────────────────────────────────────────

  Future<void> _onRecordTap() async {
    final notifier = ref.read(cameraProvider.notifier);
    final state = ref.read(cameraProvider);
    if (state.isBusy) return;

    _markHintShown();
    if (state.isCapturingVideo) {
      HapticFeedback.mediumImpact();
      final take = await notifier.stopRecording();
      if (take != null && mounted) {
        await _openRoute('/review', arguments: take.id);
      }
    } else {
      HapticFeedback.mediumImpact();
      await notifier.startRecording();
    }
  }

  Future<void> _onPhotoTap() async {
    HapticFeedback.lightImpact();
    final take = await ref.read(cameraProvider.notifier).takePhoto();
    if (take != null && mounted) {
      await _openRoute('/review', arguments: take.id);
    }
  }

  void _markHintShown() {
    final settings = ref.read(settingsProvider);
    if (!settings.firstTakeHintShown) {
      ref
          .read(settingsProvider.notifier)
          .updateSettings((s) => s.copyWith(firstTakeHintShown: true));
    }
  }

  void _toggleLayout() {
    setState(() => _pip = !_pip);
    ref.read(settingsProvider.notifier).setPreviewMode(
          _pip ? PreviewMode.portrait : PreviewMode.dual,
        );
  }

  void _cycleResolution() {
    final settings = ref.read(settingsProvider);
    const order = ['720p', '1080p', '4K'];
    final next = order[(order.indexOf(settings.defaultResolution) + 1) % order.length];
    ref.read(settingsProvider.notifier).setResolution(next);
    _toast('Resolution: ${next == '720p' ? 'HD 720p' : next == '4K' ? '4K 2160p' : 'Full HD 1080p'}');
  }

  void _cycleFps() {
    final settings = ref.read(settingsProvider);
    const order = [24, 30, 60];
    final i = order.indexOf(settings.defaultFps);
    final next = order[(i < 0 ? 1 : i + 1) % order.length];
    ref.read(settingsProvider.notifier).setFps(next);
    _toast('Frame rate: $next fps${next == 60 ? ' (if supported)' : ''}');
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)),
    );
  }

  Future<void> _openLastTake() async {
    final library = ref.read(libraryProvider);
    final project = library.currentProject;
    final takes = project == null ? const <Take>[] : library.data.takesFor(project.id);
    if (takes.isEmpty) {
      await _openRoute('/library');
    } else {
      await _openRoute('/review', arguments: takes.first.id);
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Guards that react to live device conditions while recording.
    ref.listen<int?>(freeBytesProvider, (_, bytes) {
      final recording = ref.read(cameraProvider).isCapturingVideo;
      if (recording && bytes != null && bytes < 150 * 1024 * 1024) {
        _toast('Storage almost full — recording stopped and saved.');
        _onRecordTap();
      }
    });
    ref.listen<AsyncValue<ThermalLevel>>(thermalProvider, (_, next) {
      final level = next.valueOrNull;
      if (level == ThermalLevel.critical &&
          ref.read(cameraProvider).isCapturingVideo) {
        _toast('Phone is too hot — recording stopped and saved.');
        _onRecordTap();
      }
    });

    if (_permissionGranted == false) return _buildPermissionScreen();

    final cam = ref.watch(cameraProvider.select((s) => (
          status: s.status,
          busy: s.isBusy,
          config: s.config,
          caps: s.capabilities,
          error: s.errorMessage,
          processing: s.isProcessing,
          processingMessage: s.processingMessage,
        )));
    final settings = ref.watch(settingsProvider);
    final isRecording = cam.status == CameraStatus.recording ||
        cam.status == CameraStatus.paused;
    final ready = cam.status == CameraStatus.ready;
    final controller = ref.read(cameraProvider.notifier).controller;
    final previewReady = controller != null &&
        controller.value.isInitialized &&
        (ready || isRecording || cam.status == CameraStatus.processing);
    final showHint = !settings.firstTakeHintShown && ready && !cam.busy;

    if (showHint) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _measureRecordButton());
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 28),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: previewReady
                            ? (_pip
                                ? _buildPip(controller, cam.config.zoom, cam.caps, isRecording)
                                : _buildStacked(controller, cam.config.zoom, cam.caps, isRecording))
                            : _buildPreviewPlaceholder(cam.status),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: _topBarHeight,
                        child: _TopBar(
                          capsules: _pip,
                          disabled: isRecording || !ready,
                          resolutionBadge: settings.resolutionBadge,
                          fps: settings.defaultFps,
                          torchOn: cam.config.flashMode == FlashMode.torch,
                          isFront: cam.config.isFrontCamera,
                          onResolution: _cycleResolution,
                          onFps: _cycleFps,
                          onAdjust: () => _showAdjustments(),
                          onFlash: () => ref.read(cameraProvider.notifier).toggleFlash(),
                          onTeleprompter: () => showComingSoon(context, 'Teleprompter'),
                          onRingLight: () => showComingSoon(context, 'Screen light'),
                          onFlip: () => ref.read(cameraProvider.notifier).switchCamera(),
                          onSettings: () => _openRoute('/settings'),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBottomControls(isRecording, ready && !cam.busy),
              ],
            ),
            if (cam.error != null) _buildErrorBanner(cam.error!, cam.status),
            if (cam.processing)
              LoadingOverlay(message: cam.processingMessage ?? 'Saving...'),
            if (showHint && _recordRect != null)
              _FirstTakeHint(hole: _recordRect!, onRecord: _onRecordTap, onDismiss: _markHintShown),
          ],
        ),
      ),
    );
  }

  void _measureRecordButton() {
    final box = _recordKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect != _recordRect) setState(() => _recordRect = rect);
  }

  Widget _buildPreviewPlaceholder(CameraStatus status) {
    return Center(
      child: status == CameraStatus.error
          ? const Icon(Icons.videocam_off_outlined, color: AppColors.textTertiary, size: 40)
          : const SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
    );
  }

  // Stacked: 9:16 card on top, full-width 16:9 card below.
  Widget _buildStacked(
    CameraController controller,
    double zoom,
    DeviceCapabilities? caps,
    bool isRecording,
  ) {
    return LayoutBuilder(builder: (context, c) {
      const side = 9.5, gap = 7.0, chipOverhang = 17.0;
      final top = _topBarHeight + 2;
      final landW = c.maxWidth - side * 2;
      final landH = landW * 9 / 16;
      var portH = c.maxHeight - top - landH - gap - chipOverhang;
      var portW = portH * 9 / 16;
      if (portW > c.maxWidth * 0.62) {
        portW = c.maxWidth * 0.62;
        portH = portW * 16 / 9;
      }
      final contentH = portH + gap + landH;
      final y0 = top + ((c.maxHeight - top - chipOverhang - contentH) / 2).clamp(0.0, double.infinity);

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: y0,
            left: (c.maxWidth - portW) / 2,
            width: portW,
            height: portH,
            child: _portraitLayer(controller, portH, isRecording),
          ),
          Positioned(
            top: y0 + portH + gap,
            left: side,
            width: landW,
            height: landH,
            child: _landscapeLayer(controller, isRecording, showRemaining: true),
          ),
          Positioned(
            top: y0 + portH + gap + landH - chipOverhang,
            left: 0,
            right: 0,
            child: Center(child: _zoomChips(zoom, caps)),
          ),
        ],
      );
    });
  }

  // PiP: full 9:16 preview + floating 16:9 window.
  Widget _buildPip(
    CameraController controller,
    double zoom,
    DeviceCapabilities? caps,
    bool isRecording,
  ) {
    return LayoutBuilder(builder: (context, c) {
      var portW = c.maxWidth;
      var portH = portW * 16 / 9;
      if (portH > c.maxHeight) {
        portH = c.maxHeight;
        portW = portH * 9 / 16;
      }
      final pipW = c.maxWidth * 0.62;
      final pipH = pipW * 9 / 16;
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: (c.maxWidth - portW) / 2,
            width: portW,
            height: portH,
            child: _portraitLayer(controller, portH, isRecording, radius: 14),
          ),
          Positioned(
            right: 2,
            bottom: c.maxHeight - portH + 16,
            width: pipW,
            height: pipH,
            child: GestureDetector(
              onTap: isRecording ? null : _toggleLayout,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CropPreview(
                    controller: controller,
                    borderRadius: BorderRadius.circular(10),
                    borderColor: Colors.white24,
                  ),
                  const Positioned(
                    right: 6,
                    bottom: 6,
                    child: Icon(Icons.open_in_full, color: Colors.white70, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _zoomChips(double zoom, DeviceCapabilities? caps) {
    final minZoom = caps?.minZoom ?? 1.0;
    final maxZoom = caps?.maxZoom ?? 1.0;
    return ZoomChips(
      zoom: zoom,
      minZoom: minZoom,
      maxZoom: maxZoom,
      onSelect: (v) => ref.read(cameraProvider.notifier).setZoom(v),
    );
  }

  Widget _portraitLayer(
    CameraController controller,
    double height,
    bool isRecording, {
    double radius = 10,
  }) {
    final notifier = ref.read(cameraProvider.notifier);
    final showGrid = ref.watch(cameraProvider.select((s) => s.config.showGrid));
    return Stack(
      fit: StackFit.expand,
      children: [
        CropPreview(
          controller: controller,
          borderRadius: BorderRadius.circular(radius),
          showGrid: showGrid,
          onFocusTap: notifier.setFocusPoint,
          onScaleStart: (_) => _pinchBaseZoom = ref.read(cameraProvider).config.zoom,
          onScaleUpdate: (d) {
            if (d.pointerCount < 2) return;
            notifier.setZoom(_pinchBaseZoom * d.scale);
          },
        ),
        // Fixed slots (as in the reference) so the project pill never jumps
        // when the heat warning appears.
        Positioned(
          top: (_pip ? _topBarHeight + 14 : height * 0.09 - 10),
          left: 8,
          right: 8,
          child: const Center(child: _ThermalPill()),
        ),
        Positioned(
          top: (_pip ? _topBarHeight + 46 : height * 0.205 - 10),
          left: 8,
          right: 8,
          child: Center(
            child: isRecording
                ? const _RecordingPill()
                : OverlayPill(
                    onTap: () => showProjectSheet(context),
                    padding: const EdgeInsets.fromLTRB(9, 4, 6, 4),
                    child: Consumer(builder: (context, ref, _) {
                      final label = ref.watch(libraryProvider.select((l) => l.currentLabel));
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 3),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 12),
                        ],
                      );
                    }),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _landscapeLayer(
    CameraController controller,
    bool isRecording, {
    required bool showRemaining,
  }) {
    final notifier = ref.read(cameraProvider.notifier);
    final showGrid = ref.watch(cameraProvider.select((s) => s.config.showGrid));
    return Stack(
      fit: StackFit.expand,
      children: [
        CropPreview(
          controller: controller,
          borderRadius: BorderRadius.circular(10),
          showGrid: showGrid,
          onFocusTap: notifier.setFocusPoint,
        ),
        if (showRemaining)
          Positioned(
            left: 0,
            right: 0,
            bottom: 26,
            child: Consumer(builder: (context, ref, _) {
              final remaining = ref.watch(remainingRecordTimeProvider);
              if (remaining == null) return const SizedBox.shrink();
              return Text(
                formatRemaining(remaining),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildBottomControls(bool isRecording, bool enabled) {
    final notifier = ref.read(cameraProvider.notifier);
    final isPaused = ref.watch(cameraProvider.select((s) => s.isPaused));
    final lastThumb = ref.watch(libraryProvider.select((l) {
      final project = l.currentProject;
      if (project == null) return null;
      final takes = l.data.takesFor(project.id);
      return takes.isEmpty ? null : (takes.first.isVideo ? takes.first.thumbnailPath : takes.first.portraitPath);
    }));
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 10, 8, bottomInset + 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (isRecording)
                  BarIcon(
                    tooltip: isPaused ? 'Resume' : 'Pause',
                    icon: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onTap: isPaused ? notifier.resumeRecording : notifier.pauseRecording,
                  )
                else
                  LastTakeButton(thumbnailPath: lastThumb, onTap: _openLastTake),
                SizedBox(
                  width: 40,
                  child: isRecording
                      ? null
                      : Center(child: PhotoButton(enabled: enabled, onTap: _onPhotoTap)),
                ),
                RecordButton(
                  key: _recordKey,
                  isRecording: isRecording,
                  enabled: enabled || isRecording,
                  onTap: _onRecordTap,
                ),
                BarIcon(
                  tooltip: _pip ? 'Stacked layout' : 'Picture-in-picture',
                  icon: LayoutSwapIcon(
                    size: 22,
                    color: isRecording ? AppColors.textTertiary : AppColors.accent,
                  ),
                  onTap: isRecording ? null : _toggleLayout,
                ),
                BarIcon(
                  tooltip: 'Library',
                  icon: Icon(
                    Icons.all_inbox_rounded,
                    color: isRecording ? AppColors.textTertiary : Colors.white,
                    size: 20,
                  ),
                  onTap: isRecording ? null : () => _openRoute('/library'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isRecording ? 0 : 1,
            child: IgnorePointer(
              ignoring: isRecording,
              child: LensModeSelector(
                onFrontBackTap: () => showComingSoon(context, 'Front/Back dual camera'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdjustments() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (_) => const _AdjustmentsSheet(),
    );
  }

  Widget _buildErrorBanner(String message, CameraStatus status) {
    final notifier = ref.read(cameraProvider.notifier);
    final fatal = status == CameraStatus.error;
    return Positioned(
      top: MediaQuery.of(context).padding.top + _topBarHeight + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.control,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.record.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.record, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              if (fatal)
                TextButton(onPressed: notifier.retry, child: const Text('Retry'))
              else
                IconButton(
                  onPressed: notifier.clearError,
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.no_photography_outlined, color: AppColors.accent, size: 44),
              const SizedBox(height: 20),
              const Text(
                'Camera access is off',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'FrameFuse needs the camera (and microphone for sound) to record both formats. Nothing ever leaves your device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final r = await AppPermissionHandler.requestAllRequired();
                  if (!mounted) return;
                  if (r.cameraReady) {
                    setState(() => _permissionGranted = true);
                    await ref.read(cameraProvider.notifier).initialize();
                  } else if (r.permanentlyDenied) {
                    await AppPermissionHandler.openSettings();
                  }
                },
                child: const Text('Grant Access'),
              ),
              TextButton(
                onPressed: AppPermissionHandler.openSettings,
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool capsules;
  final bool disabled;
  final String resolutionBadge;
  final int fps;
  final bool torchOn;
  final bool isFront;
  final VoidCallback onResolution;
  final VoidCallback onFps;
  final VoidCallback onAdjust;
  final VoidCallback onFlash;
  final VoidCallback onTeleprompter;
  final VoidCallback onRingLight;
  final VoidCallback onFlip;
  final VoidCallback onSettings;

  const _TopBar({
    required this.capsules,
    required this.disabled,
    required this.resolutionBadge,
    required this.fps,
    required this.torchOn,
    required this.isFront,
    required this.onResolution,
    required this.onFps,
    required this.onAdjust,
    required this.onFlash,
    required this.onTeleprompter,
    required this.onRingLight,
    required this.onFlip,
    required this.onSettings,
  });

  Widget _group(List<Widget> children, {bool capsule = false}) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: children);
    if (!capsule) return row;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(19),
      ),
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    const iconColor = Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _group([
            _SuperLabel(value: resolutionBadge, sup: 'RES', onTap: disabled ? null : onResolution),
            const SizedBox(width: 6),
            _SuperLabel(value: '$fps', sup: 'FPS', onTap: disabled ? null : onFps),
            BarIcon(
              tooltip: 'Adjust',
              compact: true,
              icon: const Icon(Icons.tune, color: iconColor, size: 21),
              onTap: onAdjust,
            ),
          ]),
          const Spacer(),
          _group([
            BarIcon(
              tooltip: torchOn ? 'Light on' : 'Light off',
              compact: true,
              icon: Icon(
                torchOn ? Icons.flash_on : Icons.flash_off,
                color: isFront ? AppColors.textTertiary : (torchOn ? AppColors.accent : iconColor),
                size: 21,
              ),
              onTap: isFront ? null : onFlash,
            ),
            BarIcon(
              tooltip: 'Teleprompter',
              compact: true,
              premium: true,
              icon: const Icon(Icons.subtitles_outlined, color: iconColor, size: 22),
              onTap: onTeleprompter,
            ),
            BarIcon(
              tooltip: 'Screen light',
              compact: true,
              premium: true,
              icon: const Icon(Icons.brightness_7, color: iconColor, size: 22),
              onTap: onRingLight,
            ),
            BarIcon(
              tooltip: 'Switch camera',
              compact: true,
              icon: Icon(Icons.cameraswitch, color: disabled ? AppColors.textTertiary : iconColor, size: 22),
              onTap: disabled ? null : onFlip,
            ),
            BarIcon(
              tooltip: 'Settings',
              compact: true,
              icon: Icon(Icons.settings, color: disabled ? AppColors.textTertiary : iconColor, size: 22),
              onTap: disabled ? null : onSettings,
            ),
          ], capsule: capsules),
        ],
      ),
    );
  }
}

/// "HD" with a small cyan "RES" superscript.
class _SuperLabel extends StatelessWidget {
  final String value;
  final String sup;
  final VoidCallback? onTap;
  const _SuperLabel({required this.value, required this.sup, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: onTap == null ? AppColors.textSecondary : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              sup,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlays ────────────────────────────────────────────────────────

class _ThermalPill extends ConsumerWidget {
  const _ThermalPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(thermalProvider).valueOrNull ?? ThermalLevel.unknown;
    if (!level.isHot) return const SizedBox.shrink();
    final text = level.index >= ThermalLevel.severe.index
        ? 'Phone too hot — recording may stop'
        : 'Phone getting hot — let it cool down';
    return OverlayPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.record, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _RecordingPill extends ConsumerWidget {
  const _RecordingPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraProvider.select((s) => (s.recordingDuration, s.isPaused)));
    final d = state.$1;
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return OverlayPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: state.$2 ? AppColors.warning : AppColors.record,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state.$2 ? '$mm:$ss  PAUSED' : '$mm:$ss',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dimmed coach mark with a hole over the record button.
class _FirstTakeHint extends StatelessWidget {
  final Rect hole;
  final VoidCallback onRecord;
  final VoidCallback onDismiss;

  const _FirstTakeHint({
    required this.hole,
    required this.onRecord,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final holeRect = hole.inflate(4);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (holeRect.contains(d.globalPosition)) {
            onRecord();
          } else {
            onDismiss();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _HolePainter(holeRect)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: holeRect.top - 48,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'Tap to record your first take',
                        style: TextStyle(
                          color: AppColors.onAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CustomPaint(size: const Size(14, 7), painter: _ArrowPainter()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect hole;
  _HolePainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(hole),
    );
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.62));
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) => oldDelegate.hole != hole;
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Adjustments sheet ───────────────────────────────────────────────

class _AdjustmentsSheet extends ConsumerWidget {
  const _AdjustmentsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(cameraProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(cameraProvider.notifier);
    final caps = cam.capabilities;
    final minExp = caps?.minExposure ?? 0;
    final maxExp = caps?.maxExposure ?? 0;
    final minZoom = caps?.minZoom ?? 1;
    final maxZoom = (caps?.maxZoom ?? 1).clamp(1.0, 10.0);

    const label = TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (maxExp > minExp) ...[
              Row(children: [
                const Text('Exposure', style: label),
                const Spacer(),
                Text(cam.config.exposure.toStringAsFixed(1),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ]),
              Slider(
                value: cam.config.exposure.clamp(minExp, maxExp),
                min: minExp,
                max: maxExp,
                onChanged: notifier.setExposure,
              ),
            ],
            if (maxZoom > minZoom) ...[
              Row(children: [
                const Text('Zoom', style: label),
                const Spacer(),
                Text('${cam.config.zoom.toStringAsFixed(1)}×',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ]),
              Slider(
                value: cam.config.zoom.clamp(minZoom, maxZoom),
                min: minZoom,
                max: maxZoom,
                onChanged: notifier.setZoom,
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Grid', style: label),
              value: settings.showGrid,
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleGrid(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Record sound', style: label),
              value: settings.enableAudio,
              onChanged: cam.isCapturingVideo
                  ? null
                  : (_) => ref.read(settingsProvider.notifier).toggleAudio(),
            ),
          ],
        ),
      ),
    );
  }
}
