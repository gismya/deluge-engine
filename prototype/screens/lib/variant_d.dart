// PROTOTYPE — throwaway. Variant D: Compare bench.
//
// Design intent
// - The question this tool answers is "is this sound better than that one, in the music?". So the
//   screen is built around A/B, not around a browser: A is the reference render, B is the candidate
//   you are working on.
// - Top: one big waveform pair on a shared time axis, A drawn upwards and B downwards from the
//   Section ruler, with one playhead. The A and B keys beside it switch which one you hear.
// - Middle: the Piece as a diff table. One row per Part or lane, A's Sound pick beside B's. Rows that
//   differ are tinted; clicking A's cell copies its pick back to B.
// - Right: the picker for the selected row. The Palette is a small grid of pads (click to pick and
//   hear), with every preset searchable below. A pick re-renders B by itself (about 2 s), so the
//   loop is: click a pad, press Tab, listen.
// - Touch (a tablet): 48 dp rows, a tap on a row selects and plays it, the re-roll and copy buttons
//   are always shown. In portrait the picker moves under the table and its pads sit in one row.
// - Setup uses the same picker; the 16 MIDI channels are a 4 x 4 grid of pads with a keyboard under it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'ui.dart';

class VariantD extends StatelessWidget {
  const VariantD({super.key, required this.model});
  final Model model;
  static const name = 'Compare bench';

  void _move(int d) {
    final keys = [for (final s in model.slots) s.key];
    final i = keys.indexOf(model.selectedSlot ?? '');
    model.selectSlot(keys[(i + d).clamp(0, keys.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final piece = model.mode == Mode.piece;
    return Keys(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): model.togglePlay,
        const SingleActivator(LogicalKeyboardKey.tab): model.toggleAB,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): model.render,
        const SingleActivator(LogicalKeyboardKey.keyN): model.rollSeed,
        const SingleActivator(LogicalKeyboardKey.keyL): model.toggleLive,
        if (piece) const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        if (piece) const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          final s = model.selected;
          if (piece && s != null) pick(model, s, null);
        },
      },
      child: Material(
        color: t.bg0,
        child: Column(children: [
          TopBar(model: model, left: [ModeSeg(model: model, pieceName: 'Bench')]),
          Expanded(
            child: RestartVeil(
              model: model,
              child: LayoutBuilder(builder: (context, box) {
                final narrow = box.maxWidth < 900;
                final main = piece ? _DiffTable(model: model, narrow: narrow) : _Pads(model: model);
                if (narrow) {
                  return Column(children: [
                    if (piece) ...[_Hero(model: model), const Hr()],
                    Expanded(flex: piece ? 1 : 3, child: main),
                    const Hr(),
                    Expanded(flex: piece ? 1 : 2, child: _Picker(model: model, narrow: true)),
                  ]);
                }
                return Row(children: [
                  Expanded(
                    child: piece ? Column(children: [_Hero(model: model), const Hr(), Expanded(child: main)]) : main,
                  ),
                  const Vr(),
                  SizedBox(width: 340, child: _Picker(model: model)),
                ]);
              }),
            ),
          ),
          StatusBar(
            model: model,
            hints: piece
                ? const [('Tab', 'hear the other'), ('Space', 'play'), ('↑↓', 'part'), ('R', 're-roll')]
                : const [('/', 'search')],
          ),
        ]),
      ),
    );
  }
}

/// Puts [sound] (or a re-roll, when null) on [slot], plays it, and re-renders B when auto-render is on.
void pick(Model model, Slot slot, String? sound) {
  if (sound == null) {
    model.reroll(slot);
  } else {
    model.setPick(slot.key, sound);
  }
  model.audition(model.picks[slot.key]!);
  if (model.autoRender) model.render();
}

// ---------------------------------------------------------------------------------------------
// Hero: the two renders on one time axis

class _Hero extends StatelessWidget {
  const _Hero({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final tall = MediaQuery.sizeOf(context).height >= 800;
    final playing = model.playing != null;
    return Container(
      height: (tall ? 252 : 204) + (t.touch ? 20 : 0),
      color: t.bg1,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(children: [
        SizedBox(
          height: t.touch ? 48 : 28,
          child: LayoutBuilder(
            builder: (context, box) => Row(children: [
              GenreMenu(model: model),
              const SizedBox(width: 8),
              SeedField(model: model),
              if (box.maxWidth > (t.touch ? 900 : 700)) ...[const SizedBox(width: 12), Facts(model: model)],
              const Spacer(),
              Hover(
                tooltip: 'Render B again after every change to a Sound pick',
                onTap: () => model.setAutoRender(!model.autoRender),
                builder: (_, h) => hit(
                  t,
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _Switch(on: model.autoRender),
                    const SizedBox(width: 8),
                    Text('Auto-render', style: t.small.copyWith(color: h ? t.text : t.text2)),
                  ]),
                ),
              ),
              const SizedBox(width: 16),
              if (box.maxWidth > 780) ...[LiveBtn(model: model), const SizedBox(width: 8)],
              RenderBtn(model: model, text: 'Render B'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 900 ? 148 : 168,
              child: Column(children: [
                Expanded(child: _key('A', model.slotA, 'Reference', t)),
                const SizedBox(height: 8),
                Expanded(child: _key('B', model.slotB, model.rendering ? 'Rendering…' : (model.dirty ? 'Not rendered yet' : 'Candidate'), t)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: _waves(t)),
            const SizedBox(width: 16),
            SizedBox(
              width: 96,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Hover(
                  onTap: model.active == null ? null : model.togglePlay,
                  tooltip: 'Play or stop  (Space)',
                  builder: (_, h) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: h ? Color.lerp(t.accent, Colors.white, 0.12) : t.accent, shape: BoxShape.circle),
                    child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28, color: t.onAccent),
                  ),
                ),
                const SizedBox(height: 10),
                Text(clock(model.position, model.lengthSeconds), style: t.display.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                Text('of ${clock(1, model.lengthSeconds)}', style: t.cap),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _key(String ab, Render? r, String role, Tk t) {
    final on = model.ab == ab;
    return Hover(
      onTap: r == null ? null : () => model.setAB(ab),
      tooltip: 'Hear $ab  (Tab switches)',
      builder: (_, h) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? t.accentSoft : (h ? t.bg2 : t.bg0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? t.accentLine : t.line),
        ),
        child: Row(children: [
          ABBadge(ab, on: on, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r == null ? 'Empty' : 'Render ${r.id}', maxLines: 1, style: t.bodyM.copyWith(color: on ? t.text : t.text2)),
              Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap.copyWith(color: ab == 'B' && model.dirty ? t.accent : t.text3)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _waves(Tk t) => LayoutBuilder(builder: (context, box) {
        final x = model.position * box.maxWidth;
        Widget wave(String ab, Render? r, WaveAlign align) {
          final on = model.ab == ab;
          if (r == null) return Center(child: Text('No render in $ab yet', style: t.small.copyWith(color: t.text3)));
          return Wave(
            seed: r.waveSeed,
            align: align,
            bar: 3,
            gap: 1.5,
            progress: on ? model.position : null,
            color: on ? t.accent : t.text3.withValues(alpha: 0.45),
            rest: t.accent.withValues(alpha: 0.38),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            model.seek(d.localPosition.dx / box.maxWidth);
            model.setAB(d.localPosition.dy < box.maxHeight / 2 ? 'A' : 'B');
          },
          child: Stack(children: [
            Column(children: [
              Expanded(child: wave('A', model.slotA, WaveAlign.up)),
              const SizedBox(height: 3),
              const SectionRuler(height: 20),
              const SizedBox(height: 3),
              Expanded(child: wave('B', model.slotB, WaveAlign.down)),
            ]),
            Positioned(left: x - 0.75, top: 0, bottom: 0, child: Container(width: 1.5, color: t.text)),
          ]),
        );
      });
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Container(
      width: t.touch ? 36 : 26,
      height: t.touch ? 20 : 16,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(color: on ? t.accent : t.bg3, borderRadius: BorderRadius.circular(8)),
      child: Container(width: t.touch ? 16 : 12, height: t.touch ? 16 : 12, decoration: BoxDecoration(color: on ? t.onAccent : t.text2, shape: BoxShape.circle)),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// The Piece as a diff of A against B

class _DiffTable extends StatelessWidget {
  const _DiffTable({required this.model, this.narrow = false});
  final Model model;
  final bool narrow;
  double get _nameW => narrow ? 100 : 132;

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final tight = narrow || MediaQuery.sizeOf(context).width < 1300;
    final a = model.slotA;
    final diff = model.diff(a?.picks, model.picks);
    final rows = <Widget>[];
    String? part;
    for (final s in model.slots) {
      final group = s.lane == null ? 'PARTS' : s.part;
      if (group != part) {
        part = group;
        rows.add(Container(
          height: 28,
          padding: const EdgeInsets.only(left: 16, top: 8),
          alignment: Alignment.centerLeft,
          child: Row(children: [Label(group), const SizedBox(width: 8), Text(group == 'PARTS' ? 'Synths' : 'Kit lanes', style: t.cap)]),
        ));
      }
      rows.add(_row(context, s, a));
    }
    return Column(children: [
      Container(
        height: t.touch ? 56 : 40,
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(children: [
          SizedBox(width: _nameW, child: const Label('Part')),
          Expanded(child: _colHead(t, 'A', a == null ? 'Empty' : 'Render ${a.id}', 'reference')),
          Expanded(
            child: Row(children: [
              Expanded(
                child: _colHead(
                  t,
                  'B',
                  'Working',
                  diff.isEmpty ? 'same as A' : (diff.length == 1 ? '1 differs' : '${diff.length} differ'),
                  on: diff.isNotEmpty,
                ),
              ),
              if (!tight) Btn('Revert to A', kind: BtnKind.ghost, onTap: diff.isEmpty ? null : model.revertToA),
              Btn(tight ? 'Keep B' : 'Keep B as A', icon: Icons.arrow_back_rounded, kind: BtnKind.ghost, tooltip: 'Make B the new reference', onTap: model.slotB == null ? null : model.promote),
            ]),
          ),
        ]),
      ),
      const Hr(),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 12), children: rows)),
    ]);
  }

  Widget _colHead(Tk t, String ab, String title, String note, {bool on = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        ABBadge(ab, on: model.ab == ab, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyM)),
        const SizedBox(width: 8),
        Flexible(child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap.copyWith(color: on ? t.accent : t.text3))),
      ]);

  Widget _row(BuildContext context, Slot s, Render? a) {
    final t = Tk.of(context);
    final sel = model.selectedSlot == s.key;
    final mine = model.picks[s.key]!;
    final theirs = a?.picks[s.key];
    final differs = theirs != null && theirs != mine;
    return Hover(
      onTap: () {
        model.selectSlot(s.key);
        if (t.touch) model.audition(mine);
      },
      onDoubleTap: t.touch ? null : () => model.audition(mine),
      builder: (_, h) => Container(
        height: t.touch ? 48 : 32,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(color: sel ? t.bg2 : (h ? t.bg1 : null), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          SizedBox(
            width: _nameW,
            child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: s.lane == null ? t.bodyM : t.body.copyWith(color: t.text2)),
          ),
          Expanded(
            child: theirs == null
                ? Text('—', style: t.body.copyWith(color: t.text3))
                : Hover(
                    onTap: differs ? () => pick(model, s, theirs) : null,
                    tooltip: differs ? 'Use A\'s pick in B' : null,
                    builder: (_, h2) => Row(children: [
                      Flexible(child: SoundName(theirs, number: !narrow, style: t.body.copyWith(color: differs ? t.text : t.text2, decoration: h2 ? TextDecoration.underline : null))),
                      if (differs && (h2 || t.touch)) ...[const SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: t.touch ? 18 : 13, color: t.text2)],
                      const SizedBox(width: 12),
                    ]),
                  ),
          ),
          Expanded(
            child: Container(
              height: t.touch ? 42 : 26,
              padding: const EdgeInsets.only(left: 8, right: 2),
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: differs ? t.accentSoft : null,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: sel ? t.accentLine : Colors.transparent),
              ),
              child: Row(children: [
                Expanded(child: SoundName(mine, number: !narrow, style: (differs || sel ? t.bodyM : t.body).copyWith(color: differs ? t.accent : (sel ? t.text : t.text2)))),
                PaletteMark(slot: s, sound: mine, on: sel, bar: false),
                Opacity(
                  opacity: h || sel || t.touch ? 1 : 0,
                  child: IconBtn(Icons.casino_outlined, size: 24, tooltip: 'Re-roll from the palette  (R)', onTap: () => pick(model, s, null)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Picker: the selected row's Palette as pads, then every preset

class _Picker extends StatefulWidget {
  const _Picker({required this.model, this.narrow = false});
  final Model model;
  final bool narrow;
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final search = TextEditingController();
  final focus = FocusNode();
  bool kits = false;

  @override
  void dispose() {
    search.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final m = widget.model;
    final piece = m.mode == Mode.piece;
    final slot = piece ? m.selected : null;
    final current = piece ? m.picks[m.selectedSlot] : m.channel.sound;
    final samples = slot != null && !slot.isSynth;
    final showKits = !piece && kits;
    final all = samples ? const <String>[] : presetPaths(kits: showKits, query: search.text);
    final per = widget.narrow ? 4 : 2; // pads in a row

    void choose(String path) {
      if (piece) {
        if (slot != null) pick(m, slot, path);
      } else {
        m.assign(m.selectedChannel, path);
        m.audition(path);
      }
    }

    return Keys(
      bindings: {const SingleActivator(LogicalKeyboardKey.slash): focus.requestFocus},
      child: Container(
        color: t.bg1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Label(piece ? (slot == null ? 'Nothing selected' : '${slot.key}  ·  ${roles[slot.part]}  ·  pick for B') : 'Channel ${m.selectedChannel}  ·  ${soundKind(current)}'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: current == null ? Text('Empty', style: t.title.copyWith(color: t.text3)) : SoundName(current, style: t.title)),
                IconBtn(Icons.play_arrow_rounded, filled: true, tooltip: 'Audition', onTap: current == null ? null : () => m.audition(current)),
                if (!piece) ...[
                  const SizedBox(width: 6),
                  IconBtn(Icons.close_rounded, filled: true, tooltip: 'Clear the channel', onTap: current == null ? null : () => m.assign(m.selectedChannel, null)),
                ],
              ]),
            ]),
          ),
          if (slot != null) ...[
            const Hr(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Label('Palette'),
                  const SizedBox(width: 8),
                  Expanded(child: Text('share of re-rolls', style: t.cap)),
                  Btn('Re-roll', icon: Icons.casino_outlined, kbd: 'R', height: 26, onTap: () => pick(m, slot, null)),
                  if (widget.narrow) ...[const SizedBox(width: 8), const Btn('Edit sound', icon: Icons.tune_rounded, kind: BtnKind.ghost, tooltip: 'Editing a sound comes in v2'), const Tag('v2')],
                ]),
                const SizedBox(height: 10),
                for (var i = 0; i < slot.palette.length; i += per)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                    child: Row(children: [
                      for (var j = i; j < i + per; j++) ...[
                        if (j > i) const SizedBox(width: 8),
                        Expanded(child: j < slot.palette.length ? _pad(t, m, slot, slot.palette[j], current) : const SizedBox.shrink()),
                      ],
                    ]),
                  ),
              ]),
            ),
          ],
          const Hr(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!piece) ...[
                Seg<bool>(items: const {false: 'Synths  171', true: 'Kits  43'}, value: kits, expand: true, onChanged: (v) => setState(() => kits = v)),
                const SizedBox(height: 8),
              ],
              SearchField(
                controller: search,
                focusNode: focus,
                hint: samples ? 'Any sample (not in the prototype)' : (showKits ? 'Any of 43 kits' : 'Any of 171 synths'),
                kbd: '/',
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
          Expanded(
            child: samples
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('A Kit lane takes any sample under SAMPLES/. The prototype offers only the palette.', style: t.cap),
                  )
                : ListView(padding: const EdgeInsets.only(bottom: 8), children: [
                    for (final p in all) PresetRow(path: p, model: m, current: p == current, onTap: () => choose(p), padding: 16),
                    if (all.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Nothing matches "${search.text}".', style: t.small)),
                  ]),
          ),
          if (!widget.narrow) const Hr(),
          if (!widget.narrow) Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 14, color: t.text3),
              const SizedBox(width: 8),
              Expanded(child: Text('Edit this sound', style: t.small.copyWith(color: t.text3))),
              const Tag('v2'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pad(Tk t, Model m, Slot slot, Entry e, String? current) {
    final on = e.sound == current;
    final playing = m.auditioning == e.sound;
    final (n, title) = splitName(e.sound);
    return Hover(
      onTap: () => pick(m, slot, e.sound),
      builder: (_, h) => Container(
        height: t.touch ? 80 : 70,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        decoration: BoxDecoration(
          color: on ? t.accentSoft : (h ? t.bg3 : t.bg2),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: on ? t.accent : (h ? t.lineStrong : t.line)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyM.copyWith(fontSize: 12.5))),
            if (playing) Icon(Icons.volume_up_rounded, size: 13, color: t.accent) else if (on) Icon(Icons.check_rounded, size: 13, color: t.accent),
          ]),
          Text(n ?? soundKind(e.sound), style: t.numSmall.copyWith(fontSize: 11, color: t.text3)),
          const Spacer(),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: e.weight / slot.total, minHeight: 3, backgroundColor: t.lineStrong, color: on ? t.accent : t.text3),
              ),
            ),
            const SizedBox(width: 8),
            Text('${(100 * e.weight / slot.total).round()}%', style: t.numSmall.copyWith(fontSize: 11, color: on ? t.text : t.text3)),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Setup: the 16 MIDI channels as pads

class _Pads extends StatelessWidget {
  const _Pads({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final sound = model.channel.sound;
    return Column(children: [
      Container(
        height: t.bar,
        color: t.bg1,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('Setup', style: t.title),
          const SizedBox(width: 10),
          Flexible(child: Text('${model.channelsUsed} of 16 MIDI channels play a preset', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small)),
          const Spacer(),
          MidiPill(model: model),
        ]),
      ),
      const Hr(),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (var r = 0; r < 4; r++) ...[
              if (r > 0) const SizedBox(height: 8),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var c = 0; c < 4; c++) ...[
                    if (c > 0) const SizedBox(width: 8),
                    Expanded(child: _pad(t, model.channels[r * 4 + c])),
                  ],
                ]),
              ),
            ],
          ]),
        ),
      ),
      const Hr(),
      Container(
        height: t.touch ? 120 : 104,
        color: t.bg1,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 184,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Label('Audition  ·  channel ${model.selectedChannel}'),
              const SizedBox(height: 6),
              sound == null ? Text('Empty', style: t.title.copyWith(color: t.text3)) : SoundName(sound, style: t.title, number: false),
              const Spacer(),
              Text('Click a key, or play ${model.midiIn}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => MiniKeys(
                height: t.touch ? 96 : 80,
                octaves: box.maxWidth > 760 ? 4 : 3,
                lit: model.auditioning != null && model.auditioning == sound ? 60 : null,
                onNote: (_) {
                  if (sound != null) model.audition(sound);
                },
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _pad(Tk t, ChannelSlot c) {
    final sel = model.selectedChannel == c.channel;
    final s = c.sound;
    return Hover(
      onTap: () {
        model.selectChannel(c.channel);
        if (t.touch && s != null) model.audition(s, channel: c.channel);
      },
      onDoubleTap: s == null || t.touch ? null : () => model.audition(s, channel: c.channel),
      builder: (_, h) => Container(
        padding: t.touch ? const EdgeInsets.fromLTRB(12, 8, 2, 0) : const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: sel ? t.accentSoft : (s == null ? (h ? t.bg1 : Colors.transparent) : (h ? t.bg2 : t.bg1)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? t.accent : t.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(c.channel.toString().padLeft(2, '0'), style: t.num.copyWith(fontWeight: FontWeight.w600, color: sel ? t.accent : (s == null ? t.text3 : t.text2))),
            if (s != null && splitName(s).$1 != null) ...[const SizedBox(width: 8), Text('preset ${splitName(s).$1}', style: t.numSmall.copyWith(fontSize: 11, color: t.text3))],
            const Spacer(),
            if (s != null) Tag(soundKind(s)),
            if (t.touch) const SizedBox(width: 10),
          ]),
          const Spacer(),
          if (s == null)
            Text(sel ? 'Pick a preset →' : 'Empty', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: t.text3))
          else ...[
            Text(splitName(s).$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyM.copyWith(fontSize: 14)),
          ],
          const Spacer(),
          SizedBox(
            height: t.touch ? 48 : 24,
            child: s == null
                ? null
                : Row(children: [
                    Meter(value: c.voices, max: 4, segments: 8),
                    const Spacer(),
                    Opacity(
                      opacity: h || sel || t.touch ? 1 : 0,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (!t.touch) IconBtn(Icons.play_arrow_rounded, size: 24, tooltip: 'Audition', onTap: () => model.audition(s, channel: c.channel)),
                        IconBtn(Icons.close_rounded, size: 24, tooltip: 'Clear the channel', onTap: () => model.assign(c.channel, null)),
                      ]),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
