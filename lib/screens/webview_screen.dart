import 'package:flutter/material.dart';

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
    // Placeholder — full webview lands in M11.
    return Scaffold(body: Center(child: Text('WebView → $url')));
  }
}
