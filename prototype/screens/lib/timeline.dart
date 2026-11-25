// PROTOTYPE — throwaway. The Piece's Timeline tab: the Piece drawn as what the Generator plays.
//
// - One row per Part or lane, its Sound pick on the left, and on the right what it plays across the
//   Sections (Intro, Groove, Build, Drop, Break, Outro), so you see where a sound matters before you
//   judge it.
// - The renders are rows of the same timeline, under the Parts and on the same time axis, with the
//   one playhead through everything. A/B is "which waveform row is lit".
// - A tap on a row selects it and plays its sound. Its button opens the picker on it, the same
//   picker the Compare tab uses.

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'picker.dart';
import 'ui.dart';

const _renderRowH = 60.0;
const _rendersH = 2 * _renderRowH + 6; // the two render rows and the gap under them

class TimelineTab extends StatelessWidget {
  const TimelineTab({super.key, required this.model});
  final Model model;

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 900;
      final headW = narrow ? (model.pickerOpen ? 264.0 : 304.0) : 344.0; // closed, each row has a button
      final nameW = narrow ? 88.0 : 100.0;
      final laneW = box.maxWidth - headW - 1;
      final diff = model.diff(model.slotA?.picks, model.slotB?.picks);
      return Stack(children: [
        Column(children: [
          // Ruler. A tap moves the playhead.
          Container(
            height: 48,
            color: t.bg1,
            child: Row(children: [
              SizedBox(
                width: headW,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: Row(children: [
                    SizedBox(width: nameW, child: const Label('Part')),
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
                  child: const SectionRuler(height: 48),
                ),
              ),
            ]),
          ),
          const Hr(),
          Expanded(
            // Rows grow to use a tall window (up to 1.5x), and scroll in a short one.
            child: LayoutBuilder(builder: (context, list) {
              final parts = model.slots.where((s) => s.lane == null).length;
              final lanes = model.slots.length - parts;
              final unit = ((list.maxHeight - 8) / (lanes + 1.4 * parts)).clamp(t.row, t.row * 1.5);
              return ListView(children: [
                for (final s in model.slots) _row(context, s, headW, nameW, s.lane == null ? unit * 1.4 : unit),
              ]);
            }),
          ),
          const Hr(),
          // The renders: rows of the same timeline.
          Container(
            color: t.bg1,
            height: 52,
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
              const SizedBox(width: 12),
              Text(clock(model.position, model.lengthSeconds), style: t.title.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              Text(' / ${clock(1, model.lengthSeconds)}', style: t.numSmall.copyWith(color: t.text3)),
              const SizedBox(width: 8),
              Btn('Keep B as A', icon: Icons.arrow_upward_rounded, kind: BtnKind.ghost, tooltip: 'Make B the new reference', onTap: model.slotB == null ? null : model.promote),
            ]),
          ),
          for (final ab in const ['A', 'B']) SizedBox(height: _renderRowH, child: _renderRow(t, ab, headW, laneW)),
          const SizedBox(height: 6),
        ]),
        // One playhead through the Parts and the renders. It skips the strip between them.
        for (final (top, bottom) in const [(0.0, _rendersH + 53), (null, 6.0)])
          Positioned(
            left: headW + 1 + model.position * laneW - 1,
            top: top,
            bottom: bottom,
            height: top == null ? _rendersH - 6 : null,
            child: IgnorePointer(child: Container(width: 2, color: t.text.withValues(alpha: 0.9))),
          ),
      ]);
    });
  }

  Widget _row(BuildContext context, Slot s, double headW, double nameW, double h) {
    final t = Tk.of(context);
    final sel = model.selectedSlot == s.key;
    final sound = model.picks[s.key]!;
    final isPart = s.lane == null;
    final i = model.slots.indexOf(s);
    final first = i == 0 || model.slots[i - 1].part != s.part;
    return Hover(
      onTap: () {
        model.selectSlot(s.key);
        model.audition(sound);
      },
      builder: (_, hov) => Container(
        height: h,
        decoration: BoxDecoration(
          color: sel ? t.accentSoft : (hov ? t.bg1 : null),
          border: Border(top: BorderSide(color: first ? t.line : Colors.transparent)),
        ),
        child: Row(children: [
          Container(width: 3, color: sel ? t.accent : Colors.transparent),
          SizedBox(
            width: headW - 3,
            child: Padding(
              padding: EdgeInsets.only(left: 13, right: model.pickerOpen ? 12 : 4),
              child: Row(children: [
                SizedBox(
                  width: nameW,
                  child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: isPart ? t.bodyM : t.body.copyWith(color: t.text2)),
                ),
                Expanded(child: SoundName(sound, number: false, style: sel || isPart ? t.bodyM : t.body)),
                if (s.entry(sound) == null) ...[const SizedBox(width: 4), const Tag('off palette')],
                // With the picker open a tap on the row already retargets it.
                if (!model.pickerOpen) IconBtn(Icons.unfold_more_rounded, tooltip: 'Change the sound  (↵)', onTap: () => changeSound(model, s)),
              ]),
            ),
          ),
          const Vr(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: (h * 0.18).clamp(6.0, 12.0)),
              child: CustomPaint(painter: _ClipPainter(s, model.seed, sel ? t.accent : t.text2), size: Size.infinite),
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
          Container(width: 3, color: on ? t.accent : Colors.transparent),
          SizedBox(
            width: headW - 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 13, right: 4),
              child: Row(children: [
                ABBadge(ab, on: on, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: r == null
                      ? Text('Empty. Render to fill', style: t.small.copyWith(color: t.text3))
                      : Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Render ${r.id}', style: t.bodyM.copyWith(color: on ? t.text : t.text2)),
                            TextSpan(text: '   seed ${r.seed}', style: t.numSmall.copyWith(color: t.text3)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (r != null)
                  IconBtn(
                    on && model.playing != null ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    filled: true,
                    tooltip: 'Play $ab',
                    active: on,
                    onTap: () => on && model.playing != null ? model.play(null) : model.play(r),
                  ),
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
                      padding: const EdgeInsets.symmetric(vertical: 7),
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
  _ClipPainter(this.slot, this.seed, this.color);
  final Slot slot;
  final int seed;
  final Color color;

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
    final clip = Paint()..color = color.withValues(alpha: 0.10);
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
