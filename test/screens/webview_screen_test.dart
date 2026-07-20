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
import 'package:incil_camp_app/util/webview_popup_scripts.dart';

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
  final List<String> javaScripts = [];
  final Map<String, JavaScriptChannelParams> javaScriptChannels = {};
  bool verticalScrollBarEnabled = true;
  bool horizontalScrollBarEnabled = true;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedUris.add(params.uri);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setVerticalScrollBarEnabled(bool enabled) async {
    verticalScrollBarEnabled = enabled;
  }

  @override
  Future<void> setHorizontalScrollBarEnabled(bool enabled) async {
    horizontalScrollBarEnabled = enabled;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {
    javaScripts.add(javaScript);
  }

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    javaScriptChannels[javaScriptChannelParams.name] = javaScriptChannelParams;
  }

  @override
  Future<void> reload() async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  UrlChangeCallback? onUrlChange;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    this.onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {
    this.onUrlChange = onUrlChange;
  }

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

  Widget wrap(
    String url, {
    List<String> externalBrowserUrls = const ['/signup'],
  }) => MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AppShellCubit>.value(
      value: shellCubit,
      child: WebViewScreen(
        url: url,
        allowedHosts: const ['incil.huulo.io'],
        inAppBrowserHosts: const ['shop.incil.ch'],
        externalBrowserUrls: externalBrowserUrls,
      ),
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

    testWidgets('hides native WebView scrollbars', (tester) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/app'));

      expect(platform.controllers.single.verticalScrollBarEnabled, isFalse);
      expect(platform.controllers.single.horizontalScrollBarEnabled, isFalse);
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
          inAppBrowserHosts: ['shop.incil.ch'],
          externalBrowserUrls: ['/signup'],
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
          inAppBrowserHosts: ['shop.incil.ch'],
          externalBrowserUrls: ['/signup'],
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

  group('WebViewScreen injected scripts', () {
    testWidgets('page start seeds consent and starts Google login remover', (
      tester,
    ) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/login'));

      platform.delegates.single.onPageStarted!('https://incil.huulo.io/login');

      expect(
        platform.controllers.single.javaScripts,
        containsAllInOrder([
          WebViewPopupScripts.preseedConsent,
          WebViewPopupScripts.removeGoogleLogin,
          WebViewPopupScripts.externalBrowserInterceptor(const ['/signup']),
        ]),
      );
    });

    testWidgets(
      'page finish dismisses popups and reruns Google login remover',
      (tester) async {
        await tester.pumpWidget(wrap('https://incil.huulo.io/login'));

        platform.delegates.single.onPageFinished!(
          'https://incil.huulo.io/login',
        );

        expect(
          platform.controllers.single.javaScripts,
          containsAllInOrder([
            WebViewPopupScripts.dismissPopups,
            WebViewPopupScripts.removeGoogleLogin,
            WebViewPopupScripts.externalBrowserInterceptor(const ['/signup']),
          ]),
        );
      },
    );

    testWidgets('URL change reruns Google login remover for SPA routes', (
      tester,
    ) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/password-reset'));

      platform.delegates.single.onUrlChange!(
        const UrlChange(url: 'https://incil.huulo.io/login'),
      );

      expect(
        platform.controllers.single.javaScripts,
        contains(WebViewPopupScripts.removeGoogleLogin),
      );
    });

    testWidgets(
      'URL change on password reset keeps external URL interception intact',
      (tester) async {
        await tester.pumpWidget(wrap('https://incil.huulo.io/login'));

        platform.delegates.single.onUrlChange!(
          const UrlChange(url: 'https://incil.huulo.io/password-reset'),
        );

        final decision = await platform.delegates.single.onNavigationRequest!(
          NavigationRequest(
            url: 'https://incil.huulo.io/signup',
            isMainFrame: true,
          ),
        );

        expect(decision, NavigationDecision.prevent);
        expect(
          platform.controllers.single.javaScripts,
          contains(WebViewPopupScripts.removeGoogleLogin),
        );
        verify(
          () => urlService.openExternal(
            Uri.parse('https://incil.huulo.io/signup'),
          ),
        ).called(1);
      },
    );

    test('Google login remover watches SPA history without timing out', () {
      expect(WebViewPopupScripts.removeGoogleLogin, contains('popstate'));
      expect(WebViewPopupScripts.removeGoogleLogin, contains('pushState'));
      expect(WebViewPopupScripts.removeGoogleLogin, contains('replaceState'));
      expect(WebViewPopupScripts.removeGoogleLogin, isNot(contains('30000')));
      expect(
        WebViewPopupScripts.removeGoogleLogin,
        isNot(contains('disconnect')),
      );
    });

    testWidgets('registers JavaScript channel for SPA external URL clicks', (
      tester,
    ) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/login'));

      final channel = platform
          .controllers
          .single
          .javaScriptChannels[WebViewPopupScripts.externalBrowserChannel];

      expect(channel, isNotNull);

      channel!.onMessageReceived(
        const JavaScriptMessage(message: 'https://incil.huulo.io/signup'),
      );

      verify(
        () =>
            urlService.openExternal(Uri.parse('https://incil.huulo.io/signup')),
      ).called(1);
    });

    testWidgets('ignores JavaScript channel URLs not listed as external', (
      tester,
    ) async {
      await tester.pumpWidget(wrap('https://incil.huulo.io/login'));

      final channel = platform
          .controllers
          .single
          .javaScriptChannels[WebViewPopupScripts.externalBrowserChannel]!;

      channel.onMessageReceived(
        const JavaScriptMessage(message: 'https://incil.huulo.io/login'),
      );

      verifyNever(() => urlService.openExternal(any()));
    });
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

    testWidgets(
      'configured external URLs override allowed hosts and leave the app',
      (tester) async {
        await tester.pumpWidget(wrap('https://incil.huulo.io/login'));

        final decision = await platform.delegates.single.onNavigationRequest!(
          NavigationRequest(
            url: 'https://incil.huulo.io/signup',
            isMainFrame: true,
          ),
        );

        expect(decision, NavigationDecision.prevent);
        verify(
          () => urlService.openExternal(
            Uri.parse('https://incil.huulo.io/signup'),
          ),
        ).called(1);
        verifyNever(() => urlService.openInAppBrowser(any()));
      },
    );

    testWidgets(
      'Google OAuth is no longer specially allowed inside the WebView',
      (tester) async {
        await tester.pumpWidget(wrap('https://incil.huulo.io/app'));

        final decision = await platform.delegates.single.onNavigationRequest!(
          NavigationRequest(
            url: 'https://accounts.google.com/o/oauth2/v2/auth',
            isMainFrame: true,
          ),
        );

        expect(decision, NavigationDecision.prevent);
        verify(
          () => urlService.openExternal(
            Uri.parse('https://accounts.google.com/o/oauth2/v2/auth'),
          ),
        ).called(1);
        verifyNever(() => urlService.openInAppBrowser(any()));
      },
    );

    testWidgets(
      'Firebase auth handler is no longer specially allowed inside the WebView',
      (tester) async {
        await tester.pumpWidget(wrap('https://incil.huulo.io/app'));

        final decision = await platform.delegates.single.onNavigationRequest!(
          NavigationRequest(
            url: 'https://auth.huulo.app/__/auth/handler?state=abc&code=123',
            isMainFrame: true,
          ),
        );

        expect(decision, NavigationDecision.prevent);
        verify(
          () => urlService.openExternal(
            Uri.parse(
              'https://auth.huulo.app/__/auth/handler?state=abc&code=123',
            ),
          ),
        ).called(1);
        verifyNever(() => urlService.openInAppBrowser(any()));
      },
    );
  });
}
