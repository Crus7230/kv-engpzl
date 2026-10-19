import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget renders at simulated phone sizes, not Android device screenshots.
Future<void> loadCompactPreviewFonts() async {
  final font = File(
    Platform.environment['KVM_PREVIEW_FONT'] ?? r'C:\Windows\Fonts\malgun.ttf',
  );
  if (await font.exists()) {
    final bytes = ByteData.sublistView(await font.readAsBytes());
    for (final family in ['Roboto', 'Malgun Gothic']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

Future<void> captureCompactPreview(
  WidgetTester tester,
  Key boundaryKey,
  String name,
) async {
  final finder = find.byKey(boundaryKey);
  await tester.runAsync(() async {
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(widget.image, tester.element(finder));
    }
  });
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/previews/compact-seeker');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}
