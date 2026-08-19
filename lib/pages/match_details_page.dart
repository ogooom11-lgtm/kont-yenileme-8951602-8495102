import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/league.dart';
import '../models/models.dart';
import 'match_time_edit_page.dart';
import 'lineup_edit_page.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Detayı'),
        actions: [
          if (m.status == MatchStatus.scheduled)
            IconButton(
              tooltip: 'Ev Kadro Düzenle',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LineupEditPage(matchId: m.id, isHome: true),
                  ),
                );
              },
              icon: const Icon(Icons.home),
            ),
          if (m.status == MatchStatus.scheduled)
            IconButton(
              tooltip: 'Saat Düzenle',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchTimeEditPage(matchId: m.id),
                  ),
                );
              },
              icon: const Icon(Icons.edit_calendar),
            ),

          if (m.status == MatchStatus.scheduled)
            IconButton(
              tooltip: 'Deplasman Kadro Düzenle',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LineupEditPage(matchId: m.id, isHome: false),
                  ),
                );
              },
              icon: const Icon(Icons.flight_takeoff),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // العنوان والنتيجة
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.titleMedium,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${home?.icon ?? ''} ${home?.name ?? '??'}  ${m.homeGoals} : ${m.awayGoals}  ${away?.name ?? '??'} ${away?.icon ?? ''}'),
                    const SizedBox(height: 6),
                    Text(_statusLine(m)),
                    if (m.startTime != null) ...[
                      const SizedBox(height: 6),
                      Text('Başlama: ${_fmtDateTime(m.startTime!)}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // التشكيلات
          Text('Kadro (11 + Kaleci)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _LineupCard(team: home, lineup: m.homeLineup, sideLabel: 'Ev Sahibi'),
          const SizedBox(height: 8),
          _LineupCard(team: away, lineup: m.awayLineup, sideLabel: 'Deplasman'),

          const SizedBox(height: 24),

          // الأحداث (الخط الزمني)
          Text('Maç Olayları', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (m.events.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Henüz olay yok.'),
              ),
            )
          else
            Card(
              elevation: 0,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: m.events.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final ev = m.events[i];
                  final team = ev.isHome ? home : away;
                  final playerName = _playerName(team, ev.playerId);
                  return ListTile(
                    leading: const Icon(Icons.sports_soccer),
                    title: Text("⚽ ${ev.minute}'  ${team?.name ?? ''} ${playerName ?? ''}"),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _statusLine(MatchGame m) {
    return switch (m.status) {
      MatchStatus.scheduled => 'Durum: Planlı',
      MatchStatus.live => 'Durum: Canlı (yaklaşık dakika ${_guessMinute(m)})',
      MatchStatus.finished => 'Durum: Bitti',
    };
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}  $h:$m';
  }

  String _guessMinute(MatchGame m) {
    if (m.events.isEmpty) return '0';
    final mx = m.events.map((e) => e.minute).reduce((a, b) => a > b ? a : b);
    return '$mx';
  }

  String? _playerName(Team? t, String? playerId) {
    if (t == null || playerId == null) return null;
    final idx = t.players.indexWhere((p) => p.id == playerId);
    return idx >= 0 ? t.players[idx].fullName : null;
  }
}

class _LineupCard extends StatelessWidget {
  final Team? team;
  final Lineup? lineup;
  final String sideLabel;

  const _LineupCard({required this.team, required this.lineup, required this.sideLabel});

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Takım bulunamadı.'),
        ),
      );
    }

    final playerNames = <String>[];
    if (lineup?.playerIds.isNotEmpty == true) {
      for (final id in lineup!.playerIds) {
        final p = team!.players.firstWhere(
              (x) => x.id == id,
          orElse: () => Player(id: id, fullName: 'Bilinmiyor', power: 0),
        );
        playerNames.add(p.fullName);
      }
    }

    String keeperName = '—';
    if (lineup?.keeperId != null) {
      final k = team!.keepers.firstWhere(
            (x) => x.id == lineup!.keeperId,
        orElse: () => GoalKeeper(id: lineup!.keeperId!, fullName: 'Bilinmiyor', keepingPower: 0),
      );
      keeperName = k.fullName;
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$sideLabel: ${team!.icon} ${team!.name}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Kaleci: $keeperName'),
            const SizedBox(height: 6),
            if (playerNames.isEmpty)
              const Text('11 kişilik kadro ayarlanmadı. (Maç başlarsa otomatik seçilir)')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: playerNames.map((n) => Chip(label: Text(n))).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
