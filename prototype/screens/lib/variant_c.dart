// PROTOTYPE — throwaway. Variant C: "Piece first, palette in view". One page built around trying
// sounds for the Generator: the Piece controls and an A/B player at the top; below, one row per Part
// or lane showing its palette as chips (with weights), so trying another pick is one click. The live
// Setup is a narrow panel on the right.

import 'package:flutter/material.dart';

import 'common.dart';
import 'data.dart';

class VariantC extends StatelessWidget {
  const VariantC({super.key, required this.model});
  final Model model;
  static const name = 'Piece first, palette in view';

  @override
  Widget build(BuildContext context) {
    final m = model;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: Row(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 72), children: [
            Row(children: [
              Text('Piece', style: tt.headlineSmall),
              const Spacer(),
              CardFolderButton(model: m),
              const SizedBox(width: 8),
              EngineStatus(model: m),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final g in genres.keys) ChoiceChip(label: Text(g), selected: m.genre == g, onSelected: (_) => m.setGenre(g)),
              const SizedBox(width: 12),
              ActionChip(avatar: const Icon(Icons.casino_outlined, size: 18), label: Text('Seed ${m.seed}'), onPressed: m.rollSeed),
              FilledButton.icon(onPressed: m.render, icon: const Icon(Icons.graphic_eq), label: Text(m.rendering ? 'Rendering…' : 'Render')),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.play_arrow), label: const Text('Play live')),
            ]),
            const SizedBox(height: 16),
            _compare(context),
            const SizedBox(height: 20),
            Text('Sounds', style: tt.titleLarge),
            Text('Each part\'s palette for ${m.genre}. Click a chip to use it in the next render. ×n is its weight.', style: tt.bodySmall),
            const SizedBox(height: 8),
            for (final s in m.slots)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 150, child: Text(s.key, style: tt.labelLarge)),
                  Expanded(child: PaletteChips(model: m, slot: s)),
                  if (s.isSynth)
                    IconButton(
                      tooltip: 'Any preset…',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () async {
                        final p = await pickPreset(context, m, only: 'SYNTHS');
                        if (p != null) m.setPick(s.key, p);
                      },
                    ),
                  IconButton(tooltip: 'Audition', icon: const Icon(Icons.volume_up_outlined), onPressed: () => m.audition(m.picks[s.key]!)),
                ]),
              ),
            const SizedBox(height: 12),
            StatusLine(model: m),
          ]),
        ),
        const VerticalDivider(width: 1),
        SizedBox(width: 280, child: _setupPanel(context)),
      ]),
    );
  }

  Widget _compare(BuildContext context) {
    final m = model;
    Widget side(String ab, Render? r) {
      final playing = r != null && m.playing == r;
      return Expanded(
        child: Card(
          color: playing ? Theme.of(context).colorScheme.primaryContainer : null,
          child: InkWell(
            onTap: r == null ? null : () => m.play(playing ? null : r),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(ab, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r?.label ?? 'empty')),
                  Icon(playing ? Icons.stop : Icons.play_arrow),
                ]),
                const SizedBox(height: 6),
                if (r != null) ...[
                  Waveform(seed: r.id * 31 + r.seed, height: 40),
                  const SizedBox(height: 6),
                  // what differs from the other side
                  Text(_diff(r, ab == 'A' ? m.slotB : m.slotA), style: Theme.of(context).textTheme.bodySmall),
                ],
              ]),
            ),
          ),
        ),
      );
    }

    return Row(children: [side('A', m.slotA), side('B', m.slotB)]);
  }

  String _diff(Render r, Render? other) {
    if (other == null) return 'Render again to compare.';
    final d = [
      for (final e in r.picks.entries)
        if (other.picks[e.key] != e.value) '${e.key}: ${shortName(e.value)}',
    ];
    if (other.seed != r.seed) d.insert(0, 'seed ${r.seed}');
    return d.isEmpty ? 'Same as the other side.' : 'Differs: ${d.join(', ')}';
  }

  Widget _setupPanel(BuildContext context) {
    final m = model;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 16, 12, 72), children: [
      Text('Live Setup', style: Theme.of(context).textTheme.titleMedium),
      const Text('Play these from your MIDI controller.'),
      const SizedBox(height: 8),
      for (final c in m.channels.where((c) => c.sound != null || c.channel <= 4 || c.channel == 10))
        ListTile(
          dense: true,
          leading: CircleAvatar(radius: 14, child: Text('${c.channel}')),
          title: Text(c.sound == null ? 'empty' : shortName(c.sound!)),
          subtitle: c.voices > 0 ? Text('${c.voices} voices') : null,
          onTap: () async {
            final p = await pickPreset(context, m);
            if (p != null) m.assign(c.channel, p);
          },
          trailing: c.sound == null ? null : IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => m.audition(c.sound!, channel: c.channel)),
        ),
      TextButton(onPressed: () {}, child: const Text('Show all 16 channels')),
      const Divider(),
      TextButton.icon(
        icon: const Icon(Icons.call_split),
        label: const Text('Copy Piece sounds to Setup'),
        onPressed: () {
          var ch = 1;
          for (final s in m.slots.where((s) => s.isSynth && s.part != 'FX')) {
            m.assign(ch++, m.picks[s.key]);
          }
        },
      ),
    ]);
  }
}
