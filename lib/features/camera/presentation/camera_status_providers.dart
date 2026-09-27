import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/storage_constants.dart';
import '../../../core/platform/native_media_service.dart';
import '../../projects/presentation/library_controller.dart';
import 'camera_controller.dart';

/// Live device thermal level (Android 10+; `unknown` elsewhere).
final thermalProvider = StreamProvider<ThermalLevel>((ref) {
  return ref.watch(nativeMediaProvider).thermalStream();
});

/// Free space on the app's storage volume, refreshed periodically
/// (every 5 s while recording, otherwise every 30 s).
final freeBytesProvider =
    StateNotifierProvider<FreeBytesNotifier, int?>((ref) {
  final notifier = FreeBytesNotifier(ref.watch(nativeMediaProvider));
  ref.listen<bool>(
    cameraProvider.select((s) => s.isCapturingVideo),
    (_, recording) => notifier.setFastPolling(recording),
  );
  return notifier;
});

class FreeBytesNotifier extends StateNotifier<int?> {
  final NativeMediaService _native;
  Timer? _timer;

  FreeBytesNotifier(this._native) : super(null) {
    refresh();
    setFastPolling(false);
  }

  Future<void> refresh() async {
    final bytes = await _native.freeBytes();
    if (mounted && bytes != null) state = bytes;
  }

  void setFastPolling(bool fast) {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: fast ? 5 : 30),
      (_) => refresh(),
    );
    if (fast) refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Estimated recording time left at the current resolution/FPS.
final remainingRecordTimeProvider = Provider<Duration?>((ref) {
  final free = ref.watch(freeBytesProvider);
  if (free == null) return null;
  final settings = ref.watch(settingsProvider);
  final usable = free - StorageConstants.minFreeStorageBytes;
  if (usable <= 0) return Duration.zero;
  return Duration(seconds: usable ~/ settings.estimatedBytesPerSecond);
});

/// "4h 1 min", "12 min", "< 1 min".
String formatRemaining(Duration d) {
  if (d.inMinutes < 1) return '< 1 min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return '${h}h $m min';
}
