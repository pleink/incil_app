import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../cubits/app_shell/app_shell_cubit.dart';
import '../cubits/webview/webview_cubit.dart';
import '../cubits/webview/webview_state.dart';
import '../di/service_locator.dart';
import '../services/url_service.dart';
import '../util/host_allowlist.dart';
import '../widgets/loading_view.dart';

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

  @override
  void initState() {
    super.initState();
    final cubit = context.read<WebViewCubit>();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => cubit.onPageStarted(),
          onPageFinished: (_) => cubit.onPageFinished(),
          onWebResourceError: (err) {
            // Only main-frame errors should trip the offline fallback; ignore
            // sub-resource hiccups (favicons, ads, …) that the page can survive.
            if (err.isForMainFrame == true) {
              cubit.onLoadFailed(err.description);
            }
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
    return BlocListener<WebViewCubit, WebViewState>(
      listenWhen: (prev, curr) => curr is WebViewFailed,
      listener: (context, state) {
        // Hand the failure to the shell cubit, which will switch to /offline.
        context.read<AppShellCubit>().reportWebViewFailure();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              BlocBuilder<WebViewCubit, WebViewState>(
                builder: (_, state) => state is WebViewLoading
                    ? const Center(child: LoadingView())
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
