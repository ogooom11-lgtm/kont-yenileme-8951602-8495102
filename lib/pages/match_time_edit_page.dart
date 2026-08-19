import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/league.dart';

class MatchTimeEditPage extends StatefulWidget {
  final String matchId;
  const MatchTimeEditPage({super.key, required this.matchId});

  @override
  State<MatchTimeEditPage> createState() => _MatchTimeEditPageState();
}

class _MatchTimeEditPageState extends State<MatchTimeEditPage> {
  DateTime? _date;
  TimeOfDay? _time;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.findMatchById(widget.matchId);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maç Saati')),
        body: const Center(child: Text('Maç bulunamadı.')),
      );
    }

    // لا تسمح بتعديل مباراة بدأت/انتهت
    if (m.status != MatchStatus.scheduled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maç Saati')),
        body: const Center(child: Text('Sadece planlı maçların saati düzenlenebilir.')),
      );
    }

    final league = state.leagues.firstWhere((lg) => lg.id == m.leagueId);
    final current = m.startTime ?? DateTime.now().add(const Duration(hours: 1));

    _date ??= DateTime(current.year, current.month, current.day);
    _time ??= TimeOfDay(hour: current.hour, minute: current.minute);

    return Scaffold(
      appBar: AppBar(title: const Text('Maç Saati Düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Tarih Seç'),
            subtitle: Text('${_date!.year}-${_two(_date!.month)}-${_two(_date!.day)}'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date!,
                firstDate: league.startDate,
                lastDate: league.endDate,
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Saat Seç'),
            subtitle: Text('${_two(_time!.hour)}:${_two(_time!.minute)}'),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _time!,
              );
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            onPressed: () async {
              final newStart = DateTime(
                _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute,
              );

              final err = await context.read<AppState>().rescheduleMatch(
                matchId: m.id,
                newStart: newStart,
                minGap: const Duration(hours: 60),
              );

              if (!mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Kurallar:\n• Aynı gün bir takım için iki maç olamaz.\n• Aynı takımın maçları arasında en az 60 saat olmalı.\n• Tarih lig aralığı içinde olmalı.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
