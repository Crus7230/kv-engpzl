import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Public, APK-only update channel. No credentials, save data or telemetry are
/// transmitted. Alpha releases are intentional; /releases/latest excludes them.
class AppUpdateRelease {
  const AppUpdateRelease({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.sha256,
    required this.bytes,
  });

  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String sha256;
  final int bytes;

  Map<String, Object> toJson() => {
    'versionName': versionName,
    'versionCode': versionCode,
    'downloadUrl': downloadUrl,
    'sha256': sha256,
    'bytes': bytes,
  };

  static AppUpdateRelease? select(
    Object? source, {
    required int installedCode,
  }) {
    if (source is! List) return null;
    final candidates = <AppUpdateRelease>[];
    for (final entry in source) {
      try {
        if (entry is! Map ||
            entry['draft'] != false ||
            entry['published_at'] == null)
          continue;
        final tag = entry['tag_name'];
        if (tag is! String ||
            !RegExp(r'^v\d+\.\d+\.\d+(-r1-alpha)?$').hasMatch(tag))
          continue;
        final body = entry['body'];
        if (body is! String) continue;
        final marker = RegExp(
          r'<!-- kvm-update: (\{[^\r\n]*\}) -->',
        ).firstMatch(body);
        if (marker == null) continue;
        final metadata = jsonDecode(marker.group(1)!);
        if (metadata is! Map || metadata['schema'] != 1) continue;
        final versionName = metadata['versionName'];
        final versionCode = metadata['versionCode'];
        if (versionName is! String ||
            !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(versionName) ||
            versionCode is! int ||
            versionCode > 2147483647 ||
            versionCode <= installedCode ||
            tag != 'v$versionName' && tag != 'v$versionName-r1-alpha')
          continue;
        final assets = entry['assets'];
        if (assets is! List) continue;
        final matching = assets
            .whereType<Map>()
            .where(
              (asset) =>
                  asset['name'] == 'KVM-R1-$versionName-alpha.apk' &&
                  asset['state'] == 'uploaded',
            )
            .toList();
        // Never choose a logic-only APK or an ambiguous asset set for a device
        // that may not have seeded its media pack yet.
        if (matching.length != 1) continue;
        final asset = matching.single;
        final size = asset['size'];
        final url = asset['browser_download_url'];
        final digest = asset['digest'];
        if (size is! int ||
            size <= 0 ||
            size > 150 * 1024 * 1024 ||
            url is! String ||
            digest is! String ||
            !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest))
          continue;
        final uri = Uri.tryParse(url);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'github.com' ||
            uri.hasPort ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            uri.path !=
                '/Crus7230/kv-engpzl/releases/download/$tag/KVM-R1-$versionName-alpha.apk')
          continue;
        candidates.add(
          AppUpdateRelease(
            versionName: versionName,
            versionCode: versionCode,
            downloadUrl: url,
            sha256: digest.substring(7).toLowerCase(),
            bytes: size,
          ),
        );
      } on FormatException {
        // A malformed release must not hide another valid release or block play.
        continue;
      }
    }
    candidates.sort((a, b) => b.versionCode.compareTo(a.versionCode));
    return candidates.firstOrNull;
  }
}

enum AppUpdateInstallResult { launched, permissionRequired }

abstract interface class AppUpdateService {
  Future<AppUpdateRelease?> check();
  Future<void> download(AppUpdateRelease release);
  Future<AppUpdateInstallResult> install();
  Future<void> openInstallPermission();
}

class AndroidAppUpdateService implements AppUpdateService {
  const AndroidAppUpdateService();

  static const channel = MethodChannel('kvm/app_updates');

  @override
  Future<AppUpdateRelease?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final data = await channel
          .invokeMapMethod<String, dynamic>('check')
          .timeout(const Duration(seconds: 5));
      if (data == null ||
          data['versionCode'] is! int ||
          data['releasesJson'] is! String)
        return null;
      return AppUpdateRelease.select(
        jsonDecode(data['releasesJson'] as String),
        installedCode: data['versionCode'] as int,
      );
    } catch (_) {
      // Offline, rate limited, old native shell or invalid metadata: keep play.
      return null;
    }
  }

  @override
  Future<void> download(AppUpdateRelease release) =>
      channel.invokeMethod<void>('download', release.toJson());

  @override
  Future<AppUpdateInstallResult> install() async {
    final state = await channel.invokeMethod<String>('install');
    return switch (state) {
      'launched' => AppUpdateInstallResult.launched,
      'permissionRequired' => AppUpdateInstallResult.permissionRequired,
      _ => throw StateError('Installer unavailable.'),
    };
  }

  @override
  Future<void> openInstallPermission() =>
      channel.invokeMethod<void>('openInstallPermission');
}
