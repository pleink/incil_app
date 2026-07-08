import 'dart:async';

import 'package:flutter/painting.dart';

/// Warms Flutter's global [ImageCache] with network images so screens can
/// render them without visible pop-in. Unlike `precacheImage` this needs no
/// [BuildContext], so the splash can hold on it before the first onboarding
/// frame is ever built.
class ImagePrewarmService {
  final _requested = <String>{};

  /// Downloads and decodes every URL not already requested this session.
  /// Completes once all images are cached, errored, or [timeout] elapsed —
  /// never throws, so callers can gate UI on it safely.
  Future<void> prewarm(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    final pending = [
      for (final url in urls)
        if (_requested.add(url)) _load(url),
    ];
    if (pending.isEmpty) return Future.value();
    return Future.wait(
      pending,
    ).timeout(timeout, onTimeout: () => const []).then((_) {});
  }

  Future<void> _load(String url) {
    // Same cache key as Image.network(url) (scale 1.0), so the slide's own
    // NetworkImage resolves synchronously from the cache afterwards.
    final completer = Completer<void>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void finish() {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      (_, _) => finish(),
      onError: (_, _) => finish(),
    );
    stream.addListener(listener);
    return completer.future;
  }
}
