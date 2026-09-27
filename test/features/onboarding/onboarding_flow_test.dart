import 'package:frame_fuse/core/theme/app_theme.dart';
import 'package:frame_fuse/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.darkTheme, home: const OnboardingScreen()),
      ),
    );
  }

  testWidgets('welcome → question → pitch echoes the answer', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Welcome to FrameFuse'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.textContaining('How often do you shoot'), findsOneWidget);
    // Continue is disabled until an answer is picked.
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.text('Sometimes'));
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('FrameFuse fixes this.'), findsOneWidget);
    expect(find.text('One take. Both formats.'), findsOneWidget);
    expect(find.textContaining("That's time"), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('onboarding_shoot_frequency'), 'sometimes');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Almost ready.'), findsOneWidget);
    expect(find.text('Totally private'), findsOneWidget);
    expect(find.text('Grant Access'), findsOneWidget);
  });

  testWidgets('system back steps backwards through onboarding', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.textContaining('How often'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to FrameFuse'), findsOneWidget);
  });
}
