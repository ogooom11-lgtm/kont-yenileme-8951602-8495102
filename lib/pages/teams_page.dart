import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/team_avatar.dart';
import 'team_add_page.dart';
import 'team_details_page.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final teams = state.teams.where((team) => team.name.toLowerCase().contains(_query.trim().toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Takımlar')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamAddPage())), icon: const Icon(Icons.add), label: const Text('Takım ekle')),
      body: state.teams.isEmpty
          ? _EmptyTeams(onAdd: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamAddPage())))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              children: [
                Text('${state.teams.length} takım · sadece ad ve ikon', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(decoration: InputDecoration(hintText: 'Takım ara', prefixIcon: const Icon(Icons.search), isDense: true, suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close))), onChanged: (value) => setState(() => _query = value)),
                const SizedBox(height: 12),
                if (teams.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Aramana uygun takım yok.'))),
                ...teams.map((team) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: TeamAvatar(team: team, size: 44),
                      title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${state.leagues.where((league) => league.teamIds.contains(team.id)).length} yarışmada'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeamDetailsPage(teamId: team.id))),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

class _EmptyTeams extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTeams({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.groups_outlined, size: 64, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 14), const Text('Henüz takım yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Takım yönetimi sade: sadece isim ve ikon yeterli.', textAlign: TextAlign.center), const SizedBox(height: 18), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('İlk takımı ekle'))])));
}
