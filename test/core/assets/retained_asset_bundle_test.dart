import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/assets/retained_asset_bundle.dart';

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(
      utf8.encode(
        key == 'assets/asset_manifest.json'
            ? jsonEncode({
                'manifestVersion': 1,
                'assets': [
                  {
                    'path': 'assets/legacy/world-map.png',
                    'sha256': 'test',
                    'bytes': 3,
                  },
                ],
              })
            : 'fallback:$key',
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(RetainedAssetBundle.channel, null);
  });

  test(
    'Android loads versioned retained media and delegates unrelated assets',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(RetainedAssetBundle.channel, (call) async {
            calls.add(call);
            return call.method == 'readAsset'
                ? Uint8List.fromList([1, 2, 3])
                : null;
          });
      final bundle = await RetainedAssetBundle.prepare(fallback: _Bundle());
      expect(calls.single.method, 'ensureInstalled');
      expect(calls.single.arguments['packId'], 'r1-media-v2');
      final bytes = await bundle.load('assets/legacy/world-map.png');
      expect(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        [1, 2, 3],
      );
      expect(await bundle.loadString('other.txt'), 'fallback:other.txt');
    },
  );

  test(
    'missing pack fails explicitly rather than resetting or fetching',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(RetainedAssetBundle.channel, (_) async {
            throw PlatformException(code: 'ASSET_PACK_UNAVAILABLE');
          });
      await expectLater(
        RetainedAssetBundle.prepare(fallback: _Bundle()),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test('desktop uses normal bundled media', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final fallback = _Bundle();
    expect(
      await RetainedAssetBundle.prepare(fallback: fallback),
      same(fallback),
    );
  });
}
