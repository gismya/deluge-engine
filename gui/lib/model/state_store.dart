import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Metadata for a saved Piece Render, persisted inside `state.json` (spec §6.5, §7.3).
class RenderRecord {
  const RenderRecord({
    required this.id,
    required this.wavPath,
    required this.genreId,
    required this.seed,
    required this.durationS,
    required this.peakVoices,
    required this.kept,
    required this.createdAt,
  });

  final String id;
  final String wavPath;
  final String genreId;
  final int seed;
  final double durationS;
  final int peakVoices;
  final bool kept;
  final DateTime createdAt;

  RenderRecord copyWith({bool? kept}) => RenderRecord(
        id: id,
        wavPath: wavPath,
        genreId: genreId,
        seed: seed,
        durationS: durationS,
        peakVoices: peakVoices,
        kept: kept ?? this.kept,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'wavPath': wavPath,
        'genreId': genreId,
        'seed': seed,
        'durationS': durationS,
        'peakVoices': peakVoices,
        'kept': kept,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static RenderRecord? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final wavPath = raw['wavPath'];
    final genreId = raw['genreId'];
    final seed = raw['seed'];
    final durationS = raw['durationS'];
    final peakVoices = raw['peakVoices'];
    final kept = raw['kept'];
    final createdAtStr = raw['createdAt'];
    if (id is! String ||
        wavPath is! String ||
        genreId is! String ||
        seed is! num ||
        durationS is! num ||
        peakVoices is! num ||
        kept is! bool ||
        createdAtStr is! String) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdAtStr);
    if (createdAt == null) return null;
    return RenderRecord(
      id: id,
      wavPath: wavPath,
      genreId: genreId,
      seed: seed.toInt(),
      durationS: durationS.toDouble(),
      peakVoices: peakVoices.toInt(),
      kept: kept,
      createdAt: createdAt,
    );
  }
}

/// Persistent GUI documents stored in `state.json` (spec §7.3).
class AppDocumentState {
  const AppDocumentState({
    this.cardFolder,
    this.setupBindings = const {},
    this.genreId,
    this.seed = 12345,
    this.lengthSeconds = 60,
    this.picks = const {},
    this.autoRender = true,
    this.audioOutput = '',
    this.midiInputs = const [],
    this.voiceWarningThreshold,
    this.renders = const [],
    this.slotAId,
    this.slotBId,
  });

  static const int currentSchemaVersion = 1;

  final String? cardFolder;
  final Map<int, String> setupBindings;
  final String? genreId;
  final int seed;
  final int lengthSeconds;
  final Map<String, String> picks;
  final bool autoRender;
  final String audioOutput;
  final List<String> midiInputs;

  /// Optional voice count threshold (null by default per spec §8, G6).
  final int? voiceWarningThreshold;

  final List<RenderRecord> renders;
  final String? slotAId;
  final String? slotBId;

  Map<String, dynamic> toJson() => {
        'version': currentSchemaVersion,
        'cardFolder': cardFolder,
        'setupBindings': {
          for (final e in setupBindings.entries) '${e.key}': e.value,
        },
        'piece': {
          'genreId': genreId,
          'seed': seed,
          'lengthSeconds': lengthSeconds,
          'picks': picks,
          'autoRender': autoRender,
        },
        'devices': {
          'audioOutput': audioOutput,
          'midiInputs': midiInputs,
        },
        'settings': {
          'voiceWarningThreshold': voiceWarningThreshold,
        },
        'renders': [for (final r in renders) r.toJson()],
        'slotAId': slotAId,
        'slotBId': slotBId,
      };

  static AppDocumentState? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final cardFolder = raw['cardFolder'] is String ? raw['cardFolder'] as String : null;

    final bindings = <int, String>{};
    final rawBindings = raw['setupBindings'];
    if (rawBindings is Map) {
      for (final e in rawBindings.entries) {
        final ch = int.tryParse('${e.key}');
        final path = e.value;
        if (ch != null && ch >= 1 && ch <= 16 && path is String && path.isNotEmpty) {
          bindings[ch] = path;
        }
      }
    }

    final piece = raw['piece'] is Map<String, dynamic>
        ? raw['piece'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final genreId = piece['genreId'] is String ? piece['genreId'] as String : null;
    final seed = piece['seed'] is num ? (piece['seed'] as num).toInt() : 12345;
    final lengthSeconds =
        piece['lengthSeconds'] is num ? (piece['lengthSeconds'] as num).toInt() : 60;
    final autoRender = piece['autoRender'] is bool ? piece['autoRender'] as bool : true;
    final picks = <String, String>{};
    if (piece['picks'] is Map) {
      for (final e in (piece['picks'] as Map).entries) {
        if (e.key is String && e.value is String) {
          picks[e.key as String] = e.value as String;
        }
      }
    }

    final devices = raw['devices'] is Map<String, dynamic>
        ? raw['devices'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final audioOutput =
        devices['audioOutput'] is String ? devices['audioOutput'] as String : '';
    final midiInputs = <String>[
      if (devices['midiInputs'] is List)
        for (final item in devices['midiInputs'] as List)
          if (item is String) item,
    ];

    final settings = raw['settings'] is Map<String, dynamic>
        ? raw['settings'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final voiceWarningThreshold = settings['voiceWarningThreshold'] is num
        ? (settings['voiceWarningThreshold'] as num).toInt()
        : null;

    final renders = <RenderRecord>[];
    if (raw['renders'] is List) {
      for (final item in raw['renders'] as List) {
        final parsed = RenderRecord.fromJson(item);
        if (parsed != null) renders.add(parsed);
      }
    }

    final slotAId = raw['slotAId'] is String ? raw['slotAId'] as String : null;
    final slotBId = raw['slotBId'] is String ? raw['slotBId'] as String : null;

    return AppDocumentState(
      cardFolder: cardFolder,
      setupBindings: bindings,
      genreId: genreId,
      seed: seed,
      lengthSeconds: lengthSeconds,
      picks: picks,
      autoRender: autoRender,
      audioOutput: audioOutput,
      midiInputs: midiInputs,
      voiceWarningThreshold: voiceWarningThreshold,
      renders: renders,
      slotAId: slotAId,
      slotBId: slotBId,
    );
  }
}

/// Persistence interface for `state.json` (spec §7.3).
abstract class StateStore {
  Future<AppDocumentState?> load();
  Future<void> save(AppDocumentState state);
}

/// Atomic JSON file store targeting `~/Library/Application Support/deluge-engine/state.json`
/// on macOS (spec §7.3), with portable fallbacks on Linux and Windows.
class FileStateStore implements StateStore {
  FileStateStore([String? path]) : filePath = path ?? defaultStatePath();

  final String filePath;
  Future<void> _pendingSave = Future<void>.value();
  int _writeSequence = 0;

  static String defaultStatePath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    if (Platform.isMacOS) {
      return p.join(
        home,
        'Library',
        'Application Support',
        'deluge-engine',
        'state.json',
      );
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? home;
      return p.join(appData, 'deluge-engine', 'state.json');
    }
    final xdg =
        Platform.environment['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share');
    return p.join(xdg, 'deluge-engine', 'state.json');
  }

  @override
  Future<AppDocumentState?> load() async {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      return AppDocumentState.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AppDocumentState state) {
    final next = _pendingSave.catchError((Object _) {}).then(
          (_) => _writeAtomically(state),
        );
    _pendingSave = next;
    return next;
  }

  Future<void> _writeAtomically(AppDocumentState state) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final tmp = File('$filePath.$pid.${++_writeSequence}.tmp');
    final encoded = const JsonEncoder.withIndent('  ').convert(state.toJson());
    try {
      await tmp.writeAsString('$encoded\n', flush: true);
      await tmp.rename(filePath);
    } catch (_) {
      if (tmp.existsSync()) {
        try {
          tmp.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
  }
}

/// In-memory [StateStore] for unit and widget tests.
class MemoryStateStore implements StateStore {
  MemoryStateStore({AppDocumentState? initial}) : saved = initial;

  AppDocumentState? saved;

  @override
  Future<AppDocumentState?> load() async => saved;

  @override
  Future<void> save(AppDocumentState state) async {
    saved = state;
  }
}
