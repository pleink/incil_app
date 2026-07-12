import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../cubits/app_shell/app_shell_cubit.dart';
import '../cubits/app_shell/app_shell_state.dart';
import '../cubits/webview/webview_cubit.dart';
import '../cubits/webview/webview_state.dart';
import '../di/service_locator.dart';
import '../l10n/app_localizations.dart';
import '../services/connectivity_service.dart';
import '../services/url_service.dart';
import '../util/host_allowlist.dart';
import '../util/webview_popup_scripts.dart';
import '../widgets/loading_view.dart';

/// iOS reports itself as Android Chrome: with an iOS UA the huulo page
/// mounts its PWA install banner, and no storage seed reliably keeps it
/// away (tried `@huulo/hideInstallBanner` — the banner still showed).
const _iosSpoofedUserAgent =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36';

/// Hosts that open in an in-app browser sheet instead of leaving the app
/// entirely — e.g. huulo's "Shop" link, which points at Incil's own webshop.
const _inAppBrowserHosts = ['shop.incil.ch'];

class WebViewScreen extends StatelessWidget {
  const WebViewScreen({
    super.key,
    required this.url,
    required this.allowedHosts,
  });

  final String url;
  final List<String> allowedHosts;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WebViewCubit(),
      child: _WebViewView(url: url, allowedHosts: allowedHosts),
    );
  }
}

class _WebViewView extends StatefulWidget {
  const _WebViewView({required this.url, required this.allowedHosts});

  final String url;
  final List<String> allowedHosts;

  @override
  State<_WebViewView> createState() => _WebViewViewState();
}

class _WebViewViewState extends State<_WebViewView> {
  late WebViewController _controller;
  final _urls = getIt<UrlService>();
  final _connectivity = getIt<ConnectivityService>();
  StreamSubscription<bool>? _connSub;
  bool _wasOnline = true;

  /// iOS: on first launch the WebContent process behind the huulo page dies
  /// (JS unresponsive, nothing painted) while a plain app restart always
  /// heals it. A restart differs from re-attaching the platform view in one
  /// way we can reproduce in-app: it discards the WKWebView entirely and
  /// starts a fresh content process. The watchdog probes the page's JS
  /// engine after load and, when it never responds, rebuilds the controller
  /// from scratch — the in-app equivalent of that restart.
  Timer? _livenessTimer;
  int _recreateAttempts = 0;
  static const _maxRecreateAttempts = 2;

  /// iOS: set when `onPageFinished` arrives; the loading overlay is lifted
  /// only once the watchdog sees the page's JS respond afterwards. A
  /// post-finish process death (and its recreate) thus stays hidden behind
  /// the loading screen — the user sees loading → content, never the white
  /// dead page.
  bool _pendingFinish = false;

  /// Null when Firebase isn't initialized (widget tests) so the watchdog's
  /// reporting degrades to a no-op instead of throwing.
  FirebaseCrashlytics? get _crashlytics =>
      Firebase.apps.isEmpty ? null : FirebaseCrashlytics.instance;

  /// The URL currently loaded in the controller. Tracked here because URL
  /// swaps can arrive through two channels: a widget rebuild (config change)
  /// or an AppShellCubit emission (push deep link) — see the BlocListener in
  /// [build]. The latter is required: go_router skips the route rebuild when
  /// the location stays `/webview`, so `didUpdateWidget` alone never sees
  /// deep links that arrive while the WebView is already on screen.
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = _createController();
    _controller.loadRequest(Uri.parse(_currentUrl));

    _connectivity.isOnline().then((online) => _wasOnline = online);
    _connSub = _connectivity.onlineStream.listen((online) {
      // Auto-reload the WebView as soon as the network comes back so users
      // don't have to manually pull-to-refresh after a connection blip.
      if (online && !_wasOnline) _controller.reload();
      _wasOnline = online;
    });

    if (Platform.isIOS) _startLivenessWatchdog();
  }

  WebViewController _createController() {
    final cubit = context.read<WebViewCubit>();
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // The huulo page paints no body background of its own; anything but
      // white here bleeds through and clashes with its white UI elements.
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (u) {
            // Seed consent keys before the huulo bundle runs so the cookie
            // banner and web push prompt never mount (issue #18).
            controller.runJavaScript(WebViewPopupScripts.preseedConsent);
            cubit.onPageStarted();
          },
          onPageFinished: (u) {
            controller.runJavaScript(WebViewPopupScripts.dismissPopups);
            if (Platform.isIOS) {
              // Don't reveal the page yet — on a first visit the content
              // process can die right after onPageFinished (huulo's auth
              // iframe); the watchdog lifts the overlay once JS responds.
              _pendingFinish = true;
            } else {
              cubit.onPageFinished();
            }
          },
          onWebResourceError: (err) {
            // A killed WebContent process is recoverable — swap in a fresh
            // controller instead of falling through to the offline screen.
            // (The first-launch hang usually doesn't fire this signal — the
            // process hangs rather than terminates — the watchdog covers
            // that; this is the fast path for when WebKit does notice.)
            if (err.errorType ==
                    WebResourceErrorType.webContentProcessTerminated &&
                _recreateAttempts < _maxRecreateAttempts) {
              _livenessTimer?.cancel();
              _recreateWebView();
              return;
            }
            // Only main-frame errors should trip the offline fallback; ignore
            // sub-resource hiccups (favicons, ads, …) that the page can survive.
            if (err.isForMainFrame == true) {
              cubit.onLoadFailed(err.description);
            }
          },
          onNavigationRequest: _handleNavigation,
        ),
      );

    if (Platform.isIOS) {
      controller.setUserAgent(_iosSpoofedUserAgent);
    }

    return controller;
  }

  /// Probes the page's JS engine for the whole lifetime of the screen: the
  /// content process doesn't only die during load — on first launch the
  /// huulo page is alive until the Firebase auth iframe kicks in seconds
  /// after onPageFinished, then goes silent. Two consecutive timeouts mean
  /// the process is gone — recover via [_recreateWebView]. A busy-but-alive
  /// page (huulo's cold boot blocks the main thread for a while) only
  /// delays a single answer, it doesn't stay silent twice in a row.
  void _startLivenessWatchdog() {
    _livenessTimer?.cancel();
    var failures = 0;
    var probeInFlight = false;
    _livenessTimer = Timer.periodic(const Duration(milliseconds: 400), (
      timer,
    ) async {
      // One probe at a time: against a dead process every probe hangs until
      // its timeout, and stacking them would just inflate the failure count.
      if (probeInFlight) return;
      probeInFlight = true;
      try {
        await _controller
            .runJavaScriptReturningResult('1')
            .timeout(const Duration(seconds: 1));
        failures = 0;
        if (_pendingFinish && mounted) {
          _pendingFinish = false;
          context.read<WebViewCubit>().onPageFinished();
        }
      } on TimeoutException {
        failures++;
        if (failures >= 2) {
          timer.cancel();
          _recreateWebView();
        }
      } catch (_) {
        // Eval errors mid-navigation say nothing about process health.
      } finally {
        probeInFlight = false;
      }
    });
  }

  /// The in-app equivalent of an app restart, which is the one thing known
  /// to heal the first-launch hang: discard the hung WKWebView entirely so
  /// a fresh controller gets a fresh WebContent process, then reload.
  /// Bounded so a page that keeps dying falls through to the regular
  /// offline handling instead of looping forever.
  void _recreateWebView() {
    if (!mounted) return;
    if (_recreateAttempts >= _maxRecreateAttempts) {
      // Recreating didn't heal it — give up and let the shell switch to the
      // offline screen rather than leaving the loading overlay up forever.
      _crashlytics?.recordError(
        'WebView content process unresponsive after '
        '$_recreateAttempts recreate attempts',
        StackTrace.current,
        fatal: false,
      );
      context.read<WebViewCubit>().onLoadFailed(
        'WebView content process unresponsive',
      );
      return;
    }
    _recreateAttempts++;
    // Breadcrumb, not an error: recovery working as designed — but worth
    // watching in the dashboard to see how often it fires in the wild.
    _crashlytics?.log('WebView recreate #$_recreateAttempts ($_currentUrl)');
    _pendingFinish = false;
    setState(() {
      _controller = _createController();
    });
    _controller.loadRequest(Uri.parse(_currentUrl));
    _startLivenessWatchdog();
  }

  @override
  void didUpdateWidget(covariant _WebViewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _swapUrl(widget.url);
    }
  }

  /// Loads [url] without recreating the controller; no-op when it is already
  /// the current URL (e.g. the same swap arriving via both channels).
  void _swapUrl(String url) {
    if (url == _currentUrl) return;
    _currentUrl = url;
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _livenessTimer?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (isHostAllowed(uri, widget.allowedHosts)) {
      return NavigationDecision.navigate;
    }
    if (isHostAllowed(uri, _inAppBrowserHosts)) {
      _urls.openInAppBrowser(uri);
    } else {
      _urls.openExternal(uri);
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WebViewCubit, WebViewState>(
          listenWhen: (prev, curr) => curr is WebViewFailed,
          listener: (context, state) {
            // Hand the failure to the shell cubit, which switches to /offline.
            context.read<AppShellCubit>().reportWebViewFailure();
          },
        ),
        // Push deep links: the shell cubit emits a new AppShellWebView with the
        // target URL, but go_router won't rebuild this route (location is
        // unchanged), so apply the swap directly from the state stream.
        BlocListener<AppShellCubit, AppShellState>(
          listenWhen: (prev, curr) => curr is AppShellWebView,
          listener: (context, state) =>
              _swapUrl((state as AppShellWebView).url),
        ),
      ],
      // System back (Android button/gesture) walks the in-WebView history
      // instead of popping the single-entry go_router stack, which would
      // close the app. At the WebView root the press is swallowed on
      // purpose; screen switches are redirect-driven, never pop-driven.
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _controller.canGoBack()) {
            await _controller.goBack();
          }
        },
        child: Scaffold(
          // Match the WebView's white so the status-bar strip outside the
          // SafeArea doesn't stand out against the page.
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              SafeArea(
                // Keyed by controller identity: when the watchdog rebuilds
                // the controller, the platform view must be rebuilt too.
                child: WebViewWidget(
                  key: ObjectKey(_controller),
                  controller: _controller,
                ),
              ),
              // Outside the SafeArea on purpose: while loading, the branded
              // surface color has to cover the status-bar strip too, which
              // is white otherwise to match the page.
              BlocBuilder<WebViewCubit, WebViewState>(
                builder: (context, state) => state is WebViewLoading
                    ? ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: Center(
                          child: LoadingView(
                            message: AppLocalizations.of(
                              context,
                            ).webviewLoadingMessage,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
