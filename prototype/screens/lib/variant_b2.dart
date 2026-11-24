// PROTOTYPE — throwaway. Variant B2: Browser and strips.
//
// Design intent
// - Keeps B's idea: the preset browser is always open on the left, the middle holds strips you
//   select and then fill from the browser, and A/B stays fixed at the bottom.
// - The strips are now dense rows in hairline groups, not tall boxes. A Piece's rows are grouped by
//   Part (the Kit's lanes, the melodic Parts, the FX lanes); a Setup's rows are the 16 MIDI channels.
// - The browser says what it fills ("Fill ACID"), puts that slot's Palette first with each sound's
//   share of re-rolls, and lists every preset below. One click assigns and auditions.
// - Under the strips, an inspector for the selected strip: its sound, the actions, a keyboard to
//   audition it. This is where v2's "edit this sound" opens.
// - The A/B deck is two stacked lanes on one time axis with one playhead, so switching keeps the
//   position. Its header says which picks differ between A and B.
// - Touch (a tablet): rows are 48 dp, a tap on a strip selects it and plays it, and every action has a
//   button that is always there. In portrait the browser moves under the strips.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'ui.dart';

class VariantB2 extends StatelessWidget {
  const VariantB2({super.key, required this.model});
  final Model model;
  static const name = 'Browser and strips';

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final piece = model.mode == Mode.piece;
    return Keys(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): model.togglePlay,
        const SingleActivator(LogicalKeyboardKey.tab): model.toggleAB,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): model.render,
        const SingleActivator(LogicalKeyboardKey.keyL): model.toggleLive,
        const SingleActivator(LogicalKeyboardKey.keyN): model.rollSeed,
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          final s = model.selected;
          if (piece && s != null) model.reroll(s);
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          final sound = piece ? model.picks[model.selectedSlot] : model.channel.sound;
          if (sound != null) model.audition(sound);
        },
      },
      child: Material(
        color: t.bg0,
        child: Column(children: [
          TopBar(model: model, left: [ModeSeg(model: model)]),
          Expanded(
            child: RestartVeil(
              model: model,
              child: LayoutBuilder(builder: (context, box) {
                final narrow = box.maxWidth < 900;
                final bar = piece ? _PieceBar(model: model) : _SetupBar(model: model);
                final strips = piece ? _PieceStrips(model: model) : _SetupStrips(model: model);
                if (narrow) {
                  return Column(children: [
                    bar,
                    const Hr(),
                    Expanded(flex: 5, child: strips),
                    const Hr(),
                    Expanded(flex: 4, child: _Browser(model: model)),
                  ]);
                }
                return Row(children: [
                  SizedBox(width: _side(t), child: _Browser(model: model)),
                  const Vr(),
                  Expanded(
                    child: Column(children: [
                      bar,
                      const Hr(),
                      Expanded(child: strips),
                      if (box.maxHeight >= (t.touch ? 860 : 560)) ...[const Hr(), _Inspector(model: model)],
                    ]),
                  ),
                ]);
              }),
            ),
          ),
          _Deck(model: model),
          StatusBar(model: model, hints: const [('Space', 'play'), ('Tab', 'A/B'), ('R', 're-roll'), ('/', 'search')]),
        ]),
      ),
    );
  }
}

/// The width of the browser, and of the transport under it.
double _side(Tk t) => t.touch ? 340 : 312;

// ---------------------------------------------------------------------------------------------
// Browser

class _Browser extends StatefulWidget {
  const _Browser({required this.model});
  final Model model;
  @override
  State<_Browser> createState() => _BrowserState();
}

class _BrowserState extends State<_Browser> {
  final search = TextEditingController();
  final focus = FocusNode();
  bool kits = false;
  String? tag;

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
    final target = piece ? (slot?.key ?? 'nothing selected') : 'Channel ${m.selectedChannel}';
    final q = search.text;
    final showKits = !piece && kits;
    final samples = slot != null && !slot.isSynth;

    void choose(String path) {
      if (piece) {
        if (slot == null) return;
        m.setPick(slot.key, path);
      } else {
        m.assign(m.selectedChannel, path);
      }
      m.audition(path);
    }

    final palette = [
      if (slot != null)
        for (final e in slot.palette)
          if (q.isEmpty || shortName(e.sound).toLowerCase().contains(q.toLowerCase())) e,
    ];
    final all = samples ? const <String>[] : presetPaths(kits: showKits, query: q, tag: showKits ? null : tag);

    return Keys(
      bindings: {const SingleActivator(LogicalKeyboardKey.slash): focus.requestFocus},
      child: Container(
        color: t.bg1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Label('Fill'),
                const SizedBox(width: 8),
                Tag(target, accent: true),
                const Spacer(),
                Text(piece ? 'Sound pick' : 'Preset', style: t.cap),
              ]),
              const SizedBox(height: 10),
              SearchField(
                controller: search,
                focusNode: focus,
                hint: samples ? 'Search the palette' : (showKits ? 'Search 43 kits' : 'Search 171 synths'),
                kbd: '/',
                onChanged: (_) => setState(() {}),
              ),
              if (!piece) ...[
                const SizedBox(height: 8),
                Seg<bool>(
                  items: const {false: 'Synths  171', true: 'Kits  43'},
                  value: kits,
                  expand: true,
                  onChanged: (v) => setState(() => kits = v),
                ),
              ],
              if (!showKits && !samples) ...[
                const SizedBox(height: 8),
                _Tags(value: tag, onChanged: (g) => setState(() => tag = g)),
              ],
            ]),
          ),
          const Hr(),
          Expanded(
            child: ListView(padding: const EdgeInsets.only(top: 4, bottom: 8), children: [
              if (palette.isNotEmpty) ...[
                _head(t, 'Palette', '${palette.length} sounds, by share of re-rolls'),
                for (final e in palette)
                  PresetRow(
                    path: e.sound,
                    model: m,
                    current: e.sound == current,
                    onTap: () => choose(e.sound),
                    trailing: WeightBar(weight: e.weight, total: slot!.total, on: e.sound == current, width: 28),
                  ),
                const SizedBox(height: 8),
                if (!samples) const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Hr()),
              ],
              if (samples)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text('A Kit lane takes any sample under SAMPLES/. The prototype lists only the palette.', style: t.cap),
                )
              else ...[
                _head(t, showKits ? 'All kits' : (tag == null ? 'All synths' : '$tag synths'), '${all.length}'),
                for (final p in all) PresetRow(path: p, model: m, current: p == current, onTap: () => choose(p)),
                if (all.isEmpty)
                  Padding(padding: const EdgeInsets.all(12), child: Text('Nothing matches "$q".', style: t.small)),
              ],
            ]),
          ),
          const Hr(),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text('${t.touch ? 'A tap' : 'A click'} fills $target and plays it', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap),
          ),
        ]),
      ),
    );
  }

  Widget _head(Tk t, String a, String b) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [Label(a), const SizedBox(width: 8), Expanded(child: Text(b, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap))]),
      );
}

// ---------------------------------------------------------------------------------------------
// Bars above the strips

/// The keyword filters: a wrapped row of chips with a mouse, one scrolling row of 48 dp chips on touch.
class _Tags extends StatelessWidget {
  const _Tags({required this.value, required this.onChanged});
  final String? value;
  final void Function(String?) onChanged;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final chips = [
      for (final g in [null, ...synthTags])
        Hover(
          onTap: () => onChanged(g),
          builder: (_, h) => hit(
            t,
            Container(
              height: t.touch ? 36 : 22,
              padding: EdgeInsets.symmetric(horizontal: t.touch ? 14 : 8, vertical: t.touch ? 9 : 3),
              decoration: BoxDecoration(
                color: value == g ? t.bg3 : (h ? t.bg2 : Colors.transparent),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: value == g ? t.lineStrong : t.line),
              ),
              child: Text(g ?? 'All', style: t.cap.copyWith(color: value == g ? t.text : t.text2)),
            ),
          ),
        ),
    ];
    if (!t.touch) return Wrap(spacing: 4, runSpacing: 4, children: chips);
    return SizedBox(
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in chips) Padding(padding: const EdgeInsets.only(right: 4), child: c)]),
    );
  }
}

class _PieceBar extends StatelessWidget {
  const _PieceBar({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => Container(
        height: Tk.of(context).bar,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, box) => Row(children: [
            GenreMenu(model: model),
            const SizedBox(width: 8),
            SeedField(model: model),
            if (box.maxWidth > (Tk.of(context).touch ? 800 : 660)) ...[const SizedBox(width: 12), Facts(model: model)],
            const Spacer(),
            if (box.maxWidth > (Tk.of(context).touch ? 1040 : 900)) ...[DirtyNote(model: model), const SizedBox(width: 12)],
            LiveBtn(model: model),
            const SizedBox(width: 8),
            RenderBtn(model: model),
          ]),
        ),
      );
}

class _SetupBar extends StatelessWidget {
  const _SetupBar({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Container(
      height: t.bar,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text('Setup', style: t.title),
        const SizedBox(width: 10),
        Flexible(child: Text('${model.channelsUsed} of 16 channels play a preset', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small)),
        const Spacer(),
        MidiPill(model: model),
        const SizedBox(width: 8),
        Btn('Clear all', kind: BtnKind.ghost, onTap: () {
          for (final c in model.channels) {
            c.sound = null;
          }
          model.assign(model.selectedChannel, null);
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Strips

class _Group extends StatelessWidget {
  const _Group({required this.title, this.tag, this.note, required this.rows});
  final String title;
  final String? tag;
  final String? note;
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Container(
      decoration: BoxDecoration(color: t.bg1, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Label(title, color: t.text2),
            if (tag != null) ...[const SizedBox(width: 8), Tag(tag!)],
            const Spacer(),
            if (note != null) Text(note!, style: t.cap),
          ]),
        ),
        for (final r in rows) ...[const Hr(), r],
      ]),
    );
  }
}

/// One strip: a row (36 px with a mouse, 48 dp on touch) with a selection bar on its left edge.
class _Strip extends StatelessWidget {
  const _Strip({required this.selected, required this.onTap, required this.builder, this.onDoubleTap});
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final List<Widget> Function(bool hovered) builder;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Hover(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      builder: (_, h) => Container(
        height: t.row,
        color: selected ? t.accentSoft : (h ? t.bg2 : null),
        child: Row(children: [
          Container(width: 2, height: t.row, color: selected ? t.accent : Colors.transparent),
          const SizedBox(width: 10),
          ...builder(h),
          const SizedBox(width: 6),
        ]),
      ),
    );
  }
}

class _SlotStrip extends StatelessWidget {
  const _SlotStrip({required this.model, required this.slot});
  final Model model;
  final Slot slot;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final pick = model.picks[slot.key]!;
    final sel = model.selectedSlot == slot.key;
    final changed = model.slotA != null && model.slotA!.picks[slot.key] != pick;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 440;
      return _Strip(
        selected: sel,
        // With a mouse a click selects and the play button auditions. On touch one tap does both.
        onTap: () {
          model.selectSlot(slot.key);
          if (t.touch) model.audition(pick);
        },
        onDoubleTap: t.touch ? null : () => model.audition(pick),
        builder: (h) => [
          SizedBox(
            width: t.touch ? 92 : (wide ? 84 : 80),
            child: Text(slot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: slot.lane == null ? t.bodyM : t.body.copyWith(color: t.text2)),
          ),
          Expanded(child: SoundName(pick, style: sel ? t.bodyM : t.body, number: wide)),
          if (changed) ...[
            const SizedBox(width: 8),
            const Tooltip(message: 'Differs from render A', child: Tag('≠ A', accent: true)),
          ],
          SizedBox(width: wide ? 10 : 2),
          PaletteMark(slot: slot, sound: pick, on: sel, bar: wide),
          const SizedBox(width: 6),
          Opacity(
            opacity: h || sel || t.touch ? 1 : 0,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconBtn(Icons.casino_outlined, size: 26, tooltip: 'Re-roll from the palette  (R)', onTap: () => model.reroll(slot)),
              if (!t.touch) IconBtn(Icons.play_arrow_rounded, size: 26, tooltip: 'Audition  (↵)', onTap: () => model.audition(pick)),
            ]),
          ),
        ],
      );
    });
  }
}

class _PieceStrips extends StatelessWidget {
  const _PieceStrips({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final drums = model.slots.where((s) => s.part == 'DRUMS').toList();
    final fx = model.slots.where((s) => s.part == 'FX').toList();
    final parts = model.slots.where((s) => s.lane == null).toList();
    final g1 = _Group(title: 'Drums', tag: 'Kit', note: '${drums.length} lanes', rows: [for (final s in drums) _SlotStrip(model: model, slot: s)]);
    final g2 = _Group(title: 'Parts', tag: 'Synths', note: '${parts.length} parts', rows: [for (final s in parts) _SlotStrip(model: model, slot: s)]);
    final g3 = _Group(title: 'FX', tag: 'Kit', note: '${fx.length} lanes', rows: [for (final s in fx) _SlotStrip(model: model, slot: s)]);
    final g4 = _Group(
      title: 'Renders',
      note: 'newest first',
      rows: [for (final r in model.renders.take(4)) _RenderStrip(model: model, r: r)],
    );
    return _Columns(left: [g1], right: [g2, g3, if (model.renders.isNotEmpty) g4]);
  }
}

class _SetupStrips extends StatelessWidget {
  const _SetupStrips({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    Widget group(int from) => _Group(
          title: 'Channels $from–${from + 7}',
          note: 'MIDI',
          rows: [for (final c in model.channels.skip(from - 1).take(8)) _ChannelStrip(model: model, c: c)],
        );
    return _Columns(left: [group(1)], right: [group(9)]);
  }
}

class _ChannelStrip extends StatelessWidget {
  const _ChannelStrip({required this.model, required this.c});
  final Model model;
  final ChannelSlot c;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final sel = model.selectedChannel == c.channel;
    final s = c.sound;
    return _Strip(
      selected: sel,
      onTap: () {
        model.selectChannel(c.channel);
        if (t.touch && s != null) model.audition(s, channel: c.channel);
      },
      onDoubleTap: s == null || t.touch ? null : () => model.audition(s, channel: c.channel),
      builder: (h) => [
        SizedBox(width: 26, child: Text(c.channel.toString().padLeft(2, '0'), style: t.num.copyWith(color: sel ? t.text : t.text3, fontWeight: FontWeight.w500))),
        Icon(soundIcon(s), size: 14, color: s == null ? t.text3.withValues(alpha: 0.6) : t.text2),
        const SizedBox(width: 8),
        Expanded(
          child: s == null
              ? Text(sel ? 'Empty. Pick a preset in the browser' : 'Empty', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: t.text3))
              : SoundName(s, style: sel ? t.bodyM : t.body),
        ),
        if (s != null) ...[
          const SizedBox(width: 8),
          Tag(soundKind(s)),
          const SizedBox(width: 10),
          Meter(value: c.voices, max: 4, segments: 6),
          const SizedBox(width: 4),
          Opacity(
            opacity: h || sel || t.touch ? 1 : 0,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!t.touch) IconBtn(Icons.play_arrow_rounded, size: 26, tooltip: 'Audition', onTap: () => model.audition(s, channel: c.channel)),
              IconBtn(Icons.close_rounded, size: 26, tooltip: 'Clear the channel', onTap: () => model.assign(c.channel, null)),
            ]),
          ),
        ],
      ],
    );
  }
}

/// One past render: what it was, and buttons to load it into A or B.
class _RenderStrip extends StatelessWidget {
  const _RenderStrip({required this.model, required this.r});
  final Model model;
  final Render r;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final i = model.renders.indexOf(r);
    final before = i + 1 < model.renders.length ? model.renders[i + 1] : null;
    final diff = before == null ? const <Slot>[] : model.diff(before.picks, r.picks);
    final what = before == null
        ? 'First render'
        : before.genre != r.genre
            ? r.genre
            : diff.isEmpty
                ? (before.seed != r.seed ? 'New seed' : 'Same picks')
                : '${diff.first.key} → ${splitName(r.picks[diff.first.key]!).$2}${diff.length > 1 ? '  +${diff.length - 1}' : ''}';
    Widget load(String ab, Render? now) => Hover(
          tooltip: 'Load into $ab',
          onTap: () => model.setSlot(ab, r),
          builder: (_, h) => hit(t, Opacity(opacity: now == r || h ? 1 : 0.55, child: ABBadge(ab, on: now == r, size: t.touch ? 28 : 20))),
        );
    return LayoutBuilder(builder: (context, box) => Container(
      height: t.row,
      padding: const EdgeInsets.only(left: 12, right: 10),
      child: Row(children: [
        SizedBox(width: 84, child: Text('Render ${r.id}', style: t.bodyM)),
        Expanded(child: Text(what, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: t.text2))),
        const SizedBox(width: 8),
        if (!t.touch && box.maxWidth >= 440) Text('seed ${r.seed}  ·  ${r.seconds} s', style: t.numSmall.copyWith(color: t.text3, fontSize: 11.5)),
        SizedBox(width: t.touch ? 4 : 12),
        load('A', model.slotA),
        SizedBox(width: t.touch ? 0 : 4),
        load('B', model.slotB),
      ]),
    ));
  }
}

/// Two columns of groups, or one when the pane is narrow.
class _Columns extends StatelessWidget {
  const _Columns({required this.left, required this.right});
  final List<Widget> left;
  final List<Widget> right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        Widget col(List<Widget> ws) => Column(mainAxisSize: MainAxisSize.min, children: [
              for (final w in ws) Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
            ]);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: box.maxWidth < 640
              ? col([...left, ...right])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: col(left)),
                  const SizedBox(width: 12),
                  Expanded(child: col(right)),
                ]),
        );
      });
}

// ---------------------------------------------------------------------------------------------
// Inspector: the selected strip

class _Inspector extends StatelessWidget {
  const _Inspector({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final piece = model.mode == Mode.piece;
    final slot = piece ? model.selected : null;
    final sound = piece ? model.picks[model.selectedSlot] : model.channel.sound;
    final head = piece
        ? (slot == null ? 'No part selected' : '${slot.key}  ·  ${roles[slot.part] ?? ''}')
        : 'Channel ${model.selectedChannel}  ·  ${soundKind(sound)}';
    final e = slot?.entry(sound);
    final sub = sound == null
        ? 'Pick a preset in the browser to play it on this channel.'
        : piece && slot != null
            ? (e != null ? '$sound  ·  from the palette, ${(100 * e.weight / slot.total).round()}% of re-rolls' : '$sound  ·  off palette, a re-roll replaces it')
            : '$sound  ·  ${model.channel.voices} voices';
    return Container(
      height: t.touch ? 156 : 116,
      color: t.bg1,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, box) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Label(head),
              const SizedBox(height: 4),
              sound == null ? Text('Empty', style: t.display.copyWith(color: t.text3)) : SoundName(sound, style: t.display),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap),
              const Spacer(),
              Row(children: [
                Btn('Audition', icon: Icons.play_arrow_rounded, kbd: '↵', onTap: sound == null ? null : () => model.audition(sound)),
                const SizedBox(width: 8),
                if (piece)
                  Btn('Re-roll', icon: Icons.casino_outlined, kbd: 'R', onTap: slot == null ? null : () => model.reroll(slot))
                else
                  Btn('Clear', icon: Icons.close_rounded, onTap: sound == null ? null : () => model.assign(model.selectedChannel, null)),
                const SizedBox(width: 8),
                const Btn('Edit sound', icon: Icons.tune_rounded, kind: BtnKind.ghost, tooltip: 'Editing a sound comes in v2'),
                const SizedBox(width: 2),
                const Tag('v2'),
              ]),
            ]),
          ),
          if (box.maxWidth > (t.touch ? 860 : 700)) ...[
            const SizedBox(width: 24),
            SizedBox(
              width: t.touch ? 392 : 300,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Label('Audition'),
                  const Spacer(),
                  Text(piece ? 'plays the pick' : 'plays channel ${model.selectedChannel}', style: t.cap),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: MiniKeys(
                    height: t.touch ? 88 : 64,
                    lit: model.auditioning != null && model.auditioning == sound ? 48 : null,
                    onNote: (_) {
                      if (sound != null) model.audition(sound);
                    },
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// A/B deck

class _Deck extends StatelessWidget {
  const _Deck({required this.model});
  final Model model;

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final a = model.slotA;
    final b = model.slotB;
    final diff = model.diff(a?.picks, b?.picks);
    final playing = model.playing != null;
    final lane = t.touch ? 52.0 : 48.0;
    final head = t.touch ? 48.0 : 34.0;
    final gutterL = narrow ? 132.0 : 196.0;
    final gutterR = t.touch ? 52.0 : 44.0;

    final play = Hover(
      onTap: model.active == null ? null : model.togglePlay,
      tooltip: 'Play or stop  (Space)',
      builder: (_, h) => Container(
        width: t.touch ? 48 : 40,
        height: t.touch ? 48 : 40,
        decoration: BoxDecoration(color: h ? Color.lerp(t.accent, Colors.white, 0.12) : t.accent, shape: BoxShape.circle),
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24, color: t.onAccent),
      ),
    );
    final time = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text.rich(
        TextSpan(children: [
          TextSpan(text: clock(model.position, model.lengthSeconds)),
          TextSpan(text: '  / ${clock(1, model.lengthSeconds)}', style: t.numSmall.copyWith(color: t.text3)),
        ]),
        style: t.display.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
      Text(playing ? 'Playing ${model.ab}' : 'Stopped on ${model.ab}', style: t.cap),
    ]);
    final seg = Seg<String>(items: const {'A': 'A', 'B': 'B'}, value: model.ab, expand: true, height: 30, onChanged: model.setAB);

    final lanes = LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth - gutterL - gutterR;
      final x = gutterL + model.position * w;
      return Stack(children: [
        Column(children: [
          SizedBox(height: lane, child: _lane('A', a, t, gutterL, gutterR, narrow)),
          SizedBox(height: lane, child: _lane('B', b, t, gutterL, gutterR, narrow)),
          Padding(padding: EdgeInsets.only(left: gutterL, right: gutterR), child: const SectionRuler(height: 20)),
        ]),
        Positioned(left: x, top: 0, height: lane * 2, child: Container(width: 1.5, color: t.text)),
        // A tap on a waveform moves the playhead and picks that lane. No drag, so nothing fights a scroll.
        Positioned(
          left: gutterL,
          width: w,
          top: 0,
          height: lane * 2,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (d) {
              model.seek(d.localPosition.dx / w);
              model.setAB(d.localPosition.dy < lane ? 'A' : 'B');
            },
          ),
        ),
      ]);
    });
    final header = SizedBox(
      height: head,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Row(children: [
          Expanded(child: _diffLine(t, diff, a, b)),
          Btn('Swap', icon: Icons.swap_vert_rounded, kind: BtnKind.ghost, onTap: b == null ? null : model.swapAB),
          Btn('Keep B as A', icon: Icons.arrow_upward_rounded, kind: BtnKind.ghost, onTap: b == null ? null : model.promote),
        ]),
      ),
    );

    final box = BoxDecoration(color: t.bg1, border: Border(top: BorderSide(color: t.line)));
    if (narrow) {
      return Container(
        decoration: box,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(children: [play, const SizedBox(width: 12), time, const Spacer(), SizedBox(width: 200, child: seg)]),
          ),
          header,
          SizedBox(height: lane * 2 + 24, child: lanes),
        ]),
      );
    }
    return Container(
      decoration: box,
      height: head + lane * 2 + 24 + 6,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: _side(t),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [Label('Compare'), Spacer(), Kbd('Tab'), SizedBox(width: 5), Kbd('Space')]),
              const Spacer(),
              Row(children: [play, const SizedBox(width: 12), time]),
              const Spacer(),
              seg,
            ]),
          ),
        ),
        const Vr(),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, Expanded(child: lanes)]),
        ),
      ]),
    );
  }

  Widget _diffLine(Tk t, List<Slot> diff, Render? a, Render? b) {
    if (a == null || b == null) return Text('Render twice to compare. The newest render lands in B.', style: t.small);
    if (diff.isEmpty) {
      return Text(a.seed == b.seed ? 'A and B use the same Sound picks.' : 'Same Sound picks, another Seed.', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small);
    }
    final s = diff.first;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: diff.length == 1 ? '1 pick differs   ' : '${diff.length} picks differ   ', style: t.small),
        TextSpan(text: '${s.key}  ', style: t.bodyM.copyWith(fontSize: t.small.fontSize)),
        TextSpan(text: splitName(a.picks[s.key]!).$2, style: t.small),
        TextSpan(text: '  →  ', style: t.small.copyWith(color: t.text3)),
        TextSpan(text: splitName(b.picks[s.key]!).$2, style: t.bodyM.copyWith(fontSize: t.small.fontSize, color: t.accent)),
        if (diff.length > 1) TextSpan(text: '   +${diff.length - 1} more', style: t.small.copyWith(color: t.text3)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _lane(String ab, Render? r, Tk t, double gutterL, double gutterR, bool narrow) {
    final on = model.ab == ab;
    return Hover(
      onTap: r == null ? null : () => model.setAB(ab),
      builder: (_, h) => Container(
        color: on ? t.accentSoft : (h ? t.bg2 : null),
        child: Row(children: [
          Container(width: 2, color: on ? t.accent : Colors.transparent),
          const SizedBox(width: 10),
          ABBadge(ab, on: on),
          const SizedBox(width: 10),
          SizedBox(
            width: gutterL - 44 - 8,
            child: r == null
                ? Text('Empty', style: t.small.copyWith(color: t.text3))
                : Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Render ${r.id}', style: t.bodyM.copyWith(fontSize: 12.5, color: on ? t.text : t.text2)),
                      if (!narrow) TextSpan(text: '   seed ${r.seed}', style: t.numSmall.copyWith(color: t.text3, fontSize: 11.5)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: r == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Wave(
                      seed: r.waveSeed,
                      progress: on ? model.position : null,
                      color: on ? t.accent : t.text3.withValues(alpha: 0.5),
                      rest: t.accent.withValues(alpha: 0.35),
                    ),
                  ),
          ),
          SizedBox(
            width: gutterR,
            child: r == null ? null : Center(child: IconBtn(Icons.download_rounded, size: 26, tooltip: 'Save the WAV', onTap: () {})),
          ),
        ]),
      ),
    );
  }
}
