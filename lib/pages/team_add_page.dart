import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

class TeamAddPage extends StatefulWidget {
  const TeamAddPage({super.key});

  @override
  State<TeamAddPage> createState() => _TeamAddPageState();
}

class _TeamAddPageState extends State<TeamAddPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _iconCtrl = TextEditingController(text: '🦊');
  final _teamPowerCtrl = TextEditingController(text: '5.00');

  // سنضيف لاعب/حارس/مدرّب كقوائم بسيطة (قابلة للإضافة ديناميكيًا)
  final List<Player> _players = [];
  final List<GoalKeeper> _keepers = [];
  Coach? _coach;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _teamPowerCtrl.dispose();
    super.dispose();
  }

  double? _parsePower(String s) {
    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null) return null;
    return double.parse(v.toStringAsFixed(2));
  }

  String? _validatePower(String? s) {
    final v = _parsePower(s ?? '');
    if (v == null) return 'Geçerli bir değer girin (1.00 - 8.00)';
    if (!isValidPower(v)) return 'Güç 1.00 ile 8.00 arasında olmalı';
    return null;
  }

  void _addPlayerDialog() {
    final name = TextEditingController();
    final power = TextEditingController(text: '5.00');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Oyuncu Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad Soyad')),
            const SizedBox(height: 8),
            TextField(controller: power, decoration: const InputDecoration(labelText: 'Güç (1.00 - 8.00)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(power.text.replaceAll(',', '.'));
              if (name.text.trim().isEmpty || p == null || !isValidPower(p)) return;
              setState(() {
                _players.add(Player(id: DateTime.now().toString(), fullName: name.text.trim(), power: double.parse(p.toStringAsFixed(2))));
              });
              Navigator.pop(context);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _addKeeperDialog() {
    final name = TextEditingController();
    final power = TextEditingController(text: '5.00');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kaleci Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad Soyad')),
            const SizedBox(height: 8),
            TextField(controller: power, decoration: const InputDecoration(labelText: 'Kalecilik Gücü (1.00 - 8.00)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(power.text.replaceAll(',', '.'));
              if (name.text.trim().isEmpty || p == null || !isValidPower(p)) return;
              setState(() {
                _keepers.add(GoalKeeper(id: DateTime.now().toString(), fullName: name.text.trim(), keepingPower: double.parse(p.toStringAsFixed(2))));
              });
              Navigator.pop(context);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _setCoachDialog() {
    final name = TextEditingController(text: _coach?.fullName ?? '');
    final iq   = TextEditingController(text: (_coach?.iqPower ?? 5.00).toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Teknik Direktör'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad Soyad')),
            const SizedBox(height: 8),
            TextField(controller: iq, decoration: const InputDecoration(labelText: 'Zeka Gücü (1.00 - 8.00)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(iq.text.replaceAll(',', '.'));
              if (name.text.trim().isEmpty || p == null || !isValidPower(p)) return;
              setState(() {
                _coach = Coach(id: DateTime.now().toString(), fullName: name.text.trim(), iqPower: double.parse(p.toStringAsFixed(2)));
              });
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 720;

    return Scaffold(
      appBar: AppBar(title: const Text('Ekip Ekle')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العمود الأيسر: بيانات الفريق الأساسية
                  Expanded(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Takım Adı'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Bu alan zorunludur' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _iconCtrl,
                          decoration: const InputDecoration(labelText: 'Simge (emoji)'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Bu alan zorunludur' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _teamPowerCtrl,
                          decoration: const InputDecoration(labelText: 'Takım Gücü (1.00 - 8.00)'),
                          validator: _validatePower,
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: _setCoachDialog,
                            icon: const Icon(Icons.school),
                            label: Text(_coach == null
                                ? 'Teknik Direktör Ayarla'
                                : 'Teknik Direktör: ${_coach!.fullName} (${_coach!.iqPower.toStringAsFixed(2)})'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16, height: 16),

                  // العمود الأيمن: اللاعبين والحراس
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text('Oyuncular', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              onPressed: _addPlayerDialog,
                              icon: const Icon(Icons.person_add),
                              tooltip: 'Oyuncu Ekle',
                            ),
                          ],
                        ),
                        Card(
                          elevation: 0,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _players.length,
                            itemBuilder: (_, i) {
                              final p = _players[i];
                              return ListTile(
                                dense: true,
                                title: Text(p.fullName),
                                trailing: Text(p.power.toStringAsFixed(2)),
                                leading: const Icon(Icons.person),
                                onLongPress: () {
                                  setState(() => _players.removeAt(i));
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Kaleciler', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              onPressed: _addKeeperDialog,
                              icon: const Icon(Icons.sports_soccer),
                              tooltip: 'Kaleci Ekle',
                            ),
                          ],
                        ),
                        Card(
                          elevation: 0,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _keepers.length,
                            itemBuilder: (_, i) {
                              final k = _keepers[i];
                              return ListTile(
                                dense: true,
                                title: Text(k.fullName),
                                trailing: Text(k.keepingPower.toStringAsFixed(2)),
                                leading: const Icon(Icons.shield_moon),
                                onLongPress: () {
                                  setState(() => _keepers.removeAt(i));
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              if (_coach == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen teknik direktör ekleyin.')),
                );
                return;
              }
              final tp = _parsePower(_teamPowerCtrl.text)!;
              await context.read<AppState>().addTeam(
                name: _nameCtrl.text,
                icon: _iconCtrl.text,
                teamPower: tp,
                players: _players,
                coach: _coach!,
                keepers: _keepers,
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
