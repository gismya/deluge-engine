// PROTOTYPE — throwaway. Variant B: "Browser and strips". A DAW-style window: the preset browser
// is always open on the left; the middle shows strips (MIDI channels in Setup mode, Parts in Piece
// mode); clicking a preset assigns it to the selected strip. An A/B deck sits at the bottom.

import 'package:flutter/material.dart';

import 'common.dart';
import 'data.dart';

class VariantB extends StatefulWidget {
  const VariantB({super.key, required this.model});
  final Model model;
  static const name = 'Browser and strips';
  @override
  State<VariantB> createState() => _VariantBState();
}

class _VariantBState extends State<VariantB> {
  String mode = 'Setup';
  String? selectedPart;

  Model get m => widget.model;

  void _choose(String path) {
    if (mode == 'Setup') {
      m.assign(m.selectedChannel, path);
    } else if (selectedPart != null) {
      m.setPick(selectedPart!, path);
    }
    m.audition(path);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(children: [
        Material(
          color: cs.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'Setup', label: Text('Setup')), ButtonSegment(value: 'Piece', label: Text('Piece'))],
                selected: {mode},
                onSelectionChanged: (s) => setState(() => mode = s.first),
              ),
              const SizedBox(width: 16),
              if (mode == 'Piece') ...[
                DropdownButton<String>(
                  value: m.genre,
                  items: [for (final g in genres.keys) DropdownMenuItem(value: g, child: Text(g))],
                  onChanged: (g) => m.setGenre(g!),
                ),
                const SizedBox(width: 12),
                Text('Seed ${m.seed}'),
                IconButton(icon: const Icon(Icons.casino_outlined), onPressed: m.rollSeed),
                FilledButton.icon(onPressed: m.render, icon: const Icon(Icons.graphic_eq), label: Text(m.rendering ? 'Rendering…' : 'Render ${m.lengthSeconds} s')),
              ],
              const Spacer(),
              CardFolderButton(model: m),
              const SizedBox(width: 8),
              EngineStatus(model: m),
            ]),
          ),
        ),
        Expanded(
          child: Row(children: [
            SizedBox(
              width: 320,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Text(
                    mode == 'Setup'
                        ? 'Click a preset to put it on channel ${m.selectedChannel}'
                        : (selectedPart == null ? 'Select a part strip first' : 'Click a preset for $selectedPart'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(child: PresetBrowser(model: m, dense: true, onChoose: _choose, only: mode == 'Piece' ? 'SYNTHS' : null)),
              ]),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: mode == 'Setup' ? _channelStrips(context) : _partStrips(context)),
          ]),
        ),
        const Divider(height: 1),
        _abDeck(context),
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 56), child: StatusLine(model: m)),
      ]),
    );
  }

  Widget _strip(BuildContext context, {required bool selected, required String title, required String body, String? sub, VoidCallback? onTap, List<Widget> actions = const [], int voices = 0}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Expanded(child: Text(body, style: Theme.of(context).textTheme.bodyMedium)),
          if (sub != null) Text(sub, style: Theme.of(context).textTheme.labelSmall),
          // voice meter
          Container(height: 6, width: 116 * (voices / 6).clamp(0, 1), color: Colors.green),
          Row(children: actions),
        ]),
      ),
    );
  }

  Widget _channelStrips(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 240,
          child: Row(children: [
            for (final c in m.channels)
              _strip(
                context,
                selected: m.selectedChannel == c.channel,
                title: 'CH ${c.channel}',
                body: c.sound == null ? 'empty' : shortName(c.sound!),
                sub: c.sound == null ? null : (c.sound!.startsWith('KITS') ? 'Kit' : 'Synth'),
                voices: c.voices,
                onTap: () => m.selectChannel(c.channel),
                actions: [
                  IconButton(icon: const Icon(Icons.play_arrow), onPressed: c.sound == null ? null : () => m.audition(c.sound!, channel: c.channel)),
                  IconButton(icon: const Icon(Icons.close), onPressed: c.sound == null ? null : () => m.assign(c.channel, null)),
                ],
              ),
          ]),
        ),
      );

  Widget _partStrips(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Wrap(children: [
          for (final s in m.slots)
            SizedBox(
              height: 200,
              child: _strip(
                context,
                selected: selectedPart == s.key,
                title: s.key,
                body: shortName(m.picks[s.key] ?? ''),
                sub: '${s.palette.length} in palette',
                onTap: s.isSynth ? () => setState(() => selectedPart = s.key) : null,
                actions: [
                  IconButton(tooltip: 'Re-roll', icon: const Icon(Icons.casino_outlined), onPressed: () => m.reroll(s)),
                  IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => m.audition(m.picks[s.key]!)),
                ],
              ),
            ),
        ]),
      );

  Widget _abDeck(BuildContext context) {
    Widget side(String ab, Render? r) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                CircleAvatar(child: Text(ab)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r?.label ?? 'Render a Piece to fill $ab'),
                    if (r != null) Waveform(seed: r.id * 31 + r.seed, height: 28),
                  ]),
                ),
                IconButton(
                  icon: Icon(m.playing == r && r != null ? Icons.stop : Icons.play_arrow),
                  onPressed: r == null ? null : () => m.play(m.playing == r ? null : r),
                ),
                PopupMenuButton<Render>(
                  tooltip: 'Choose render',
                  itemBuilder: (_) => [for (final x in m.renders) PopupMenuItem(value: x, child: Text(x.label))],
                  onSelected: (x) => m.setSlot(ab, x),
                ),
              ]),
            ),
          ),
        );
    return Padding(padding: const EdgeInsets.all(8), child: Row(children: [side('A', m.slotA), side('B', m.slotB)]));
  }
}
