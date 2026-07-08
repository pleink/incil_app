import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Warms Flutter's global [ImageCache] with network images so screens can
/// render them without visible pop-in. Unlike `precacheImage` this needs no
/// [BuildContext], so the splash can hold on it before the first onboarding
/// frame is ever built. Images land in the flutter_cache_manager disk cache,
/// so a repeat launch resolves them without network.
class ImagePrewarmService {
  ImagePrewarmService({ImageProvider Function(String url)? providerFactory})
    : _providerFactory = providerFactory ?? CachedNetworkImageProvider.new;

  final ImageProvider Function(String url) _providerFactory;

  /// Keyed by URL; entries stay after completion so a URL is only resolved
  /// once per session. Storing the future (not just the URL) lets a second
  /// caller await a load that is still in flight instead of skipping it.
  final _loads = <String, Future<void>>{};

  /// Streams whose listeners stay attached after the load completes. A
  /// listened-to image counts as "live" in [ImageCache], so it resolves
  /// synchronously even if large decodes evicted it from the LRU cache —
  /// without this, prewarming several full-screen photos can push the first
  /// one out before its screen ever builds. [release] detaches them.
  final _held = <(ImageStream, ImageStreamListener)>[];

  /// Downloads and decodes every URL, reusing loads already started this
  /// session. Completes once all images are cached, errored, or [timeout]
  /// elapsed — never throws, so callers can gate UI on it safely.
  Future<void> prewarm(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (urls.isEmpty) return Future.value();
    final pending = [
      for (final url in urls) _loads.putIfAbsent(url, () => _load(url)),
    ];
    return Future.wait(pending)
        .timeout(
          timeout,
          onTimeout: () {
            debugPrint(
              'ImagePrewarmService: timed out after $timeout — '
              'slow images will pop in after their screen is shown',
            );
            return const [];
          },
        )
        .then((_) {});
  }

  /// Detaches the listeners that keep prewarmed images live. Call once the
  /// screen that needed them is gone for good (e.g. onboarding completed) so
  /// the images become evictable again.
  void release() {
    for (final (stream, listener) in _held) {
      stream.removeListener(listener);
    }
    _held.clear();
    // Loads whose listener was just detached no longer pin their image, so a
    // later prewarm must resolve them again (cheap: disk cache).
    _loads.clear();
  }

  Future<void> _load(String url) {
    // Same cache key as the slide's own CachedNetworkImageProvider(url)
    // (scale 1.0), so it resolves synchronously from the cache afterwards.
    final completer = Completer<void>();
    final stream = _providerFactory(url).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (_, _) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (error, _) {
        debugPrint('ImagePrewarmService: failed to load $url: $error');
        if (!completer.isCompleted) completer.complete();
      },
    );
    stream.addListener(listener);
    _held.add((stream, listener));
    return completer.future;
  }
}
