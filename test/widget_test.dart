import 'package:flutter_test/flutter_test.dart';
import 'package:kutsu_app/store/db.dart';

// Unit tests for the session-grouping key: a "session" is one device power-on
// period, keyed by the device clock (power-on epoch = ts - up).
void main() {
  group('KutsuDb.sessionKey', () {
    test('all readings in one power cycle share a key', () {
      // Same power-on (epoch 1_700_000_000); ts and up advance together.
      final a = KutsuDb.sessionKey(1700000010, 10, 50000);
      final b = KutsuDb.sessionKey(1700000020, 20, 51500);
      expect(a, equals(b));
      expect(a, equals(1700000000 * 1000));
    });

    test('a restart (uptime resets) starts a new session', () {
      final before = KutsuDb.sessionKey(1700000050, 50, 60000);
      final after = KutsuDb.sessionKey(1700000055, 5, 61000); // rebooted
      expect(before, isNot(equals(after)));
    });

    test('falls back safely when the device clock is unusable', () {
      final k = KutsuDb.sessionKey(null, 5, 100000);
      expect(k, isA<int>());
    });
  });
}
