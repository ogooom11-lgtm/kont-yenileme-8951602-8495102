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
    for (final lg in state.leagues) {
      all.addAll(lg.matches.where((m) => !m.isBye));
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
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(filter(MatchStatus.scheduled)),
          _list(filter(MatchStatus.live)),
          _list(filter(MatchStatus.finished).reversed.toList()),
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
