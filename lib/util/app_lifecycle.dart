import 'dart:async';

import 'package:flutter/widgets.dart';

/// Completes once the app is in the foreground ([AppLifecycleState.resumed]).
///
/// While an iOS system alert (e.g. the push permission prompt) is on screen —
/// including its dismissal animation — the app sits in the `inactive` state.
/// A WKWebView platform view created during that window starts with a
/// suspended content process: it either never paints (white screen until the
/// app is restarted) or hangs mid-load. Callers that are about to put a
/// WebView on screen await this first.
Future<void> waitUntilAppResumed() async {
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    return;
  }
  final resumed = Completer<void>();
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(
    onResume: () {
      listener.dispose();
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  await resumed.future;
  // `resumed` is dispatched from applicationDidBecomeActive, but the UIKit
  // scene can still be mid-activation at that point — a WKWebView attached in
  // that window still latches NotVisible. Give the transition a beat.
  await Future<void>.delayed(const Duration(milliseconds: 500));
}
