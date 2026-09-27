import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/camera/presentation/camera_controller.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/domain/app_settings.dart';

/// FrameFuse — One take. Both formats.
///
/// A creator-focused camera application that produces portrait (9:16) and
/// landscape (16:9) content from a single recording.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Load persisted settings before the first frame so routing (onboarding vs
  // camera) and camera configuration never race an async load.
  AppSettings settings;
  try {
    settings = await SettingsRepository().load();
  } catch (_) {
    settings = const AppSettings();
  }

  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(settings)],
      child: const FrameFuseApp(),
    ),
  );
}
