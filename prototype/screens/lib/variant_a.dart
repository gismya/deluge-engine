// PROTOTYPE — throwaway. Variant A: "Tabs and tables". A classic desktop window: a toolbar,
// a Setup tab with one table row per MIDI channel, a Piece tab with a form, a parts table and a
// render list. Presets are picked in a dialog.

import 'package:flutter/material.dart';

import 'common.dart';
import 'data.dart';

class VariantA extends StatelessWidget {
  const VariantA({super.key, required this.model});
  final Model model;
  static const name = 'Tabs and tables';

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Deluge Engine'),
            actions: [CardFolderButton(model: model), const SizedBox(width: 12), EngineStatus(model: model), const SizedBox(width: 12)],
            bottom: const TabBar(tabs: [Tab(text: 'Setup'), Tab(text: 'Piece')]),
          ),
          body: TabBarView(children: [_SetupTab(model: model), _PieceTab(model: model)]),
          bottomNavigationBar: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 56), child: StatusLine(model: model)),
        ),
      );
}

class _SetupTab extends StatelessWidget {
  const _SetupTab({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('MIDI ch')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Preset')),
            DataColumn(label: Text('Voices')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final c in model.channels)
              DataRow(cells: [
                DataCell(Text('${c.channel}')),
                DataCell(Text(c.sound == null ? '—' : (c.sound!.startsWith('KITS') ? 'Kit' : 'Synth'))),
                DataCell(
                  Text(c.sound == null ? 'Empty, click to choose' : shortName(c.sound!)),
                  onTap: () async {
                    final p = await pickPreset(context, model);
                    if (p != null) model.assign(c.channel, p);
                  },
                ),
                DataCell(Text(c.voices == 0 ? '' : '${c.voices}')),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Audition',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: c.sound == null ? null : () => model.audition(c.sound!, channel: c.channel),
                  ),
                  IconButton(tooltip: 'Clear', icon: const Icon(Icons.close), onPressed: c.sound == null ? null : () => model.assign(c.channel, null)),
                ])),
              ]),
          ],
        ),
      );
}

class _PieceTab extends StatelessWidget {
  const _PieceTab({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 280,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<String>(
              value: model.genre,
              decoration: const InputDecoration(labelText: 'Genre'),
              items: [for (final g in genres.keys) DropdownMenuItem(value: g, child: Text(g))],
              onChanged: (g) => model.setGenre(g!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey(model.seed),
                  initialValue: '${model.seed}',
                  decoration: const InputDecoration(labelText: 'Seed'),
                  onFieldSubmitted: (v) => model.setSeed(int.tryParse(v) ?? model.seed),
                ),
              ),
              IconButton(tooltip: 'New seed', icon: const Icon(Icons.casino_outlined), onPressed: model.rollSeed),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: model.lengthSeconds,
              decoration: const InputDecoration(labelText: 'Length'),
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 s')),
                DropdownMenuItem(value: 60, child: Text('60 s')),
                DropdownMenuItem(value: 120, child: Text('2 min')),
              ],
              onChanged: (v) => model.lengthSeconds = v!,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: model.rendering ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.graphic_eq),
              label: const Text('Render'),
              onPressed: model.render,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(icon: const Icon(Icons.play_arrow), label: const Text('Play live'), onPressed: () => model.status = 'Play live: Perform in real time (prototype)'),
          ]),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DataTable(
              columns: const [DataColumn(label: Text('Part')), DataColumn(label: Text('Sound pick')), DataColumn(label: Text(''))],
              rows: [
                for (final s in model.slots)
                  DataRow(cells: [
                    DataCell(Text(s.key)),
                    DataCell(
                      Text(shortName(model.picks[s.key] ?? '')),
                      onTap: s.isSynth
                          ? () async {
                              final p = await pickPreset(context, model, only: 'SYNTHS');
                              if (p != null) model.setPick(s.key, p);
                            }
                          : null,
                    ),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'Re-roll from palette', icon: const Icon(Icons.casino_outlined), onPressed: () => model.reroll(s)),
                      IconButton(tooltip: 'Audition', icon: const Icon(Icons.play_arrow), onPressed: () => model.audition(model.picks[s.key]!)),
                    ])),
                  ]),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Renders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (model.renders.isEmpty) const Text('Nothing rendered yet.'),
            for (final r in model.renders)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(r.label)),
                      IconButton(
                        icon: Icon(model.playing == r ? Icons.stop : Icons.play_arrow),
                        onPressed: () => model.play(model.playing == r ? null : r),
                      ),
                    ]),
                    Waveform(seed: r.id * 31 + r.seed, height: 32),
                    Row(children: [
                      TextButton(onPressed: () => model.setSlot('A', r), child: Text(model.slotA == r ? 'A ✓' : 'Set as A')),
                      TextButton(onPressed: () => model.setSlot('B', r), child: Text(model.slotB == r ? 'B ✓' : 'Set as B')),
                    ]),
                  ]),
                ),
              ),
            if (model.slotA != null && model.slotB != null)
              FilledButton.tonal(
                onPressed: () => model.play(model.playing == model.slotA ? model.slotB : model.slotA),
                child: Text('Swap A/B (now ${model.playing == model.slotB ? 'B' : 'A'})'),
              ),
          ]),
        ),
      ]);
}
