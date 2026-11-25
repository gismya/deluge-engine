// PROTOTYPE — throwaway. The picker: the one way to change a sound, on both Piece tabs and in Setup.
// For a Part or lane it shows the Palette as pads (tap to pick and hear), then every preset. In
// Setup it fills the selected MIDI channel. Closed, it folds to a rail (or a bar in portrait) that
// still names the selected row and its sound.

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'ui.dart';

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

/// Selects [slot] and opens the picker on it.
void changeSound(Model model, Slot slot) {
  model.selectSlot(slot.key);
  model.setPicker(true);
}

class Picker extends StatefulWidget {
  const Picker({super.key, required this.model, this.narrow = false});
  final Model model;
  final bool narrow; // under the main area, not beside it
  @override
  State<Picker> createState() => _PickerState();
}

class _PickerState extends State<Picker> {
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
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Label(piece ? (slot == null ? 'Nothing selected' : '${slot.key}  ·  ${roles[slot.part]}  ·  pick for B') : 'Channel ${m.selectedChannel}  ·  ${soundKind(current)}'),
                  const SizedBox(height: 4),
                  current == null ? Text('Empty', style: t.title.copyWith(color: t.text3)) : SoundName(current, style: t.title),
                ]),
              ),
              IconBtn(Icons.play_arrow_rounded, filled: true, tooltip: 'Audition', onTap: current == null ? null : () => m.audition(current)),
              if (piece) IconBtn(Icons.close_rounded, tooltip: 'Close the picker  (Esc)', onTap: () => m.setPicker(false)),
              if (!piece) IconBtn(Icons.backspace_outlined, tooltip: 'Clear the channel', onTap: current == null ? null : () => m.assign(m.selectedChannel, null)),
            ]),
          ),
          if (slot != null) ...[
            const Hr(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Label('Palette'),
                  const SizedBox(width: 8),
                  Expanded(child: Text('share of re-rolls', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap)),
                  Btn('Re-roll', icon: Icons.casino_outlined, tooltip: 'Re-roll from the palette  (R)', onTap: () => pick(m, slot, null)),
                ]),
                const SizedBox(height: 4),
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
                    for (final p in all) PresetRow(path: p, model: m, current: p == current, onTap: () => choose(p)),
                    if (all.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Nothing matches "${search.text}".', style: t.small)),
                  ]),
          ),
          if (!widget.narrow && MediaQuery.sizeOf(context).height >= 760) ...[
            const Hr(),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.tune_rounded, size: 18, color: t.text3),
                const SizedBox(width: 8),
                Expanded(child: Text('Edit this sound', style: t.small.copyWith(color: t.text3))),
                const Tag('v2'),
              ]),
            ),
          ],
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
        height: 84,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: on ? t.accentSoft : (h ? t.bg3 : t.bg2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? t.accent : (h ? t.lineStrong : t.line)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyM)),
            if (playing) Icon(Icons.volume_up_rounded, size: 16, color: t.accent) else if (on) Icon(Icons.check_rounded, size: 16, color: t.accent),
          ]),
          Text(n ?? soundKind(e.sound), style: t.numSmall.copyWith(fontSize: 12, color: t.text3)),
          const Spacer(),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: e.weight / slot.total, minHeight: 4, backgroundColor: t.lineStrong, color: on ? t.accent : t.text3),
              ),
            ),
            const SizedBox(width: 8),
            Text('${(100 * e.weight / slot.total).round()}%', style: t.numSmall.copyWith(fontSize: 12, color: on ? t.text : t.text3)),
          ]),
        ]),
      ),
    );
  }
}

/// The picker, closed: the whole strip is one button that opens it. A rail on the right of a wide
/// window, a bar along the bottom of a narrow one.
class PickerClosed extends StatelessWidget {
  const PickerClosed({super.key, required this.model, this.narrow = false});
  final Model model;
  final bool narrow;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final slot = model.selected;
    final sound = model.picks[model.selectedSlot];
    final part = Label(slot == null ? 'Nothing selected' : slot.key, color: t.text2);
    final name = sound == null ? const SizedBox.shrink() : SoundName(sound, number: false, style: t.bodyM);
    return Hover(
      tooltip: 'Open the picker  (↵)',
      onTap: () => model.setPicker(true),
      builder: (_, h) => Container(
        width: narrow ? null : 64,
        height: narrow ? 64 : null,
        color: h ? t.bg2 : t.bg1,
        child: narrow
            ? Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(children: [
                  part,
                  const SizedBox(width: 10),
                  Expanded(child: name),
                  const SizedBox(width: 12),
                  Btn('Change sound', icon: Icons.keyboard_arrow_up_rounded, onTap: () => model.setPicker(true)),
                  const SizedBox(width: 8),
                ]),
              )
            : Column(children: [
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: t.bg2, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.lineStrong.withValues(alpha: 0.7))),
                  child: Icon(Icons.library_music_outlined, size: 22, color: t.text),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Row(children: [Text('Change sound', style: t.bodyM.copyWith(color: t.text2)), const SizedBox(width: 16), part, const SizedBox(width: 10), Flexible(child: name)]),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
      ),
    );
  }
}
