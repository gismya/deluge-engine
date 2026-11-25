// PROTOTYPE — throwaway. The Piece's Compare tab: the A/B bench.
//
// - A is the reference render, B the candidate you are working on.
// - Top: both waveforms on one time axis, A drawn upwards and B downwards from the Section ruler,
//   with the one playhead. The A and B keys beside them switch which one you hear.
// - Under it: the Piece as a diff table. One row per Part or lane, A's Sound pick beside B's. Rows
//   that differ are tinted; tapping A's cell copies its pick back to B.

import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'picker.dart';
import 'ui.dart';

class CompareTab extends StatelessWidget {
  const CompareTab({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => Column(children: [
          _Hero(model: model, narrow: box.maxWidth < 900),
          const Hr(),
          Expanded(child: _DiffTable(model: model, width: box.maxWidth)),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------
// Hero: the two renders on one time axis

class _Hero extends StatelessWidget {
  const _Hero({required this.model, required this.narrow});
  final Model model;
  final bool narrow;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final tall = MediaQuery.sizeOf(context).height >= 800;
    final playing = model.playing != null;
    return Container(
      height: tall ? 216 : 176,
      color: t.bg1,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: narrow ? 152 : 176,
          child: Column(children: [
            Expanded(child: _key('A', model.slotA, 'Reference', t)),
            const SizedBox(height: 8),
            Expanded(child: _key('B', model.slotB, model.rendering ? 'Rendering…' : (model.dirty ? 'Out of date' : 'Candidate'), t)),
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: h ? Color.lerp(t.accent, Colors.white, 0.12) : t.accent, shape: BoxShape.circle),
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36, color: t.onAccent),
              ),
            ),
            const SizedBox(height: 8),
            Text(clock(model.position, model.lengthSeconds), style: t.display.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            Text('of ${clock(1, model.lengthSeconds)}', style: t.cap),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? t.accentLine : t.line),
        ),
        child: Row(children: [
          ABBadge(ab, on: on, size: 36),
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

        // A tap moves the playhead and switches to the render under the finger. No drag.
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
              const SectionRuler(height: 22),
              const SizedBox(height: 3),
              Expanded(child: wave('B', model.slotB, WaveAlign.down)),
            ]),
            Positioned(left: x - 1, top: 0, bottom: 0, child: Container(width: 2, color: t.text)),
          ]),
        );
      });
}

// ---------------------------------------------------------------------------------------------
// The Piece as a diff of A against B

class _DiffTable extends StatelessWidget {
  const _DiffTable({required this.model, required this.width});
  final Model model;
  final double width;
  bool get narrow => width < 900;
  double get _nameW => narrow ? 104 : 136;

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final a = model.slotA;
    final diff = model.diff(a?.picks, model.picks);
    final rows = <Widget>[];
    String? part;
    for (final s in model.slots) {
      final group = s.lane == null ? 'PARTS' : s.part;
      if (group != part) {
        part = group;
        rows.add(Container(
          height: 32,
          padding: const EdgeInsets.only(left: 16, top: 10),
          alignment: Alignment.centerLeft,
          child: Row(children: [Label(group), const SizedBox(width: 8), Text(group == 'PARTS' ? 'Synths' : 'Kit lanes', style: t.cap)]),
        ));
      }
      rows.add(_row(context, s, a));
    }
    return Column(children: [
      Container(
        height: 56,
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
              if (width >= 1000) Btn('Revert to A', kind: BtnKind.ghost, tooltip: 'Put B\'s Sound picks back to A\'s', onTap: diff.isEmpty ? null : model.revertToA),
              Btn(width >= 1000 ? 'Keep B as A' : 'Keep B', icon: Icons.arrow_back_rounded, kind: BtnKind.ghost, tooltip: 'Make B the new reference', onTap: model.slotB == null ? null : model.promote),
            ]),
          ),
        ]),
      ),
      const Hr(),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 12), children: rows)),
    ]);
  }

  Widget _colHead(Tk t, String ab, String title, String note, {bool on = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        ABBadge(ab, on: model.ab == ab, size: 22),
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
      // A tap selects the row and plays its sound.
      onTap: () {
        model.selectSlot(s.key);
        model.audition(mine);
      },
      builder: (_, h) => Container(
        height: t.row,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(color: sel ? t.bg2 : (h ? t.bg1 : null), borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: _nameW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: s.lane == null ? t.bodyM : t.body.copyWith(color: t.text2)),
            ),
          ),
          Expanded(
            child: theirs == null
                ? Align(alignment: Alignment.centerLeft, child: Text('—', style: t.body.copyWith(color: t.text3)))
                // The whole cell is the target, and the arrow says what a tap does.
                : Hover(
                    onTap: differs ? () => pick(model, s, theirs) : null,
                    tooltip: differs ? 'Use A\'s pick in B' : null,
                    builder: (_, h2) => Row(children: [
                      Flexible(child: SoundName(theirs, number: !narrow, style: t.body.copyWith(color: differs ? t.text : t.text2))),
                      if (differs) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: h2 ? t.bg3 : t.bg0, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.lineStrong.withValues(alpha: 0.7))),
                          child: Icon(Icons.arrow_forward_rounded, size: 18, color: t.text),
                        ),
                      ],
                      const SizedBox(width: 12),
                    ]),
                  ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 10),
              margin: const EdgeInsets.only(top: 2, bottom: 2, right: 2),
              decoration: BoxDecoration(
                color: differs ? t.accentSoft : null,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: sel ? t.accentLine : Colors.transparent),
              ),
              child: Row(children: [
                Expanded(child: SoundName(mine, number: !narrow, style: (differs || sel ? t.bodyM : t.body).copyWith(color: differs ? t.accent : (sel ? t.text : t.text2)))),
                PaletteMark(slot: s, sound: mine, on: sel, bar: false),
                IconBtn(Icons.casino_outlined, tooltip: 'Re-roll from the palette  (R)', onTap: () => pick(model, s, null)),
                if (!model.pickerOpen) IconBtn(Icons.unfold_more_rounded, tooltip: 'Change the sound  (↵)', onTap: () => changeSound(model, s)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
