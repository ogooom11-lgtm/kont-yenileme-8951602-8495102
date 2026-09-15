import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/match_card.dart';
import 'league_create_page.dart';
import 'league_details_page.dart';
import 'settings_page.dart';

class LeaguesPage extends StatefulWidget {
  const LeaguesPage({super.key});

  @override
  State<LeaguesPage> createState() => _LeaguesPageState();
}

class _LeaguesPageState extends State<LeaguesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final leagues = state.leagues.where((league) => league.title.toLowerCase().contains(_query.trim().toLowerCase())).toList();
    final allMatches = state.leagues.expand((league) => league.matches).where((match) => !match.isBye).toList();
    final live = allMatches.where((match) => match.status == MatchStatus.live).length;
    final completed = allMatches.where((match) => match.status == MatchStatus.finished).length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('KONT', style: TextStyle(fontWeight: FontWeight.w900)), Text('Yarışma merkezi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400))]),
        actions: [
          IconButton(tooltip: 'Tema', onPressed: state.toggleTheme, icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode)),
          IconButton(tooltip: 'Ayarlar', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.tune)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Yeni yarışma'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _Hero(teams: state.teams.length, leagues: state.leagues.length, matches: allMatches.length, live: live, completed: completed),
          const SizedBox(height: 18),
          Row(children: [const Text('Yarışmaların', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const Spacer(), Text('${leagues.length}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(hintText: 'Yarışma ara', prefixIcon: const Icon(Icons.search), isDense: true, suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close))),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          if (leagues.isEmpty)
            _EmptyState(hasTeams: state.teams.isNotEmpty, onCreate: () => _create(context, state))
          else
            ...leagues.map((league) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _LeagueCard(league: league))),
          const SizedBox(height: 10),
          const Text('Yaklaşan maçlar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          ..._upcoming(state).take(3).map((match) => Padding(padding: const EdgeInsets.only(bottom: 8), child: MatchCard(match: match, compact: true))),
          if (_upcoming(state).isEmpty) const Text('Henüz planlı maç yok.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  List<MatchGame> _upcoming(AppState state) {
    final result = <MatchGame>[];
    for (final league in state.leagues) {
      result.addAll(league.matches.where((match) => !match.isBye && (match.status == MatchStatus.scheduled || match.status == MatchStatus.live)));
    }
    result.sort((a, b) => (a.startTime ?? DateTime.now()).compareTo(b.startTime ?? DateTime.now()));
    return result;
  }

  void _create(BuildContext context, AppState state) {
    if (state.teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce en az iki takım ekleyin.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LeagueCreatePage()));
  }
}

class _Hero extends StatelessWidget {
  final int teams;
  final int leagues;
  final int matches;
  final int live;
  final int completed;
  const _Hero({required this.teams, required this.leagues, required this.matches, required this.live, required this.completed});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF142C3D), Color(0xFF0B6E4F)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.auto_awesome, color: AppTheme.gold, size: 28), SizedBox(width: 10), Text('Sahayı sen yönet', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 8),
      const Text('Takımını ekle, formatı seç, gerisini KONT hesaplasın.', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 18),
      Row(children: [_HeroStat('$teams', 'Takım'), _HeroStat('$leagues', 'Yarışma'), _HeroStat('$matches', 'Maç'), _HeroStat('$completed', 'Biten')]),
      if (live > 0) ...[const SizedBox(height: 12), Text('● $live maç şu an canlı', style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.w800))],
    ]),
  );
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)), Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11))]));
}

class _LeagueCard extends StatelessWidget {
  final League league;
  const _LeagueCard({required this.league});

  @override
  Widget build(BuildContext context) {
    final real = league.matches.where((match) => !match.isBye).toList();
    final done = real.where((match) => match.status == MatchStatus.finished).length;
    final progress = real.isEmpty ? 0.0 : done / real.length;
    final color = Color(league.leagueColorValue);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeagueDetailsPage(leagueId: league.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.82)])),
            child: Row(children: [Text(league.icon, style: const TextStyle(fontSize: 28)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(league.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)), Text(league.format.title, style: const TextStyle(color: Colors.white70, fontSize: 12))])), const Icon(Icons.chevron_right, color: Colors.white)]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 13, 16, 14), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${league.teamIds.length} takım'), Text('$done/${real.length} maç bitti', style: const TextStyle(fontWeight: FontWeight.w800)), Text('${(progress * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 9),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, color: color, minHeight: 7, backgroundColor: color.withOpacity(0.13))),
            if (league.format.hasKnockout) ...[const SizedBox(height: 8), Row(children: [Icon(Icons.account_tree_outlined, size: 16, color: color), const SizedBox(width: 5), Text('Kupa haritası hazır', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))])],
          ])),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasTeams;
  final VoidCallback onCreate;
  const _EmptyState({required this.hasTeams, required this.onCreate});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Icon(hasTeams ? Icons.emoji_events_outlined : Icons.groups_outlined, size: 56, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 10), Text(hasTeams ? 'İlk yarışmanı oluştur' : 'Önce takım ekle', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 6), Text(hasTeams ? 'Kupa haritası, fikstür ve puan tablosu saniyeler içinde hazır.' : 'Yarışma oluşturmak için en az iki takım gerekiyor.', textAlign: TextAlign.center), if (hasTeams) ...[const SizedBox(height: 14), FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Yarışma oluştur'))]])));
}
