import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/helpers.dart';

class TeamDetailsPage extends StatelessWidget {
  final String teamId;
  const TeamDetailsPage({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final team = state.findTeam(teamId);
    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Takım')),
        body: const Center(child: Text('Takım bulunamadı.')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editTeam(context, state, team),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final err = await state.deleteTeam(team.id);
                    if (!context.mounted) return;
                    if (err != null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(err)));
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(team.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF149E6E), Color(0xFF0B6E4F)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 28),
                      Text(team.icon, style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 6),
                      Text(
                        'Güç ${team.teamPower.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Özet'),
                  Tab(text: 'Kadro'),
                  Tab(text: 'Ligler'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _Overview(team: team),
              _Squad(team: team),
              _Leagues(team: team),
            ],
          ),
        ),
      ),
    );
  }

  void _editTeam(BuildContext context, AppState state, Team team) {
    final name = TextEditingController(text: team.name);
    final icon = TextEditingController(text: team.icon);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takımı düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: icon, decoration: const InputDecoration(labelText: 'İkon')),
            const SizedBox(height: 8),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              state.updateTeam(team.id, name.text, icon.text);
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final Team team;
  const _Overview({required this.team});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.statsForTeam(team.id);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.school)),
            title: Text(team.coach.fullName),
            subtitle: Text('IQ ${team.coach.iqPower.toStringAsFixed(1)}'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _box('Maç', '${stats.played}', Colors.blue),
            const SizedBox(width: 8),
            _box('G', '${stats.win}', Colors.green),
            const SizedBox(width: 8),
            _box('M', '${stats.lose}', Colors.red),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _box('Atılan', '${stats.goalsFor}', Colors.orange),
            const SizedBox(width: 8),
            _box('Yenen', '${stats.goalsAgainst}', Colors.deepOrange),
            const SizedBox(width: 8),
            _box('Av', '${stats.goalsFor - stats.goalsAgainst}', Colors.grey),
          ],
        ),
        const SizedBox(height: 18),
        const Text('Son maçlar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (stats.matches.isEmpty) const Text('Henüz maç yok.'),
        ...stats.matches.reversed.take(10).map((m) {
          final home = m.homeTeamId == team.id;
          final opp = state.findTeam(home ? m.awayTeamId : m.homeTeamId);
          final my = home ? m.homeGoals : m.awayGoals;
          final og = home ? m.awayGoals : m.homeGoals;
          final color = my > og
              ? Colors.green
              : (my < og ? Colors.red : Colors.grey);
          return Card(
            child: ListTile(
              leading: Container(width: 4, color: color),
              title: Text('${team.name} vs ${opp?.name ?? "?"}'),
              trailing: Text('$my - $og',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            ),
          );
        }),
      ],
    );
  }

  Widget _box(String l, String v, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(v,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18, color: c)),
              Text(l, style: TextStyle(fontSize: 11, color: c)),
            ],
          ),
        ),
      );
}

class _Squad extends StatelessWidget {
  final Team team;
  const _Squad({required this.team});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text('Kaleciler', style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              onPressed: () => _add(context, state, keeper: true),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        ...team.keepers.map((k) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.sports_handball, color: Colors.white)),
                title: Text(k.fullName),
                subtitle: Text('Güç ${k.keepingPower.toStringAsFixed(1)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => state.removeKeeper(team.id, k.id),
                ),
              ),
            )),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Oyuncular', style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              onPressed: () => _add(context, state, keeper: false),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        ...team.players.map((p) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(p.power.toStringAsFixed(0))),
                title: Text(p.fullName),
                subtitle: LinearProgressIndicator(value: p.power / 8),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => state.removePlayer(team.id, p.id),
                ),
              ),
            )),
      ],
    );
  }

  void _add(BuildContext context, AppState state, {required bool keeper}) {
    final name = TextEditingController();
    var power = 5.0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(keeper ? 'Kaleci ekle' : 'Oyuncu ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad')),
              Slider(
                value: power,
                min: 1,
                max: 8,
                onChanged: (v) => setS(() => power = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                if (keeper) {
                  state.addKeeperToTeam(
                    team.id,
                    GoalKeeper(
                      id: newId(),
                      fullName: name.text.trim(),
                      keepingPower: power,
                    ),
                  );
                } else {
                  state.addPlayerToTeam(
                    team.id,
                    Player(id: newId(), fullName: name.text.trim(), power: power),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Leagues extends StatelessWidget {
  final Team team;
  const _Leagues({required this.team});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mine = state.leagues.where((l) => l.teamIds.contains(team.id)).toList();
    if (mine.isEmpty) {
      return const Center(child: Text('Bu takım henüz bir turnuvada değil.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mine.length,
      itemBuilder: (_, i) {
        final lg = mine[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Color(lg.leagueColorValue), child: Text(lg.icon)),
            title: Text(lg.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(lg.format.title),
          ),
        );
      },
    );
  }
}
