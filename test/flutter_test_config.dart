import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/updates/app_update_service.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Widget tests have no Android host/network. Unmocked platform replies can
  // outlive pumpAndSettle; use an explicit no-update response for normal boots.
  // app_update_test.dart overrides this handler to verify positive/error cases.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(AndroidAppUpdateService.channel, (call) async {
        if (call.method == 'check') {
          return {'versionCode': 0, 'releasesJson': '[]'};
        }
        throw StateError('An installer must be explicitly mocked in a test.');
      });
  await testMain();
}
