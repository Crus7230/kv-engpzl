import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Media has its own immutable version, independent from app/content versions.
/// Android seeds it once from a full APK, then reuses it in logic-only updates.
class RetainedAssetBundle extends CachingAssetBundle {
  RetainedAssetBundle({required this.fallback, required this.manifest});

  static const channel = MethodChannel('kvm/retained_assets');
  static const packId = 'r1-media-v2';
  final AssetBundle fallback;
  final Map<String, dynamic> manifest;

  Set<String> get mediaPaths => {
    for (final asset in manifest['assets'] as List)
      (asset as Map)['path'] as String,
  };

  static Future<AssetBundle> prepare({AssetBundle? fallback}) async {
    final source = fallback ?? rootBundle;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
      return source;
    final decoded = jsonDecode(
      await source.loadString('assets/asset_manifest.json'),
    );
    if (decoded is! Map<String, dynamic> || decoded['manifestVersion'] != 1) {
      throw const FormatException('Unsupported media manifest.');
    }
    await channel.invokeMethod<void>('ensureInstalled', {
      'packId': packId,
      'assets': decoded['assets'],
    });
    return RetainedAssetBundle(fallback: source, manifest: decoded);
  }

  @override
  Future<ByteData> load(String key) async {
    if (!mediaPaths.contains(key)) return fallback.load(key);
    final bytes = await channel.invokeMethod<Uint8List>('readAsset', {
      'packId': packId,
      'path': key,
    });
    if (bytes == null) throw StateError('Missing installed media: $key');
    return ByteData.sublistView(bytes);
  }
}
