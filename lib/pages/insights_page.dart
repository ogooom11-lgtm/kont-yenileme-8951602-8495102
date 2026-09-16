import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../widgets/match_card.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.leagues.expand((l) => l.matches).where((m) => !m.isBye).toList();
    final finished = matches.where((m) => m.status == MatchStatus.finished).toList();
    final live = matches.where((m) => m.status == MatchStatus.live).toList();
    final upcoming = matches.where((m) => m.status == MatchStatus.scheduled).toList()
      ..sort((a, b) => (a.startTime ?? DateTime.now()).compareTo(b.startTime ?? DateTime.now()));
    final goals = finished.fold<int>(0, (sum, m) => sum + m.homeGoals + m.awayGoals);
    final teamRecords = state.teams.map((team) {
      final stats = state.statsForTeam(team.id);
      final score = stats.win * 3 + stats.draw;
      return (team: team, stats: stats, score: score);
    }).where((item) => item.stats.played > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      appBar: AppBar(title: const Text('Sezon merkezi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _InsightHero(
            leagueCount: state.leagues.length,
            teamCount: state.teams.length,
            matchCount: matches.length,
            finished: finished.length,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MetricCard('Canlı', '${live.length}', Icons.sensors, Colors.red),
              const SizedBox(width: 8),
              _MetricCard('Biten', '${finished.length}', Icons.check_circle, Colors.green),
              const SizedBox(width: 8),
              _MetricCard('Gol', '$goals', Icons.sports_soccer, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          const _Header('Formdaki takımlar', Icons.local_fire_department_outlined),
          const SizedBox(height: 8),
          if (teamRecords.isEmpty)
            _EmptyCard('Maç sonuçları girildikçe en başarılı takımlar burada görünür.'),
          ...teamRecords.take(5).toList().asMap().entries.map((entry) {
            final item = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: entry.key == 0 ? const Color(0xFFE8B923) : null,
                  child: Text(item.team.icon),
                ),
                title: Text(item.team.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${item.stats.played} maç · ${item.stats.win}G ${item.stats.draw}B ${item.stats.lose}M'),
                trailing: Text('${item.score} puan', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            );
          }),
          const SizedBox(height: 18),
          const _Header('Turnuva performansı', Icons.insights_outlined),
          const SizedBox(height: 8),
          if (state.leagues.isEmpty)
            _EmptyCard('İlk turnuvanı oluşturduğunda sezon özeti burada oluşur.'),
          ...state.leagues.map((league) {
            final real = league.matches.where((m) => !m.isBye).toList();
            final done = real.where((m) => m.status == MatchStatus.finished).length;
            final value = real.isEmpty ? 0.0 : done / real.length;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(league.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(league.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text('${(value * 100).round()}%', style: TextStyle(color: Color(league.leagueColorValue), fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: value, color: Color(league.leagueColorValue)),
                    const SizedBox(height: 6),
                    Text('$done / ${real.length} maç · ${league.format.title}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
          const _Header('Sıradaki maçlar', Icons.calendar_month_outlined),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            _EmptyCard('Yaklaşan planlı maç yok.'),
          ...upcoming.take(3).map((match) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MatchCard(match: match, compact: true),
              )),
        ],
      ),
    );
  }
}

class _InsightHero extends StatelessWidget {
  final int leagueCount;
  final int teamCount;
  final int matchCount;
  final int finished;
  const _InsightHero({required this.leagueCount, required this.teamCount, required this.matchCount, required this.finished});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF142C3D), Color(0xFF0B6E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFE8B923), size: 30),
              SizedBox(width: 12),
              Text('Sezonun nabzı', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text('$leagueCount turnuva  ·  $teamCount takım\n$matchCount maç  ·  $finished tamamlandı', style: const TextStyle(color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 5),
              Text(value, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Header(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard(this.text);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
}
