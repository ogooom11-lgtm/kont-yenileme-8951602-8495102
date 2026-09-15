import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../utils/helpers.dart';
import 'match_time_edit_page.dart';

class MatchDetailsPage extends StatelessWidget {
  final String matchId;
  const MatchDetailsPage({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final match = state.findMatchById(matchId);
    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maç')),
        body: const Center(child: Text('Maç bulunamadı.')),
      );
    }
    final home = state.findTeam(match.homeTeamId);
    final away = state.findTeam(match.awayTeamId);
    final league = state.leagueOfMatch(match.id);
    final scheduled = match.status == MatchStatus.scheduled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç merkezi'),
        actions: [
          if (scheduled)
            IconButton(
              tooltip: 'Maç saatini düzenle',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchTimeEditPage(matchId: match.id)),
              ),
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _ScoreHero(match: match, homeName: home?.name ?? '?', homeIcon: home?.icon ?? '⚽', awayName: away?.name ?? '?', awayIcon: away?.icon ?? '⚽', state: state),
          const SizedBox(height: 14),
          if (league != null && match.stage.isKnockout)
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(match.stage.label()),
                subtitle: Text(league.title + (match.tieId == null ? ' · Tek maç' : ' · Rövanşlı eşleşme')),
              ),
            ),
          if (scheduled || match.status == MatchStatus.live) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _manualResult(context, state, match),
              icon: const Icon(Icons.scoreboard_outlined),
              label: const Text('Sonuç gir'),
            ),
          ],
          if (match.status == MatchStatus.live) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => state.recordAiGoal(matchId: match.id, isHome: true),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Ev golü'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => state.recordAiGoal(matchId: match.id, isHome: false),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Dep golü'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text('Maç olayları', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (match.events.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Henüz kayıtlı olay yok.')))
          else
            Card(
              child: Column(
                children: match.events.map((event) => ListTile(
                  dense: true,
                  leading: Icon(_eventIcon(event.type)),
                  title: Text('${event.type.label}  ${event.minute}\''),
                  subtitle: Text(event.isHome ? (home?.name ?? 'Ev sahibi') : (away?.name ?? 'Deplasman')),
                )).toList(),
              ),
            ),
          const SizedBox(height: 18),
          Text('Kurallar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(match.stage.isKnockout ? 'Eleme maçı' : 'Puan maçı'),
              subtitle: Text(match.stage.isKnockout
                  ? 'Eşitlikler turnuvanın uzatma ve penaltı ayarlarına göre çözülür.'
                  : 'Sonuç puan tablosuna işlenir.'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(EventType type) => switch (type) {
        EventType.goal || EventType.penaltyGoal || EventType.ownGoal => Icons.sports_soccer,
        EventType.yellow => Icons.square,
        EventType.red => Icons.square,
        EventType.save => Icons.pan_tool_outlined,
      };

  void _manualResult(BuildContext context, AppState state, MatchGame match) {
    final h = TextEditingController(text: '${match.homeGoals}');
    final a = TextEditingController(text: '${match.awayGoals}');
    final ph = TextEditingController(text: '${match.homePenalties}');
    final pa = TextEditingController(text: '${match.awayPenalties}');
    var penalties = match.usedPenalties;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Resmî sonuç', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: TextField(controller: h, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Ev'))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('-', style: TextStyle(fontSize: 22))),
                  Expanded(child: TextField(controller: a, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Dep'))),
                ],
              ),
              if (match.stage.isKnockout)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Penaltı atışları'),
                  value: penalties,
                  onChanged: (value) => setSheetState(() => penalties = value),
                ),
              if (penalties)
                Row(
                  children: [
                    Expanded(child: TextField(controller: ph, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Ev pen'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: pa, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Dep pen'))),
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
                        content: Text('${h.text.isEmpty ? "0" : h.text} - ${a.text.isEmpty ? "0" : a.text} sonucu resmi hale gelecek.'),
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
                    usedPenalties: penalties,
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

class _ScoreHero extends StatelessWidget {
  final MatchGame match;
  final String homeName;
  final String homeIcon;
  final String awayName;
  final String awayIcon;
  final AppState state;
  const _ScoreHero({required this.match, required this.homeName, required this.homeIcon, required this.awayName, required this.awayIcon, required this.state});

  @override
  Widget build(BuildContext context) {
    final scheduled = match.status == MatchStatus.scheduled;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary.withOpacity(0.12), Theme.of(context).colorScheme.surface],
          ),
        ),
        child: Column(
          children: [
            Text(match.stage.label(week: match.week, groupName: match.groupName), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Team(name: homeName, icon: homeIcon)),
                Text(scheduled ? 'VS' : '${match.homeGoals} - ${match.awayGoals}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                Expanded(child: _Team(name: awayName, icon: awayIcon)),
              ],
            ),
            const SizedBox(height: 10),
            Text(_statusText(), style: TextStyle(color: match.status == MatchStatus.live ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            if (match.startTime != null) Text(formatDateTime(match.startTime!), style: Theme.of(context).textTheme.bodySmall),
            if (match.usedPenalties) Text('Penaltı: ${match.homePenalties} - ${match.awayPenalties}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _statusText() => switch (match.status) {
        MatchStatus.scheduled => 'Planlı',
        MatchStatus.live => 'CANLI · ${state.liveMinuteFor(match.id)}\'',
        MatchStatus.finished => 'Tamamlandı',
      };
}

class _Team extends StatelessWidget {
  final String name;
  final String icon;
  const _Team({required this.name, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 5),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      );
}
