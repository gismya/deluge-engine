// PROTOTYPE — throwaway. The Setup screen: the 16 MIDI channels as a 4 x 4 grid of pads, with a
// keyboard under it to audition the selected channel. The picker beside it fills that channel.

import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'ui.dart';

class SetupPads extends StatelessWidget {
  const SetupPads({super.key, required this.model});
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
          const SizedBox(width: 12),
          Expanded(child: Text('${model.channelsUsed} of 16 MIDI channels play a preset', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small)),
          const SizedBox(width: 12),
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
        height: 128,
        color: t.bg1,
        padding: const EdgeInsets.all(16),
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
            child: MiniKeys(
              lit: model.auditioning != null && model.auditioning == sound ? 60 : null,
              onNote: (_) {
                if (sound != null) model.audition(sound);
              },
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
      // A tap selects the channel and plays its preset.
      onTap: () {
        model.selectChannel(c.channel);
        if (s != null) model.audition(s, channel: c.channel);
      },
      builder: (_, h) => Container(
        decoration: BoxDecoration(
          color: sel ? t.accentSoft : (s == null ? (h ? t.bg1 : Colors.transparent) : (h ? t.bg2 : t.bg1)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? t.accent : t.line),
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(c.channel.toString().padLeft(2, '0'), style: t.num.copyWith(fontWeight: FontWeight.w600, color: sel ? t.accent : (s == null ? t.text3 : t.text2))),
                const Spacer(),
                if (s != null) Tag(soundKind(s)),
              ]),
              const Spacer(),
              if (s == null)
                Text(sel ? 'Pick a preset' : 'Empty', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: t.text3))
              else
                Text(splitName(s).$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.title.copyWith(fontWeight: FontWeight.w500)),
              const Spacer(),
              SizedBox(height: 12, child: s == null ? null : Align(alignment: Alignment.centerLeft, child: Meter(value: c.voices, max: 4, segments: 8))),
            ]),
          ),
          if (s != null)
            Positioned(
              right: 2,
              bottom: 2,
              child: IconBtn(Icons.backspace_outlined, tooltip: 'Clear the channel', onTap: () => model.assign(c.channel, null)),
            ),
        ]),
      ),
    );
  }
}
