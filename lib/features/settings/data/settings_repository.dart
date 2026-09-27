import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';
import '../../../shared/models/aspect_ratio.dart';

/// Repository for persisting and loading app settings.
class SettingsRepository {
  static const _keyResolution = 'settings_resolution';
  static const _keyFps = 'settings_fps';
  static const _keyQuality = 'settings_quality';
  static const _keyStabilization = 'settings_stabilization';
  static const _keyAudio = 'settings_audio';
  static const _keyAutoSave = 'settings_auto_save';
  static const _keyPortraitGuide = 'settings_portrait_guide';
  static const _keyLandscapeGuide = 'settings_landscape_guide';
  static const _keyGrid = 'settings_grid';
  static const _keySafeZones = 'settings_safe_zones';
  static const _keyPreviewMode = 'settings_preview_mode';
  static const _keySavePath = 'settings_save_path';
  static const _keyAutoCleanup = 'settings_auto_cleanup';
  static const _keyTheme = 'settings_theme';
  static const _keyTimer = 'settings_timer';
  static const _keyOnboarding = 'onboarding_complete';
  static const _keyShootFrequency = 'onboarding_shoot_frequency';
  static const _keyFirstTakeHint = 'first_take_hint_shown';

  /// Load settings from SharedPreferences.
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      defaultResolution: prefs.getString(_keyResolution) ?? '1080p',
      defaultFps: prefs.getInt(_keyFps) ?? 30,
      videoQuality: prefs.getString(_keyQuality) ?? 'High',
      enableStabilization: prefs.getBool(_keyStabilization) ?? true,
      enableAudio: prefs.getBool(_keyAudio) ?? true,
      autoSave: prefs.getBool(_keyAutoSave) ?? true,
      showPortraitGuide: prefs.getBool(_keyPortraitGuide) ?? true,
      showLandscapeGuide: prefs.getBool(_keyLandscapeGuide) ?? true,
      showGrid: prefs.getBool(_keyGrid) ?? false,
      showSafeZones: prefs.getBool(_keySafeZones) ?? false,
      defaultPreviewMode: _parsePreviewMode(prefs.getString(_keyPreviewMode)),
      savePath: prefs.getString(_keySavePath) ?? '',
      autoCleanup: prefs.getBool(_keyAutoCleanup) ?? false,
      themeMode: prefs.getString(_keyTheme) ?? 'dark',
      timerSeconds: prefs.getInt(_keyTimer) ?? 0,
      onboardingComplete: prefs.getBool(_keyOnboarding) ?? false,
      shootFrequency: prefs.getString(_keyShootFrequency),
      firstTakeHintShown: prefs.getBool(_keyFirstTakeHint) ?? false,
    );
  }

  /// Save settings to SharedPreferences.
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyResolution, settings.defaultResolution);
    await prefs.setInt(_keyFps, settings.defaultFps);
    await prefs.setString(_keyQuality, settings.videoQuality);
    await prefs.setBool(_keyStabilization, settings.enableStabilization);
    await prefs.setBool(_keyAudio, settings.enableAudio);
    await prefs.setBool(_keyAutoSave, settings.autoSave);
    await prefs.setBool(_keyPortraitGuide, settings.showPortraitGuide);
    await prefs.setBool(_keyLandscapeGuide, settings.showLandscapeGuide);
    await prefs.setBool(_keyGrid, settings.showGrid);
    await prefs.setBool(_keySafeZones, settings.showSafeZones);
    await prefs.setString(_keyPreviewMode, settings.defaultPreviewMode.name);
    await prefs.setString(_keySavePath, settings.savePath);
    await prefs.setBool(_keyAutoCleanup, settings.autoCleanup);
    await prefs.setString(_keyTheme, settings.themeMode);
    await prefs.setInt(_keyTimer, settings.timerSeconds);
    await prefs.setBool(_keyOnboarding, settings.onboardingComplete);
    if (settings.shootFrequency != null) {
      await prefs.setString(_keyShootFrequency, settings.shootFrequency!);
    }
    await prefs.setBool(_keyFirstTakeHint, settings.firstTakeHintShown);
  }

  /// Update a single setting.
  Future<AppSettings> update(
    AppSettings current,
    AppSettings Function(AppSettings) updater,
  ) async {
    final updated = updater(current);
    await save(updated);
    return updated;
  }

  PreviewMode _parsePreviewMode(String? value) {
    if (value == null) return PreviewMode.dual;
    return PreviewMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => PreviewMode.dual,
    );
  }
}
