import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:incil_camp_app/cubits/app_shell/app_shell_cubit.dart';
import 'package:incil_camp_app/cubits/app_shell/app_shell_state.dart';
import 'package:incil_camp_app/models/app_state.dart';
import 'package:incil_camp_app/models/emergency_config.dart';
import 'package:incil_camp_app/models/force_update_config.dart';
import 'package:incil_camp_app/models/onboarding_config.dart';
import 'package:incil_camp_app/models/onboarding_slide.dart';
import 'package:incil_camp_app/services/app_state_service.dart';
import 'package:incil_camp_app/services/local_storage_service.dart';
import 'package:incil_camp_app/services/push_service.dart';
import 'package:incil_camp_app/services/version_service.dart';

class _AppStateServiceMock extends Mock implements AppStateService {}

class _VersionServiceMock extends Mock implements VersionService {}

class _LocalStorageServiceMock extends Mock implements LocalStorageService {}

class _PushServiceMock extends Mock implements PushService {}

AppState _state({
  EmergencyConfig emergency = EmergencyConfig.empty,
  ForceUpdateConfig forceUpdate = ForceUpdateConfig.empty,
  OnboardingConfig onboarding = OnboardingConfig.empty,
  String webviewUrl = 'https://incil.huulo.io/app',
  List<String> allowedHosts = const ['incil.huulo.io'],
  Map<String, String> tags = const {},
}) => AppState(
  webviewUrl: webviewUrl,
  allowedHosts: allowedHosts,
  emergency: emergency,
  forceUpdate: forceUpdate,
  onboarding: onboarding,
  oneSignalTags: tags,
);

class _ForceUpdateConfigFake extends Fake implements ForceUpdateConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(_ForceUpdateConfigFake());
    registerFallbackValue(<String, String>{});
  });

  late _AppStateServiceMock appStateService;
  late _VersionServiceMock versionService;
  late _LocalStorageServiceMock storage;
  late _PushServiceMock pushService;
  late StreamController<AppState?> controller;

  setUp(() {
    appStateService = _AppStateServiceMock();
    versionService = _VersionServiceMock();
    storage = _LocalStorageServiceMock();
    pushService = _PushServiceMock();
    controller = StreamController<AppState?>.broadcast();

    when(() => appStateService.stream).thenAnswer((_) => controller.stream);
    when(() => appStateService.current).thenReturn(null);
    when(() => appStateService.retry()).thenAnswer((_) async {});
    when(() => versionService.mustForceUpdate(any())).thenReturn(false);
    when(() => storage.completedOnboardingVersion).thenReturn(0);
    when(
      () => storage.setCompletedOnboardingVersion(any()),
    ).thenAnswer((_) async {});
    when(() => pushService.applyTags(any())).thenAnswer((_) async {});
    when(() => pushService.requestPermission()).thenAnswer((_) async {});
  });

  tearDown(() => controller.close());

  AppShellCubit build({Duration splashTimeout = const Duration(seconds: 8)}) =>
      AppShellCubit(
        appStateService: appStateService,
        versionService: versionService,
        storage: storage,
        pushService: pushService,
        splashTimeout: splashTimeout,
      );

  group('initial state', () {
    test('starts on Splash when AppStateService has no cached state', () {
      final cubit = build();
      expect(cubit.state, isA<AppShellSplash>());
      cubit.close();
    });

    test('resolves immediately if AppStateService.current is non-null', () {
      when(() => appStateService.current).thenReturn(_state());
      final cubit = build();
      expect(cubit.state, isA<AppShellWebView>());
      cubit.close();
    });
  });

  group('screen-priority resolution', () {
    blocTest<AppShellCubit, AppShellState>(
      'emergency wins over force-update, onboarding, and webview',
      build: build,
      act: (c) => controller.add(
        _state(
          emergency: const EmergencyConfig(enabled: true, title: 'E'),
          forceUpdate: const ForceUpdateConfig(enabled: true, minIosBuild: 999),
          onboarding: const OnboardingConfig(
            enabled: true,
            version: 5,
            slides: [OnboardingSlide(title: 't', body: 'b')],
          ),
        ),
      ),
      verify: (c) => expect(c.state, isA<AppShellEmergency>()),
    );

    blocTest<AppShellCubit, AppShellState>(
      'force-update wins over onboarding and webview when version mandates it',
      build: () {
        when(() => versionService.mustForceUpdate(any())).thenReturn(true);
        return build();
      },
      act: (c) => controller.add(
        _state(
          forceUpdate: const ForceUpdateConfig(enabled: true, minIosBuild: 999),
          onboarding: const OnboardingConfig(
            enabled: true,
            version: 5,
            slides: [OnboardingSlide(title: 't', body: 'b')],
          ),
        ),
      ),
      verify: (c) => expect(c.state, isA<AppShellForceUpdate>()),
    );

    blocTest<AppShellCubit, AppShellState>(
      'onboarding shows when enabled and completed version is behind',
      build: () {
        when(() => storage.completedOnboardingVersion).thenReturn(0);
        return build();
      },
      act: (c) => controller.add(
        _state(
          onboarding: const OnboardingConfig(
            enabled: true,
            version: 2,
            slides: [OnboardingSlide(title: 't', body: 'b')],
          ),
        ),
      ),
      verify: (c) => expect(c.state, isA<AppShellOnboarding>()),
    );

    blocTest<AppShellCubit, AppShellState>(
      'onboarding is skipped when completed version is up to date',
      build: () {
        when(() => storage.completedOnboardingVersion).thenReturn(2);
        return build();
      },
      act: (c) => controller.add(
        _state(
          onboarding: const OnboardingConfig(
            enabled: true,
            version: 2,
            slides: [OnboardingSlide(title: 't', body: 'b')],
          ),
        ),
      ),
      verify: (c) => expect(c.state, isA<AppShellWebView>()),
    );

    blocTest<AppShellCubit, AppShellState>(
      'falls through to WebView when no special state applies',
      build: build,
      act: (c) => controller.add(_state()),
      verify: (c) => expect(c.state, isA<AppShellWebView>()),
    );
  });

  group('splash timeout', () {
    test(
      'transitions to Offline when no AppState arrives before timeout',
      () async {
        final cubit = build(splashTimeout: const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(cubit.state, isA<AppShellOffline>());
        await cubit.close();
      },
    );

    test(
      'does NOT fall through to Offline once AppState arrives in time',
      () async {
        final cubit = build(splashTimeout: const Duration(milliseconds: 100));
        controller.add(_state());
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(cubit.state, isA<AppShellWebView>());
        await cubit.close();
      },
    );
  });

  group('side effects', () {
    blocTest<AppShellCubit, AppShellState>(
      'applies OneSignal tags when the AppState changes them',
      build: build,
      act: (c) => controller.add(_state(tags: const {'app': 'incil'})),
      verify: (_) =>
          verify(() => pushService.applyTags({'app': 'incil'})).called(1),
    );

    blocTest<AppShellCubit, AppShellState>(
      'does NOT re-apply the same tag map on a duplicate snapshot',
      build: build,
      act: (c) {
        controller.add(_state(tags: const {'app': 'incil'}));
        controller.add(_state(tags: const {'app': 'incil'}));
      },
      verify: (_) => verify(() => pushService.applyTags(any())).called(1),
    );

    blocTest<AppShellCubit, AppShellState>(
      'markOnboardingCompleted persists the version and re-resolves',
      build: () {
        when(() => storage.completedOnboardingVersion).thenReturn(0);
        when(() => appStateService.current).thenReturn(
          _state(
            onboarding: const OnboardingConfig(
              enabled: true,
              version: 3,
              slides: [OnboardingSlide(title: 't', body: 'b')],
            ),
          ),
        );
        return build();
      },
      act: (c) async {
        when(() => storage.completedOnboardingVersion).thenReturn(3);
        await c.markOnboardingCompleted(3);
      },
      verify: (c) {
        verify(() => storage.setCompletedOnboardingVersion(3)).called(1);
        verify(() => pushService.requestPermission()).called(1);
        expect(c.state, isA<AppShellWebView>());
      },
    );

    blocTest<AppShellCubit, AppShellState>(
      'reportWebViewFailure transitions to Offline',
      build: () {
        when(() => appStateService.current).thenReturn(_state());
        return build();
      },
      act: (c) => c.reportWebViewFailure(),
      verify: (c) => expect(c.state, isA<AppShellOffline>()),
    );

    blocTest<AppShellCubit, AppShellState>(
      'handleDeepLink swaps the WebView URL when host is allowed',
      build: () {
        when(
          () => appStateService.current,
        ).thenReturn(_state(allowedHosts: const ['incil.huulo.io']));
        return build();
      },
      act: (c) =>
          c.handleDeepLink(Uri.parse('https://incil.huulo.io/program/123')),
      verify: (c) {
        final s = c.state;
        expect(s, isA<AppShellWebView>());
        expect(
          (s as AppShellWebView).url,
          'https://incil.huulo.io/program/123',
        );
      },
    );

    blocTest<AppShellCubit, AppShellState>(
      'handleDeepLink rejects a disallowed host',
      build: () {
        when(
          () => appStateService.current,
        ).thenReturn(_state(allowedHosts: const ['incil.huulo.io']));
        return build();
      },
      act: (c) => c.handleDeepLink(Uri.parse('https://evil.example.com/foo')),
      verify: (c) {
        // URL unchanged from the original AppState.
        expect((c.state as AppShellWebView).url, 'https://incil.huulo.io/app');
      },
    );
  });
}
