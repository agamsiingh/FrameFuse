import 'package:permission_handler/permission_handler.dart';

/// Centralized permission handling for FrameFuse.
///
/// Only camera and microphone are runtime-requested. Saving to the shared
/// gallery goes through MediaStore, which needs no permission on Android 10+
/// (Android 8–9 request legacy storage lazily at export time).
class AppPermissionHandler {
  AppPermissionHandler._();

  /// Request camera + microphone together (single system dialog sequence).
  static Future<PermissionResult> requestAllRequired() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    final camera = statuses[Permission.camera];
    final microphone = statuses[Permission.microphone];
    return PermissionResult(
      camera: camera?.isGranted ?? false,
      microphone: microphone?.isGranted ?? false,
      permanentlyDenied: (camera?.isPermanentlyDenied ?? false) ||
          (microphone?.isPermanentlyDenied ?? false),
    );
  }

  /// Check current permission statuses without requesting.
  static Future<PermissionResult> checkAll() async {
    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;
    return PermissionResult(
      camera: camera.isGranted,
      microphone: microphone.isGranted,
      permanentlyDenied:
          camera.isPermanentlyDenied || microphone.isPermanentlyDenied,
    );
  }

  /// Legacy storage write permission (Android 8–9 only; granted implicitly
  /// on newer versions where it is a no-op).
  static Future<bool> requestLegacyStorage() async {
    final status = await Permission.storage.request();
    return status.isGranted || status.isLimited;
  }

  /// Open the app settings page so the user can manually grant permissions.
  static Future<bool> openSettings() => openAppSettings();
}

/// Result of a permission check/request.
class PermissionResult {
  final bool camera;
  final bool microphone;
  final bool permanentlyDenied;

  const PermissionResult({
    required this.camera,
    required this.microphone,
    this.permanentlyDenied = false,
  });

  bool get allGranted => camera && microphone;
  bool get cameraReady => camera;
  bool get recordingReady => camera && microphone;
}
