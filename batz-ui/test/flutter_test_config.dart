import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/machine_lock.dart';

/// Runs around every test file of `test/`: the file holds the machine lock
/// shared while it runs, so that a performance measurement, which takes it
/// exclusive, runs alone (see [MachineLock]).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(MachineLock.acquireShared);
  tearDownAll(MachineLock.releaseShared);
  await testMain();
}
