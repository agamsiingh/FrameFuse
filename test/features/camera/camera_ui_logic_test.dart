import 'package:frame_fuse/core/platform/native_media_service.dart';
import 'package:frame_fuse/features/camera/presentation/camera_status_providers.dart';
import 'package:frame_fuse/features/camera/presentation/widgets/capture_controls.dart';
import 'package:frame_fuse/features/camera/presentation/widgets/crop_preview.dart';
import 'package:frame_fuse/features/recording/presentation/widgets/trim_bar.dart';
import 'package:frame_fuse/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CropPreview tap mapping', () {
    // A 9:16 frame shown in a 16:9 view: only the middle band is visible.
    const frame = Size(1080, 1920);
    const view = Size(400, 225);

    test('view center maps to frame center', () {
      final p = CropPreview.toFrameForTest(const Offset(200, 112.5), view, frame);
      expect(p.dx, closeTo(0.5, 1e-9));
      expect(p.dy, closeTo(0.5, 1e-9));
    });

    test('view edges map inside the visible band', () {
      final top = CropPreview.toFrameForTest(const Offset(0, 0), view, frame);
      final visibleH = (1080 / 1920) / (400 / 225);
      expect(top.dx, closeTo(0, 1e-9));
      expect(top.dy, closeTo(0.5 - visibleH / 2, 1e-9));
    });

    test('same-aspect view maps 1:1', () {
      final p = CropPreview.toFrameForTest(const Offset(90, 320), const Size(180, 320), frame);
      expect(p.dx, closeTo(0.5, 1e-9));
      expect(p.dy, closeTo(1.0, 1e-9));
    });
  });

  group('remaining time', () {
    test('formats like the reference', () {
      expect(formatRemaining(const Duration(hours: 4, minutes: 1, seconds: 30)), '4h 1 min');
      expect(formatRemaining(const Duration(minutes: 12)), '12 min');
      expect(formatRemaining(const Duration(seconds: 20)), '< 1 min');
    });

    test('bitrate estimate grows with resolution and fps', () {
      const hd = AppSettings(defaultResolution: '720p', defaultFps: 30);
      const fhd = AppSettings(defaultResolution: '1080p', defaultFps: 30);
      const fhd60 = AppSettings(defaultResolution: '1080p', defaultFps: 60);
      const uhd = AppSettings(defaultResolution: '4K', defaultFps: 30);
      expect(hd.estimatedBytesPerSecond, lessThan(fhd.estimatedBytesPerSecond));
      expect(fhd.estimatedBytesPerSecond, lessThan(fhd60.estimatedBytesPerSecond));
      expect(fhd60.estimatedBytesPerSecond, lessThan(uhd.estimatedBytesPerSecond));
      // ~20 Mbps ≈ 2.5 MB/s for 1080p30.
      expect(fhd.estimatedBytesPerSecond, closeTo(2532000, 10000));
    });

    test('resolution badges', () {
      expect(const AppSettings(defaultResolution: '720p').resolutionBadge, 'HD');
      expect(const AppSettings(defaultResolution: '1080p').resolutionBadge, 'FHD');
      expect(const AppSettings(defaultResolution: '4K').resolutionBadge, '4K');
    });
  });

  group('zoom chips', () {
    test('offer ultra-wide, 1× and 2× only when supported', () {
      expect(const ZoomChips(zoom: 1, minZoom: 1, maxZoom: 1, onSelect: _noop).presets, [1.0]);
      expect(const ZoomChips(zoom: 1, minZoom: 1, maxZoom: 8, onSelect: _noop).presets, [1.0, 2.0, 5.0]);
      expect(const ZoomChips(zoom: 1, minZoom: 0.6, maxZoom: 3, onSelect: _noop).presets, [0.6, 1.0, 2.0]);
    });
  });

  test('clock formatting', () {
    expect(formatClock(const Duration(seconds: 3)), '0:03');
    expect(formatClock(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('thermal levels', () {
    expect(ThermalLevel.fromStatus(-1), ThermalLevel.unknown);
    expect(ThermalLevel.fromStatus(1).isHot, isFalse);
    expect(ThermalLevel.fromStatus(2).isHot, isTrue);
    expect(ThermalLevel.fromStatus(6), ThermalLevel.critical);
  });
}

void _noop(double _) {}
