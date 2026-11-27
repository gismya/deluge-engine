import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/backend/fake_backend.dart';
import 'package:deluge_engine_gui/main.dart';
import 'package:deluge_engine_gui/model/app_model.dart';
import 'package:deluge_engine_gui/model/state_store.dart';
import 'package:deluge_engine_gui/shell/chrome.dart';
import 'package:deluge_engine_gui/shell/folder_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _StubFolderPicker implements FolderPicker {
  _StubFolderPicker(this.result);
  String? result;

  @override
  Future<String?> pickFolder({String? prompt}) async => result;
}

void main() {
  testWidgets(
      'first launch asks for a card folder, shows image build progress, then opens shell',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeBackend(
      stepDelay: Duration.zero,
      restartDelay: Duration.zero,
      holdCardBuild: true,
      cardBuildSteps: 4,
    );
    final store = MemoryStateStore();
    final model = AppModel(backend: backend, store: store);
    final picker = _StubFolderPicker('/Users/test/MyDelugeCard');

    await tester.pumpWidget(
      DelugeEngineApp(model: model, folderPicker: picker),
    );
    await tester.pump();
    await tester.pump();

    // First-launch screen asks for a card folder.
    expect(find.text('Choose a Deluge card folder'), findsOneWidget);
    final chooseBtn = find.text('Choose card folder…');
    expect(chooseBtn, findsOneWidget);

    // Touch sizing check: interactive tap target (GestureDetector) is >= 48x48 dp.
    final btnSize = tester.getSize(
      find.ancestor(of: chooseBtn, matching: find.byType(GestureDetector)).first,
    );
    expect(btnSize.height, greaterThanOrEqualTo(48));

    // Choose folder -> transitions to building progress view.
    await tester.tap(chooseBtn);
    await tester.pump();
    await tester.pump();

    expect(find.text('Building card image'), findsOneWidget);
    expect(find.text('0 / 4'), findsOneWidget);

    backend.advanceCardProgress(2, 4);
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 4'), findsOneWidget);

    // Complete build -> transitions into main shell showing card path & Piece | Setup.
    backend.completeCardBuild();
    await tester.pump();
    await tester.pump();

    expect(find.text('Choose a Deluge card folder'), findsNothing);
    expect(find.text('/Users/test/MyDelugeCard'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(TopBar), matching: find.text('Piece')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(TopBar), matching: find.text('Setup')),
      findsOneWidget,
    );
    expect(store.saved?.cardFolder, '/Users/test/MyDelugeCard');
  });

  testWidgets('a freeze shows its code, restarts automatically, and recovers',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeBackend(
      stepDelay: Duration.zero,
      restartDelay: const Duration(milliseconds: 200),
    );
    final store = MemoryStateStore(
      initial: const AppDocumentState(cardFolder: '~/Music/Deluge card'),
    );
    final model = AppModel(backend: backend, store: store);

    await tester.pumpWidget(DelugeEngineApp(model: model));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(model.cardState, CardState.ready);
    expect(model.backendStatus, BackendStatus.running);

    // Trigger freeze -> shows freeze code in veil and status bar while restarting.
    await backend.simulateFreeze(
      code: 'E380',
      message: 'Null pointer',
      loaded: 'SYNTHS/165 Acid Arp.XML',
    );
    await tester.pump();

    expect(find.textContaining('E380'), findsWidgets);
    expect(find.textContaining('Restarting'), findsWidgets);
    expect(find.textContaining('165 Acid Arp'), findsWidgets);

    // Advance past restartDelay -> recovers to running.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(model.backendStatus, BackendStatus.running);
    expect(model.cardState, CardState.ready);
    expect(find.textContaining('Restarting and reloading'), findsNothing);
    // Status bar still remembers last freeze code & loaded preset.
    expect(find.textContaining('E380'), findsOneWidget);
  });

  testWidgets('three freezes in a minute stop with a Restart button',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeBackend(
      stepDelay: Duration.zero,
      restartDelay: const Duration(milliseconds: 50),
    );
    final store = MemoryStateStore(
      initial: const AppDocumentState(cardFolder: '~/Music/Deluge card'),
    );
    final model = AppModel(backend: backend, store: store);

    await tester.pumpWidget(DelugeEngineApp(model: model));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Freeze 1 -> auto-restarts.
    await backend.simulateFreeze(code: 'E380', loaded: 'SYNTHS/000 Bass.XML');
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.backendStatus, BackendStatus.running);

    // Freeze 2 -> auto-restarts.
    await backend.simulateFreeze(code: 'E381', loaded: 'SYNTHS/001 Sync.XML');
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.backendStatus, BackendStatus.running);

    // Freeze 3 within 1 minute -> stops restarting and shows Restart button.
    await backend.simulateFreeze(code: 'S002', loaded: 'KITS/003 TR-909.XML');
    await tester.pump(const Duration(milliseconds: 80));

    expect(model.backendStatus, BackendStatus.crashed);
    expect(find.textContaining('S002'), findsWidgets);
    final restartBtn = find.text('Restart');
    expect(restartBtn, findsOneWidget);

    // Tap Restart -> recovers.
    await tester.tap(restartBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(model.backendStatus, BackendStatus.running);
    expect(model.cardState, CardState.ready);
  });

  testWidgets('protocol version mismatch shows an error and does not go on',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeBackend(
      protocolVersionOverride: 99,
      stepDelay: Duration.zero,
    );
    final store = MemoryStateStore(
      initial: const AppDocumentState(cardFolder: '~/Music/Deluge card'),
    );
    final model = AppModel(backend: backend, store: store);

    await tester.pumpWidget(DelugeEngineApp(model: model));
    await tester.pump();
    await tester.pump();

    expect(model.backendStatus, BackendStatus.versionMismatch);
    expect(find.text('Incompatible Engine version'), findsOneWidget);
    expect(find.textContaining('v99'), findsWidgets);
  });

  testWidgets('top bar switches Piece | Setup and toggles {} debug state drawer',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeBackend(stepDelay: Duration.zero);
    final store = MemoryStateStore(
      initial: const AppDocumentState(cardFolder: '~/Music/Deluge card'),
    );
    final model = AppModel(backend: backend, store: store);

    await tester.pumpWidget(DelugeEngineApp(model: model));
    await tester.pump();
    await tester.pump();

    backend.setVoices(6);
    await tester.pump();
    await tester.pump();
    expect(find.text('6 voices'), findsOneWidget);

    // Switch to Setup mode.
    await tester.tap(find.text('Setup'));
    await tester.pump();
    expect(model.mode, AppMode.setup);

    // Open `{}` state inspector panel.
    await tester.tap(find.byIcon(Icons.data_object));
    await tester.pump();
    expect(find.textContaining('"cardFolder"'), findsOneWidget);

    // Close `{}` state inspector panel.
    await tester.tap(find.byIcon(Icons.data_object));
    await tester.pump();
    expect(find.textContaining('"cardFolder"'), findsNothing);
  });
}
