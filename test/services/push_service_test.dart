import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/services/push_service.dart';

// Note: `initialize()` is never called here — it touches OneSignal statics
// which require a platform. `debugDispatchTarget` exercises the same
// dispatch/buffer path the click listener uses.
void main() {
  group('PushService target dispatch', () {
    test(
      'dispatch without a handler buffers; attaching flushes exactly once',
      () {
        final service = PushService();
        final received = <Uri>[];

        service.debugDispatchTarget(Uri.parse('https://a.example/1'));
        expect(received, isEmpty);

        service.onTargetUrl = received.add;
        expect(received, [Uri.parse('https://a.example/1')]);

        // Buffer must be cleared: re-attaching does not re-fire.
        service.onTargetUrl = received.add;
        expect(received, hasLength(1));
      },
    );

    test('multiple dispatches without a handler keep only the last URI', () {
      final service = PushService();
      final received = <Uri>[];

      service.debugDispatchTarget(Uri.parse('https://a.example/first'));
      service.debugDispatchTarget(Uri.parse('https://a.example/second'));

      service.onTargetUrl = received.add;
      expect(received, [Uri.parse('https://a.example/second')]);
    });

    test('handler attached first → immediate invoke, nothing buffered', () {
      final service = PushService();
      final received = <Uri>[];
      service.onTargetUrl = received.add;

      service.debugDispatchTarget(Uri.parse('https://a.example/live'));
      expect(received, [Uri.parse('https://a.example/live')]);

      // Detach then re-attach: nothing should have been buffered.
      service.onTargetUrl = null;
      service.onTargetUrl = received.add;
      expect(received, hasLength(1));
    });

    test('constructor-provided handler receives dispatches directly', () {
      final received = <Uri>[];
      final service = PushService(onTargetUrl: received.add);

      service.debugDispatchTarget(Uri.parse('https://a.example/ctor'));
      expect(received, [Uri.parse('https://a.example/ctor')]);
    });
  });
}
