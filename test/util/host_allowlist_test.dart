import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/util/host_allowlist.dart';

void main() {
  group('isHostAllowed', () {
    const hosts = ['incil.huulo.io', 'huulo.io', 'media.huulo.io'];

    test('allows exact match', () {
      expect(
        isHostAllowed(Uri.parse('https://incil.huulo.io/app'), hosts),
        isTrue,
      );
    });

    test('allows subdomain of an allowed host', () {
      expect(
        isHostAllowed(Uri.parse('https://cdn.huulo.io/foo'), hosts),
        isTrue,
      );
    });

    test('rejects unrelated host', () {
      expect(isHostAllowed(Uri.parse('https://google.com'), hosts), isFalse);
    });

    test('does NOT match by suffix collision', () {
      // evilhuulo.io must not be accepted just because it ends with "huulo.io".
      expect(isHostAllowed(Uri.parse('https://evilhuulo.io'), hosts), isFalse);
    });

    test('rejects non-http scheme', () {
      expect(isHostAllowed(Uri.parse('tel:+41000'), hosts), isFalse);
      expect(isHostAllowed(Uri.parse('mailto:a@b.ch'), hosts), isFalse);
      expect(isHostAllowed(Uri.parse('intent://foo'), hosts), isFalse);
    });

    test('handles case-insensitive host comparison', () {
      expect(isHostAllowed(Uri.parse('https://INCIL.HUULO.IO'), hosts), isTrue);
    });

    test('returns false on empty allowlist', () {
      expect(
        isHostAllowed(Uri.parse('https://anything.com'), const []),
        isFalse,
      );
    });

    test('returns false on empty host', () {
      expect(isHostAllowed(Uri.parse('https:///foo'), hosts), isFalse);
    });

    test('ignores empty/whitespace entries in allowlist', () {
      expect(
        isHostAllowed(Uri.parse('https://incil.huulo.io'), const [
          '',
          '   ',
          'incil.huulo.io',
        ]),
        isTrue,
      );
    });
  });
}
