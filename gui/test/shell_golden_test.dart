import 'package:deluge_engine_gui/backend/fake_backend.dart';
import 'package:deluge_engine_gui/main.dart';
import 'package:deluge_engine_gui/model/app_model.dart';
import 'package:deluge_engine_gui/model/state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'golden_helper.dart';

void main() {
  setUpAll(() async {
    installTolerantGoldenComparator('test/shell_golden_test.dart');
    await loadTestFonts();
  });

  const sizes = [
    Size(1440, 900),
    Size(800, 1280),
  ];

  for (final size in sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('shell-ready-$tag', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final backend = FakeBackend(stepDelay: Duration.zero);
      final store = MemoryStateStore(
        initial: const AppDocumentState(
          cardFolder: '~/Music/Deluge card',
          setupBindings: {
            1: 'SYNTHS/165 Acid Arp.XML',
            2: 'SYNTHS/148 Warm 5th Pad.XML',
            10: 'KITS/003 TR-909.XML',
          },
        ),
      );
      final model = AppModel(backend: backend, store: store);

      await tester.pumpWidget(DelugeEngineApp(model: model));
      await tester.pump();
      await tester.pump();
      backend.setVoices(9);
      await tester.pump();
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shell-ready-$tag.png'),
      );
    });

    testWidgets('shell-first-launch-$tag', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final backend = FakeBackend(stepDelay: Duration.zero);
      final store = MemoryStateStore();
      final model = AppModel(backend: backend, store: store);

      await tester.pumpWidget(DelugeEngineApp(model: model));
      await tester.pump();
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shell-first-launch-$tag.png'),
      );
    });
  }

  testWidgets('shell-crashed-1440x900', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeBackend(
      stepDelay: Duration.zero,
      restartDelay: Duration.zero,
    );
    final store = MemoryStateStore(
      initial: const AppDocumentState(cardFolder: '~/Music/Deluge card'),
    );
    final model = AppModel(backend: backend, store: store);

    await tester.pumpWidget(DelugeEngineApp(model: model));
    await tester.pump();
    await tester.pump();

    await backend.simulateFreeze(code: 'E380', loaded: 'SYNTHS/165 Acid Arp.XML');
    await tester.pump();
    await backend.simulateFreeze(code: 'E380', loaded: 'SYNTHS/165 Acid Arp.XML');
    await tester.pump();
    await backend.simulateFreeze(code: 'E380', loaded: 'SYNTHS/165 Acid Arp.XML');
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shell-crashed-1440x900.png'),
    );
  });
}
