import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

/// Eski adla uyumluluk.
class LeagueAddPage extends StatelessWidget {
  const LeagueAddPage({super.key});
  @override
  Widget build(BuildContext context) => const LeagueCreatePage();
}

class LeagueCreatePage extends StatefulWidget {
  const LeagueCreatePage({super.key});

  @override
  State<LeagueCreatePage> createState() => _LeagueCreatePageState();
}

class _LeagueCreatePageState extends State<LeagueCreatePage> {
  final _page = PageController();
  int _step = 0;
  static const _total = 4;

  final _titleCtrl = TextEditingController();
  Color _color = const Color(0xFF0B6E4F);
  String _icon = '🏆';
  LeagueFormat _format = LeagueFormat.leagueDouble;

  int _winPoints = 3;
  int _drawPoints = 1;
  int _losePoints = 0;
  int _groupCount = 2;
  int _qualifiers = 2;
  int _swissMatches = 3;

  final List<String> _selected = [];
  String _query = '';

  List<RankDefinition> _ranks = [];
  int _rankMin = 1;
  int _rankMax = 4;
  String _rankLabel = '';
  Color _rankColor = Colors.green;

  DateTime? _start;
  int _daysBetween = 3;
  RangeValues _hours = const RangeValues(16, 22);

  bool _creating = false;

  static const _icons = ['🏆', '⚽', '🌍', '⚡', '🌟', '🔥', '🛡️', '🥇'];
  static const _colors = [
    Color(0xFF0B6E4F),
    Color(0xFF1565C0),
    Color(0xFFB71C1C),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF004D40),
    Color(0xFF1A237E),
    Color(0xFF212121),
  ];

  @override
  void dispose() {
    _page.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _go(int next) async {
    if (next > _step && !_validateStep(_step)) return;
    setState(() => _step = next.clamp(0, _total - 1));
    await _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_titleCtrl.text.trim().isEmpty) {
          _toast('Turnuva adı girin.');
          return false;
        }
        return true;
      case 1:
        return true;
      case 2:
        if (_selected.length < _format.minTeams) {
          _toast('Bu format için en az ${_format.minTeams} takım seçin.');
          return false;
        }
        if (_format == LeagueFormat.swiss && _selected.length.isOdd) {
          _toast('Swiss formatında takım sayısı çift olmalı.');
          return false;
        }
        if (_format.hasGroups && _selected.length < _groupCount * 2) {
          _toast('Her grupta en az 2 takım olmalı.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _total - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Turnuva'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(
            value: (_step + 1) / _total,
            minHeight: 4,
            color: _color,
            backgroundColor: _color.withOpacity(0.15),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Text('Adım ${_step + 1}/$_total',
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text(
                  const ['Kimlik', 'Format', 'Takımlar', 'Takvim'][_step],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _stepIdentity(),
                _stepFormat(),
                _stepTeams(),
                _stepSchedule(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _go(_step - 1),
                        child: const Text('Geri'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _color),
                      onPressed: _creating
                          ? null
                          : () {
                              if (last) {
                                _create();
                              } else {
                                _go(_step + 1);
                              }
                            },
                      child: _creating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(last ? 'Turnuvayı Oluştur' : 'Devam'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepIdentity() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleCtrl,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Turnuva adı',
            hintText: 'Örn: Süper Lig 2026',
            prefixIcon: Icon(Icons.emoji_events_outlined),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Renk', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _colors
              .map((c) => GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      backgroundColor: c,
                      radius: 18,
                      child: _color == c
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        const Text('İkon', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _icons
              .map((e) => ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: _icon == e,
                    onSelected: (_) => setState(() => _icon = e),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _stepFormat() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Gerçekçi format seçin',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 4),
        Text('Her format kendi fikstür ve ilerleme kurallarıyla çalışır.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        ...LeagueFormat.values.map((f) {
          final sel = _format == f;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: sel
                  ? _color.withOpacity(0.12)
                  : Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: sel ? _color : Theme.of(context).dividerColor,
                  width: sel ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _format = f),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        sel ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: sel ? _color : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(f.subtitle, style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(f.example,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _color,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (_format.usesPoints) ...[
          const SizedBox(height: 8),
          const Text('Puanlama', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              _numBox('Galibiyet', _winPoints, (v) => _winPoints = v),
              const SizedBox(width: 8),
              _numBox('Beraberlik', _drawPoints, (v) => _drawPoints = v),
              const SizedBox(width: 8),
              _numBox('Mağlubiyet', _losePoints, (v) => _losePoints = v),
            ],
          ),
        ],
        if (_format.hasGroups) ...[
          const SizedBox(height: 16),
          Text('Grup sayısı: $_groupCount',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: _groupCount.toDouble(),
            min: 2,
            max: 8,
            divisions: 6,
            label: '$_groupCount grup',
            activeColor: _color,
            onChanged: (v) => setState(() => _groupCount = v.toInt()),
          ),
          if (_format.hasKnockout) ...[
            Text('Gruptan çıkan: $_qualifiers',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _qualifiers.toDouble(),
              min: 1,
              max: 4,
              divisions: 3,
              label: '$_qualifiers takım',
              activeColor: _color,
              onChanged: (v) => setState(() => _qualifiers = v.toInt()),
            ),
          ],
        ],
        if (_format == LeagueFormat.swiss) ...[
          const SizedBox(height: 8),
          Text('Her takım $_swissMatches maç oynar',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: _swissMatches.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            label: '$_swissMatches maç',
            activeColor: _color,
            onChanged: (v) => setState(() => _swissMatches = v.toInt()),
          ),
        ],
        if (_format.usesPoints) ...[
          const SizedBox(height: 12),
          const Text('Tablo renkleri (opsiyonel)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('ŞL / Avrupa / Düşme'),
                onPressed: () {
                  setState(() {
                    _ranks = [
                      RankDefinition(
                          minRank: 1,
                          maxRank: 4,
                          colorValue: 0xFF1B5E20,
                          label: 'Şampiyonlar Ligi'),
                      RankDefinition(
                          minRank: 5,
                          maxRank: 6,
                          colorValue: 0xFF0D47A1,
                          label: 'Avrupa Ligi'),
                      RankDefinition(
                          minRank: 18,
                          maxRank: 20,
                          colorValue: 0xFFB71C1C,
                          label: 'Küme düşme'),
                    ];
                  });
                },
              ),
              ActionChip(
                label: const Text('Dünya Kupası'),
                onPressed: () {
                  setState(() {
                    _ranks = [
                      RankDefinition(
                          minRank: 1,
                          maxRank: 2,
                          colorValue: 0xFF1B5E20,
                          label: 'Eleme turu'),
                    ];
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Etiket',
                  ),
                  onChanged: (v) => _rankLabel = v,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _rankMin,
                items: [
                  for (var i = 1; i <= 20; i++)
                    DropdownMenuItem(value: i, child: Text('$i'))
                ],
                onChanged: (v) => setState(() => _rankMin = v ?? 1),
              ),
              const Text(' - '),
              DropdownButton<int>(
                value: _rankMax,
                items: [
                  for (var i = 1; i <= 20; i++)
                    DropdownMenuItem(value: i, child: Text('$i'))
                ],
                onChanged: (v) => setState(() => _rankMax = v ?? 1),
              ),
              IconButton(
                onPressed: () {
                  if (_rankLabel.trim().isEmpty) return;
                  setState(() {
                    _ranks.add(RankDefinition(
                      minRank: _rankMin,
                      maxRank: _rankMax,
                      colorValue: _rankColor.value,
                      label: _rankLabel.trim(),
                    ));
                  });
                },
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          ..._ranks.map((r) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    radius: 8, backgroundColor: Color(r.colorValue)),
                title: Text(r.label),
                subtitle: Text('${r.minRank}–${r.maxRank}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _ranks.remove(r)),
                ),
              )),
        ],
      ],
    );
  }

  Widget _numBox(String label, int value, void Function(int) onChanged) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          DropdownButton<int>(
            isExpanded: true,
            value: value,
            items: [0, 1, 2, 3, 4, 5]
                .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                .toList(),
            onChanged: (v) => setState(() => onChanged(v ?? value)),
          ),
        ],
      ),
    );
  }

  Widget _stepTeams() {
    final state = context.watch<AppState>();
    final filtered = state.teams
        .where((t) => t.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Takım ara',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${_selected.length} seçili  ·  min ${_format.minTeams}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: _selected.length < 2
                    ? null
                    : () => setState(() => _selected.shuffle()),
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('Kura'),
              ),
            ],
          ),
        ),
        if (_selected.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < _selected.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(
                        '${i + 1}. ${state.findTeam(_selected[i])?.name ?? "?"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () =>
                          setState(() => _selected.removeAt(i)),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final t = filtered[i];
              final sel = _selected.contains(t.id);
              return CheckboxListTile(
                value: sel,
                secondary: Text(t.icon, style: const TextStyle(fontSize: 22)),
                title: Text(t.name),
                subtitle: Text('Güç ${t.teamPower.toStringAsFixed(1)}'),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(t.id);
                    } else {
                      _selected.remove(t.id);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stepSchedule() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Başlangıç tarihi'),
          subtitle: Text(_start == null
              ? 'Seçilmedi'
              : '${_start!.day}.${_start!.month}.${_start!.year}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: _start ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 6),
            );
            if (d != null) setState(() => _start = d);
          },
        ),
        const Divider(),
        Text(
          'Maç saatleri: ${_hours.start.toInt()}:00 – ${_hours.end.toInt()}:00',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        RangeSlider(
          values: _hours,
          min: 8,
          max: 24,
          divisions: 16,
          labels: RangeLabels(
            '${_hours.start.toInt()}:00',
            '${_hours.end.toInt()}:00',
          ),
          activeColor: _color,
          onChanged: (v) {
            if (v.end - v.start >= 2) setState(() => _hours = v);
          },
        ),
        const SizedBox(height: 8),
        Text('Turlar arası $_daysBetween gün',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Slider(
          value: _daysBetween.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          label: '$_daysBetween gün',
          activeColor: _color,
          onChanged: (v) => setState(() => _daysBetween = v.toInt()),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppTheme.seed.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Özet',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('• ${_titleCtrl.text.trim().isEmpty ? "Adsız" : _titleCtrl.text}'),
                Text('• ${_format.title}'),
                Text('• ${_selected.length} takım'),
                if (_format.hasGroups) Text('• $_groupCount grup'),
                if (_start != null)
                  Text('• Başlangıç ${_start!.day}.${_start!.month}.${_start!.year}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _create() async {
    if (!_validateStep(2)) {
      await _go(2);
      return;
    }
    if (_start == null) {
      _toast('Başlangıç tarihi seçin.');
      return;
    }
    setState(() => _creating = true);
    final err = await context.read<AppState>().createLeagueAndSchedule(
          title: _titleCtrl.text,
          format: _format,
          teamIds: List.of(_selected),
          startDate: _start!,
          startHour: _hours.start.toInt(),
          endHour: _hours.end.toInt(),
          daysBetweenRounds: _daysBetween,
          minGap: Duration(hours: (_daysBetween * 24) - 8),
          winPoints: _winPoints,
          drawPoints: _drawPoints,
          losePoints: _losePoints,
          leagueColorValue: _color.value,
          rankDefinitions: _ranks,
          groupCount: _groupCount,
          qualifiersPerGroup: _qualifiers,
          swissMatches: _swissMatches,
          icon: _icon,
        );
    if (!mounted) return;
    setState(() => _creating = false);
    if (err != null) {
      _toast(err);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Turnuva oluşturuldu. Fikstür hazır.')),
    );
  }
}
