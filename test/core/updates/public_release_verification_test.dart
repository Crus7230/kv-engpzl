import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/updates/app_update_service.dart';

// Optional release-time contract check. JSON must be fetched anonymously from
// GitHub's public releases endpoint, not synthesized from the local fixture.
void main() {
  final jsonPath = Platform.environment['KVM_RELEASE_JSON'];
  test(
    'published full APK is selected once by the production update parser',
    () {
      final version = Platform.environment['KVM_RELEASE_VERSION']!;
      final code = int.parse(Platform.environment['KVM_RELEASE_CODE']!);
      final bytes = int.parse(Platform.environment['KVM_RELEASE_BYTES']!);
      final digest = Platform.environment['KVM_RELEASE_SHA256']!.toLowerCase();
      final releases = jsonDecode(File(jsonPath!).readAsStringSync());

      final selected = AppUpdateRelease.select(
        releases,
        installedCode: code - 1,
      );
      expect(selected, isNotNull);
      expect(selected!.versionName, version);
      expect(selected.versionCode, code);
      expect(selected.bytes, bytes);
      expect(selected.sha256, digest);
      expect(
        selected.downloadUrl,
        'https://github.com/Crus7230/kv-engpzl/releases/download/'
        'v$version-r1-alpha/KVM-R1-$version-alpha.apk',
      );
      expect(AppUpdateRelease.select(releases, installedCode: code), isNull);
    },
    skip: jsonPath == null
        ? 'Set KVM_RELEASE_JSON and expected release metadata to audit a release.'
        : false,
  );
}
