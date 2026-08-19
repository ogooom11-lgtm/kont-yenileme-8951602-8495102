import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../utils/helpers.dart';

class MatchTimeEditPage extends StatefulWidget {
  final String matchId;
  const MatchTimeEditPage({super.key, required this.matchId});

  @override
  State<MatchTimeEditPage> createState() => _MatchTimeEditPageState();
}

class _MatchTimeEditPageState extends State<MatchTimeEditPage> {
  DateTime? _date;
  TimeOfDay? _time;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.findMatchById(widget.matchId);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maç saati')),
        body: const Center(child: Text('Maç bulunamadı.')),
      );
    }
    if (m.status != MatchStatus.scheduled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maç saati')),
        body: const Center(child: Text('Sadece planlı maç düzenlenir.')),
      );
    }

    final current = m.startTime ?? DateTime.now().add(const Duration(hours: 1));
    if (!_ready) {
      _date = DateTime(current.year, current.month, current.day);
      _time = TimeOfDay(hour: current.hour, minute: current.minute);
      _ready = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Maç saatini düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Tarih'),
            subtitle: Text(formatDate(_date!)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date!,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Saat'),
            subtitle: Text('${two(_time!.hour)}:${two(_time!.minute)}'),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _time!,
              );
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            onPressed: () async {
              final start = DateTime(
                _date!.year,
                _date!.month,
                _date!.day,
                _time!.hour,
                _time!.minute,
              );
              final err = await context.read<AppState>().rescheduleMatch(
                    matchId: m.id,
                    newStart: start,
                    minGap: const Duration(hours: 48),
                  );
              if (!mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Kurallar:\n• Aynı gün aynı takıma ikinci maç yok.\n• Takımlar arasında en az 48 saat dinlenme.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
