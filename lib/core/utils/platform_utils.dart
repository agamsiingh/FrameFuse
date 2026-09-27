import 'dart:io';

/// Platform-level utility checks.
class PlatformUtils {
  PlatformUtils._();

  /// Android SDK version check helpers.
  static bool get isAndroid => Platform.isAndroid;

  /// Returns true if running on a device/emulator.
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}
