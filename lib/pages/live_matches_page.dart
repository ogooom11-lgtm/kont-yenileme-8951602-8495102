import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../widgets/match_card.dart';

class LiveMatchesPage extends StatefulWidget {
  const LiveMatchesPage({super.key});

  @override
  State<LiveMatchesPage> createState() => _LiveMatchesPageState();
}

class _LiveMatchesPageState extends State<LiveMatchesPage> {
  final Map<String, Timer> _pending = {};

  @override
  void dispose() {
    for (final t in _pending.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final matches = <MatchGame>[];
    final names = <String, String>{};

    for (final lg in state.leagues) {
      for (final m in lg.matches) {
        if (m.startTime == null || m.isBye) continue;
        final due = !m.startTime!.isAfter(todayEnd);
        final open = m.status != MatchStatus.finished || _pending.containsKey(m.id);
        if (due && open) {
          matches.add(m);
          names[m.id] = lg.title;
        }
      }
    }
    matches.sort((a, b) => a.startTime!.compareTo(b.startTime!));

    return Scaffold(
      appBar: AppBar(title: const Text('Günün maçları')),
      body: matches.isEmpty
          ? const Center(child: Text('Bugün oynanacak açık maç yok.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final m = matches[i];
                final pending = _pending.containsKey(m.id);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        names[m.id] ?? '',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    MatchCard(match: m),
                    if (m.status != MatchStatus.finished && !pending)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _score(context, state, m),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Sonuç gir'),
                        ),
                      ),
                    if (pending)
                      TextButton.icon(
                        onPressed: () {
                          _pending[m.id]?.cancel();
                          setState(() => _pending.remove(m.id));
                          state.undoMatchResult(m.id);
                        },
                        icon: const Icon(Icons.undo, color: Colors.orange),
                        label: const Text('Geri al (5 sn)'),
                      ),
                  ],
                );
              },
            ),
    );
  }

  void _score(BuildContext context, AppState state, MatchGame match) {
    final h = TextEditingController();
    final a = TextEditingController();
    final ph = TextEditingController();
    final pa = TextEditingController();
    var pens = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Maç sonucu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: h,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Ev'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('-'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: a,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Dep'),
                      ),
                    ),
                  ],
                ),
                if (match.stage.isKnockout)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Penaltı atışları'),
                    value: pens,
                    onChanged: (value) => setDialogState(() => pens = value),
                  ),
                if (pens)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ph,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Ev pen'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: pa,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Dep pen'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                if (state.confirmResults) {
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (confirmContext) => AlertDialog(
                      title: const Text('Sonuç kaydedilsin mi?'),
                      content: Text('${h.text.isEmpty ? "0" : h.text} - ${a.text.isEmpty ? "0" : a.text}'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('Düzenle')),
                        FilledButton(onPressed: () => Navigator.pop(confirmContext, true), child: const Text('Onayla')),
                      ],
                    ),
                  );
                  if (confirmed != true || !ctx.mounted) return;
                }
                final error = await state.setMatchResult(
                  match.id,
                  int.tryParse(h.text) ?? 0,
                  int.tryParse(a.text) ?? 0,
                  homePenalties: int.tryParse(ph.text) ?? 0,
                  awayPenalties: int.tryParse(pa.text) ?? 0,
                  usedPenalties: pens,
                );
                if (!ctx.mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(error)));
                  return;
                }
                Navigator.pop(ctx);
                setState(() {
                  _pending[match.id] = Timer(const Duration(seconds: 5), () {
                    if (mounted) setState(() => _pending.remove(match.id));
                  });
                });
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
