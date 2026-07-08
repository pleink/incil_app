import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:incil_camp_app/cubits/app_shell/app_shell_cubit.dart';
import 'package:incil_camp_app/cubits/app_shell/app_shell_state.dart';
import 'package:incil_camp_app/l10n/app_localizations.dart';
import 'package:incil_camp_app/models/onboarding_config.dart';
import 'package:incil_camp_app/models/onboarding_slide.dart';
import 'package:incil_camp_app/screens/onboarding_screen.dart';
import 'package:incil_camp_app/widgets/primary_button.dart';

class _AppShellCubitMock extends MockCubit<AppShellState>
    implements AppShellCubit {}

const _nextLabel = 'Weiter';
const _doneLabel = "Los geht's";

// imageUrl stays null throughout: widget tests have no network, and the
// beige fallback path is what renders anyway.
const _twoSlides = OnboardingConfig(
  enabled: true,
  version: 3,
  slides: [
    OnboardingSlide(title: 'Willkommen im Lager', body: 'Erster Text.'),
    OnboardingSlide(title: 'Was geht als Nächstes?', body: 'Zweiter Text.'),
  ],
);

void main() {
  late _AppShellCubitMock shell;

  setUp(() {
    shell = _AppShellCubitMock();
    when(() => shell.markOnboardingCompleted(any())).thenAnswer((_) async {});
  });

  Widget wrap(OnboardingConfig config) => MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AppShellCubit>.value(
      value: shell,
      child: OnboardingScreen(config: config),
    ),
  );

  group('OnboardingScreen', () {
    testWidgets('empty slides bypass onboarding via completion', (
      tester,
    ) async {
      const config = OnboardingConfig(enabled: true, version: 7, slides: []);

      await tester.pumpWidget(wrap(config));
      await tester.pump();

      verify(() => shell.markOnboardingCompleted(7)).called(1);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('renders the first slide with next button and story bars', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_twoSlides));

      expect(
        find.text('Willkommen im Lager', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Erster Text.'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, _nextLabel), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, _doneLabel), findsNothing);
      // One story bar per slide.
      expect(find.byType(AnimatedContainer), findsNWidgets(2));
      verifyNever(() => shell.markOnboardingCompleted(any()));
    });

    testWidgets('next advances to the last slide and swaps the button label', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_twoSlides));

      await tester.tap(find.widgetWithText(PrimaryButton, _nextLabel));
      await tester.pumpAndSettle();

      expect(
        find.text('Was geht als Nächstes?', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Zweiter Text.'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, _doneLabel), findsOneWidget);
      verifyNever(() => shell.markOnboardingCompleted(any()));
    });

    testWidgets('done button on the last slide completes with the version', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_twoSlides));

      await tester.tap(find.widgetWithText(PrimaryButton, _nextLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, _doneLabel));
      await tester.pump();

      verify(() => shell.markOnboardingCompleted(3)).called(1);
    });

    testWidgets('swiping to the last slide also swaps the button label', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_twoSlides));

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 800);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(PrimaryButton, _doneLabel), findsOneWidget);
    });
  });
}
