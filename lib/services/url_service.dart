import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

class UrlService {
  Future<bool> openExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      developer.log(
        'Failed to launch external URL: $uri',
        name: 'UrlService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<bool> dial(String phoneNumber) {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    return openExternal(uri);
  }
}
