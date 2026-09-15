import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class TeamAddPage extends StatefulWidget {
  const TeamAddPage({super.key});

  @override
  State<TeamAddPage> createState() => _TeamAddPageState();
}

class _TeamAddPageState extends State<TeamAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _icon = '⚽';
  bool _saving = false;

  static const _icons = [
    '⚽', '🦁', '🦅', '🐺', '🐉', '🐯', '🦊', '🐻',
    '🦈', '🔥', '⚡', '⭐', '💎', '🛡️', '🌙', '☀️',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni takım')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.28), width: 2),
                ),
                child: Text(_icon, style: const TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Takım adı',
                hintText: 'Örn: Al Wakrah FC',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Takım adı gerekli'
                  : null,
            ),
            const SizedBox(height: 24),
            Text('Takım ikonunu seç',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _icons
                  .map(
                    (icon) => ChoiceChip(
                      label: Text(icon, style: const TextStyle(fontSize: 22)),
                      selected: _icon == icon,
                      onSelected: (_) => setState(() => _icon = icon),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Card(
              color: color.withOpacity(0.08),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Takımını oluşturmak için bu kadar yeterli. KONT maçları ve turnuvaları otomatik olarak düzenler.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Kaydediliyor...' : 'Takımı ekle'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await context.read<AppState>().addTeam(
          name: _nameController.text,
          icon: _icon,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }
}
