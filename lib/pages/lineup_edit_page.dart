import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/league.dart';
import '../models/models.dart';

class LineupEditPage extends StatefulWidget {
  final String matchId;
  final bool isHome; // true => home, false => away
  const LineupEditPage({super.key, required this.matchId, required this.isHome});

  @override
  State<LineupEditPage> createState() => _LineupEditPageState();
}

class _LineupEditPageState extends State<LineupEditPage> {
  final Set<String> _selectedPlayers = {};
  String? _keeperId;

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
        body: const Center(child: Text('Maç başladı veya bitti. Kadro düzenlenemez.')),
      );
    }

    final team = state.findTeam(widget.isHome ? m.homeTeamId : m.awayTeamId);
    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kadro')),
        body: const Center(child: Text('Takım bulunamadı.')),
      );
    }

    // املأ التشكيلة الحالية إن وُجدت
    final current = widget.isHome ? m.homeLineup : m.awayLineup;
    if (_selectedPlayers.isEmpty && current != null) {
      _selectedPlayers.addAll(current.playerIds);
      _keeperId = current.keeperId;
    }

    return Scaffold(
      appBar: AppBar(title: Text('${team.icon} ${team.name} — Kadro Seç')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Oyuncular (11 kişi)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (team.players.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Oyuncu yok. Takım sayfasından oyuncu ekleyin.'),
              ),
            )
          else
            ...team.players.map((p) {
              final selected = _selectedPlayers.contains(p.id);
              return CheckboxListTile(
                title: Text(p.fullName),
                subtitle: Text('Güç: ${p.power.toStringAsFixed(2)}'),
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      if (_selectedPlayers.length < 11) {
                        _selectedPlayers.add(p.id);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maksimum 11 oyuncu.')),
                        );
                      }
                    } else {
                      _selectedPlayers.remove(p.id);
                    }
                  });
                },
              );
            }),

          const SizedBox(height: 16),
          Text('Kaleci (1 kişi)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (team.keepers.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kaleci yok. Takım sayfasından kaleci ekleyin.'),
              ),
            )
          else
            ...team.keepers.map((k) {
              return RadioListTile<String>(
                value: k.id,
                groupValue: _keeperId,
                onChanged: (v) => setState(() => _keeperId = v),
                title: Text(k.fullName),
                subtitle: Text('Kalecilik: ${k.keepingPower.toStringAsFixed(2)}'),
              );
            }),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            onPressed: () async {
              if (_selectedPlayers.length != 11) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tam olarak 11 oyuncu seçin.')),
                );
                return;
              }
              final keeperOk = _keeperId != null;
              if (!keeperOk) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bir kaleci seçin.')),
                );
                return;
              }
              await context.read<AppState>().setLineup(
                matchId: m.id,
                isHome: widget.isHome,
                playerIds: _selectedPlayers.toList(),
                keeperId: _keeperId,
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
