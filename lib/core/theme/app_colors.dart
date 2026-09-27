import 'package:flutter/material.dart';

/// FrameFuse color tokens (sampled from the reference design).
///
/// Pure-black, camera-first UI with a single cyan accent and a red record
/// state. Everything else is a neutral grey step.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────
  static const Color accent = Color(0xFF25D0E4); // FrameFuse cyan
  static const Color accentPressed = Color(0xFF1DB4C6);
  static const Color accentMuted = Color(0xFF0D3E45); // disabled CTA
  static const Color onAccent = Color(0xFF0B2A30); // dark text on cyan
  static const Color record = Color(0xFFFF3B30); // record / destructive

  /// Kept for existing call sites.
  static const Color primary = accent;
  static const Color recording = record;

  // ── Surfaces ───────────────────────────────────────────────────
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF000000);
  static const Color card = Color(0xFF1C1C1E); // privacy card, sheets
  static const Color option = Color(0xFF1F1F1F); // onboarding options
  static const Color control = Color(0xFF2C2C2E); // Close pill, icon tiles
  static const Color controlBorder = Color(0xFF3A3A3C);
  static const Color filmstrip = Color(0xFF222222);
  static const Color surfaceVariant = card;
  static const Color scrim = Color(0xB3000000);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9A9E);
  static const Color textTertiary = Color(0xFF6E6E73);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color dotInactive = Color(0xFF5A5A5A);

  // ── Functional ─────────────────────────────────────────────────
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFFB340);
  static const Color error = record;

  // ── Format accents (both formats share the brand accent) ───────
  static const Color portraitAccent = accent;
  static const Color landscapeAccent = accent;
}
