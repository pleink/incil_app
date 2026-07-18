import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

class UrlService {
  Future<bool> openExternal(Uri uri) =>
      _launch(uri, LaunchMode.externalApplication);

  /// Opens [uri] in a native in-app browser sheet — SFSafariViewController
  /// on iOS, Chrome Custom Tabs on Android — instead of leaving the app.
  Future<bool> openInAppBrowser(Uri uri) =>
      _launch(uri, LaunchMode.inAppBrowserView);

  Future<bool> dial(String phoneNumber) {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    return openExternal(uri);
  }

  Future<bool> _launch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (e, st) {
      developer.log(
        'Failed to launch URL: $uri',
        name: 'UrlService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
