import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/helpers.dart';

class TeamAddPage extends StatefulWidget {
  const TeamAddPage({super.key});

  @override
  State<TeamAddPage> createState() => _TeamAddPageState();
}

class _TeamAddPageState extends State<TeamAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _icon = '🦊';
  double _power = 5;
  final _players = <Player>[];
  final _keepers = <GoalKeeper>[];
  Coach? _coach;

  static const _icons = [
    '🦊', '🐺', '🦁', '🦅', '🐉', '🐯', '🐻', '🦈',
    '⚡', '🔥', '🛡️', '⭐', '🎯', '💎', '🌙', '☀️',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Takım')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Takım adı'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null,
            ),
            const SizedBox(height: 16),
            const Text('Arma', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons
                  .map((e) => ChoiceChip(
                        label: Text(e, style: const TextStyle(fontSize: 20)),
                        selected: _icon == e,
                        onSelected: (_) => setState(() => _icon = e),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('Takım gücü: ${_power.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _power,
              min: 1,
              max: 8,
              divisions: 70,
              label: _power.toStringAsFixed(2),
              onChanged: (v) => setState(() => _power = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school),
              title: Text(_coach == null
                  ? 'Teknik direktör ekle'
                  : '${_coach!.fullName}  (${_coach!.iqPower.toStringAsFixed(1)})'),
              trailing: const Icon(Icons.edit),
              onTap: _editCoach,
            ),
            const Divider(),
            _header('Oyuncular', Icons.person_add, _addPlayer),
            ..._players.map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person),
                  title: Text(p.fullName),
                  trailing: Text(p.power.toStringAsFixed(1)),
                  onLongPress: () => setState(() => _players.remove(p)),
                )),
            const SizedBox(height: 8),
            _header('Kaleciler', Icons.sports_handball, _addKeeper),
            ..._keepers.map((k) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield),
                  title: Text(k.fullName),
                  trailing: Text(k.keepingPower.toStringAsFixed(1)),
                  onLongPress: () => setState(() => _keepers.remove(k)),
                )),
            const SizedBox(height: 8),
            Text(
              'İpucu: satırı uzun basarak silebilirsiniz. 11 oyuncu şart değil.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  Widget _header(String t, IconData icon, VoidCallback onAdd) {
    return Row(
      children: [
        Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        IconButton(onPressed: onAdd, icon: Icon(icon)),
      ],
    );
  }

  Future<void> _personDialog({
    required String title,
    required void Function(String name, double power) onOk,
  }) async {
    final name = TextEditingController();
    var power = 5.0;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ad soyad'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Text('Güç: ${power.toStringAsFixed(2)}'),
              Slider(
                value: power,
                min: 1,
                max: 8,
                divisions: 70,
                onChanged: (v) => setS(() => power = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                onOk(name.text.trim(), double.parse(power.toStringAsFixed(2)));
                Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _addPlayer() {
    _personDialog(
      title: 'Oyuncu ekle',
      onOk: (n, p) => setState(() {
        _players.add(Player(id: newId(), fullName: n, power: p));
      }),
    );
  }

  void _addKeeper() {
    _personDialog(
      title: 'Kaleci ekle',
      onOk: (n, p) => setState(() {
        _keepers.add(GoalKeeper(id: newId(), fullName: n, keepingPower: p));
      }),
    );
  }

  void _editCoach() {
    _personDialog(
      title: 'Teknik direktör',
      onOk: (n, p) => setState(() {
        _coach = Coach(id: newId(), fullName: n, iqPower: p);
      }),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _coach ??= Coach(id: newId(), fullName: 'Teknik Direktör', iqPower: 5);
    await context.read<AppState>().addTeam(
          name: _nameCtrl.text,
          icon: _icon,
          teamPower: double.parse(_power.toStringAsFixed(2)),
          players: _players,
          coach: _coach!,
          keepers: _keepers,
        );
    if (mounted) Navigator.pop(context);
  }
}
