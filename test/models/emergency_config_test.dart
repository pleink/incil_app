import 'package:flutter_test/flutter_test.dart';
import 'package:incil_camp_app/models/emergency_config.dart';

void main() {
  group('EmergencyConfig', () {
    test('empty is disabled with all fields null', () {
      const config = EmergencyConfig.empty;
      expect(config.enabled, isFalse);
      expect(config.title, isNull);
      expect(config.subtitle, isNull);
      expect(config.body1, isNull);
      expect(config.contact, isNull);
      expect(config.body2, isNull);
      expect(config.footer, isNull);
      expect(config.updatedAt, isNull);
      expect(config.callablePhone, isNull);
    });

    test('fromJson parses all fields', () {
      final config = EmergencyConfig.fromJson(const {
        'enabled': true,
        'title': 'Notfall',
        'subtitle': 'Bitte ruhig bleiben',
        'body1': 'Erster Absatz',
        'contact': '+41 79 123 45 67',
        'body2': 'Zweiter Absatz',
        'footer': 'Fussnote',
        'updatedAt': '2026-07-01T10:00:00.000Z',
      });

      expect(config.enabled, isTrue);
      expect(config.title, 'Notfall');
      expect(config.subtitle, 'Bitte ruhig bleiben');
      expect(config.body1, 'Erster Absatz');
      expect(config.contact, '+41 79 123 45 67');
      expect(config.body2, 'Zweiter Absatz');
      expect(config.footer, 'Fussnote');
      expect(config.updatedAt, DateTime.utc(2026, 7, 1, 10));
    });

    test('fromJson tolerates empty map', () {
      final config = EmergencyConfig.fromJson(const {});
      expect(config, EmergencyConfig.empty);
    });

    test('toJson -> fromJson round-trip with all fields set', () {
      final original = EmergencyConfig(
        enabled: true,
        title: 'Notfall',
        subtitle: 'Untertitel',
        body1: 'Text 1',
        contact: '+41791234567',
        body2: 'Text 2',
        footer: 'Fussnote',
        updatedAt: DateTime.utc(2026, 7, 1, 12, 30),
      );

      expect(EmergencyConfig.fromJson(original.toJson()), original);
    });

    test('toJson -> fromJson round-trip with only enabled', () {
      const original = EmergencyConfig(enabled: true);
      expect(EmergencyConfig.fromJson(original.toJson()), original);
    });

    test('toJson omits null fields', () {
      const config = EmergencyConfig(enabled: false, title: 'T');
      expect(config.toJson(), {'enabled': false, 'title': 'T'});
    });

    test('callablePhone is not part of toJson', () {
      const config = EmergencyConfig(enabled: true, contact: '+41791234567');
      expect(config.toJson().containsKey('callablePhone'), isFalse);
    });

    group('callablePhone', () {
      String? callable(String? contact) =>
          EmergencyConfig(enabled: true, contact: contact).callablePhone;

      test('null contact -> null', () {
        expect(callable(null), isNull);
      });

      test('empty contact -> null', () {
        expect(callable(''), isNull);
      });

      test('whitespace-only contact -> null', () {
        expect(callable('   '), isNull);
      });

      test('plain digits pass through', () {
        expect(callable('117'), '117');
        expect(callable('0791234567'), '0791234567');
      });

      test('leading + is kept', () {
        expect(callable('+41791234567'), '+41791234567');
      });

      test('spaces are stripped', () {
        expect(callable('+41 79 123 45 67'), '+41791234567');
      });

      test('dashes are stripped', () {
        expect(callable('079-123-45-67'), '0791234567');
      });

      test('parentheses are stripped', () {
        expect(callable('(079) 123 45 67'), '0791234567');
      });

      test('dots are stripped', () {
        expect(callable('079.123.45.67'), '0791234567');
      });

      test('mixed separators are stripped', () {
        expect(callable('+41 (79) 123-45.67'), '+41791234567');
      });

      test('fewer than 3 digits -> null', () {
        expect(callable('12'), isNull);
        expect(callable('+1'), isNull);
      });

      test('exactly 3 digits is valid', () {
        expect(callable('112'), '112');
      });

      test('exactly 15 digits is valid', () {
        expect(callable('123456789012345'), '123456789012345');
        expect(callable('+123456789012345'), '+123456789012345');
      });

      test('more than 15 digits -> null', () {
        expect(callable('1234567890123456'), isNull);
      });

      test('plus not at start -> null', () {
        expect(callable('079+1234567'), isNull);
      });

      test('multiple plus signs -> null', () {
        expect(callable('++41791234567'), isNull);
      });

      test('letters -> null', () {
        expect(callable('call me'), isNull);
        expect(callable('0800-FLOWERS'), isNull);
      });

      test('other garbage -> null', () {
        expect(callable('tel:+41791234567'), isNull);
        expect(callable('#*123'), isNull);
      });
    });
  });
}
