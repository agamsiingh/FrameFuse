import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/camera/presentation/camera_screen.dart';
import 'features/camera/presentation/camera_controller.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/recording/presentation/review_screen.dart';
import 'features/gallery/presentation/gallery_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

/// Root application widget for FrameFuse.
class FrameFuseApp extends ConsumerWidget {
  const FrameFuseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      // "/" decides between first-run onboarding and the camera.
      onGenerateRoute: (settings) {
        final Widget page;
        switch (settings.name) {
          case '/':
            page = const _Entry();
          case '/onboarding':
            page = const OnboardingScreen();
          case '/camera':
            page = const CameraScreen();
          case '/review':
            page = const ReviewScreen();
          case '/library':
            page = const GalleryScreen();
          case '/settings':
            page = const SettingsScreen();
          default:
            page = const _Entry();
        }
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}

class _Entry extends ConsumerWidget {
  const _Entry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(settingsProvider.select((s) => s.onboardingComplete));
    return done ? const CameraScreen() : const OnboardingScreen();
  }
}
