import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'team_add_page.dart';
import 'team_details_page.dart';

class TeamsPage extends StatelessWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takımlar'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TeamAddPage()),
          );
        },
        icon: const Icon(Icons.group_add),
        label: const Text('Takım ekle'),
      ),
      body: state.teams.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Henüz takım yok.\nSağ alttan ilk takımınızı ekleyin.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              itemCount: state.teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = state.teams[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(t.icon, style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(t.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${t.players.length} oyuncu · ${t.keepers.length} kaleci · güç ${t.teamPower.toStringAsFixed(1)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TeamDetailsPage(teamId: t.id),
                      ));
                    },
                  ),
                );
              },
            ),
    );
  }
}
