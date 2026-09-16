import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/standings_service.dart';
import '../widgets/competition_bracket.dart';
import '../widgets/match_card.dart';

class LeagueDetailsPage extends StatelessWidget {
  final String leagueId;
  const LeagueDetailsPage({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final league = state.findLeague(leagueId);
    if (league == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Turnuva')),
        body: const Center(child: Text('Turnuva bulunamadı.')),
      );
    }
    final color = Color(league.leagueColorValue);
    final tabCount = league.format.hasGroups
        ? 5
        : (league.format.hasTable ? 4 : 4);

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 168,
              pinned: true,
              backgroundColor: color,
              foregroundColor: Colors.white,
              actions: [
                if (league.format.hasKnockout)
                  IconButton(
                    tooltip: 'Sonraki tur',
                    icon: const Icon(Icons.skip_next),
                    onPressed: () async {
                      final err = await state.forceAdvance(league.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err ?? 'Sonraki tur üretildi.'),
                      ));
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _settings(context, state, league),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  league.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.75), color],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 72, 20, 48),
                  alignment: Alignment.topLeft,
                  child: Text(
                    '${league.icon}  ${league.format.title}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
              ),
              bottom: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: 'Özet'),
                  const Tab(text: 'Fikstür'),
                  if (league.format.hasGroups) const Tab(text: 'Gruplar'),
                  Tab(text: league.format.hasKnockout && !league.format.hasTable
                      ? 'Eleme'
                      : 'Puan'),
                  const Tab(text: 'İstatistik'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(league: league),
              _MatchesTab(league: league),
              if (league.format.hasGroups) _GroupsTab(league: league),
              league.format.hasTable
                  ? _StandingsTab(league: league)
                  : _CupTab(league: league),
              _StatsTab(league: league),
            ],
          ),
        ),
      ),
    );
  }

  void _settings(BuildContext context, AppState state, League league) {
    final ctrl = TextEditingController(text: league.title);
    var autoAdvance = league.autoAdvance;
    var extraTime = league.allowExtraTime;
    var penalties = league.allowPenalties;
    var seededDraw = league.seededKnockoutDraw;
    var restHours = league.minRestHours;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(labelText: 'Turnuva adı'),
                ),
                const SizedBox(height: 8),
                if (league.format.hasKnockout) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Turları otomatik ilerlet'),
                    value: autoAdvance,
                    onChanged: (v) => setSheetState(() => autoAdvance = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Uzatma kuralı'),
                    value: extraTime,
                    onChanged: (v) => setSheetState(() => extraTime = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Penaltı atışları'),
                    value: penalties,
                    onChanged: (v) => setSheetState(() => penalties = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Seribaşı yerleşimi'),
                    subtitle: const Text('Yeni turlarda takım sırasını koru'),
                    value: seededDraw,
                    onChanged: (v) => setSheetState(() => seededDraw = v),
                  ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Minimum dinlenme: $restHours saat',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Slider(
                  value: restHours.toDouble().clamp(24.0, 96.0).toDouble(),
                  min: 24,
                  max: 96,
                  divisions: 12,
                  label: '$restHours saat',
                  onChanged: (v) => setSheetState(() => restHours = v.toInt()),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    await state.updateLeagueName(league.id, ctrl.text);
                    await state.updateLeagueRules(
                      league.id,
                      autoAdvance: autoAdvance,
                      allowExtraTime: extraTime,
                      allowPenalties: penalties,
                      minRestHours: restHours,
                      seededKnockoutDraw: seededDraw,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Ayarları kaydet'),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('Silinsin mi?'),
                        content: const Text('Tüm maçlar kalıcı olarak silinir.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('İptal')),
                          TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Sil')),
                        ],
                      ),
                    );
                    if (ok == true && ctx.mounted) {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      await state.deleteLeague(league.id);
                    }
                  },
                  child: const Text('Turnuvayı sil',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final League league;
  const _OverviewTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final real = league.matches.where((m) => !m.isBye).toList();
    final done = real.where((m) => m.status == MatchStatus.finished).length;
    final progress = real.isEmpty ? 0.0 : done / real.length;
    final next = real
        .where((m) =>
            m.status == MatchStatus.scheduled || m.status == MatchStatus.live)
        .toList()
      ..sort((a, b) => (a.startTime ?? DateTime.now())
          .compareTo(b.startTime ?? DateTime.now()));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                        child: Text('İlerleme',
                            style: TextStyle(fontWeight: FontWeight.w700))),
                    Text('%${(progress * 100).toStringAsFixed(0)}'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(6),
                  color: Color(league.leagueColorValue),
                ),
                const SizedBox(height: 8),
                Text('$done / ${real.length} maç tamamlandı',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        if (league.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Turnuva notu'),
              subtitle: Text(league.notes),
            ),
          ),
        ],
        if (league.knockoutEntryStages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.alt_route_outlined),
              title: const Text('Özel giriş turları'),
              subtitle: Text('${league.knockoutEntryStages.length} takım kendi başlangıç turundan kuraya katılıyor.'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Sıradaki maç',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (next.isNotEmpty)
          MatchCard(match: next.first)
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Planlı maç kalmadı.')),
            ),
          ),
        if (league.format.hasKnockout) ...[
          const SizedBox(height: 18),
          const Text('Turnuva yolu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Kim hangi turda? Harita sonuçlarla birlikte canlı güncellenir.'),
          CompetitionBracket(league: league),
        ],
      ],
    );
  }
}

class _MatchesTab extends StatelessWidget {
  final League league;
  const _MatchesTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final matches = league.matches.where((m) => !m.isBye).toList()
      ..sort((a, b) => (a.startTime ?? DateTime.now())
          .compareTo(b.startTime ?? DateTime.now()));
    if (matches.isEmpty) {
      return const Center(child: Text('Fikstür boş.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => MatchCard(match: matches[i]),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  final League league;
  const _GroupsTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tables = StandingsService.byGroup(league: league, findTeam: state.findTeam);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final g in league.groups) ...[
          Text('Grup ${g.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          _table(context, tables[g.id] ?? [], league),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _StandingsTab extends StatelessWidget {
  final League league;
  const _StandingsTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (league.format.hasGroups) {
      return _GroupsTab(league: league);
    }
    final table =
        StandingsService.build(league: league, findTeam: state.findTeam);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _table(context, table, league),
    );
  }
}

Widget _table(BuildContext context, List<LeagueTableItem> table, League league) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columnSpacing: 14,
      headingRowHeight: 36,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 44,
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Takım')),
        DataColumn(label: Text('O')),
        DataColumn(label: Text('G')),
        DataColumn(label: Text('B')),
        DataColumn(label: Text('M')),
        DataColumn(label: Text('Av')),
        DataColumn(label: Text('P')),
      ],
      rows: [
        for (var i = 0; i < table.length; i++)
          DataRow(
            color: WidgetStateProperty.all(_rankColor(league, i + 1)),
            cells: [
              DataCell(Text('${i + 1}')),
              DataCell(SizedBox(
                width: 120,
                child: Text(
                  '${table[i].teamIcon} ${table[i].teamName}',
                  overflow: TextOverflow.ellipsis,
                ),
              )),
              DataCell(Text('${table[i].played}')),
              DataCell(Text('${table[i].won}')),
              DataCell(Text('${table[i].drawn}')),
              DataCell(Text('${table[i].lost}')),
              DataCell(Text('${table[i].goalDifference}')),
              DataCell(Text('${table[i].points}',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
      ],
    ),
  );
}

Color? _rankColor(League league, int rank) {
  for (final r in league.rankDefinitions) {
    if (rank >= r.minRank && rank <= r.maxRank) {
      return Color(r.colorValue).withValues(alpha: 0.16);
    }
  }
  return null;
}

class _CupTab extends StatelessWidget {
  final League league;
  const _CupTab({required this.league});

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.zero,
        children: [
          CompetitionBracket(league: league),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              'Kartlara dokunarak maç detayını, skoru ve turu geçen takımı açabilirsin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
}

class _StatsTab extends StatelessWidget {
  final League league;
  const _StatsTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final finished = league.matches.where((m) => m.status == MatchStatus.finished && !m.isBye).toList();
    final goals = finished.fold<int>(0, (sum, match) => sum + match.homeGoals + match.awayGoals);
    final wins = <String, int>{};
    for (final match in finished) {
      final winner = match.winnerTeamId ?? (match.homeGoals == match.awayGoals
          ? null
          : match.homeGoals > match.awayGoals
              ? match.homeTeamId
              : match.awayTeamId);
      if (winner != null) wins.update(winner, (value) => value + 1, ifAbsent: () => 1);
    }
    final ranking = wins.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _Metric('Tamamlanan', '${finished.length}', Icons.check_circle_outline, Colors.green),
            const SizedBox(width: 8),
            _Metric('Toplam gol', '$goals', Icons.sports_soccer, Colors.orange),
            const SizedBox(width: 8),
            _Metric('Takım', '${league.teamIds.length}', Icons.groups_outlined, Colors.blue),
          ],
        ),
        const SizedBox(height: 20),
        const Text('En çok kazananlar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (ranking.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Sonuçlar girildiğinde turnuva performansı burada görünür.')))
        else
          ...ranking.take(8).toList().asMap().entries.map((entry) {
            final team = state.findTeam(entry.value.key);
            return Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: entry.key == 0 ? const Color(0xFFE8B923) : null, child: Text(team?.icon ?? '⚽')),
              title: Text(team?.name ?? '?', style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text('${entry.value.value} galibiyet', style: const TextStyle(fontWeight: FontWeight.w800)),
            ));
          }),
        const SizedBox(height: 18),
        if (league.format.hasTable) ...[
          const Text('Tablo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          _table(context, StandingsService.build(league: league, findTeam: state.findTeam), league),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
    child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 4), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17)), Text(label, style: TextStyle(color: color, fontSize: 10))]),
  ));
}
