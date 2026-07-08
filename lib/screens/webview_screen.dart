import 'dart:async';
import 'dart:io' show Platform;

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

const _iosSpoofedUserAgent =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36';

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
  late final WebViewController _controller;
  final _urls = getIt<UrlService>();
  final _connectivity = getIt<ConnectivityService>();
  StreamSubscription<bool>? _connSub;
  bool _wasOnline = true;

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
    final cubit = context.read<WebViewCubit>();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            // Seed consent keys before the huulo bundle runs so the cookie
            // banner and web push prompt never mount (issue #18).
            _controller.runJavaScript(WebViewPopupScripts.preseedConsent);
            cubit.onPageStarted();
          },
          onPageFinished: (_) {
            _controller.runJavaScript(WebViewPopupScripts.dismissPopups);
            cubit.onPageFinished();
          },
          onWebResourceError: (err) {
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
      _controller.setUserAgent(_iosSpoofedUserAgent);
    }

    _currentUrl = widget.url;
    _controller.loadRequest(Uri.parse(_currentUrl));

    _connectivity.isOnline().then((online) => _wasOnline = online);
    _connSub = _connectivity.onlineStream.listen((online) {
      // Auto-reload the WebView as soon as the network comes back so users
      // don't have to manually pull-to-refresh after a connection blip.
      if (online && !_wasOnline) _controller.reload();
      _wasOnline = online;
    });
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
    _connSub?.cancel();
    super.dispose();
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (isHostAllowed(uri, widget.allowedHosts)) {
      return NavigationDecision.navigate;
    }
    _urls.openExternal(uri);
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
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
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
