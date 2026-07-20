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
import 'package:incil_camp_app/services/connectivity_service.dart';
import 'package:incil_camp_app/services/image_prewarm_service.dart';
import 'package:incil_camp_app/services/local_storage_service.dart';
import 'package:incil_camp_app/services/push_service.dart';
import 'package:incil_camp_app/services/version_service.dart';

class _AppStateServiceMock extends Mock implements AppStateService {}

class _VersionServiceMock extends Mock implements VersionService {}

class _LocalStorageServiceMock extends Mock implements LocalStorageService {}

class _PushServiceMock extends Mock implements PushService {}

class _ConnectivityServiceMock extends Mock implements ConnectivityService {}

class _ImagePrewarmServiceMock extends Mock implements ImagePrewarmService {}

AppState _state({
  EmergencyConfig emergency = EmergencyConfig.empty,
  ForceUpdateConfig forceUpdate = ForceUpdateConfig.empty,
  OnboardingConfig onboarding = OnboardingConfig.empty,
  String webviewUrl = 'https://incil.huulo.io/app',
  List<String> allowedHosts = const ['incil.huulo.io'],
  List<String> inAppBrowserHosts = const ['shop.incil.ch'],
  List<String> externalBrowserUrls = const ['/signup'],
  Map<String, String> tags = const {},
}) => AppState(
  webviewUrl: webviewUrl,
  allowedHosts: allowedHosts,
  inAppBrowserHosts: inAppBrowserHosts,
  externalBrowserUrls: externalBrowserUrls,
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
    registerFallbackValue(<String>[]);
  });

  late _AppStateServiceMock appStateService;
  late _VersionServiceMock versionService;
  late _LocalStorageServiceMock storage;
  late _PushServiceMock pushService;
  late _ConnectivityServiceMock connectivity;
  late _ImagePrewarmServiceMock imagePrewarm;
  late StreamController<AppState?> controller;
  late StreamController<bool> connController;

  setUp(() {
    appStateService = _AppStateServiceMock();
    versionService = _VersionServiceMock();
    storage = _LocalStorageServiceMock();
    pushService = _PushServiceMock();
    connectivity = _ConnectivityServiceMock();
    imagePrewarm = _ImagePrewarmServiceMock();
    controller = StreamController<AppState?>.broadcast();
    connController = StreamController<bool>.broadcast();

    when(() => appStateService.stream).thenAnswer((_) => controller.stream);
    when(() => appStateService.current).thenReturn(null);
    when(() => appStateService.hasRealData).thenReturn(true);
    when(() => appStateService.hasFreshData).thenReturn(true);
    when(() => appStateService.retry()).thenAnswer((_) async {});
    when(() => versionService.mustForceUpdate(any())).thenReturn(false);
    when(() => storage.completedOnboardingVersion).thenReturn(0);
    when(
      () => storage.setCompletedOnboardingVersion(any()),
    ).thenAnswer((_) async {});
    when(() => storage.pushPermissionRequested).thenReturn(false);
    when(() => storage.setPushPermissionRequested()).thenAnswer((_) async {});
    when(() => pushService.applyTags(any())).thenAnswer((_) async {});
    when(() => pushService.requestPermission()).thenAnswer((_) async {});
    when(() => connectivity.isOnline()).thenAnswer((_) async => true);
    when(() => imagePrewarm.prewarm(any())).thenAnswer((_) async {});
    when(
      () => connectivity.onlineStream,
    ).thenAnswer((_) => connController.stream);
  });

  tearDown(() {
    controller.close();
    connController.close();
  });

  AppShellCubit build({
    Duration minSplashDuration = Duration.zero,
    Duration splashTimeout = const Duration(seconds: 8),
  }) => AppShellCubit(
    appStateService: appStateService,
    versionService: versionService,
    storage: storage,
    pushService: pushService,
    connectivity: connectivity,
    imagePrewarm: imagePrewarm,
    minSplashDuration: minSplashDuration,
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

  group('minimum splash duration', () {
    test(
      'holds on Splash until the minimum elapses even when data is ready',
      () async {
        when(() => appStateService.current).thenReturn(_state());
        final cubit = build(
          minSplashDuration: const Duration(milliseconds: 80),
        );

        expect(cubit.state, isA<AppShellSplash>());
        await Future<void>.delayed(const Duration(milliseconds: 140));
        expect(cubit.state, isA<AppShellWebView>());

        await cubit.close();
      },
    );

    test('resolves the freshest state once the minimum elapses', () async {
      final cubit = build(minSplashDuration: const Duration(milliseconds: 80));
      controller.add(
        _state(emergency: const EmergencyConfig(enabled: true, title: 'E')),
      );
      when(() => appStateService.current).thenReturn(
        _state(emergency: const EmergencyConfig(enabled: true, title: 'E')),
      );

      expect(cubit.state, isA<AppShellSplash>());
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(cubit.state, isA<AppShellEmergency>());

      await cubit.close();
    });
  });

  group('screen-priority resolution', () {
    blocTest<AppShellCubit, AppShellState>(
      'emergency wins over force-update, onboarding, and webview',
      build: build,
      act: (c) => controller.add(
        _state(
          emergency: const EmergencyConfig(enabled: true, title: 'E'),
          forceUpdate: const ForceUpdateConfig(
            enabled: true,
            minIosBuildNumber: 999,
          ),
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
          forceUpdate: const ForceUpdateConfig(
            enabled: true,
            minIosBuildNumber: 999,
          ),
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
      'enabled force-update falls through to WebView when VersionService '
      'does not mandate it (gating fully delegated)',
      build: build, // default stub: mustForceUpdate -> false
      act: (c) => controller.add(
        _state(
          forceUpdate: const ForceUpdateConfig(
            enabled: true,
            minIosBuildNumber: 999,
            minAndroidVersionCode: 999,
          ),
        ),
      ),
      verify: (c) {
        expect(c.state, isA<AppShellWebView>());
        verify(() => versionService.mustForceUpdate(any())).called(1);
      },
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

    test('holds on Splash past min duration when only cached data exists, then '
        'resolves the fresh snapshot once it arrives', () async {
      // Cached state says webview; the fresh snapshot enables onboarding.
      when(() => appStateService.hasFreshData).thenReturn(false);
      when(() => appStateService.current).thenReturn(_state());
      final cubit = build(splashTimeout: const Duration(seconds: 8));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        cubit.state,
        isA<AppShellSplash>(),
        reason: 'cached data alone must not resolve the splash',
      );

      when(() => appStateService.hasFreshData).thenReturn(true);
      final fresh = _state(
        onboarding: const OnboardingConfig(
          enabled: true,
          version: 1,
          slides: [OnboardingSlide(title: 't', body: 'b')],
        ),
      );
      when(() => appStateService.current).thenReturn(fresh);
      controller.add(fresh);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<AppShellOnboarding>());
      await cubit.close();
    });

    test(
      'holds on Splash until the onboarding slide images are prewarmed',
      () async {
        final prewarmCompleter = Completer<void>();
        when(
          () => imagePrewarm.prewarm(any()),
        ).thenAnswer((_) => prewarmCompleter.future);

        final cubit = build();
        controller.add(
          _state(
            onboarding: const OnboardingConfig(
              enabled: true,
              version: 1,
              slides: [
                OnboardingSlide(
                  title: 't',
                  body: 'b',
                  imageUrl: 'https://example.com/slide.png',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state,
          isA<AppShellSplash>(),
          reason: 'must wait for the images before showing onboarding',
        );
        verify(
          () => imagePrewarm.prewarm(['https://example.com/slide.png']),
        ).called(1);

        prewarmCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state, isA<AppShellOnboarding>());

        await cubit.close();
      },
    );

    test(
      'falls back to the cached state (not Offline) when the timeout elapses '
      'without a fresh snapshot',
      () async {
        when(() => appStateService.hasFreshData).thenReturn(false);
        when(() => appStateService.current).thenReturn(_state());
        final cubit = build(splashTimeout: const Duration(milliseconds: 50));

        await Future<void>.delayed(const Duration(milliseconds: 120));
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
      'does NOT request push permission when WebView is shown — the prompt '
      'belongs to the end of onboarding',
      build: build,
      act: (c) => controller.add(_state()),
      verify: (_) => verifyNever(() => pushService.requestPermission()),
    );

    blocTest<AppShellCubit, AppShellState>(
      'does NOT re-request push permission on onboarding completion if '
      'already asked',
      build: () {
        when(() => storage.pushPermissionRequested).thenReturn(true);
        when(() => appStateService.current).thenReturn(_state());
        return build();
      },
      act: (c) => c.markOnboardingCompleted(1),
      verify: (_) => verifyNever(() => pushService.requestPermission()),
    );

    blocTest<AppShellCubit, AppShellState>(
      'does NOT request push permission when entering Emergency screen',
      build: build,
      act: (c) => controller.add(
        _state(emergency: const EmergencyConfig(enabled: true, title: 'E')),
      ),
      verify: (_) => verifyNever(() => pushService.requestPermission()),
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

    test('markOnboardingCompleted holds Onboarding until the permission '
        'request completes — a WKWebView created while the iOS alert has the '
        'app inactive never paints (white screen until restart)', () async {
      final permissionAnswered = Completer<void>();
      when(
        () => pushService.requestPermission(),
      ).thenAnswer((_) => permissionAnswered.future);
      when(() => appStateService.current).thenReturn(
        _state(
          onboarding: const OnboardingConfig(
            enabled: true,
            version: 3,
            slides: [OnboardingSlide(title: 't', body: 'b')],
          ),
        ),
      );
      final cubit = build();
      expect(cubit.state, isA<AppShellOnboarding>());

      final completion = cubit.markOnboardingCompleted(3);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Alert still open: the shell must not resolve to WebView yet, and the
      // version must stay unpersisted so snapshots keep resolving Onboarding.
      expect(cubit.state, isA<AppShellOnboarding>());
      verifyNever(() => storage.setCompletedOnboardingVersion(any()));

      when(() => storage.completedOnboardingVersion).thenReturn(3);
      permissionAnswered.complete();
      await completion;

      expect(cubit.state, isA<AppShellWebView>());
      verify(() => storage.setCompletedOnboardingVersion(3)).called(1);
      await cubit.close();
    });

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

  group('connectivity-driven recovery', () {
    test(
      'first launch with no Firestore data and offline goes straight to Offline',
      () async {
        when(() => appStateService.current).thenReturn(_state());
        when(() => appStateService.hasRealData).thenReturn(false);
        when(() => connectivity.isOnline()).thenAnswer((_) async => false);

        final cubit = build();
        // Push the initial offline read through before the first emit.
        await Future<void>.microtask(() {});
        // Re-emit so _resolve runs against the updated _isOnline.
        controller.add(_state());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(cubit.state, isA<AppShellOffline>());
        await cubit.close();
      },
    );

    test(
      'auto-retries when connectivity flips online while on Offline screen',
      () async {
        when(() => appStateService.current).thenReturn(_state());
        final cubit = build();
        cubit.reportWebViewFailure();
        expect(cubit.state, isA<AppShellOffline>());

        // Drop and recover — only an offline→online transition triggers retry.
        connController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        connController.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(() => appStateService.retry()).called(1);
        expect(cubit.state, isA<AppShellWebView>());
        await cubit.close();
      },
    );

    test(
      'does NOT auto-retry on connectivity events while NOT on Offline screen',
      () async {
        when(() => appStateService.current).thenReturn(_state());
        final cubit = build();
        expect(cubit.state, isA<AppShellWebView>());

        connController.add(false);
        connController.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verifyNever(() => appStateService.retry());
        await cubit.close();
      },
    );
  });

  group('deep link queueing', () {
    final target = Uri.parse('https://incil.huulo.io/program/42');

    test(
      'link during Splash is queued and applied on the first snapshot',
      () async {
        final cubit = build();
        expect(cubit.state, isA<AppShellSplash>());

        cubit.handleDeepLink(target);
        expect(cubit.state, isA<AppShellSplash>());

        controller.add(_state());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect((cubit.state as AppShellWebView).url, target.toString());
        await cubit.close();
      },
    );

    test(
      'link while Emergency is queued and applied once emergency lifts',
      () async {
        final cubit = build();
        controller.add(
          _state(emergency: const EmergencyConfig(enabled: true, title: 'E')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(cubit.state, isA<AppShellEmergency>());

        cubit.handleDeepLink(target);
        expect(cubit.state, isA<AppShellEmergency>());

        controller.add(_state());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect((cubit.state as AppShellWebView).url, target.toString());
        await cubit.close();
      },
    );

    test('link while Onboarding is queued and applied after '
        'markOnboardingCompleted', () async {
      final onboardingState = _state(
        onboarding: const OnboardingConfig(
          enabled: true,
          version: 3,
          slides: [OnboardingSlide(title: 't', body: 'b')],
        ),
      );
      when(() => appStateService.current).thenReturn(onboardingState);
      final cubit = build();
      expect(cubit.state, isA<AppShellOnboarding>());

      cubit.handleDeepLink(target);
      expect(cubit.state, isA<AppShellOnboarding>());

      when(() => storage.completedOnboardingVersion).thenReturn(3);
      await cubit.markOnboardingCompleted(3);

      expect((cubit.state as AppShellWebView).url, target.toString());
      await cubit.close();
    });

    test('applied link survives an identical follow-up snapshot and is not '
        're-applied (URL stability)', () async {
      final cubit = build();
      cubit.handleDeepLink(target);

      controller.add(_state());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((cubit.state as AppShellWebView).url, target.toString());

      // Routine Firestore churn: same config URL — must not yank the user
      // back to the home page, and the consumed link must not re-apply.
      controller.add(_state());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((cubit.state as AppShellWebView).url, target.toString());

      // A real config URL change DOES navigate away.
      controller.add(_state(webviewUrl: 'https://incil.huulo.io/new'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (cubit.state as AppShellWebView).url,
        'https://incil.huulo.io/new',
      );
      await cubit.close();
    });

    test('disallowed host is dropped at apply time and not resurrected by '
        'later snapshots', () async {
      final cubit = build();
      cubit.handleDeepLink(Uri.parse('https://evil.example.com/foo'));

      controller.add(_state());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (cubit.state as AppShellWebView).url,
        'https://incil.huulo.io/app',
      );

      controller.add(_state());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (cubit.state as AppShellWebView).url,
        'https://incil.huulo.io/app',
      );
      await cubit.close();
    });

    test('last-write-wins when two links are queued before apply', () async {
      final cubit = build();
      cubit.handleDeepLink(Uri.parse('https://incil.huulo.io/first'));
      cubit.handleDeepLink(Uri.parse('https://incil.huulo.io/second'));

      controller.add(_state());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        (cubit.state as AppShellWebView).url,
        'https://incil.huulo.io/second',
      );
      await cubit.close();
    });

    test('apply-time validation uses the snapshot allowlist, not the '
        'receive-time one', () async {
      // current == null at receive-time → no allowlist available yet.
      final cubit = build();
      cubit.handleDeepLink(Uri.parse('https://other.huulo.io/x'));

      controller.add(
        _state(allowedHosts: const ['incil.huulo.io', 'other.huulo.io']),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect((cubit.state as AppShellWebView).url, 'https://other.huulo.io/x');
      await cubit.close();
    });

    test(
      'link while ForceUpdate is queued and applied once the block lifts',
      () async {
        when(() => versionService.mustForceUpdate(any())).thenReturn(true);
        final cubit = build();
        controller.add(
          _state(
            forceUpdate: const ForceUpdateConfig(
              enabled: true,
              minIosBuildNumber: 999,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(cubit.state, isA<AppShellForceUpdate>());

        cubit.handleDeepLink(target);
        expect(cubit.state, isA<AppShellForceUpdate>());

        // Force-update lifted (e.g. config lowered the minimum version).
        when(() => versionService.mustForceUpdate(any())).thenReturn(false);
        controller.add(_state());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect((cubit.state as AppShellWebView).url, target.toString());
        await cubit.close();
      },
    );

    test(
      'queued link with a non-http(s) scheme is dropped at apply time',
      () async {
        final cubit = build();
        cubit.handleDeepLink(Uri.parse('tel:+41791234567'));

        controller.add(_state());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          (cubit.state as AppShellWebView).url,
          'https://incil.huulo.io/app',
        );
        await cubit.close();
      },
    );

    test('immediately rejected link (disallowed host while WebView active) '
        'is NOT queued and does not resurface on later snapshots', () async {
      when(() => appStateService.current).thenReturn(_state());
      final cubit = build();
      expect(cubit.state, isA<AppShellWebView>());

      cubit.handleDeepLink(Uri.parse('https://evil.example.com/foo'));
      expect(
        (cubit.state as AppShellWebView).url,
        'https://incil.huulo.io/app',
      );

      // Even with the disallowed host now allowed, a rejected immediate
      // link must not have been queued for later application.
      controller.add(
        _state(allowedHosts: const ['incil.huulo.io', 'evil.example.com']),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (cubit.state as AppShellWebView).url,
        'https://incil.huulo.io/app',
      );
      await cubit.close();
    });

    test('immediate apply with a non-http(s) scheme leaves the WebView URL '
        'unchanged', () async {
      when(() => appStateService.current).thenReturn(_state());
      final cubit = build();
      expect(cubit.state, isA<AppShellWebView>());

      cubit.handleDeepLink(Uri.parse('mailto:hi@incil.huulo.io'));
      expect(
        (cubit.state as AppShellWebView).url,
        'https://incil.huulo.io/app',
      );
      await cubit.close();
    });

    test(
      'link queued while Offline is applied after retryFromOffline',
      () async {
        final cubit = build(splashTimeout: const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(cubit.state, isA<AppShellOffline>());

        cubit.handleDeepLink(target);
        expect(cubit.state, isA<AppShellOffline>());

        when(() => appStateService.current).thenReturn(_state());
        await cubit.retryFromOffline();

        expect((cubit.state as AppShellWebView).url, target.toString());
        await cubit.close();
      },
    );
  });
}
