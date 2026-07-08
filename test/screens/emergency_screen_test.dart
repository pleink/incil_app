import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:incil_camp_app/di/service_locator.dart';
import 'package:incil_camp_app/l10n/app_localizations.dart';
import 'package:incil_camp_app/models/emergency_config.dart';
import 'package:incil_camp_app/screens/emergency_screen.dart';
import 'package:incil_camp_app/services/url_service.dart';
import 'package:incil_camp_app/widgets/primary_button.dart';

class _UrlServiceMock extends Mock implements UrlService {}

const _callButtonLabel = 'Notfallnummer anrufen';
const _fallbackTitle = 'Notfall';

const _fullConfig = EmergencyConfig(
  enabled: true,
  title: 'Sturmwarnung',
  subtitle: 'Lager wird evakuiert',
  body1: 'Bitte begebt euch sofort zum Sammelpunkt.',
  contact: '+41 79 123 45 67',
  body2: 'Weitere Infos folgen per Push.',
  footer: 'Lagerleitung Incil',
);

void main() {
  late _UrlServiceMock urlService;

  setUp(() {
    urlService = _UrlServiceMock();
    when(() => urlService.dial(any())).thenAnswer((_) async => true);
    getIt.registerSingleton<UrlService>(urlService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget wrap(EmergencyConfig config) => MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: EmergencyScreen(config: config),
  );

  double topOf(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  group('EmergencyScreen', () {
    testWidgets('renders all six fields plus updatedAt in the correct order', (
      tester,
    ) async {
      final updatedAt = DateTime(2026, 7, 1, 12, 30);
      final config = EmergencyConfig(
        enabled: true,
        title: _fullConfig.title,
        subtitle: _fullConfig.subtitle,
        body1: _fullConfig.body1,
        contact: _fullConfig.contact,
        body2: _fullConfig.body2,
        footer: _fullConfig.footer,
        updatedAt: updatedAt,
      );

      await tester.pumpWidget(wrap(config));

      final title = find.text('Sturmwarnung');
      final subtitle = find.text('Lager wird evakuiert');
      final body1 = find.text('Bitte begebt euch sofort zum Sammelpunkt.');
      final button = find.widgetWithText(PrimaryButton, _callButtonLabel);
      final body2 = find.text('Weitere Infos folgen per Push.');
      final footer = find.text('Lagerleitung Incil');
      final updated = find.textContaining('01.07.2026');

      for (final f in [title, subtitle, body1, button, body2, footer]) {
        expect(f, findsOneWidget);
      }
      expect(updated, findsOneWidget);

      // Design order: message cards stacked together, call button pinned to
      // the bottom above footer + timestamp.
      final positions = [
        topOf(tester, title),
        topOf(tester, subtitle),
        topOf(tester, body1),
        topOf(tester, body2),
        topOf(tester, button),
        topOf(tester, footer),
        topOf(tester, updated),
      ];
      for (var i = 1; i < positions.length; i++) {
        expect(
          positions[i],
          greaterThan(positions[i - 1]),
          reason: 'element $i must be rendered below element ${i - 1}',
        );
      }
    });

    testWidgets('omits empty and whitespace-only fields (no blank texts)', (
      tester,
    ) async {
      const config = EmergencyConfig(
        enabled: true,
        title: 'Titel',
        subtitle: '   ',
        body1: '',
        contact: null,
        body2: '\n\t',
        footer: 'Fusszeile',
      );

      await tester.pumpWidget(wrap(config));

      expect(find.text('Titel'), findsOneWidget);
      expect(find.text('Fusszeile'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);

      // No Text widget may hold blank content.
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.data?.trim().isNotEmpty, isTrue);
      }
    });

    testWidgets('shows call button for a valid contact', (tester) async {
      await tester.pumpWidget(
        wrap(const EmergencyConfig(enabled: true, contact: '0791234567')),
      );

      expect(
        find.widgetWithText(PrimaryButton, _callButtonLabel),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    for (final (label, contact) in [
      ('null', null),
      ('empty', ''),
      ('whitespace', '   '),
      ('too short', '12'),
      ('letters', '0800-FLOWERS'),
    ]) {
      testWidgets('hides call button when contact is $label', (tester) async {
        await tester.pumpWidget(
          wrap(EmergencyConfig(enabled: true, contact: contact)),
        );

        expect(find.byType(PrimaryButton), findsNothing);
        verifyNever(() => urlService.dial(any()));
      });
    }

    testWidgets('never renders the raw contact value as text', (tester) async {
      await tester.pumpWidget(wrap(_fullConfig));

      expect(find.text('+41 79 123 45 67'), findsNothing);
      expect(find.textContaining('+41'), findsNothing);
    });

    testWidgets('tapping the call button dials the sanitized number once', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const EmergencyConfig(enabled: true, contact: '+41 (0)79 123-45.67'),
        ),
      );

      await tester.tap(find.widgetWithText(PrimaryButton, _callButtonLabel));
      await tester.pump();

      verify(() => urlService.dial('+410791234567')).called(1);
      verifyNoMoreInteractions(urlService);
    });

    testWidgets('all-null config renders fallback title without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(EmergencyConfig.empty));

      expect(tester.takeException(), isNull);
      expect(find.text(_fallbackTitle), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
      // Only the title text is rendered.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('blank title falls back to the default title', (tester) async {
      await tester.pumpWidget(
        wrap(const EmergencyConfig(enabled: true, title: '   ')),
      );

      expect(find.text(_fallbackTitle), findsOneWidget);
    });

    testWidgets('long content scrolls instead of overflowing', (tester) async {
      final longText = List.filled(40, 'Sehr langer Absatz.').join(' ');
      final config = EmergencyConfig(
        enabled: true,
        title: 'Titel',
        subtitle: longText,
        body1: longText,
        contact: '0791234567',
        body2: longText,
        footer: longText,
        updatedAt: DateTime(2026, 7, 1),
      );

      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(config));

      // No RenderFlex overflow exception thrown during layout.
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Footer starts off-screen and becomes reachable by scrolling.
      final footerFinder = find.text(longText).last;
      await tester.scrollUntilVisible(
        footerFinder,
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
