import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:incil_camp_app/di/service_locator.dart';
import 'package:incil_camp_app/screens/webview_screen.dart';
import 'package:incil_camp_app/services/connectivity_service.dart';
import 'package:incil_camp_app/services/url_service.dart';

class _UrlServiceMock extends Mock implements UrlService {}

class _ConnectivityServiceMock extends Mock implements ConnectivityService {}

/// Fake platform implementation recording created controllers and every
/// `loadRequest` issued against them.
class _FakeWebViewPlatform extends WebViewPlatform {
  final List<_FakeWebViewController> controllers = [];

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
  ) => _FakeNavigationDelegate(params);

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

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

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
  late _ConnectivityServiceMock connectivity;

  setUp(() {
    platform = _FakeWebViewPlatform();
    WebViewPlatform.instance = platform;

    connectivity = _ConnectivityServiceMock();
    when(() => connectivity.isOnline()).thenAnswer((_) async => true);
    when(
      () => connectivity.onlineStream,
    ).thenAnswer((_) => const Stream<bool>.empty());

    getIt
      ..registerSingleton<UrlService>(_UrlServiceMock())
      ..registerSingleton<ConnectivityService>(connectivity);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget wrap(String url) => MaterialApp(
    home: WebViewScreen(url: url, allowedHosts: const ['incil.huulo.io']),
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
  });
}
