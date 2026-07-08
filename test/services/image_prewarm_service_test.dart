import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/services/image_prewarm_service.dart';

/// An [ImageProvider] whose completion the test controls: the image "loads"
/// (or errors) exactly when the test completes [completer].
class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  final completer = Completer<ImageInfo>();

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(completer.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, _TestImageProvider> providers;
  late int factoryCalls;
  late ImagePrewarmService service;

  setUp(() {
    providers = {};
    factoryCalls = 0;
    service = ImagePrewarmService(
      providerFactory: (url) {
        factoryCalls++;
        return providers.putIfAbsent(url, _TestImageProvider.new);
      },
    );
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
  });

  Future<ImageInfo> testImageInfo() async =>
      ImageInfo(image: await createTestImage(width: 1, height: 1));

  // Lets the image stream deliver its pending microtask callbacks.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('ImagePrewarmService', () {
    test('completes immediately for an empty URL list', () async {
      await expectLater(service.prewarm([]), completes);
      expect(factoryCalls, 0);
    });

    test('completes once all images are loaded, not before', () async {
      var done = false;
      unawaited(service.prewarm(['a', 'b']).whenComplete(() => done = true));

      await flush();
      expect(done, isFalse);

      providers['a']!.completer.complete(await testImageInfo());
      await flush();
      expect(done, isFalse, reason: 'must wait for the second image too');

      providers['b']!.completer.complete(await testImageInfo());
      await flush();
      expect(done, isTrue);
    });

    test('an errored image completes the prewarm without throwing', () async {
      final future = service.prewarm(['broken']);
      providers['broken']!.completer.completeError(Exception('404'));
      await expectLater(future, completes);
    });

    test('resolves after the timeout when an image never loads', () async {
      await expectLater(
        service.prewarm(['stuck'], timeout: const Duration(milliseconds: 50)),
        completes,
      );
      expect(providers['stuck']!.completer.isCompleted, isFalse);
    });

    test(
      'a second prewarm for an in-flight URL awaits the same load',
      () async {
        var firstDone = false;
        var secondDone = false;
        unawaited(service.prewarm(['a']).whenComplete(() => firstDone = true));
        unawaited(service.prewarm(['a']).whenComplete(() => secondDone = true));

        await flush();
        expect(firstDone, isFalse);
        expect(
          secondDone,
          isFalse,
          reason: 'second caller must not resolve before the image is cached',
        );
        expect(factoryCalls, 1, reason: 'the in-flight load must be reused');

        providers['a']!.completer.complete(await testImageInfo());
        await flush();
        expect(firstDone, isTrue);
        expect(secondDone, isTrue);
      },
    );

    test('an already-loaded URL is not requested again', () async {
      final first = service.prewarm(['a']);
      providers['a']!.completer.complete(await testImageInfo());
      await first;

      await expectLater(service.prewarm(['a']), completes);
      expect(factoryCalls, 1);
    });
  });
}
