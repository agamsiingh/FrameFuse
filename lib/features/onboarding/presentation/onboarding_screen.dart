import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/brand.dart';
import '../../camera/presentation/camera_controller.dart';

/// Answers to "How often do you shoot the same content twice?".
enum ShootFrequency {
  allTheTime('All the time'),
  often('Often'),
  sometimes('Sometimes'),
  rarely('Rarely');

  final String label;
  const ShootFrequency(this.label);

  static ShootFrequency? fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// First-run flow: welcome → question → pitch → permissions → done.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { welcome, question, pitch, permissions, done }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  _Step _step = _Step.welcome;
  ShootFrequency? _answer;
  bool _requesting = false;
  bool _permanentlyDenied = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _answer = ShootFrequency.fromName(ref.read(settingsProvider).shootFrequency);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from system Settings after granting manually.
    if (state == AppLifecycleState.resumed && _step == _Step.permissions) {
      AppPermissionHandler.checkAll().then((r) {
        if (mounted && r.allGranted) _go(_Step.done);
      });
    }
  }

  void _go(_Step step) => setState(() => _step = step);

  Future<void> _grantAccess() async {
    if (_permanentlyDenied) {
      await AppPermissionHandler.openSettings();
      return;
    }
    setState(() {
      _requesting = true;
      _permissionError = null;
    });
    final result = await AppPermissionHandler.requestAllRequired();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _permanentlyDenied = result.permanentlyDenied && !result.allGranted;
    });
    if (result.cameraReady) {
      // Microphone is optional — takes are recorded silent without it.
      _go(_Step.done);
    } else {
      setState(() {
        _permissionError = _permanentlyDenied
            ? 'Camera access is turned off. Enable it in Settings to continue.'
            : 'FrameFuse needs the camera to record.';
      });
    }
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).updateSettings(
          (s) => s.copyWith(
            onboardingComplete: true,
            shootFrequency: _answer?.name,
          ),
        );
    // The root route swaps to the camera once onboarding is complete.
  }

  void _back() {
    switch (_step) {
      case _Step.welcome:
        break;
      case _Step.question:
        _go(_Step.welcome);
      case _Step.pitch:
        _go(_Step.question);
      case _Step.permissions:
        _go(_Step.pitch);
      case _Step.done:
        _go(_Step.permissions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.welcome:
        return _WelcomeStep(onNext: () => _go(_Step.question));
      case _Step.question:
        return _QuestionStep(
          selected: _answer,
          onSelect: (a) => setState(() => _answer = a),
          onNext: () async {
            await ref.read(settingsProvider.notifier).updateSettings(
                  (s) => s.copyWith(shootFrequency: _answer?.name),
                );
            _go(_Step.pitch);
          },
        );
      case _Step.pitch:
        return _PitchStep(
          answer: _answer ?? ShootFrequency.allTheTime,
          onNext: () => _go(_Step.permissions),
        );
      case _Step.permissions:
        return _PermissionStep(
          busy: _requesting,
          error: _permissionError,
          openSettings: _permanentlyDenied,
          onGrant: _grantAccess,
        );
      case _Step.done:
        return _DoneStep(onFinish: _finish);
    }
  }
}

// ── Shared layout ─────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  final Widget body;
  final int? dotIndex;
  final String buttonLabel;
  final VoidCallback? onButton;
  final bool showArrow;
  final bool busy;

  const _StepScaffold({
    required this.body,
    required this.buttonLabel,
    required this.onButton,
    this.dotIndex,
    this.showArrow = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: body),
        if (dotIndex != null) ...[
          PageDots(count: 3, index: dotIndex!),
          const SizedBox(height: 22),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 0, 19, 28),
          child: SizedBox(
            height: 46,
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onButton,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(buttonLabel),
                        if (showArrow) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

const _heroStyle = TextStyle(
  color: Colors.white,
  fontSize: 27,
  fontWeight: FontWeight.w800,
  height: 1.2,
);

const _subtleStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 13.5,
  fontWeight: FontWeight.w400,
  height: 1.45,
  letterSpacing: 0.6,
);

// ── Steps ─────────────────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      buttonLabel: 'Get Started',
      onButton: onNext,
      body: const Column(
        children: [
          Spacer(flex: 36),
          FrameFuseLogo(width: 104),
          SizedBox(height: 26),
          Text(
            'Welcome to FrameFuse',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Spacer(flex: 10),
          Text(
            'Creators waste hours re-shooting\nthe same content.',
            textAlign: TextAlign.center,
            style: _subtleStyle,
          ),
          Spacer(flex: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Starting today,\n'),
                TextSpan(
                  text: "you don't.",
                  style: TextStyle(color: AppColors.accent),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: _heroStyle,
          ),
          Spacer(flex: 26),
        ],
      ),
    );
  }
}

class _QuestionStep extends StatelessWidget {
  final ShootFrequency? selected;
  final ValueChanged<ShootFrequency> onSelect;
  final VoidCallback onNext;

  const _QuestionStep({
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      dotIndex: 0,
      buttonLabel: 'Continue',
      onButton: selected == null ? null : onNext,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Column(
          children: [
            const Spacer(flex: 30),
            const Text(
              'How often do you shoot the same\ncontent twice?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pick the closest answer.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 18),
            for (final option in ShootFrequency.values) ...[
              _OptionTile(
                label: option.label,
                selected: option == selected,
                onTap: () => onSelect(option),
              ),
              const SizedBox(height: 10),
            ],
            const Spacer(flex: 22),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.option,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.accent : const Color(0xFF757575),
                      width: 1.4,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PitchStep extends StatelessWidget {
  final ShootFrequency answer;
  final VoidCallback onNext;

  const _PitchStep({required this.answer, required this.onNext});

  InlineSpan get _echo {
    const bold = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    switch (answer) {
      case ShootFrequency.allTheTime:
        return const TextSpan(children: [
          TextSpan(text: 'You shoot the same content twice '),
          TextSpan(text: 'all the time', style: bold),
          TextSpan(text: '.'),
        ]);
      case ShootFrequency.often:
        return const TextSpan(children: [
          TextSpan(text: 'You shoot the same content twice '),
          TextSpan(text: 'often', style: bold),
          TextSpan(text: '.'),
        ]);
      case ShootFrequency.sometimes:
        return const TextSpan(children: [
          TextSpan(text: 'You '),
          TextSpan(text: 'sometimes', style: bold),
          TextSpan(text: ' shoot the same content twice.'),
        ]);
      case ShootFrequency.rarely:
        return const TextSpan(children: [
          TextSpan(text: 'Even '),
          TextSpan(text: 'rare', style: bold),
          TextSpan(text: ' re-shoots add up.'),
        ]);
    }
  }

  String get _headline => answer == ShootFrequency.allTheTime ||
          answer == ShootFrequency.often
      ? "That's hours\nyou're not getting back."
      : "That's time\nyou're not getting back.";

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      dotIndex: 1,
      buttonLabel: 'Continue',
      onButton: onNext,
      body: Column(
        children: [
          const Spacer(flex: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text.rich(
              _echo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(width: 96, height: 1.5, color: AppColors.accent),
          const SizedBox(height: 22),
          Text(
            _headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'FrameFuse fixes this.',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(flex: 10),
          const _FormatsIllustration(),
          const Spacer(flex: 10),
          const Text(
            'One take. Both formats.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(flex: 14),
        ],
      ),
    );
  }
}

/// Portrait (TikTok/Reels) and landscape (YouTube) crops of one scene.
class _FormatsIllustration extends StatelessWidget {
  const _FormatsIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth - 26; // 13dp side margins
        final portraitW = width * 0.335;
        final portraitH = portraitW * 16 / 9;
        final landscapeW = width - portraitW - 6;
        final landscapeH = landscapeW * 9 / 16;
        // Portrait window: full scene height, centred horizontally.
        const portraitWindowW = (9 / 16) * (9 / 16);
        return SizedBox(
          height: portraitH,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SceneCard(
                width: portraitW,
                height: portraitH,
                window: const Rect.fromLTWH(
                  0.5 - portraitWindowW / 2,
                  0,
                  portraitWindowW,
                  1,
                ),
                tags: const ['TikTok', 'Reels'],
              ),
              const SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: portraitH * 0.08),
                child: _SceneCard(
                  width: landscapeW,
                  height: landscapeH,
                  window: const Rect.fromLTWH(0, 0, 1, 1),
                  tags: const ['YouTube'],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SceneCard extends StatelessWidget {
  final double width;
  final double height;
  final Rect window;
  final List<String> tags;

  const _SceneCard({
    required this.width,
    required this.height,
    required this.window,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: SunsetScenePainter(window: window)),
            Positioned(
              left: 5,
              top: 5,
              child: Row(
                children: [
                  for (final tag in tags)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC3A3D42),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  final bool busy;
  final bool openSettings;
  final String? error;
  final VoidCallback onGrant;

  const _PermissionStep({
    required this.busy,
    required this.openSettings,
    required this.error,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      dotIndex: 2,
      buttonLabel: openSettings ? 'Open Settings' : 'Grant Access',
      onButton: onGrant,
      busy: busy,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          children: [
            const Spacer(flex: 22),
            const Text(
              'Almost ready.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Camera and microphone access are\nrequired to record both formats.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.45,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 32),
            const _PermissionRow(icon: Icons.photo_camera, label: 'Camera'),
            const Divider(height: 1, color: AppColors.divider),
            const _PermissionRow(icon: Icons.mic, label: 'Microphone'),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.record, fontSize: 12.5),
              ),
            ],
            const Spacer(flex: 10),
            const _PrivacyCard(),
            const Spacer(flex: 18),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PermissionRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 21),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    const item = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      letterSpacing: 0.3,
    );
    Widget check(String text) => Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Row(
            children: [
              const Icon(Icons.check, color: AppColors.accent, size: 13),
              const SizedBox(width: 8),
              Text(text, style: item),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: AppColors.accent, size: 26),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Totally private',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Zero data collection',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your footage never leaves your device. Ever.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          check('No sign-up or account'),
          check('No analytics or tracking'),
          check('Works completely offline'),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  final VoidCallback onFinish;
  const _DoneStep({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      buttonLabel: 'Try it now',
      showArrow: true,
      onButton: onFinish,
      body: Column(
        children: [
          const Spacer(flex: 28),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
            ),
            child: const Icon(Icons.check, color: AppColors.accent, size: 36),
          ),
          const SizedBox(height: 40),
          const Text(
            'Your content workflow\njust levelled up.',
            textAlign: TextAlign.center,
            style: _subtleStyle,
          ),
          const SizedBox(height: 62),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "Let's shoot your\n"),
                TextSpan(
                  text: 'first take.',
                  style: TextStyle(color: AppColors.accent),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: _heroStyle,
          ),
          const Spacer(flex: 40),
        ],
      ),
    );
  }
}
