import 'dart:async';

import 'package:stackly_auth/motion.dart';

/// Loaded by `flutter test` before every test file in this directory.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Motion.ambient = false;
  await testMain();
}
