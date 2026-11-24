// PROTOTYPE — throwaway. Fake data and an in-memory model for the screen prototype
// (wayfinder ticket "What do the Setup and Piece screens look like?").
// Nothing here talks to a real Engine.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

const synthNames = [
  '000 Rich Saw Bass', '001 Sync Bass', '002 Basic Square Bass', '003 Synthwave Bass', '004 Dubby Bass',
  '005 Sweet Mono Bass', '006 Vaporwave Bass', '007 Detuned Saw Bass', '008 FM Rich Distorted Bass',
  '009 Hoover Bass', '010 Gravel Basscamp', '011 Dubstep Bass', '012 Blunt Sync Bass', '013 Trap Bass 1',
  '014 Trap Bass 2', '015 Resonant Filter Bass', '016 Dark Saturated Bass', '017 Impact Saw Lead',
  '018 Rich Saw Lead', '019 Fizzy Strings', '020 Soft Saw Lead', '021 80s TV Lead', '022 Rich Filter LFO Lead',
  '023 Analog Mono Wow', '024 Warble Bass Pluck', '025 Soft Synth Organ', '026 PW Organ', '027 PW Envelope',
  '028 PWM', '029 Chiptune Trill', '030 Distant Porta', '031 Nasal Choir', '032 Bandpass Choir',
  '033 Rich Square', '034 Square Choir', '035 Bell Lead & Bass', '036 Analog Ambient Square', '037 Echo Chord',
  '038 Vapor Arp', '039 Detuned Retriggering Saws', '040 Spacer Leader', '041 Zithar - Vibed',
  '042 High Triangle', '043 Square Porta', '044 8-Bit Lead', '045 Square Sync', '046 Saw Sync',
  '047 Basic Dirty Bass', '048 Thin Pulse Bass', '049 Basic FM', '050 FM Basic Bass', '051 FM Rich Brass',
  '052 Soft FM', '053 Detuned FM Horns', '054 Ghostly Sines', '055 FM Theremin', '056 FM Bell Modulation',
  '057 FM Lead', '058 FM Rising Attack', '059 Distorted Lead Guitar', '060 Bass Guitar',
  '061 Blown-Staccato-Panpipes', '062 Trumpet', '063 Tuba', '064 Reeds-Flute-Oboe', '065 Cello', '066 Violin',
  '067 Marimba', '068 FM Bells 1', '069 FM Bells 2', '070 Glockenspiel', '071 Rhodes', '072 Kyoto Phono',
  '073 Piano', '074 Electric Piano', '075 Electric Piano With Strings', '076 Organ', '077 FM Perc-Organ',
  '078 House', '079 Phased Arper', '080 House', '081 Xylophone Big Bass', '082 Short Sharp Delay',
  '083 Dark Chorus', '084 FM Narrow Band', '085 Deep Fizz', '086 Techno Organ', '087 Define Leader',
  '088 Yelp Chords', '089 Degraded Retro Lead', '090 FM Organ', '091 FM Ricochet', '092 Degraded Tremolo',
  '093 FM Distorted Bells', '094 Ambient Occlusion Lead', '095 Harsh FM Feedback', '096 FM Guitar Power Chord',
  '097 Saturated Filter', '098 Saturated Sync', '099 Overdrive Reese Sync', '100 Noise Lead', '101 Atebit',
  '102 Harsh 5th', '103 Sci-fi Chaos', '104 Alien Vomit', '105 Attack Bass', '106 Hang Drum',
  '107 FM LPG Percussion', '108 Robo Arp', '109 Talking Arp', '110 Crystalline Ringmod', '111 Satellite Drum',
  '112 Hard Tech Beat', '113 Bio Lab', '114 Sootheerio', '115 Sounds After Take-off',
  '116 Evolving Frequencies', '117 Belledy', '118 Small Bridge Pad', '119 Stars Of The Bin Pad',
  '120 High Harsh Pad', '121 Tiny Lights', '122 Majestic Synth Orchestra', '123 Space Dust',
  '124 Filter Modulation Pad', '125 Evolving Pad', '126 Dark FM Pad', '127 Alien Larvae', '128 Lunar Landing',
  '129 Sci-fi Scenic', '130 Dark Strings', '131 Warm Strings', '132 Organ Strings', '133 80s Strings',
  '134 Melody String', '135 Soothing Growth Pad', '136 Synthwave Pad', '137 Epic Saw Modulation Pad',
  '138 Brassy Pad', '139 Detuned Saw Pad', '140 Slow Aural Swells', '141 Ringmod Pad', '142 Phaser',
  '143 Chillout Pad', '144 Sweep Chords', '145 Eerie High Pad', '146 Atmospheric Squares Pad',
  '147 Resonant Filter Pad', '148 Warm 5th Pad', '149 Cold 5th Pad', '150 Vaporwave Pad', '151 Radiant FM Pad',
  '152 Small Jet Pad', '153 FM Modulation Pad', '154 Rich FM Pad 1', '155 Rich FM Pad 2', '156 Rich FM Pad 3',
  '157 Rich FM Pad 4', '158 Tempo-Synced LFO', '159 80s Bass Rhythm', '160 Synthwave Bass Arp',
  '161 Synthwave Vibrato Arp', '162 Busy Arp', '163 Crisp Pop Arp', '164 Study Arp', '165 Acid Arp',
  '166 Harpsichord Cyborg', '167 FM Metallic Bass Arp', '168 Hang Drum', '169 Double Bass', '170 Sitar',
];

const kitNames = [
  '000 TR-808', '001 DDD-1', '002 SDS-5', '003 TR-909', '004 R-50', '005 R-100', '006 LD', '007 HR-16B',
  '008 SCDT', '009 RX-5', '010 XV-5080', '011 KR-55', '012 HR-II', '013 AT Rhythm', '014 CR-78',
  '015 Andrew Stirton Frugal', '016 Electronisounds 1', '017 Electronisounds 2', '018 Electronisounds 3',
  '019 Fairburg', '020 Leonard Ludvigsen Beatbox', '021 hodeur 1', '022 hodeur 2', '023 hodeur 3',
  '024 James R Closs 1', '025 James R Closs 2', '026 Amiga909', '027 Reciprocal Sound', '028 Danny Taurus',
  '029 Danny Taurus 2', '030 Chaz Bundick', '031 Reuben Winter', '032 Kody Nielson', '033 Alfred Darlington',
  '034 Travis Egedy', '035 Sjionel Timu', '036 Stefanie Franciotti', '037 Stephanie Engelbrecht',
  '038 Jonathan Snipes (FX)', '039 Campbell Kneale', '040 John Atkinson', '041 Jonathan Snipes (Waterfalls)',
  '042 Phil Elverum',
];

String synth(String name) => 'SYNTHS/$name.XML';
String kit(String name) => 'KITS/$name.XML';
String shortName(String path) => path.split('/').last.replaceAll(RegExp(r'\.(XML|wav)$'), '');

/// A preset's number and title: 'SYNTHS/165 Acid Arp.XML' gives ('165', 'Acid Arp'). Samples have no number.
(String?, String) splitName(String path) {
  final n = shortName(path);
  final preset = (path.startsWith('SYNTHS/') || path.startsWith('KITS/')) && RegExp(r'^\d{3} ').hasMatch(n);
  return preset ? (n.substring(0, 3), n.substring(4)) : (null, n);
}

/// Keyword filters for the synth list.
const synthTags = ['Bass', 'Lead', 'Pad', 'Arp', 'FM', 'Strings', 'Organ', 'Bell'];

/// The Role each Part plays (deluge-generative GLOSSARY).
const roles = {
  'DRUMS': 'Drums', 'FX': 'FX', 'ACID': 'Bass', 'BASS': 'Bass', 'SUB': 'Bass', 'DRONE': 'Pad', 'PAD': 'Pad',
  'STRINGS': 'Pad', 'STAB': 'Chords', 'ARP': 'Lead', 'MOTIF': 'Lead',
};

/// The Sections a 32-bar render passes through, with their bar counts and loudness.
const sections = [('Intro', 4, 0.35), ('Groove', 8, 0.7), ('Build', 4, 0.8), ('Drop', 8, 1.0), ('Break', 4, 0.3), ('Outro', 4, 0.5)];
const totalBars = 32;

/// One palette entry: a sound and its weight.
class Entry {
  const Entry(this.sound, this.weight);
  final String sound;
  final int weight;
}

/// A Part, or a lane of the DRUMS/FX part.
class Slot {
  const Slot(this.part, this.lane, this.palette);
  final String part;
  final String? lane;
  final List<Entry> palette;
  String get key => lane == null ? part : '$part · $lane';
  String get name => lane ?? part;
  int get total => palette.fold(0, (a, e) => a + e.weight);
  Entry? entry(String? sound) => palette.where((e) => e.sound == sound).firstOrNull;
  bool get isSynth => palette.first.sound.startsWith('SYNTHS/');
}

List<Entry> _p(List<(String, int)> l) => [for (final (s, w) in l) Entry(s.contains('/') ? s : synth(s), w)];

final _acid = _p([('165 Acid Arp', 3), ('015 Resonant Filter Bass', 2), ('097 Saturated Filter', 2), ('005 Sweet Mono Bass', 1)]);
final _bass = _p([('047 Basic Dirty Bass', 3), ('000 Rich Saw Bass', 2), ('007 Detuned Saw Bass', 1), ('008 FM Rich Distorted Bass', 1)]);
final _drone = _p([('148 Warm 5th Pad', 2), ('126 Dark FM Pad', 2), ('139 Detuned Saw Pad', 2), ('149 Cold 5th Pad', 1)]);
final _stab = _p([('086 Techno Organ', 3), ('037 Echo Chord', 2), ('026 PW Organ', 1), ('083 Dark Chorus', 1)]);
final _rolling = _p([('000 Rich Saw Bass', 3), ('047 Basic Dirty Bass', 2), ('012 Blunt Sync Bass', 1), ('050 FM Basic Bass', 1)]);
final _arp = _p([('167 FM Metallic Bass Arp', 3), ('058 FM Rising Attack', 2), ('068 FM Bells 1', 2), ('067 Marimba', 1)]);
final _melPad = _p([('153 FM Modulation Pad', 3), ('139 Detuned Saw Pad', 2), ('151 Radiant FM Pad', 2), ('142 Phaser', 1)]);
final _sub = _p([('002 Basic Square Bass', 3), ('050 FM Basic Bass', 2), ('047 Basic Dirty Bass', 1)]);
final _dubStab = _p([('037 Echo Chord', 3), ('082 Short Sharp Delay', 2), ('072 Kyoto Phono', 1)]);
final _dubPad = _p([('131 Warm Strings', 3), ('139 Detuned Saw Pad', 2), ('126 Dark FM Pad', 2)]);

List<Entry> _samples(List<(String, int)> l) => [for (final (s, w) in l) Entry('SAMPLES/DRUMS/$s.wav', w)];

final _drumLanes = <Slot>[
  Slot('DRUMS', 'Kick', _samples([('909 Kick', 3), ('Deep Sky Kick HQ', 1), ('Deep Sky Kick distorted', 1), ('808 Kick distorted', 1)])),
  Slot('DRUMS', 'Snare', _samples([('909 Snare', 3), ('XV5080 Snare dry', 1), ('DDD1 Snare dry', 1)])),
  Slot('DRUMS', 'Rim', _samples([('909 Rim', 2), ('808 Rim', 1), ('DDD1 Rim', 1)])),
  Slot('DRUMS', 'Closed hat', _samples([('909 Closed Hat', 3), ('808 Closed Hat', 1), ('DDD1 Closed Hat', 1)])),
  Slot('DRUMS', 'Open hat', _samples([('909 Open Hat', 3), ('808 Open Hat', 1), ('DDD1 Open Hat', 1)])),
  Slot('DRUMS', 'Crash', _samples([('909 Crash', 3), ('XV5080 Crash', 1), ('DDD1 Crash', 1)])),
  Slot('DRUMS', 'Tom', _samples([('909 Tom', 2), ('808 Tom', 1)])),
];
final _fxLanes = <Slot>[
  Slot('FX', 'Riser', [const Entry('SYNTHS/GENERATIVE/FX/GEN Riser.XML', 1)]),
  Slot('FX', 'Fall', [const Entry('SYNTHS/GENERATIVE/FX/GEN Fall.XML', 1)]),
  Slot('FX', 'Impact', [const Entry('SYNTHS/GENERATIVE/FX/GEN Impact.XML', 1)]),
];

/// Genres and their parts. Detroit's palettes are stand-ins borrowed from the other genres.
final genres = <String, List<Slot>>{
  'Acid techno': [..._drumLanes, Slot('ACID', null, _acid), Slot('DRONE', null, _drone), ..._fxLanes],
  'Melodic techno': [..._drumLanes, Slot('BASS', null, _rolling), Slot('PAD', null, _melPad), Slot('ARP', null, _arp), ..._fxLanes],
  'Dub techno': [..._drumLanes, Slot('SUB', null, _sub), Slot('STAB', null, _dubStab), Slot('PAD', null, _dubPad), ..._fxLanes],
  'Detroit techno': [..._drumLanes, Slot('BASS', null, _bass), Slot('STRINGS', null, _dubPad), Slot('STAB', null, _stab), Slot('MOTIF', null, _arp), ..._fxLanes],
};

class ChannelSlot {
  ChannelSlot(this.channel);
  final int channel;
  String? sound; // a SYNTHS/ or KITS/ path, or null when the channel is empty
  int voices = 0;
}

class Render {
  Render(this.id, this.genre, this.seed, this.picks, this.seconds);
  final int id;
  final String genre;
  final int seed;
  final Map<String, String> picks;
  final int seconds;
  String get label => '#$id $genre · seed $seed';
  int get waveSeed => seed * 31 + picks.values.join().length * 7 + id;
}

enum Mode { piece, setup }

enum EngineState { running, restarting }

/// The whole prototype state. Lives in memory only.
class Model extends ChangeNotifier {
  Model() {
    channels[0].sound = synth('165 Acid Arp');
    channels[1].sound = synth('148 Warm 5th Pad');
    channels[9].sound = kit('003 TR-909');
    _rerollAll();
    _seedRenders();
    _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
  }

  final _rng = Random(7);
  late final Timer _ticker;

  String cardFolder = '~/Music/Deluge card';
  EngineState engine = EngineState.running;
  String? lastError;
  String status = 'Engine ready';

  final channels = [for (var c = 1; c <= 16; c++) ChannelSlot(c)];
  int selectedChannel = 1;

  String genre = 'Acid techno';
  int seed = 12345;
  int lengthSeconds = 60;
  final picks = <String, String>{};
  final renders = <Render>[];
  bool rendering = false;
  Render? slotA;
  Render? slotB;
  Render? playing;
  String? auditioning;

  Mode mode = Mode.piece;
  String? selectedSlot; // the key of the Part or lane the browser fills
  String ab = 'A'; // which render the transport plays
  double position = 0.31; // playhead, 0..1
  bool live = false; // the Generator playing live, not a render
  bool pickerOpen = false; // variant E's command palette
  bool autoRender = true; // variant D: render the candidate after each change
  String midiIn = 'KeyStep 37';

  int get tempo => 126 + seed % 12;
  String get keyName => const ['A min', 'C min', 'D min', 'F min', 'G min', 'E min'][seed % 6];

  List<Slot> get slots => genres[genre]!;
  Slot? get selected => slots.where((s) => s.key == selectedSlot).firstOrNull;
  ChannelSlot get channel => channels[selectedChannel - 1];
  Render? get active => ab == 'A' ? slotA : slotB;
  int get channelsUsed => channels.where((c) => c.sound != null).length;

  /// Whether the working picks differ from the newest render, so a render is due.
  bool get dirty {
    final r = renders.firstOrNull;
    if (r == null) return true;
    if (r.genre != genre || r.seed != seed) return true;
    return picks.entries.any((e) => r.picks[e.key] != e.value);
  }

  /// The slots whose pick differs between two sets of picks.
  List<Slot> diff(Map<String, String>? a, Map<String, String>? b) =>
      a == null || b == null ? const [] : [for (final s in slots) if (a[s.key] != b[s.key]) s];

  void setMode(Mode m) {
    mode = m;
    notifyListeners();
  }

  void selectSlot(String? key) {
    selectedSlot = key;
    notifyListeners();
  }

  void setPicker(bool open) {
    pickerOpen = open;
    notifyListeners();
  }

  void setAutoRender(bool v) {
    autoRender = v;
    notifyListeners();
  }

  void setAB(String v) {
    ab = v;
    if (playing != null && active != null) playing = active;
    notifyListeners();
  }

  void toggleAB() => setAB(ab == 'A' ? 'B' : 'A');

  void togglePlay() {
    live = false;
    play(playing == null ? active : null);
  }

  void toggleLive() {
    live = !live;
    playing = null;
    status = live ? 'Playing $genre live, seed $seed' : 'Stopped';
    notifyListeners();
  }

  void seek(double p) {
    position = p.clamp(0.0, 1.0);
    notifyListeners();
  }

  void promote() {
    if (slotB == null) return;
    slotA = slotB;
    status = 'A is now ${slotA!.label}';
    notifyListeners();
  }

  void swapAB() {
    final a = slotA;
    slotA = slotB;
    slotB = a;
    notifyListeners();
  }

  /// Puts the working picks back to what render A used.
  void revertToA() {
    if (slotA == null) return;
    picks
      ..clear()
      ..addAll(slotA!.picks);
    status = 'Sound picks back to A';
    notifyListeners();
  }

  /// Two renders one Sound pick apart, so A/B has something to show at launch.
  void _seedRenders() {
    final acid = slots.firstWhere((s) => s.lane == null);
    selectedSlot = acid.key;
    picks[acid.key] = acid.palette.first.sound;
    slotA = Render(1, genre, seed, Map.of(picks), lengthSeconds);
    picks[acid.key] = acid.palette.last.sound;
    slotB = Render(2, genre, seed, Map.of(picks), lengthSeconds);
    renders.addAll([slotB!, slotA!]);
    ab = 'B';
  }
  int get totalVoices => channels.fold(0, (a, c) => a + c.voices) + (playing != null || live ? 9 : 0);

  void _tick() {
    var changed = false;
    for (final c in channels) {
      if (c.voices > 0) {
        c.voices = max(0, c.voices - 1);
        changed = true;
      }
    }
    if (playing != null || live) {
      position = (position + 0.4 / lengthSeconds) % 1.0;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void setCardFolder(String f) {
    cardFolder = f;
    status = 'Card image rebuilt from $f (prototype: nothing happened)';
    notifyListeners();
  }

  void assign(int channel, String? sound) {
    channels[channel - 1].sound = sound;
    status = sound == null ? 'Channel $channel cleared' : 'Channel $channel ← ${shortName(sound)}';
    notifyListeners();
  }

  void selectChannel(int c) {
    selectedChannel = c;
    notifyListeners();
  }

  void audition(String sound, {int? channel}) {
    if (engine != EngineState.running) return;
    auditioning = sound;
    final c = channel ?? selectedChannel;
    channels[c - 1].voices = 1 + _rng.nextInt(4);
    status = 'Auditioning ${shortName(sound)} on channel $c (C3)';
    notifyListeners();
    Timer(const Duration(milliseconds: 900), () {
      if (auditioning == sound) auditioning = null;
      notifyListeners();
    });
  }

  void setGenre(String g) {
    genre = g;
    _rerollAll();
    selectedSlot = slots.firstWhere((s) => s.lane == null).key;
    status = 'Genre: $g. Sound picks rolled from its palette';
    notifyListeners();
  }

  void rollSeed() {
    seed = _rng.nextInt(99999);
    status = 'Seed $seed';
    notifyListeners();
  }

  void setSeed(int s) {
    seed = s;
    notifyListeners();
  }

  void setPick(String slotKey, String sound) {
    picks[slotKey] = sound;
    status = '$slotKey ← ${shortName(sound)}';
    notifyListeners();
  }

  String _roll(Slot s) {
    final total = s.palette.fold(0, (a, e) => a + e.weight);
    var r = _rng.nextInt(total);
    for (final e in s.palette) {
      r -= e.weight;
      if (r < 0) return e.sound;
    }
    return s.palette.last.sound;
  }

  void reroll(Slot s) => setPick(s.key, _roll(s));

  void _rerollAll() {
    picks.clear();
    for (final s in slots) {
      picks[s.key] = _roll(s);
    }
  }

  Future<void> render() async {
    if (rendering || engine != EngineState.running) return;
    rendering = true;
    status = 'Rendering $lengthSeconds s of $genre, seed $seed…';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final r = Render(renders.length + 1, genre, seed, Map.of(picks), lengthSeconds);
    renders.insert(0, r);
    if (slotA == null) {
      slotA = r;
      ab = 'A';
    } else {
      slotB = r;
      ab = 'B';
    }
    if (playing != null) playing = r;
    rendering = false;
    status = 'Rendered ${r.label} in 0.4 s (fake)';
    notifyListeners();
  }

  void play(Render? r) {
    playing = r;
    if (r != null) live = false;
    if (r != null && r == slotA) ab = 'A';
    if (r != null && r == slotB) ab = 'B';
    status = r == null ? 'Stopped' : 'Playing ${r.label}';
    notifyListeners();
  }

  void setSlot(String ab, Render r) {
    if (ab == 'A') {
      slotA = r;
    } else {
      slotB = r;
    }
    notifyListeners();
  }

  /// Shows what the GUI does when the Engine process freezes: error, restart, same Setup afterwards.
  Future<void> simulateFreeze() async {
    engine = EngineState.restarting;
    lastError = 'Engine froze: E380 (prototype)';
    playing = null;
    status = 'Engine stopped. Restarting and reloading your Setup…';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    engine = EngineState.running;
    status = 'Engine restarted. Setup reloaded';
    notifyListeners();
  }

  /// The full state as JSON, for the prototype's state drawer.
  String toJson() => const JsonEncoder.withIndent('  ').convert({
        'cardFolder': cardFolder,
        'engine': engine.name,
        'lastError': lastError,
        'totalVoices': totalVoices,
        'mode': mode.name,
        'selectedChannel': selectedChannel,
        'selectedSlot': selectedSlot,
        'ab': ab,
        'position': position,
        'live': live,
        'dirty': dirty,
        'setup': {for (final c in channels) if (c.sound != null) 'ch${c.channel}': shortName(c.sound!)},
        'piece': {'genre': genre, 'seed': seed, 'lengthSeconds': lengthSeconds, 'picks': {for (final e in picks.entries) e.key: shortName(e.value)}},
        'renders': [for (final r in renders) r.label],
        'A': slotA?.label,
        'B': slotB?.label,
        'playing': playing?.label,
      });

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }
}
