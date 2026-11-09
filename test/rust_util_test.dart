import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/utils/rust_util.dart';

void main() {
  test('concurrent users wait for the same complete initialization', () async {
    final ready = Completer<void>();
    var starts = 0;
    final initializer = RustInitializer(() {
      starts++;
      return ready.future;
    });
    var completed = false;

    final first = initializer.ensureInitialized();
    final second = initializer.ensureInitialized();
    final observed = first.then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);

    expect(starts, 1);
    expect(identical(first, second), isTrue);
    expect(completed, isFalse);
    ready.complete();
    await observed;
    await second;
    await initializer.ensureInitialized();
    expect(starts, 1);
    expect(completed, isTrue);
  });

  test(
    'failed initialization stays failed without reinitializing FRB',
    () async {
      final failure = StateError('native library unavailable');
      var starts = 0;
      final initializer = RustInitializer(() async {
        starts++;
        throw failure;
      });

      await expectLater(
        initializer.ensureInitialized(),
        throwsA(same(failure)),
      );
      await expectLater(
        initializer.ensureInitialized(),
        throwsA(same(failure)),
      );
      expect(starts, 1);
    },
  );

  test(
    'synchronous initialization errors are shared as a failed future',
    () async {
      final failure = StateError('loader failed');
      var starts = 0;
      final initializer = RustInitializer(() {
        starts++;
        throw failure;
      });

      await expectLater(
        initializer.ensureInitialized(),
        throwsA(same(failure)),
      );
      await expectLater(
        initializer.ensureInitialized(),
        throwsA(same(failure)),
      );
      expect(starts, 1);
    },
  );
}
