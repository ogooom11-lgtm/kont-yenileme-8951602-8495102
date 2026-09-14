import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/match_card.dart';
import 'league_create_page.dart';
import 'league_details_page.dart';
import 'settings_page.dart';

class LeaguesPage extends StatelessWidget {
  const LeaguesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KONT', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Lig & Kupa Yöneticisi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tema',
            onPressed: state.toggleTheme,
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (state.teams.length < 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Önce en az 2 takım ekleyin (Takımlar sekmesi).'),
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LeagueCreatePage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Turnuva'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _HeroBanner(leagueCount: state.leagues.length, teamCount: state.teams.length),
          const SizedBox(height: 20),
          Text('Aktif turnuvalar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 10),
          if (state.leagues.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 56, color: cs.outline),
                    const SizedBox(height: 12),
                    const Text('Henüz turnuva yok',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      'Gerçekçi formatlarla lig, kupa veya Dünya Kupası oluşturun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            ...state.leagues.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LeagueCard(league: l),
                )),
          const SizedBox(height: 16),
          Text('Yaklaşan maçlar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 10),
          ..._upcoming(state).take(5).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MatchCard(match: m, compact: true),
              )),
          if (_upcoming(state).isEmpty)
            Text('Planlı maç yok.', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  List<MatchGame> _upcoming(AppState state) {
    final list = <MatchGame>[];
    for (final lg in state.leagues) {
      for (final m in lg.matches) {
        if (m.startTime == null || m.isBye) continue;
        if (m.status == MatchStatus.scheduled || m.status == MatchStatus.live) {
          list.add(m);
        }
      }
    }
    list.sort((a, b) => a.startTime!.compareTo(b.startTime!));
    return list;
  }
}

class _HeroBanner extends StatelessWidget {
  final int leagueCount;
  final int teamCount;
  const _HeroBanner({required this.leagueCount, required this.teamCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B6E4F), Color(0xFF149E6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sahayı sen yönet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          Text(
            '8 gerçekçi format · otomatik fikstür · puan durumu · eleme turu',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _chip('$leagueCount turnuva'),
              const SizedBox(width: 8),
              _chip('$teamCount takım'),
              const SizedBox(width: 8),
              _chip('Android'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.gold.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
        ),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _LeagueCard extends StatelessWidget {
  final League league;
  const _LeagueCard({required this.league});

  @override
  Widget build(BuildContext context) {
    final finished =
        league.matches.where((m) => m.status == MatchStatus.finished).length;
    final total = league.matches.where((m) => !m.isBye).length;
    final progress = total == 0 ? 0.0 : finished / total;
    final color = Color(league.leagueColorValue);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LeagueDetailsPage(leagueId: league.id),
          ));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              color: color,
              child: Row(
                children: [
                  Text(league.icon, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          league.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          league.format.title,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('Maç', '$total'),
                      _stat('Biten', '$finished'),
                      _stat('Takım', '${league.teamIds.length}'),
                      if (league.groups.isNotEmpty)
                        _stat('Grup', '${league.groups.length}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      color: color,
                      backgroundColor: color.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String l, String v) => Column(
        children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}
