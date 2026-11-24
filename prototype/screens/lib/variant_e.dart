// PROTOTYPE — throwaway. Variant E: Timeline.
//
// Design intent
// - Sound-first: the Piece is drawn as what the Generator plays. One row per Part or lane, its Sound
//   pick on the left, and on the right what it plays across the Sections (Intro, Groove, Build, Drop,
//   Break, Outro), so you see where a sound matters before you judge it.
// - The renders are rows of the same timeline, under the Parts and on the same time axis, with one
//   playhead through everything. A/B is "which waveform row is lit".
// - No browser on screen. Changing a sound opens a command palette over the timeline: the Palette
//   first, with each sound's share of re-rolls, then every preset, then actions. Type to filter,
//   move with the arrow keys to hear each sound, Enter to pick. The timeline keeps the whole window.
// - Setup is the same idea: a list of the 16 MIDI channels, and the same palette to fill one.
// - Touch (a tablet): every row has a visible "change" button that opens the palette, palette rows
//   are 48 dp with their own play button, and nothing needs a keyboard.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'ui.dart';

class VariantE extends StatelessWidget {
  const VariantE({super.key, required this.model});
  final Model model;
  static const name = 'Timeline';

  void _move(int d) {
    if (model.mode == Mode.setup) {
      model.selectChannel((model.selectedChannel + d).clamp(1, 16));
      return;
    }
    final keys = [for (final s in model.slots) s.key];
    model.selectSlot(keys[(keys.indexOf(model.selectedSlot ?? '') + d).clamp(0, keys.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final piece = model.mode == Mode.piece;
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Keys(
      bindings: model.pickerOpen
          ? const {}
          : {
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => model.setPicker(true),
              const SingleActivator(LogicalKeyboardKey.enter): () => model.setPicker(true),
              const SingleActivator(LogicalKeyboardKey.slash): () => model.setPicker(true),
              const SingleActivator(LogicalKeyboardKey.space): model.togglePlay,
              const SingleActivator(LogicalKeyboardKey.tab): model.toggleAB,
              const SingleActivator(LogicalKeyboardKey.keyR, meta: true): model.render,
              const SingleActivator(LogicalKeyboardKey.keyL): model.toggleLive,
              const SingleActivator(LogicalKeyboardKey.keyN): model.rollSeed,
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
              const SingleActivator(LogicalKeyboardKey.keyR): () {
                final s = model.selected;
                if (piece && s != null) model.reroll(s);
              },
            },
      child: Material(
        color: t.bg0,
        child: Stack(children: [
          Column(children: [
            TopBar(
              model: model,
              left: [ModeSeg(model: model, pieceName: 'Timeline')],
              right: [
                narrow
                    ? IconBtn(Icons.search, tooltip: 'Find a sound', onTap: () => model.setPicker(true))
                    : Btn('Find a sound', icon: Icons.search, kbd: '⌘K', onTap: () => model.setPicker(true)),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(child: RestartVeil(model: model, child: piece ? _Timeline(model: model) : _Channels(model: model))),
            StatusBar(
              model: model,
              hints: const [('↑↓', 'row'), ('↵', 'change the sound'), ('Space', 'play'), ('Tab', 'A/B')],
            ),
          ]),
          if (model.pickerOpen) Positioned.fill(child: _Palette(model: model)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Timeline

class _Timeline extends StatelessWidget {
  const _Timeline({required this.model});
  final Model model;

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 900;
      final headW = narrow ? 244.0 : (t.touch ? 340.0 : 324.0);
      final laneW = box.maxWidth - headW - 1;
      final diff = model.diff(model.slotA?.picks, model.slotB?.picks);
      final renderH = t.touch ? 56.0 : 48.0;
      return Column(children: [
        Container(
          height: t.bar,
          color: t.bg1,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            GenreMenu(model: model),
            const SizedBox(width: 8),
            SeedField(model: model),
            if (box.maxWidth > (t.touch ? 1000 : 760)) ...[const SizedBox(width: 12), Facts(model: model)],
            const Spacer(),
            if (box.maxWidth > (t.touch ? 1200 : 1000)) ...[DirtyNote(model: model), const SizedBox(width: 12)],
            LiveBtn(model: model),
            const SizedBox(width: 8),
            RenderBtn(model: model),
          ]),
        ),
        const Hr(),
        Expanded(
          child: Stack(children: [
            Column(children: [
              // Ruler. A tap moves the playhead.
              Container(
                height: t.touch ? 36 : 28,
                color: t.bg1,
                child: Row(children: [
                  SizedBox(
                    width: headW,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Row(children: [
                        SizedBox(width: t.touch ? 92 : 84, child: const Label('Part')),
                        const Expanded(child: Label('Sound pick')),
                        Text('$totalBars bars', style: t.cap),
                      ]),
                    ),
                  ),
                  const Vr(),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => model.seek(d.localPosition.dx / laneW),
                      child: const SectionRuler(height: 28),
                    ),
                  ),
                ]),
              ),
              const Hr(),
              Expanded(
                // Rows grow to use a tall window (up to 1.6x), and scroll in a short one.
                child: LayoutBuilder(builder: (context, list) {
                  final parts = model.slots.where((s) => s.lane == null).length;
                  final lanes = model.slots.length - parts;
                  final base = t.touch ? 48.0 : 32.0;
                  final unit = ((list.maxHeight - 8) / (lanes + 1.4 * parts)).clamp(base, base * 1.6);
                  return ListView(children: [
                    for (final s in model.slots) _row(context, s, headW, s.lane == null ? unit * 1.4 : unit),
                  ]);
                }),
              ),
              const Hr(),
              // The renders: rows of the same timeline.
              Container(
                color: t.bg1,
                height: t.touch ? 48 : 34,
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(children: [
                  const Label('Renders'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      diff.isEmpty
                          ? 'A and B use the same Sound picks'
                          : '${diff.first.key}: ${splitName(model.slotA!.picks[diff.first.key]!).$2} in A, ${splitName(model.slotB!.picks[diff.first.key]!).$2} in B${diff.length > 1 ? ', +${diff.length - 1} more' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.small,
                    ),
                  ),
                  Text(clock(model.position, model.lengthSeconds), style: t.num.copyWith(fontWeight: FontWeight.w600)),
                  Text(' / ${clock(1, model.lengthSeconds)}', style: t.numSmall.copyWith(color: t.text3)),
                  const SizedBox(width: 8),
                  Btn('Keep B as A', icon: Icons.arrow_upward_rounded, kind: BtnKind.ghost, onTap: model.slotB == null ? null : model.promote),
                ]),
              ),
              for (final ab in const ['A', 'B']) SizedBox(height: renderH, child: _renderRow(t, ab, headW, laneW)),
              const SizedBox(height: 6),
            ]),
            // One playhead through the Parts and the renders.
            Positioned(
              left: headW + 1 + model.position * laneW - 0.75,
              top: 0,
              bottom: 6,
              child: IgnorePointer(child: Container(width: 1.5, color: t.text.withValues(alpha: 0.9))),
            ),
          ]),
        ),
      ]);
    });
  }

  Widget _row(BuildContext context, Slot s, double headW, double h) {
    final t = Tk.of(context);
    final sel = model.selectedSlot == s.key;
    final pick = model.picks[s.key]!;
    final isPart = s.lane == null;
    final first = model.slots.indexOf(s) == 0 || model.slots[model.slots.indexOf(s) - 1].part != s.part;
    return Hover(
      onTap: () {
        model.selectSlot(s.key);
        if (t.touch) model.audition(pick);
      },
      onDoubleTap: t.touch
          ? null
          : () {
              model.selectSlot(s.key);
              model.setPicker(true);
            },
      builder: (_, hov) => Container(
        height: h,
        decoration: BoxDecoration(
          color: sel ? t.accentSoft : (hov ? t.bg1 : null),
          border: Border(top: BorderSide(color: first ? t.line : Colors.transparent)),
        ),
        child: Row(children: [
          Container(width: 2, color: sel ? t.accent : Colors.transparent),
          SizedBox(
            width: headW - 2,
            child: Padding(
              padding: EdgeInsets.only(left: 14, right: t.touch ? 0 : 6),
              child: Row(children: [
                SizedBox(
                  width: t.touch ? 92 : 84,
                  child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: isPart ? t.bodyM : t.body.copyWith(color: t.text2)),
                ),
                Expanded(child: SoundName(pick, number: false, style: sel || isPart ? t.bodyM : t.body)),
                if (s.entry(pick) == null) ...[const SizedBox(width: 4), const Tag('off palette')],
                Opacity(
                  opacity: hov || sel || t.touch ? 1 : 0,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!t.touch) IconBtn(Icons.play_arrow_rounded, size: 26, tooltip: 'Audition', onTap: () => model.audition(pick)),
                    IconBtn(
                      Icons.unfold_more_rounded,
                      size: 26,
                      tooltip: 'Change the sound  (↵)',
                      onTap: () {
                        model.selectSlot(s.key);
                        model.setPicker(true);
                      },
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const Vr(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: (h * 0.16).clamp(5.0, 10.0)),
              child: CustomPaint(painter: _ClipPainter(s, model.seed, sel ? t.accent : t.text2, t), size: Size.infinite),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _renderRow(Tk t, String ab, double headW, double laneW) {
    final r = ab == 'A' ? model.slotA : model.slotB;
    final on = model.ab == ab;
    return Hover(
      onTap: r == null ? null : () => model.setAB(ab),
      builder: (_, h) => Container(
        color: on ? t.accentSoft : (h ? t.bg1 : null),
        child: Row(children: [
          Container(width: 2, color: on ? t.accent : Colors.transparent),
          SizedBox(
            width: headW - 2,
            child: Padding(
              padding: EdgeInsets.only(left: 14, right: t.touch ? 0 : 6),
              child: Row(children: [
                ABBadge(ab, on: on, size: t.touch ? 28 : 22),
                const SizedBox(width: 10),
                Expanded(
                  child: r == null
                      ? Text('Empty. Render to fill', style: t.small.copyWith(color: t.text3))
                      : Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Render ${r.id}', style: t.bodyM.copyWith(color: on ? t.text : t.text2)),
                            TextSpan(text: '   seed ${r.seed}', style: t.numSmall.copyWith(color: t.text3, fontSize: 11.5)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (r != null) ...[
                  IconBtn(
                    on && model.playing != null ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 26,
                    tooltip: 'Play $ab',
                    active: on,
                    onTap: () => on && model.playing != null ? model.play(null) : model.play(r),
                  ),
                  if (!t.touch) IconBtn(Icons.download_rounded, size: 26, tooltip: 'Save the WAV', onTap: () {}),
                ],
              ]),
            ),
          ),
          const Vr(),
          Expanded(
            child: r == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // A tap moves the playhead and lights this render. No drag.
                    onTapDown: (d) {
                      model.seek(d.localPosition.dx / laneW);
                      model.setAB(ab);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wave(
                        seed: r.waveSeed,
                        progress: on ? model.position : null,
                        color: on ? t.accent : t.text3.withValues(alpha: 0.5),
                        rest: t.accent.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// What one Part or lane plays over the 32 bars: a clip per Section it plays in, with its hits or
/// notes inside. The patterns are made up, but they follow the Seed, like the Generator's would.
class _ClipPainter extends CustomPainter {
  _ClipPainter(this.slot, this.seed, this.color, this.t);
  final Slot slot;
  final int seed;
  final Color color;
  final Tk t;

  /// The Sections (by index) the slot plays in, and its hits per bar.
  (Set<int>, int) get _plan => switch (slot.name) {
        'Kick' => ({0, 1, 2, 3, 5}, 4),
        'Snare' => ({1, 2, 3}, 2),
        'Rim' => ({1, 4}, 3),
        'Closed hat' => ({1, 2, 3, 5}, 8),
        'Open hat' => ({1, 3}, 4),
        'Crash' => ({1, 3}, 0),
        'Tom' => ({2}, 6),
        'Riser' => ({2}, 0),
        'Fall' => ({4}, 0),
        'Impact' => ({3}, 0),
        _ => (roles[slot.part] == 'Pad' ? {0, 1, 2, 3, 4, 5} : (roles[slot.part] == 'Bass' ? {1, 2, 3, 5} : {1, 3, 4}), 8),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final (active, perBar) = _plan;
    final r = Random(seed * 13 + slot.key.length * 101);
    final clip = Paint()..color = color.withValues(alpha: t.dark ? 0.10 : 0.09);
    final ink = Paint()..color = color.withValues(alpha: 0.85);
    final melodic = slot.lane == null;
    final pad = roles[slot.part] == 'Pad';
    var start = 0;
    for (var i = 0; i < sections.length; i++) {
      final bars = sections[i].$2;
      final x0 = start / totalBars * size.width + 1.5;
      final w = bars / totalBars * size.width - 3;
      final barW = w / bars;
      start += bars;
      if (!active.contains(i)) continue;
      // One-shot lanes: a hit where the Section starts, or a ramp into its end.
      if (perBar == 0) {
        if (slot.name == 'Riser') {
          final path = Path()
            ..moveTo(x0 + w * 0.25, size.height)
            ..lineTo(x0 + w, size.height)
            ..lineTo(x0 + w, 1)
            ..close();
          canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.35));
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + w - 2.5, 0, 2.5, size.height), const Radius.circular(1.25)), ink);
        } else {
          // A hit and its tail: long for the Fall, short for a Crash or an Impact.
          final len = slot.name == 'Fall' ? barW * 2.5 : barW * 1.2;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x0, size.height / 2 - 1.5, len, 3), const Radius.circular(1.5)),
            Paint()..color = color.withValues(alpha: 0.35),
          );
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0, 0, 2.5, size.height), const Radius.circular(1.25)), ink);
        }
        continue;
      }
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0, 0, w, size.height), const Radius.circular(3)), clip);
      if (pad) {
        // Long notes, a chord change every two bars.
        for (var b = 0; b < bars; b += 2) {
          final y = 3 + r.nextInt(3) * (size.height - 9) / 3;
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + b * barW + 2, y, barW * 2 - 4, 3), const Radius.circular(1.5)), ink);
        }
      } else if (melodic) {
        // A piano roll: one dash per step that plays, at one of six heights.
        for (var b = 0; b < bars; b++) {
          final rr = Random(seed + slot.key.length + b % 2); // the two-bar Pattern repeats
          for (var st = 0; st < perBar; st++) {
            if (rr.nextDouble() < 0.28) continue;
            final y = 2 + rr.nextInt(6) * (size.height - 7) / 5;
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + (b + st / perBar) * barW + 0.5, y, max(3.0, barW / perBar - 1.5), 3), const Radius.circular(1.5)), ink);
          }
        }
      } else {
        // A drum lane: a tick per hit. The Tom rolls denser towards the end of the Build.
        for (var b = 0; b < bars; b++) {
          var n = slot.name == 'Tom' ? (b < bars - 2 ? 0 : perBar + b * 2) : perBar;
          while (n > 1 && barW / n < 4.5) {
            n = n ~/ 2; // fewer ticks when the lane is narrow, so they stay ticks
          }
          for (var st = 0; st < n; st++) {
            final off = slot.name == 'Snare' || slot.name == 'Open hat' ? 0.5 / n : 0.0;
            final x = x0 + (b + st / n + off) * barW;
            final tall = st % 2 == 0 || perBar <= 4;
            final hh = tall ? size.height - 6 : (size.height - 6) * 0.55;
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, (size.height - hh) / 2, 1.5, hh), const Radius.circular(0.75)), ink);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ClipPainter o) => o.slot != slot || o.seed != seed || o.color != color;
}

// ---------------------------------------------------------------------------------------------
// Setup: the 16 MIDI channels as a list

class _Channels extends StatelessWidget {
  const _Channels({required this.model});
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
      Container(
        height: 28,
        padding: const EdgeInsets.only(left: 18, right: 16),
        child: Row(children: [
          const SizedBox(width: 44, child: Label('Ch')),
          const Expanded(flex: 3, child: Label('Preset')),
          const SizedBox(width: 72, child: Label('Kind')),
          const SizedBox(width: 70, child: Label('Voices')),
          const Spacer(flex: 4),
          SizedBox(width: t.touch ? 96 : 84),
        ]),
      ),
      const Hr(),
      Expanded(child: ListView(children: [for (final c in model.channels) _row(t, c)])),
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
              Text('Tap a key, or play ${model.midiIn}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => MiniKeys(
                height: t.touch ? 96 : 80,
                octaves: box.maxWidth > 1000 ? 5 : (box.maxWidth > 700 ? 4 : 3),
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

  Widget _row(Tk t, ChannelSlot c) {
    final sel = model.selectedChannel == c.channel;
    final s = c.sound;
    void change() {
      model.selectChannel(c.channel);
      model.setPicker(true);
    }

    return Hover(
      onTap: () {
        model.selectChannel(c.channel);
        if (t.touch && s != null) model.audition(s, channel: c.channel);
      },
      onDoubleTap: t.touch ? null : change,
      builder: (_, h) => Container(
        height: t.row,
        color: sel ? t.accentSoft : (h ? t.bg1 : null),
        child: Row(children: [
          Container(width: 2, color: sel ? t.accent : Colors.transparent),
          const SizedBox(width: 16),
          SizedBox(width: 44, child: Text(c.channel.toString().padLeft(2, '0'), style: t.num.copyWith(fontWeight: FontWeight.w500, color: sel ? t.text : t.text3))),
          Expanded(
            flex: 3,
            child: s == null
                ? Text('Empty', style: t.body.copyWith(color: t.text3))
                : SoundName(s, style: sel ? t.bodyM : t.body),
          ),
          SizedBox(width: 72, child: s == null ? null : Align(alignment: Alignment.centerLeft, child: Tag(soundKind(s)))),
          SizedBox(width: 70, child: s == null ? null : Align(alignment: Alignment.centerLeft, child: Meter(value: c.voices, max: 4, segments: 8))),
          const Spacer(flex: 4),
          SizedBox(
            width: t.touch ? 96 : 84,
            child: Opacity(
              opacity: h || sel || t.touch ? 1 : 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (!t.touch && s != null) IconBtn(Icons.play_arrow_rounded, size: 26, tooltip: 'Audition', onTap: () => model.audition(s, channel: c.channel)),
                IconBtn(s == null ? Icons.add_rounded : Icons.unfold_more_rounded, size: 26, tooltip: s == null ? 'Pick a preset  (↵)' : 'Change the preset  (↵)', onTap: change),
                if (s != null) IconBtn(Icons.close_rounded, size: 26, tooltip: 'Clear the channel', onTap: () => model.assign(c.channel, null)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// The palette: one searchable list of sounds and actions, over the screen

class _Item {
  _Item(this.section, {this.sound, this.entry, this.action, this.icon, this.run});
  final String section;
  final String? sound;
  final Entry? entry;
  final String? action;
  final IconData? icon;
  final VoidCallback? run;
}

class _Palette extends StatefulWidget {
  const _Palette({required this.model});
  final Model model;
  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final search = TextEditingController();
  final scroll = ScrollController();
  int cursor = 0;

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  Model get m => widget.model;
  bool get piece => m.mode == Mode.piece;

  List<_Item> get items {
    final q = search.text.trim().toLowerCase();
    bool ok(String s) => q.isEmpty || s.toLowerCase().contains(q);
    final slot = piece ? m.selected : null;
    return [
      if (slot != null)
        for (final e in slot.palette)
          if (ok(shortName(e.sound))) _Item('Palette of ${slot.key}', sound: e.sound, entry: e),
      if (slot != null && ok('re-roll ${slot.key}')) _Item('Actions', action: 'Re-roll ${slot.key} from its palette', icon: Icons.casino_outlined, run: () => m.reroll(slot)),
      if (piece && ok('render')) _Item('Actions', action: 'Render ${m.lengthSeconds} s', icon: Icons.graphic_eq_rounded, run: m.render),
      if (piece && ok('new seed')) _Item('Actions', action: 'New seed', icon: Icons.tag_rounded, run: m.rollSeed),
      if (piece && q.isNotEmpty)
        for (final g in genres.keys)
          if (g != m.genre && ok('genre $g')) _Item('Actions', action: 'Genre: $g', icon: Icons.album_outlined, run: () => m.setGenre(g)),
      if (slot == null || slot.isSynth)
        for (final p in presetPaths(kits: false, query: q)) _Item('Synths', sound: p),
      if (!piece)
        for (final p in presetPaths(kits: true, query: q)) _Item('Kits', sound: p),
    ];
  }

  void _choose(_Item it) {
    if (it.run != null) {
      it.run!();
    } else if (piece) {
      final s = m.selected;
      if (s != null) m.setPick(s.key, it.sound!);
      m.audition(it.sound!);
    } else {
      m.assign(m.selectedChannel, it.sound);
      m.audition(it.sound!);
    }
    m.setPicker(false);
  }

  void _step(int d, List<_Item> list) {
    if (list.isEmpty) return;
    setState(() => cursor = (cursor + d).clamp(0, list.length - 1));
    final it = list[cursor];
    if (it.sound != null) m.audition(it.sound!); // moving through the list plays each sound
  }

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final list = items;
    if (cursor >= list.length) cursor = list.isEmpty ? 0 : list.length - 1;
    final current = piece ? m.picks[m.selectedSlot] : m.channel.sound;
    final target = piece ? (m.selected?.key ?? 'the Piece') : 'Channel ${m.selectedChannel}';
    final size = MediaQuery.sizeOf(context);
    final rowH = t.touch ? 48.0 : 32.0;

    final rows = <Widget>[];
    String? section;
    for (var i = 0; i < list.length; i++) {
      final it = list[i];
      if (it.section != section) {
        section = it.section;
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(16, rows.isEmpty ? 8 : 14, 16, 4),
          child: Row(children: [
            Label(section),
            const SizedBox(width: 8),
            if (it.entry != null) Text('share of re-rolls', style: t.cap),
          ]),
        ));
      }
      if (it.sound != null) {
        rows.add(PresetRow(
          path: it.sound!,
          model: m,
          height: rowH,
          padding: 16,
          current: it.sound == current,
          cursor: i == cursor && !t.touch,
          onTap: () => _choose(it),
          trailing: it.entry == null ? null : WeightBar(weight: it.entry!.weight, total: m.selected!.total, on: it.sound == current, width: 64),
        ));
      } else {
        rows.add(Hover(
          onTap: () => _choose(it),
          builder: (_, h) => Container(
            height: rowH,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: h || (i == cursor && !t.touch) ? t.bg2 : null, borderRadius: BorderRadius.circular(5)),
            child: Row(children: [
              Icon(it.icon, size: t.touch ? 18 : 15, color: t.text2),
              const SizedBox(width: 10),
              Expanded(child: Text(it.action!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body)),
            ]),
          ),
        ));
      }
    }

    return Keys(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => m.setPicker(false),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _step(1, list),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _step(-1, list),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (list.isNotEmpty) _choose(list[cursor]);
        },
      },
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => m.setPicker(false),
            child: Container(color: Colors.black.withValues(alpha: t.dark ? 0.5 : 0.25)),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: EdgeInsets.only(top: size.height < 760 ? 56 : 96, left: 16, right: 16),
            constraints: BoxConstraints(maxWidth: 620, maxHeight: min(580, size.height - (size.height < 760 ? 100 : 200))),
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.lineStrong),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: t.dark ? 0.5 : 0.18), blurRadius: 40, offset: const Offset(0, 16))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: SearchField(
                    controller: search,
                    hint: 'Sound for $target, or an action',
                    autofocus: !t.touch, // on a tablet, don't raise the keyboard until the field is tapped
                    bare: true,
                    height: 52,
                    onChanged: (_) => setState(() => cursor = 0),
                  ),
                ),
                Tag(target, accent: true),
                const SizedBox(width: 8),
                IconBtn(Icons.close_rounded, tooltip: 'Close  (Esc)', onTap: () => m.setPicker(false)),
                const SizedBox(width: 8),
              ]),
              const Hr(),
              Flexible(
                child: list.isEmpty
                    ? Padding(padding: const EdgeInsets.all(24), child: Text('Nothing matches "${search.text}".', style: t.small))
                    : ListView(controller: scroll, shrinkWrap: true, padding: const EdgeInsets.only(bottom: 8), children: rows),
              ),
              if (!t.touch) ...[
                const Hr(),
                Container(
                  height: 34,
                  color: t.bg2,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Kbd('↑↓'),
                    const SizedBox(width: 6),
                    Text('move and hear', style: t.cap),
                    const SizedBox(width: 16),
                    const Kbd('↵'),
                    const SizedBox(width: 6),
                    Text('pick', style: t.cap),
                    const SizedBox(width: 16),
                    const Kbd('Esc'),
                    const SizedBox(width: 6),
                    Text('close', style: t.cap),
                    const Spacer(),
                    Text('${list.length} results', style: t.cap),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
