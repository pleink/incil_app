import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:incil_camp_app/cubits/app_shell/app_shell_cubit.dart';
import 'package:incil_camp_app/cubits/app_shell/app_shell_state.dart';
import 'package:incil_camp_app/di/service_locator.dart';
import 'package:incil_camp_app/l10n/app_localizations.dart';
import 'package:incil_camp_app/screens/webview_screen.dart';
import 'package:incil_camp_app/services/connectivity_service.dart';
import 'package:incil_camp_app/services/url_service.dart';

class _UrlServiceMock extends Mock implements UrlService {}

class _ConnectivityServiceMock extends Mock implements ConnectivityService {}

class _AppShellCubitMock extends MockCubit<AppShellState>
    implements AppShellCubit {}

/// Fake platform implementation recording created controllers and every
/// `loadRequest` issued against them.
class _FakeWebViewPlatform extends WebViewPlatform {
  final List<_FakeWebViewController> controllers = [];
  final List<_FakeNavigationDelegate> delegates = [];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = _FakeNavigationDelegate(params);
    delegates.add(delegate);
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  final List<Uri> loadedUris = [];

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedUris.add(params.uri);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> reload() async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  late _FakeWebViewPlatform platform;
  late _UrlServiceMock urlService;
  late _ConnectivityServiceMock connectivity;
  late _AppShellCubitMock shellCubit;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    platform = _FakeWebViewPlatform();
    WebViewPlatform.instance = platform;

    urlService = _UrlServiceMock();
    when(() => urlService.openExternal(any())).thenAnswer((_) async => true);
    when(
      () => urlService.openInAppBrowser(any()),
    ).thenAnswer((_) async => true);

    connectivity = _ConnectivityServiceMock();
    when(() => connectivity.isOnline()).thenAnswer((_) async => true);
    when(
      () => connectivity.onlineStream,
    ).thenAnswer((_) => const Stream<bool>.empty());

    shellCubit = _AppShellCubitMock();
    whenListen(
      shellCubit,
      const Stream<AppShellState>.empty(),
      initialState: const AppShellSplash(),
    );

    getIt
      ..registerSingleton<UrlService>(urlService)
      ..registerSingleton<ConnectivityService>(connectivity);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget wrap(String url) => MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AppShellCubit>.value(
      value: shellCubit,
      child: WebViewScreen(url: url, allowedHosts: const ['incil.huulo.io']),
    ),
  );

  group('WebViewScreen URL updates', () {
    testWidgets('initial build loads the initial URL once', (tester) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/app'));

      expect(platform.controllers, hasLength(1));
      expect(platform.controllers.single.loadedUris, [
        Uri.parse('https://incil.huulo.io/app'),
      ]);
    });

    testWidgets('URL change triggers exactly one extra loadRequest on the SAME '
        'controller (no re-creation)', (tester) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/app'));
      await tester.pumpWidget(wrap('https://incil.huulo.io/program/42'));

      expect(platform.controllers, hasLength(1));
      expect(platform.controllers.single.loadedUris, [
        Uri.parse('https://incil.huulo.io/app'),
        Uri.parse('https://incil.huulo.io/program/42'),
      ]);
    });

    testWidgets('rebuild with an unchanged URL does not reload', (
      tester,
    ) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/app'));
      await tester.pumpWidget(wrap('https://incil.huulo.io/app'));

      expect(platform.controllers, hasLength(1));
      expect(platform.controllers.single.loadedUris, hasLength(1));
    });

    testWidgets(
      'AppShellWebView emission with a new URL loads it even without a '
      'widget rebuild (push deep link while WebView is active)',
      (tester) async {
        // go_router does not rebuild the route when the location stays
        // /webview, so the deep link must arrive via the cubit stream.
        const deepLink = AppShellWebView(
          url: 'https://incil.huulo.io/post/das-war-incil-24',
          allowedHosts: ['incil.huulo.io'],
          oneSignalTags: {},
        );
        whenListen(
          shellCubit,
          Stream<AppShellState>.fromIterable(const [deepLink]),
          initialState: const AppShellSplash(),
        );

        await tester.pumpWidget(wrap('https://incil.huulo.io/app'));
        await tester.pump();

        expect(platform.controllers, hasLength(1));
        expect(platform.controllers.single.loadedUris, [
          Uri.parse('https://incil.huulo.io/app'),
          Uri.parse('https://incil.huulo.io/post/das-war-incil-24'),
        ]);
      },
    );

    testWidgets(
      'AppShellWebView emission with the current URL does not reload',
      (tester) async {
        const same = AppShellWebView(
          url: 'https://incil.huulo.io/app',
          allowedHosts: ['incil.huulo.io'],
          oneSignalTags: {},
        );
        whenListen(
          shellCubit,
          Stream<AppShellState>.fromIterable(const [same]),
          initialState: const AppShellSplash(),
        );

        await tester.pumpWidget(wrap('https://incil.huulo.io/app'));
        await tester.pump();

        expect(platform.controllers.single.loadedUris, hasLength(1));
      },
    );
  });

  group('WebViewScreen navigation interception', () {
    testWidgets('shop.incil.ch opens in the in-app browser, not externally', (
      tester,
    ) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/app'));

      final decision = await platform.delegates.single.onNavigationRequest!(
        NavigationRequest(
          url: 'https://shop.incil.ch/products',
          isMainFrame: true,
        ),
      );

      expect(decision, NavigationDecision.prevent);
      verify(
        () => urlService.openInAppBrowser(
          Uri.parse('https://shop.incil.ch/products'),
        ),
      ).called(1);
      verifyNever(() => urlService.openExternal(any()));
    });

    testWidgets('unrelated external hosts still open externally', (
      tester,
    ) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/app'));

      final decision = await platform.delegates.single.onNavigationRequest!(
        NavigationRequest(url: 'https://example.com', isMainFrame: true),
      );

      expect(decision, NavigationDecision.prevent);
      verify(
        () => urlService.openExternal(Uri.parse('https://example.com')),
      ).called(1);
      verifyNever(() => urlService.openInAppBrowser(any()));
    });
  });
}
