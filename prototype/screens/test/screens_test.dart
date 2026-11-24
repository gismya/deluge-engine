// PROTOTYPE — renders each variant's main states to PNG (with the real fonts) so the screens can be
// looked at without running the app: flutter test --update-goldens test/screens_test.dart
// Set ONLY=D to render one variant.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screens_prototype/data.dart';
import 'package:screens_prototype/main.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await loader.load();
}

/// A named state: what to do to the model (and the widgets) before the picture is taken.
typedef Shot = ({String name, Future<void> Function(WidgetTester t, Model m) arrange});

Future<void> _nothing(WidgetTester t, Model m) async {}

final shots = <String, List<Shot>>{
  'B2': [
    (name: 'piece', arrange: _nothing),
    (name: 'setup', arrange: (t, m) async => m.setMode(Mode.setup)),
    (
      name: 'ab',
      arrange: (t, m) async {
        m.selectSlot('DRONE');
        m.setPick('DRONE', synth('126 Dark FM Pad'));
        m.play(m.slotA);
        m.seek(0.62);
      }
    ),
  ],
  'D': [
    (name: 'piece', arrange: _nothing),
    (name: 'setup', arrange: (t, m) async => m.setMode(Mode.setup)),
    (
      name: 'ab',
      arrange: (t, m) async {
        m.selectSlot('DRONE');
        m.setPick('DRONE', synth('126 Dark FM Pad'));
        m.play(m.slotA);
        m.seek(0.62);
      }
    ),
  ],
  'E': [
    (name: 'piece', arrange: _nothing),
    (name: 'setup', arrange: (t, m) async => m.setMode(Mode.setup)),
    (
      name: 'ab',
      arrange: (t, m) async {
        m.play(m.slotA);
        m.seek(0.62);
      }
    ),
    (name: 'picker', arrange: (t, m) async => m.setPicker(true)),
  ],
};

void main() {
  setUpAll(() async {
    final material = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    await _font('Inter', ['assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-Medium.ttf', 'assets/fonts/Inter-SemiBold.ttf']);
    await _font('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  });

  final only = Platform.environment['ONLY'];
  for (final v in variants) {
    if (only != null && only != v) continue;
    for (final shot in shots[v]!) {
      // Desktop (mouse): every state dark at both sizes, light once at the large size.
      // Tablet (touch, 48 dp targets): every state dark in landscape and portrait, light once.
      for (final (size, dark, touch) in [
        (const Size(1440, 900), true, false),
        (const Size(1100, 720), true, false),
        (const Size(1440, 900), false, false),
        (const Size(1280, 800), true, true),
        (const Size(800, 1280), true, true),
        (const Size(1280, 800), false, true),
      ]) {
        final file = '$v-${shot.name}-${touch ? 'tablet-' : ''}${dark ? 'dark' : 'light'}-${size.width.toInt()}x${size.height.toInt()}';
        testWidgets(file, (tester) async {
          debugDisableShadows = false; // draw the palette's real shadow
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(PrototypeApp(initialVariant: v, dark: dark, touch: touch, showSwitcher: false));
          final model = tester.state<PrototypeAppState>(find.byType(PrototypeApp)).model;
          await shot.arrange(tester, model);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$file.png'));
          debugDisableShadows = true;
        });
      }
    }
  }
}
