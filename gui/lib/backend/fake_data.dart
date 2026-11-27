import 'dart:math';

import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;

/// Fake card catalog, genres, Palettes, peaks, Sections, and notes for
/// [FakeBackend]. Contains factory preset names only (no audio, spec §8).
const List<String> fakeSynthNames = [
  '000 Rich Saw Bass',
  '001 Sync Bass',
  '002 Basic Square Bass',
  '003 Synthwave Bass',
  '004 Dubby Bass',
  '005 Sweet Mono Bass',
  '006 Vaporwave Bass',
  '007 Detuned Saw Bass',
  '008 FM Rich Distorted Bass',
  '009 Hoover Bass',
  '012 Blunt Sync Bass',
  '015 Resonant Filter Bass',
  '017 Impact Saw Lead',
  '018 Rich Saw Lead',
  '020 Soft Saw Lead',
  '026 PW Organ',
  '037 Echo Chord',
  '047 Basic Dirty Bass',
  '050 FM Basic Bass',
  '058 FM Rising Attack',
  '067 Marimba',
  '068 FM Bells 1',
  '072 Kyoto Phono',
  '082 Short Sharp Delay',
  '083 Dark Chorus',
  '086 Techno Organ',
  '097 Saturated Filter',
  '126 Dark FM Pad',
  '131 Warm Strings',
  '139 Detuned Saw Pad',
  '142 Phaser',
  '148 Warm 5th Pad',
  '149 Cold 5th Pad',
  '151 Radiant FM Pad',
  '153 FM Modulation Pad',
  '165 Acid Arp',
  '167 FM Metallic Bass Arp',
];

const List<String> fakeKitNames = [
  '000 TR-808',
  '001 DDD-1',
  '002 SDS-5',
  '003 TR-909',
  '004 R-50',
  '005 R-100',
  '006 LD',
  '007 HR-16B',
  '009 RX-5',
  '010 XV-5080',
  '014 CR-78',
];

pb.Catalog buildFakeCatalog() => pb.Catalog(
      synths: [
        for (final name in fakeSynthNames)
          pb.PresetEntry(path: 'SYNTHS/$name.XML', name: name),
      ],
      kits: [
        for (final name in fakeKitNames)
          pb.PresetEntry(path: 'KITS/$name.XML', name: name),
      ],
    );

List<pb.PaletteEntry> _synthPalette(List<(String, int)> entries) => [
      for (final (name, weight) in entries)
        pb.PaletteEntry(path: 'SYNTHS/$name.XML', weight: weight),
    ];

List<pb.PaletteEntry> _samplePalette(List<(String, int)> entries) => [
      for (final (name, weight) in entries)
        pb.PaletteEntry(path: 'SAMPLES/DRUMS/$name.wav', weight: weight),
    ];

List<pb.LaneInfo> _drumLanes() => [
      pb.LaneInfo(
        index: 0,
        name: 'Kick',
        palette: _samplePalette([
          ('909 Kick', 3),
          ('Deep Sky Kick HQ', 1),
          ('Deep Sky Kick distorted', 1),
          ('808 Kick distorted', 1),
        ]),
      ),
      pb.LaneInfo(
        index: 1,
        name: 'Snare',
        palette: _samplePalette([
          ('909 Snare', 3),
          ('XV5080 Snare dry', 1),
          ('DDD1 Snare dry', 1),
        ]),
      ),
      pb.LaneInfo(
        index: 2,
        name: 'Rim',
        palette: _samplePalette([
          ('909 Rim', 2),
          ('808 Rim', 1),
          ('DDD1 Rim', 1),
        ]),
      ),
      pb.LaneInfo(
        index: 3,
        name: 'Closed hat',
        palette: _samplePalette([
          ('909 Closed Hat', 3),
          ('808 Closed Hat', 1),
          ('DDD1 Closed Hat', 1),
        ]),
      ),
      pb.LaneInfo(
        index: 4,
        name: 'Open hat',
        palette: _samplePalette([
          ('909 Open Hat', 3),
          ('808 Open Hat', 1),
          ('DDD1 Open Hat', 1),
        ]),
      ),
      pb.LaneInfo(
        index: 5,
        name: 'Crash',
        palette: _samplePalette([
          ('909 Crash', 3),
          ('XV5080 Crash', 1),
          ('DDD1 Crash', 1),
        ]),
      ),
      pb.LaneInfo(
        index: 6,
        name: 'Tom',
        palette: _samplePalette([
          ('909 Tom', 2),
          ('808 Tom', 1),
        ]),
      ),
    ];

List<pb.LaneInfo> _fxLanes() => [
      pb.LaneInfo(
        index: 12,
        name: 'Riser',
        palette: [
          pb.PaletteEntry(
            path: 'SYNTHS/GENERATIVE/FX/GEN Riser.XML',
            weight: 1,
          ),
        ],
      ),
      pb.LaneInfo(
        index: 13,
        name: 'Fall',
        palette: [
          pb.PaletteEntry(
            path: 'SYNTHS/GENERATIVE/FX/GEN Fall.XML',
            weight: 1,
          ),
        ],
      ),
      pb.LaneInfo(
        index: 14,
        name: 'Impact',
        palette: [
          pb.PaletteEntry(
            path: 'SYNTHS/GENERATIVE/FX/GEN Impact.XML',
            weight: 1,
          ),
        ],
      ),
    ];

pb.Genres buildFakeGenres() => pb.Genres(
      genres: [
        pb.GenreInfo(
          id: 'techno-acid',
          name: 'Acid techno',
          parts: [
            pb.PartInfo(
              index: 0,
              name: 'ACID',
              role: 'Bass',
              palette: _synthPalette([
                ('165 Acid Arp', 3),
                ('015 Resonant Filter Bass', 2),
                ('097 Saturated Filter', 2),
                ('005 Sweet Mono Bass', 1),
              ]),
            ),
            pb.PartInfo(
              index: 1,
              name: 'DRONE',
              role: 'Pad',
              palette: _synthPalette([
                ('148 Warm 5th Pad', 2),
                ('126 Dark FM Pad', 2),
                ('139 Detuned Saw Pad', 2),
                ('149 Cold 5th Pad', 1),
              ]),
            ),
            pb.PartInfo(
              index: 2,
              name: 'DRUMS',
              role: 'Drums',
              lanes: _drumLanes(),
            ),
            pb.PartInfo(
              index: 3,
              name: 'FX',
              role: 'FX',
              lanes: _fxLanes(),
            ),
          ],
        ),
        pb.GenreInfo(
          id: 'techno-melodic',
          name: 'Melodic techno',
          parts: [
            pb.PartInfo(
              index: 0,
              name: 'BASS',
              role: 'Bass',
              palette: _synthPalette([
                ('000 Rich Saw Bass', 3),
                ('047 Basic Dirty Bass', 2),
                ('012 Blunt Sync Bass', 1),
                ('050 FM Basic Bass', 1),
              ]),
            ),
            pb.PartInfo(
              index: 1,
              name: 'PAD',
              role: 'Pad',
              palette: _synthPalette([
                ('153 FM Modulation Pad', 3),
                ('139 Detuned Saw Pad', 2),
                ('151 Radiant FM Pad', 2),
                ('142 Phaser', 1),
              ]),
            ),
            pb.PartInfo(
              index: 2,
              name: 'ARP',
              role: 'Lead',
              palette: _synthPalette([
                ('167 FM Metallic Bass Arp', 3),
                ('058 FM Rising Attack', 2),
                ('068 FM Bells 1', 2),
                ('067 Marimba', 1),
              ]),
            ),
            pb.PartInfo(
              index: 3,
              name: 'DRUMS',
              role: 'Drums',
              lanes: _drumLanes(),
            ),
            pb.PartInfo(
              index: 4,
              name: 'FX',
              role: 'FX',
              lanes: _fxLanes(),
            ),
          ],
        ),
        pb.GenreInfo(
          id: 'techno-dub',
          name: 'Dub techno',
          parts: [
            pb.PartInfo(
              index: 0,
              name: 'SUB',
              role: 'Bass',
              palette: _synthPalette([
                ('002 Basic Square Bass', 3),
                ('050 FM Basic Bass', 2),
                ('047 Basic Dirty Bass', 1),
              ]),
            ),
            pb.PartInfo(
              index: 1,
              name: 'STAB',
              role: 'Chords',
              palette: _synthPalette([
                ('037 Echo Chord', 3),
                ('082 Short Sharp Delay', 2),
                ('072 Kyoto Phono', 1),
              ]),
            ),
            pb.PartInfo(
              index: 2,
              name: 'PAD',
              role: 'Pad',
              palette: _synthPalette([
                ('131 Warm Strings', 3),
                ('139 Detuned Saw Pad', 2),
                ('126 Dark FM Pad', 2),
              ]),
            ),
            pb.PartInfo(
              index: 3,
              name: 'DRUMS',
              role: 'Drums',
              lanes: _drumLanes(),
            ),
            pb.PartInfo(
              index: 4,
              name: 'FX',
              role: 'FX',
              lanes: _fxLanes(),
            ),
          ],
        ),
        pb.GenreInfo(
          id: 'techno-detroit',
          name: 'Detroit techno',
          parts: [
            pb.PartInfo(
              index: 0,
              name: 'BASS',
              role: 'Bass',
              palette: _synthPalette([
                ('047 Basic Dirty Bass', 3),
                ('000 Rich Saw Bass', 2),
                ('007 Detuned Saw Bass', 1),
                ('008 FM Rich Distorted Bass', 1),
              ]),
            ),
            pb.PartInfo(
              index: 1,
              name: 'STRINGS',
              role: 'Pad',
              palette: _synthPalette([
                ('131 Warm Strings', 3),
                ('139 Detuned Saw Pad', 2),
                ('126 Dark FM Pad', 2),
              ]),
            ),
            pb.PartInfo(
              index: 2,
              name: 'STAB',
              role: 'Chords',
              palette: _synthPalette([
                ('086 Techno Organ', 3),
                ('037 Echo Chord', 2),
                ('026 PW Organ', 1),
                ('083 Dark Chorus', 1),
              ]),
            ),
            pb.PartInfo(
              index: 3,
              name: 'MOTIF',
              role: 'Lead',
              palette: _synthPalette([
                ('167 FM Metallic Bass Arp', 3),
                ('058 FM Rising Attack', 2),
                ('068 FM Bells 1', 2),
                ('067 Marimba', 1),
              ]),
            ),
            pb.PartInfo(
              index: 4,
              name: 'DRUMS',
              role: 'Drums',
              lanes: _drumLanes(),
            ),
            pb.PartInfo(
              index: 5,
              name: 'FX',
              role: 'FX',
              lanes: _fxLanes(),
            ),
          ],
        ),
      ],
    );

/// Generates deterministic fake [pb.PeakPair]s (~2000 pairs) shaped across
/// musical Sections so waveforms look realistic and repeatable.
List<pb.PeakPair> buildFakePeaks(int seed, {int count = 2000}) {
  final rng = Random(seed);
  final out = <pb.PeakPair>[];
  const sections = [
    ('Intro', 4, 0.35),
    ('Groove', 8, 0.70),
    ('Build', 4, 0.80),
    ('Drop', 8, 1.00),
    ('Break', 4, 0.30),
    ('Outro', 4, 0.50),
  ];
  const totalBars = 32.0;

  for (var i = 0; i < count; i++) {
    final bar = (i / count) * totalBars;
    var start = 0.0;
    var level = 0.5;
    for (final (name, bars, base) in sections) {
      if (bar < start + bars) {
        final p = (bar - start) / bars;
        level = switch (name) {
          'Intro' => base + 0.2 * p,
          'Build' => 0.5 + 0.45 * p,
          'Outro' => base * (1 - 0.75 * p),
          _ => base,
        };
        break;
      }
      start += bars;
    }
    final beat = (bar * 4) % 1.0;
    final kick = exp(-beat * 3.2);
    final amp = (level * (0.45 + 0.55 * kick) * (0.7 + 0.3 * rng.nextDouble()))
        .clamp(0.03, 0.98);
    out.add(pb.PeakPair(min: -amp, max: amp));
  }
  return out;
}

List<pb.SectionMarker> buildFakeSections(double durationS) {
  const layout = [
    ('Intro', 0.0),
    ('Groove', 4 / 32),
    ('Build', 12 / 32),
    ('Drop', 16 / 32),
    ('Break', 24 / 32),
    ('Outro', 28 / 32),
  ];
  return [
    for (final (name, frac) in layout)
      pb.SectionMarker(name: name, timeS: durationS * frac),
  ];
}

List<pb.TimelineNote> buildFakeNotes(
  pb.GenreInfo genre,
  int seed,
  double durationS,
) {
  final rng = Random(seed ^ 0x5A3C);
  final notes = <pb.TimelineNote>[];
  const steps = 64;
  final stepS = durationS / steps;

  for (final part in genre.parts) {
    if (part.lanes.isEmpty) {
      for (var s = 0; s < steps; s++) {
        if (rng.nextDouble() < 0.35) {
          notes.add(
            pb.TimelineNote(
              part: part.index,
              startS: s * stepS,
              lengthS: stepS * (1 + rng.nextInt(3)),
              pitch: 36 + rng.nextInt(24),
              velocity: 80 + rng.nextInt(40),
            ),
          );
        }
      }
    } else {
      for (final lane in part.lanes) {
        final density = lane.index == 0 ? 0.5 : 0.25;
        for (var s = 0; s < steps; s++) {
          if (rng.nextDouble() < density) {
            notes.add(
              pb.TimelineNote(
                lane: lane.index,
                startS: s * stepS,
                lengthS: stepS * 0.5,
                pitch: 36 + lane.index,
                velocity: 90 + rng.nextInt(35),
              ),
            );
          }
        }
      }
    }
  }
  return notes;
}
