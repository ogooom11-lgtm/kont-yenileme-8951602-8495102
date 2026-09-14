import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';

class LineupEditPage extends StatefulWidget {
  final String matchId;
  final bool isHome;
  const LineupEditPage({super.key, required this.matchId, required this.isHome});

  @override
  State<LineupEditPage> createState() => _LineupEditPageState();
}

class _LineupEditPageState extends State<LineupEditPage> {
  final Set<String> _selected = {};
  String? _keeperId;
  bool _inited = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.findMatchById(widget.matchId);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kadro')),
        body: const Center(child: Text('Maç bulunamadı.')),
      );
    }
    if (m.status != MatchStatus.scheduled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kadro')),
        body: const Center(child: Text('Maç başladı veya bitti.')),
      );
    }
    final team = state.findTeam(widget.isHome ? m.homeTeamId : m.awayTeamId);
    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kadro')),
        body: const Center(child: Text('Takım bulunamadı.')),
      );
    }

    if (!_inited) {
      final current = widget.isHome ? m.homeLineup : m.awayLineup;
      if (current != null) {
        _selected.addAll(current.playerIds);
        _keeperId = current.keeperId;
      }
      _inited = true;
    }

    final maxPlayers = team.players.length < 11 ? team.players.length : 11;

    return Scaffold(
      appBar: AppBar(title: Text('${team.icon} ${team.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Oyuncular  (${_selected.length}/$maxPlayers)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (team.players.isEmpty)
            const ListTile(title: Text('Oyuncu yok. Takım sayfasından ekleyin.')),
          ...team.players.map((p) {
            final on = _selected.contains(p.id);
            return CheckboxListTile(
              value: on,
              title: Text(p.fullName),
              subtitle: Text('Güç ${p.power.toStringAsFixed(2)}'),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    if (_selected.length < maxPlayers) {
                      _selected.add(p.id);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('En fazla $maxPlayers oyuncu.')),
                      );
                    }
                  } else {
                    _selected.remove(p.id);
                  }
                });
              },
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Kaleci', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (team.keepers.isEmpty)
            const ListTile(title: Text('Kaleci yok.')),
          ...team.keepers.map((k) => RadioListTile<String>(
                value: k.id,
                groupValue: _keeperId,
                onChanged: (v) => setState(() => _keeperId = v),
                title: Text(k.fullName),
                subtitle: Text('Kalecilik ${k.keepingPower.toStringAsFixed(2)}'),
              )),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            onPressed: () async {
              if (maxPlayers > 0 && _selected.length != maxPlayers) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tam $maxPlayers oyuncu seçin.')),
                );
                return;
              }
              if (team.keepers.isNotEmpty && _keeperId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bir kaleci seçin.')),
                );
                return;
              }
              final error = await context.read<AppState>().setLineup(
                    matchId: m.id,
                    isHome: widget.isHome,
                    playerIds: _selected.toList(),
                    keeperId: _keeperId,
                  );
              if (!context.mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error)));
                return;
              }
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
