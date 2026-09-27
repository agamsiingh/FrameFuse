import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/aspect_ratio.dart';
import '../../../shared/widgets/brand.dart';
import '../../camera/presentation/camera_controller.dart';
import '../../camera/presentation/camera_status_providers.dart';

/// Settings. Every control here changes real behaviour.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final free = ref.watch(freeBytesProvider);
    final remaining = ref.watch(remainingRecordTimeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _Header('Recording'),
          _Card(children: [
            _ChoiceTile(
              icon: Icons.high_quality_outlined,
              title: 'Resolution',
              value: settings.defaultResolution,
              options: const {'720p': 'HD 720p', '1080p': 'Full HD 1080p', '4K': '4K'},
              onChanged: notifier.setResolution,
            ),
            _ChoiceTile(
              icon: Icons.speed,
              title: 'Frame rate',
              value: '${settings.defaultFps}',
              options: const {'24': '24 fps', '30': '30 fps', '60': '60 fps'},
              onChanged: (v) => notifier.setFps(int.parse(v)),
            ),
            _SwitchTile(
              icon: Icons.mic_none,
              title: 'Record sound',
              value: settings.enableAudio,
              onChanged: (_) => notifier.toggleAudio(),
            ),
          ]),
          const _Note('If your phone can’t record at the chosen resolution or frame rate, FrameFuse automatically uses the closest supported one.'),
          const _Header('Camera'),
          _Card(children: [
            _SwitchTile(
              icon: Icons.grid_3x3,
              title: 'Grid',
              value: settings.showGrid,
              onChanged: (_) => notifier.toggleGrid(),
            ),
            _ChoiceTile(
              icon: Icons.dashboard_outlined,
              title: 'Preview layout',
              value: settings.defaultPreviewMode == PreviewMode.portrait ? 'pip' : 'stacked',
              options: const {'stacked': 'Stacked', 'pip': 'Picture-in-picture'},
              onChanged: (v) => notifier.setPreviewMode(
                v == 'pip' ? PreviewMode.portrait : PreviewMode.dual,
              ),
            ),
          ]),
          const _Header('Storage'),
          _Card(children: [
            _InfoTile(
              icon: Icons.sd_storage_outlined,
              title: 'Free space',
              value: free == null ? '—' : _formatBytes(free),
            ),
            _InfoTile(
              icon: Icons.timer_outlined,
              title: 'Recording time left',
              value: remaining == null ? '—' : formatRemaining(remaining),
            ),
            const _InfoTile(
              icon: Icons.folder_outlined,
              title: 'Exports saved to',
              value: 'Movies/FrameFuse',
            ),
          ]),
          const _Header('Premium'),
          _Card(children: [
            for (final f in const ['Teleprompter', 'Screen light', 'Front/Back dual camera'])
              _TapTile(
                icon: Icons.lock_outline,
                title: f,
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CrownIcon(size: 13),
                    SizedBox(width: 6),
                    Text('Coming Soon', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                onTap: () => showComingSoon(context, f),
              ),
          ]),
          const _Header('About'),
          _Card(children: [
            const _InfoTile(
              icon: Icons.info_outline,
              title: AppConstants.appName,
              value: 'v${AppConstants.appVersion}',
            ),
            _TapTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Totally private', style: TextStyle(fontSize: 18)),
                  content: const Text(
                    'FrameFuse has no account, no analytics and no network access. '
                    'Recordings stay on your device and are only copied to your '
                    'gallery or shared when you choose to.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.45),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                  ],
                ),
              ),
            ),
            _TapTile(
              icon: Icons.replay,
              title: 'Show intro again',
              onTap: () async {
                await notifier.updateSettings((s) => s.copyWith(
                      onboardingComplete: false,
                      firstTakeHintShown: false,
                    ));
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
            ),
            _TapTile(
              icon: Icons.code,
              title: 'Open-source licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: FrameFuseLogo(width: 48),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    const gb = 1024 * 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    return '${(bytes / (1024 * 1024)).round()} MB';
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, height: 1.4),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 52, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500);

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: _titleStyle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: _titleStyle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            options[value] ?? value,
            style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in options.entries)
                  ListTile(
                    title: Text(e.value, style: _titleStyle),
                    trailing: e.key == value
                        ? const Icon(Icons.check, color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.pop(ctx, e.key),
                  ),
              ],
            ),
          ),
        );
        if (picked != null && picked != value) onChanged(picked);
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: _titleStyle),
      trailing: Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
    );
  }
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _TapTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: _titleStyle),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}
