import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../widgets/match_card.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = <MatchGame>[];
    final query = _query.trim().toLowerCase();
    for (final lg in state.leagues) {
      for (final match in lg.matches.where((m) => !m.isBye)) {
        final home = state.findTeam(match.homeTeamId)?.name.toLowerCase() ?? '';
        final away = state.findTeam(match.awayTeamId)?.name.toLowerCase() ?? '';
        if (query.isEmpty || home.contains(query) || away.contains(query) || lg.title.toLowerCase().contains(query)) {
          all.add(match);
        }
      }
    }
    all.sort((a, b) => (a.startTime ?? DateTime.now())
        .compareTo(b.startTime ?? DateTime.now()));

    List<MatchGame> filter(MatchStatus s) =>
        all.where((m) => m.status == s).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maçlar'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Planlı (${filter(MatchStatus.scheduled).length})'),
            Tab(text: 'Canlı (${filter(MatchStatus.live).length})'),
            Tab(text: 'Biten (${filter(MatchStatus.finished).length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Takım veya turnuva ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(Icons.close),
                      ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _list(filter(MatchStatus.scheduled)),
                _list(filter(MatchStatus.live)),
                _list(filter(MatchStatus.finished).reversed.toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<MatchGame> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Maç yok.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => MatchCard(match: items[i]),
    );
  }
}
