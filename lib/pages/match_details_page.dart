import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/helpers.dart';
import 'lineup_edit_page.dart';
import 'match_time_edit_page.dart';

class MatchDetailsPage extends StatelessWidget {
  final String matchId;
  const MatchDetailsPage({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.findMatchById(matchId);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maç')),
        body: const Center(child: Text('Maç bulunamadı.')),
      );
    }
    final home = state.findTeam(m.homeTeamId);
    final away = state.findTeam(m.awayTeamId);
    final planned = m.status == MatchStatus.scheduled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç detayı'),
        actions: [
          if (planned) ...[
            IconButton(
              tooltip: 'Ev kadro',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LineupEditPage(matchId: m.id, isHome: true),
                ),
              ),
              icon: const Icon(Icons.home_outlined),
            ),
            IconButton(
              tooltip: 'Deplasman kadro',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LineupEditPage(matchId: m.id, isHome: false),
                ),
              ),
              icon: const Icon(Icons.flight_takeoff),
            ),
            IconButton(
              tooltip: 'Saat',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchTimeEditPage(matchId: m.id),
                ),
              ),
              icon: const Icon(Icons.edit_calendar),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    m.stage.label(week: m.week, groupName: m.groupName),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(home?.icon ?? '?', style: const TextStyle(fontSize: 36)),
                            Text(home?.name ?? '?',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Text(
                        m.status == MatchStatus.scheduled
                            ? 'VS'
                            : '${m.homeGoals} - ${m.awayGoals}',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(away?.icon ?? (m.isBye ? '—' : '?'),
                                style: const TextStyle(fontSize: 36)),
                            Text(m.isBye ? 'Bay' : (away?.name ?? '?'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_status(state, m)),
                  if (m.startTime != null) Text(formatDateTime(m.startTime!)),
                  if (m.usedPenalties)
                    Text('Penaltılar ${m.homePenalties} - ${m.awayPenalties}'),
                ],
              ),
            ),
          ),
          if (planned || m.status == MatchStatus.live) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _manualResult(context, state, m),
              icon: const Icon(Icons.scoreboard_outlined),
              label: const Text('Sonuç gir'),
            ),
          ],
          if (m.status == MatchStatus.live) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => state.recordAiGoal(matchId: m.id, isHome: true),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Ev golü'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => state.recordAiGoal(matchId: m.id, isHome: false),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Dep golü'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text('Kadrolar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _LineupCard(team: home, lineup: m.homeLineup, side: 'Ev sahibi'),
          const SizedBox(height: 8),
          _LineupCard(team: away, lineup: m.awayLineup, side: 'Deplasman'),
          const SizedBox(height: 18),
          Text('Olaylar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (m.events.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Henüz olay yok.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final ev in m.events)
                    ListTile(
                      leading: const Icon(Icons.sports_soccer),
                      title: Text(
                        "${ev.type.label}  ${ev.minute}'  ${_player(ev.isHome ? home : away, ev.playerId) ?? ''}",
                      ),
                      subtitle: Text(
                          ev.isHome ? (home?.name ?? '') : (away?.name ?? '')),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _status(AppState state, MatchGame m) => switch (m.status) {
        MatchStatus.scheduled => 'Planlı',
        MatchStatus.live => 'Canlı  ${state.liveMinuteFor(m.id)}\'',
        MatchStatus.finished => 'Bitti',
      };

  String? _player(Team? t, String? id) {
    if (t == null || id == null) return null;
    for (final p in t.players) {
      if (p.id == id) return p.fullName;
    }
    return null;
  }

  void _manualResult(BuildContext context, AppState state, MatchGame m) {
    final h = TextEditingController(text: '${m.homeGoals}');
    final a = TextEditingController(text: '${m.awayGoals}');
    final ph = TextEditingController(text: '${m.homePenalties}');
    final pa = TextEditingController(text: '${m.awayPenalties}');
    var pens = m.usedPenalties || (m.stage.isKnockout && m.tieId == null);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Maç sonucu',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
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
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('-', style: TextStyle(fontSize: 22)),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Penaltı atışları'),
                value: pens,
                onChanged: (v) => setS(() => pens = v),
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
                    const SizedBox(width: 12),
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (state.confirmResults) {
                    final confirmed = await showDialog<bool>(
                      context: ctx,
                      builder: (confirmContext) => AlertDialog(
                        title: const Text('Sonuç kaydedilsin mi?'),
                        content: Text('${h.text.trim().isEmpty ? "0" : h.text} - ${a.text.trim().isEmpty ? "0" : a.text} sonucu resmi hale gelecek.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('Düzenle')),
                          FilledButton(onPressed: () => Navigator.pop(confirmContext, true), child: const Text('Onayla')),
                        ],
                      ),
                    );
                    if (confirmed != true || !ctx.mounted) return;
                  }
                  final error = await state.setMatchResult(
                    m.id,
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
                },
                child: const Text('Kaydet ve bitir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineupCard extends StatelessWidget {
  final Team? team;
  final Lineup? lineup;
  final String side;
  const _LineupCard({required this.team, required this.lineup, required this.side});

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Takım yok'),
        ),
      );
    }
    final names = <String>[];
    if (lineup != null) {
      for (final id in lineup!.playerIds) {
        final p = team!.players.where((x) => x.id == id);
        names.add(p.isEmpty ? '?' : p.first.fullName);
      }
    }
    String keeper = '—';
    if (lineup?.keeperId != null) {
      final k = team!.keepers.where((x) => x.id == lineup!.keeperId);
      keeper = k.isEmpty ? '?' : k.first.fullName;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$side · ${team!.icon} ${team!.name}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Kaleci: $keeper'),
            const SizedBox(height: 6),
            if (names.isEmpty)
              const Text('Kadro seçilmedi. Maç başlarsa otomatik kurulur.')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: names.map((n) => Chip(label: Text(n))).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
