import 'dart:convert';
import 'dart:io';

import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/backend/fake_backend.dart';
import 'package:deluge_engine_gui/model/app_model.dart';
import 'package:deluge_engine_gui/model/state_store.dart';
import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileStateStore', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('de_gui_state_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('round-trips AppDocumentState via atomic write to state.json',
        () async {
      final store = FileStateStore(p.join(tempDir.path, 'state.json'));
      expect(await store.load(), isNull);

      final doc = AppDocumentState(
        cardFolder: '/Users/test/DelugeCard',
        setupBindings: const {
          1: 'SYNTHS/165 Acid Arp.XML',
          10: 'KITS/003 TR-909.XML',
        },
        genreId: 'techno-acid',
        seed: 4242,
        lengthSeconds: 60,
        picks: const {'part:0': 'SYNTHS/165 Acid Arp.XML'},
        autoRender: false,
        audioOutput: 'MacBook Pro Speakers',
        midiInputs: const ['KeyStep 37'],
        voiceWarningThreshold: 24,
        renders: [
          RenderRecord(
            id: 'r1',
            wavPath: '/tmp/r1.wav',
            genreId: 'techno-acid',
            seed: 4242,
            durationS: 60.0,
            peakVoices: 14,
            kept: true,
            createdAt: DateTime.utc(2026, 11, 27, 12, 0),
          ),
        ],
        slotAId: 'r1',
        slotBId: null,
      );

      await store.save(doc);
      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.cardFolder, '/Users/test/DelugeCard');
      expect(loaded.setupBindings[1], 'SYNTHS/165 Acid Arp.XML');
      expect(loaded.setupBindings[10], 'KITS/003 TR-909.XML');
      expect(loaded.genreId, 'techno-acid');
      expect(loaded.seed, 4242);
      expect(loaded.autoRender, isFalse);
      expect(loaded.audioOutput, 'MacBook Pro Speakers');
      expect(loaded.midiInputs, ['KeyStep 37']);
      expect(loaded.voiceWarningThreshold, 24);
      expect(loaded.renders.single.kept, isTrue);
      expect(loaded.slotAId, 'r1');
    });

    test('returns null cleanly on corrupt state.json', () async {
      final path = p.join(tempDir.path, 'state.json');
      File(path).writeAsStringSync('{not valid json');
      final store = FileStateStore(path);
      expect(await store.load(), isNull);
    });
  });

  group('AppModel', () {
    test('first launch stays unselected until card folder is chosen, then persists',
        () async {
      final store = MemoryStateStore();
      final backend = FakeBackend(
        stepDelay: Duration.zero,
        restartDelay: Duration.zero,
      );
      final model = AppModel(backend: backend, store: store);
      addTearDown(() async {
        await model.disposeAsync();
      });

      await model.init();
      expect(model.cardState, CardState.unselected);
      expect(model.cardFolder, isNull);
      expect(model.backendStatus, BackendStatus.running);

      await model.setCardFolder('/Volumes/DELUGE');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(model.cardState, CardState.ready);
      expect(model.cardFolder, '/Volumes/DELUGE');
      expect(model.catalog.synths, isNotEmpty);
      expect(model.genres, isNotEmpty);
      expect(store.saved?.cardFolder, '/Volumes/DELUGE');
    });

    test('re-sends SetCard, SetDevices, and SetSetup after Backend restart',
        () async {
      final store = MemoryStateStore(
        initial: const AppDocumentState(
          cardFolder: '/Volumes/DELUGE',
          setupBindings: {1: 'SYNTHS/165 Acid Arp.XML'},
          audioOutput: 'MacBook Pro Speakers',
          midiInputs: ['KeyStep 37'],
        ),
      );
      final backend = FakeBackend(
        stepDelay: Duration.zero,
        restartDelay: const Duration(milliseconds: 20),
      );
      final model = AppModel(backend: backend, store: store);
      addTearDown(() async {
        await model.disposeAsync();
      });

      await model.init();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(model.cardState, CardState.ready);

      backend.sentMessages.clear();
      await backend.simulateFreeze(
        code: 'E380',
        message: 'Test freeze',
        loaded: 'SYNTHS/165 Acid Arp.XML',
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(model.backendStatus, BackendStatus.running);
      expect(model.lastFreeze?.code, 'E380');
      expect(model.lastFreeze?.loaded, 'SYNTHS/165 Acid Arp.XML');

      final kinds = backend.sentMessages.map((m) => m.whichKind()).toList();
      expect(kinds, contains(pb.ToEngine_Kind.setCard));
      expect(kinds, contains(pb.ToEngine_Kind.setDevices));
      expect(kinds, contains(pb.ToEngine_Kind.setSetup));

      final debugJson = jsonDecode(model.toDebugJson()) as Map<String, dynamic>;
      expect(debugJson['cardFolder'], '/Volumes/DELUGE');
      expect(debugJson['lastFreeze']['code'], 'E380');
    });
  });
}
