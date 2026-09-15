import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/match_card.dart';

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
    final stats = state.statsForTeam(team.id);
    final competitions = state.leagues.where((l) => l.teamIds.contains(team.id)).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF0B6E4F),
            actions: [
              IconButton(
                tooltip: 'Düzenle',
                onPressed: () => _edit(context, state, team),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Takımı sil',
                onPressed: () => _delete(context, state, team),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF142C3D), Color(0xFF0B6E4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 28),
                    Text(team.icon, style: const TextStyle(fontSize: 66)),
                    const SizedBox(height: 6),
                    const Text('Sadece isim ve ikon. Gerisini KONT yönetir.',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _StatsStrip(stats: stats),
                const SizedBox(height: 22),
                const _SectionTitle(title: 'Turnuvalar', icon: Icons.emoji_events_outlined),
                const SizedBox(height: 8),
                if (competitions.isEmpty)
                  const _EmptyCard('Bu takım henüz bir turnuvaya eklenmedi.')
                else
                  ...competitions.map((league) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(league.leagueColorValue),
                            child: Text(league.icon),
                          ),
                          title: Text(league.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${league.format.title} · ${league.teamIds.length} takım'),
                        ),
                      )),
                const SizedBox(height: 22),
                const _SectionTitle(title: 'Son maçlar', icon: Icons.history),
                const SizedBox(height: 8),
                if (stats.matches.isEmpty)
                  const _EmptyCard('Bu takımın tamamlanmış maçı yok.')
                else
                  ...stats.matches.reversed.take(8).map((match) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MatchCard(match: match, compact: true),
                      )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, AppState state, Team team) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takım silinsin mi?'),
        content: Text('${team.name} herhangi bir turnuvada kullanılmıyorsa silinebilir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await state.deleteTeam(team.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.pop(context);
    }
  }

  void _edit(BuildContext context, AppState state, Team team) {
    final name = TextEditingController(text: team.name);
    var icon = team.icon;
    const icons = ['⚽', '🦁', '🦅', '🐺', '🐉', '🐯', '🦊', '🔥', '⚡', '⭐', '💎', '🛡️'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Takımı düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Takım adı')),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  children: icons.map((item) => ChoiceChip(
                    label: Text(item),
                    selected: icon == item,
                    onSelected: (_) => setDialogState(() => icon = item),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final error = await state.updateTeam(team.id, name.text, icon);
                if (!ctx.mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(error)));
                  return;
                }
                Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final TeamStats stats;
  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat('Maç', stats.played, Colors.blue),
        const SizedBox(width: 8),
        _Stat('Galibiyet', stats.win, Colors.green),
        const SizedBox(width: 8),
        _Stat('Beraberlik', stats.draw, Colors.orange),
        const SizedBox(width: 8),
        _Stat('Mağlubiyet', stats.lose, Colors.red),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text('$value', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 9)),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
