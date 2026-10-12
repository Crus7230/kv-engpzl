import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MissingRetainedAssetsException implements Exception {
  const MissingRetainedAssetsException();
}

/// Media has its own immutable version, independent from app/content versions.
/// Android seeds it once from a full APK, then reuses it in logic-only updates.
class RetainedAssetBundle extends CachingAssetBundle {
  RetainedAssetBundle({required this.fallback, required this.manifest});

  static const channel = MethodChannel('kvm/retained_assets');
  static const packId = 'r1-media-v3';
  final AssetBundle fallback;
  final Map<String, dynamic> manifest;

  Set<String> get mediaPaths => {
    for (final asset in manifest['assets'] as List)
      (asset as Map)['path'] as String,
  };

  static Future<AssetBundle> prepare({
    AssetBundle? fallback,
    bool download = false,
  }) async {
    final source = fallback ?? rootBundle;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
      return source;
    final decoded = jsonDecode(
      await source.loadString('assets/asset_manifest.json'),
    );
    if (decoded is! Map<String, dynamic> ||
        decoded['manifestVersion'] != 1 ||
        decoded['packId'] != packId ||
        decoded['assets'] is! List) {
      throw const FormatException('Unsupported media manifest.');
    }
    final installed = await channel.invokeMethod<bool>(
      download ? 'downloadPack' : 'ensureInstalled',
      {
        'packId': packId,
        'assets': decoded['assets'],
        'download': decoded['download'],
      },
    );
    if (installed == false) throw const MissingRetainedAssetsException();
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
