import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SectionTitle('Görünüm', Icons.palette_outlined),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: state.themeMode,
                  onChanged: (v) {
                    if (v != null) state.setThemeMode(v);
                  },
                  title: const Text('Sistem teması'),
                  secondary: const Icon(Icons.brightness_auto_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: state.themeMode,
                  onChanged: (v) {
                    if (v != null) state.setThemeMode(v);
                  },
                  title: const Text('Açık tema'),
                  secondary: const Icon(Icons.light_mode_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: state.themeMode,
                  onChanged: (v) {
                    if (v != null) state.setThemeMode(v);
                  },
                  title: const Text('Koyu tema'),
                  secondary: const Icon(Icons.dark_mode_outlined),
                ),
                SwitchListTile.adaptive(
                  value: state.compactCards,
                  onChanged: state.setCompactCards,
                  title: const Text('Kompakt maç kartları'),
                  subtitle: const Text('Daha fazla maçı tek ekranda göster'),
                  secondary: const Icon(Icons.view_agenda_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Maç motoru', Icons.sports_soccer_outlined),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: state.autoLiveSimulation,
                  onChanged: state.setAutoLiveSimulation,
                  title: const Text('Canlı maç simülasyonu'),
                  subtitle: const Text(
                      'Başlangıç saatinde maçları otomatik başlat ve 90 dakika oynat'),
                  secondary: const Icon(Icons.sensors_outlined),
                ),
                SwitchListTile.adaptive(
                  value: state.smartAutoAdvance,
                  onChanged: state.setSmartAutoAdvance,
                  title: const Text('Akıllı tur ilerletme'),
                  subtitle: const Text(
                      'Sonuçlar tamamlandığında grup ve eleme fikstürünü hazırla'),
                  secondary: const Icon(Icons.auto_awesome_outlined),
                ),
                SwitchListTile.adaptive(
                  value: state.confirmResults,
                  onChanged: state.setConfirmResults,
                  title: const Text('Sonuçtan önce onay iste'),
                  subtitle: const Text('Yanlış skor girişlerini engelle'),
                  secondary: const Icon(Icons.verified_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Veri ve yedek', Icons.shield_outlined),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Yedeği panoya kopyala'),
                  subtitle: Text('${state.teams.length} takım · ${state.leagues.length} turnuva'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: state.exportJson()));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tam yedek panoya kopyalandı.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined),
                  title: const Text('Yedekten geri yükle'),
                  subtitle: const Text('Panodaki JSON yedeğini içe aktar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _import(context, state),
                ),
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined,
                      color: Theme.of(context).colorScheme.error),
                  title: const Text('Tüm verileri temizle'),
                  subtitle: const Text('Takımlar, turnuvalar ve maçlar silinir'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _clear(context, state),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'KONT 3.0  •  Yerel ve özel\nVerilerin cihazında saklanır.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedekten geri yükle'),
        content: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '{"teams": [], "leagues": []}',
            labelText: 'JSON yedeği',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('İçe aktar'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty || !context.mounted) return;
    final error = await state.importJson(raw);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Yedek başarıyla geri yüklendi.')),
    );
  }

  Future<void> _clear(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Her şey silinsin mi?'),
        content: const Text(
            'Bu işlem tüm takımları, turnuvaları ve fikstürleri kalıcı olarak kaldırır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil ve sıfırla'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KONT tertemiz bir sayfa ile hazır.')),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
        ],
      ),
    );
  }
}
