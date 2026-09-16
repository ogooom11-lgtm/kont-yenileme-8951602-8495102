import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

/// Eski adla uyumluluk.
class LeagueAddPage extends StatelessWidget {
  const LeagueAddPage({super.key});
  @override
  Widget build(BuildContext context) => const LeagueCreatePage();
}

/// Turnuva kurulumunun kısa ve anlaşılır akışı:
/// kimlik → format ve takımlar → fikstür kuralları.
class LeagueCreatePage extends StatefulWidget {
  const LeagueCreatePage({super.key});

  @override
  State<LeagueCreatePage> createState() => _LeagueCreatePageState();
}

class _LeagueCreatePageState extends State<LeagueCreatePage> {
  final _pageController = PageController();
  final _titleController = TextEditingController();
  int _step = 0;
  bool _saving = false;

  LeagueFormat _format = LeagueFormat.leagueDouble;
  String _icon = '🏆';
  Color _color = AppTheme.seed;
  final List<String> _selected = [];
  String _query = '';

  DateTime? _start;
  RangeValues _hours = const RangeValues(16, 22);
  int _roundGap = 7;
  int _minRest = 48;
  int _winPoints = 3;
  int _drawPoints = 1;
  int _losePoints = 0;
  int _groupCount = 2;
  final int _qualifiers = 2;
  int _swissMatches = 3;
  bool _randomizeDraw = true;
  bool _customKnockoutEntries = false;
  bool _seededKnockoutDraw = true;
  final Map<String, MatchStage> _entryStages = {};
  bool _autoAdvance = true;
  bool _extraTime = true;
  bool _penalties = true;
  bool _thirdPlace = false;
  String _notes = '';

  static const _icons = ['🏆', '⚽', '🌍', '🔥', '⚡', '🌟', '🥇', '🛡️'];
  static const _colors = [
    Color(0xFF0B6E4F), Color(0xFF1565C0), Color(0xFFB71C1C),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF142C3D),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['Kimlik', 'Format ve takımlar', 'Kurallar'];
    final last = _step == labels.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni yarışma'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(value: (_step + 1) / labels.length, color: _color),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Row(
              children: [
                Text('Adım ${_step + 1}/${labels.length}', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text(labels[_step], style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_identityStep(), _formatAndTeamsStep(), _rulesStep()],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(child: OutlinedButton(onPressed: () => _go(_step - 1), child: const Text('Geri'))),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _color),
                      onPressed: _saving ? null : () => last ? _create() : _go(_step + 1),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(last ? 'Yarışmayı oluştur' : 'Devam et'),
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

  Future<void> _go(int next) async {
    if (next > _step && !_validate(_step)) return;
    setState(() => _step = next.clamp(0, 2).toInt());
    await _pageController.animateToPage(_step, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  bool _validate(int step) {
    if (step == 0) {
      if (_titleController.text.trim().isEmpty) {
        _toast('Yarışma adı girin.');
        return false;
      }
    }
    if (step == 1) {
      if (_selected.length < _format.minTeams) {
        _toast('${_format.title} için en az ${_format.minTeams} takım seçin.');
        return false;
      }
      if (_format == LeagueFormat.swiss && (_selected.length.isOdd || _swissMatches >= _selected.length)) {
        _toast('Sabit maç formatında takım sayısı çift, maç sayısı takım sayısından küçük olmalı.');
        return false;
      }
      if (_format.hasGroups && _selected.length < _groupCount * 2) {
        _toast('Her grupta en az iki takım olmalı.');
        return false;
      }
      if (_format.hasGroups && _format.hasKnockout && _qualifiers != 2) {
        _toast('Gruplu elemede her gruptan iki takım çıkmalıdır.');
        return false;
      }
    }
    if (step == 2 && _start == null) {
      _toast('Başlangıç tarihi seçin.');
      return false;
    }
    return true;
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Widget _identityStep() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          Center(
            child: Container(
              width: 108,
              height: 108,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: _color.withValues(alpha: 0.3), width: 2)),
              child: Text(_icon, style: const TextStyle(fontSize: 50)),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Yarışma adı', hintText: 'Örn: Al Wakrah Kupası 2026', prefixIcon: Icon(Icons.emoji_events_outlined)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          const Text('Renk', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, children: _colors.map((item) => GestureDetector(
            onTap: () => setState(() => _color = item),
            child: CircleAvatar(backgroundColor: item, radius: 19, child: _color == item ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
          )).toList()),
          const SizedBox(height: 22),
          const Text('İkon', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _icons.map((item) => ChoiceChip(label: Text(item, style: const TextStyle(fontSize: 21)), selected: _icon == item, onSelected: (_) => setState(() => _icon = item))).toList()),
          const SizedBox(height: 24),
          Card(color: _color.withValues(alpha: 0.08), child: const Padding(padding: EdgeInsets.all(16), child: Text('Önce kimliğini oluştur. Sonraki adımda KONT, seçtiğin takımlara göre doğru fikstürü ve turnuva haritasını hazırlayacak.'))),
        ],
      );

  bool get _isDirectCup =>
      _format == LeagueFormat.cupSingle || _format == LeagueFormat.cupTwoLegged;

  MatchStage _defaultEntryStage() =>
      MatchStageX.fromTeamCount(nextPowerOfTwo(_selected.length.clamp(2, 64).toInt()));

  MatchStage _entryStageFor(String teamId) =>
      _entryStages[teamId] ?? _defaultEntryStage();

  Map<String, MatchStage> _selectedEntryStages() => {
        for (final teamId in _selected) teamId: _entryStageFor(teamId),
      };

  String _entryStageDescription(MatchStage stage) => switch (stage) {
        MatchStage.roundOf64 => '64 takım / eleme turu',
        MatchStage.roundOf32 => '32 takım / eleme turu',
        MatchStage.roundOf16 => '16 takım / son 16',
        MatchStage.quarterFinal => '8 takım / çeyrek final',
        MatchStage.semiFinal => '4 takım / yarı final',
        MatchStage.finalMatch => '2 takım / final',
        _ => stage.label(),
      };

  Widget _knockoutEntrySettings(AppState state) {
    final sortedIds = List<String>.from(_selected);
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.alt_route_outlined),
              title: Text('Giriş turları', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Takımların hangi eleme aşamasında başlayacağını belirle.'),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: false,
              groupValue: _customKnockoutEntries,
              onChanged: (_) => setState(() {
                _customKnockoutEntries = false;
                _entryStages.clear();
              }),
              title: const Text('Herkes ilk uygun turdan başlasın'),
              subtitle: const Text('KONT takım sayısına göre son 32, son 16 veya çeyrek finali seçer.'),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: true,
              groupValue: _customKnockoutEntries,
              onChanged: (_) => setState(() => _customKnockoutEntries = true),
              title: const Text('Takımlara özel giriş turu ver'),
              subtitle: const Text('Örneğin bazı takımlar son 16\'dan, bazıları son 32\'den başlasın.'),
            ),
            if (_customKnockoutEntries) ...[
              const Divider(height: 18),
              Text('Takım başlangıçları', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Daha ileri başlayan takım, önceki turları oynamadan kuraya katılır. Bay geçişleri otomatik hesaplanır.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              ...sortedIds.map((teamId) {
                final team = state.findTeam(teamId);
                final value = _entryStageFor(teamId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<MatchStage>(
                    value: value,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: team?.name ?? 'Takım',
                      prefixIcon: Text(team?.icon ?? '⚽', style: const TextStyle(fontSize: 20)),
                      helperText: _entryStageDescription(value),
                    ),
                    items: knockoutStageOrder
                        .map((stage) => DropdownMenuItem(value: stage, child: Text(stage.label())))
                        .toList(),
                    onChanged: (next) {
                      if (next == null) return;
                      setState(() => _entryStages[teamId] = next);
                    },
                  ),
                );
              }),
              Card(
                color: _color.withValues(alpha: 0.08),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Not: Ayarlar gerçekçi bir bracket oluşturmak için kontrol edilir. Finalde iki takım kalmıyorsa KONT dağılımı kabul etmez.'),
                ),
              ),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Seribaşı yerleşimi'),
              subtitle: const Text('Takım seçim sırasını koru; güçlü takımları erken eşleştirme.'),
              value: _seededKnockoutDraw,
              onChanged: (value) => setState(() => _seededKnockoutDraw = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatAndTeamsStep() {
    final state = context.watch<AppState>();
    final query = _query.trim().toLowerCase();
    final visible = state.teams.where((team) => team.name.toLowerCase().contains(query)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text('Formatı seç', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...LeagueFormat.values.map((format) => _formatCard(format)),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('${_selected.length} takım seçili  ·  minimum ${_format.minTeams}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(onPressed: state.teams.isEmpty ? null : () => setState(() => _selected..clear()..addAll(state.teams.map((team) => team.id))), child: const Text('Tümünü seç')),
          ],
        ),
        TextField(decoration: const InputDecoration(hintText: 'Takım ara', prefixIcon: Icon(Icons.search), isDense: true), onChanged: (value) => setState(() => _query = value)),
        const SizedBox(height: 8),
        if (_selected.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(scrollDirection: Axis.horizontal, children: [for (final id in _selected) Padding(padding: const EdgeInsets.only(right: 6), child: InputChip(label: Text(state.findTeam(id)?.name ?? '?'), onDeleted: () => setState(() => _selected.remove(id))))]),
          ),
        const Divider(height: 20),
        if (visible.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('Takım yok. Önce Takımlar sekmesinden en az iki takım ekleyin.', textAlign: TextAlign.center))
        else
          ...visible.map((team) => CheckboxListTile(
            value: _selected.contains(team.id),
            secondary: Text(team.icon, style: const TextStyle(fontSize: 24)),
            title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Sadece isim ve ikonla yönetilir'),
            onChanged: (value) => setState(() {
              if (value == true) {
                if (!_selected.contains(team.id)) _selected.add(team.id);
              } else {
                _selected.remove(team.id);
              }
            }),
          )),
        if (_isDirectCup) _knockoutEntrySettings(state),
      ],
    );
  }

  Widget _formatCard(LeagueFormat format) {
    final selected = _format == format;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? _color.withValues(alpha: 0.12) : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: selected ? _color : Theme.of(context).dividerColor, width: selected ? 2 : 1)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _format = format),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? _color : Colors.grey),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(format.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(format.subtitle, style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 3),
                  Text(format.example, style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
                ])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rulesStep() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Başlangıç tarihi', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(_start == null ? 'Seçilmedi' : '${_start!.day}.${_start!.month}.${_start!.year}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final now = DateTime.now();
              final date = await showDatePicker(context: context, initialDate: _start ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 6));
              if (date != null) setState(() => _start = date);
            },
          ),
          const Divider(),
          Text('Maç saatleri: ${_hours.start.toInt()}:00 – ${_hours.end.toInt()}:00', style: const TextStyle(fontWeight: FontWeight.w800)),
          RangeSlider(values: _hours, min: 8, max: 24, divisions: 16, labels: RangeLabels('${_hours.start.toInt()}:00', '${_hours.end.toInt()}:00'), activeColor: _color, onChanged: (value) { if (value.end - value.start >= 2) setState(() => _hours = value); }),
          Text('Haftalar/turlar arası $_roundGap gün', style: const TextStyle(fontWeight: FontWeight.w800)),
          Slider(value: _roundGap.toDouble(), min: 1, max: 14, divisions: 13, label: '$_roundGap gün', activeColor: _color, onChanged: (value) => setState(() => _roundGap = value.toInt())),
          Text('Takım başına minimum dinlenme $_minRest saat', style: const TextStyle(fontWeight: FontWeight.w800)),
          Slider(value: _minRest.toDouble(), min: 24, max: 96, divisions: 12, label: '$_minRest saat', activeColor: _color, onChanged: (value) => setState(() => _minRest = value.toInt())),
          if (_format.usesPoints) ...[
            const SizedBox(height: 8),
            const Text('Puanlama', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [_scoreSelect('Galibiyet', _winPoints, (value) => _winPoints = value), const SizedBox(width: 8), _scoreSelect('Beraberlik', _drawPoints, (value) => _drawPoints = value), const SizedBox(width: 8), _scoreSelect('Mağlubiyet', _losePoints, (value) => _losePoints = value)]),
          ],
          if (_format.hasGroups) ...[
            const SizedBox(height: 10),
            Text('Grup sayısı: $_groupCount', style: const TextStyle(fontWeight: FontWeight.w800)),
            Slider(value: _groupCount.toDouble(), min: 2, max: 8, divisions: 6, activeColor: _color, onChanged: (value) => setState(() => _groupCount = value.toInt())),
            if (_format.hasKnockout) Text('Gruptan çıkan: $_qualifiers takım', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (_format.hasKnockout) Text('Eleme turu için her gruptan 2 takım çıkar.', style: TextStyle(color: _color, fontWeight: FontWeight.w700)),
          ],
          if (_format == LeagueFormat.swiss) ...[
            const SizedBox(height: 8),
            Text('Takım başına $_swissMatches sabit maç', style: const TextStyle(fontWeight: FontWeight.w800)),
            Slider(value: _swissMatches.toDouble(), min: 1, max: 15, divisions: 14, activeColor: _color, onChanged: (value) => setState(() => _swissMatches = value.toInt())),
          ],
          if (_format.hasKnockout)
            Card(
              child: Column(children: [
                SwitchListTile.adaptive(title: const Text('Turları otomatik ilerlet'), subtitle: const Text('Maçlar tamamlanınca sonraki turu hazırla'), value: _autoAdvance, onChanged: (value) => setState(() => _autoAdvance = value)),
                SwitchListTile.adaptive(title: const Text('Uzatma'), value: _extraTime, onChanged: (value) => setState(() => _extraTime = value)),
                SwitchListTile.adaptive(title: const Text('Penaltı atışları'), value: _penalties, onChanged: (value) => setState(() => _penalties = value)),
                SwitchListTile.adaptive(title: const Text('Üçüncülük maçı'), subtitle: const Text('Yarı final kaybedenlerini karşılaştır'), value: _thirdPlace, onChanged: (value) => setState(() => _thirdPlace = value)),
              ]),
            ),
          if (_format.hasGroups)
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Grupları kura ile karıştır'), value: _randomizeDraw, onChanged: (value) => setState(() => _randomizeDraw = value)),
          const SizedBox(height: 8),
          TextField(maxLines: 2, decoration: const InputDecoration(labelText: 'Not (opsiyonel)', prefixIcon: Icon(Icons.notes_outlined)), onChanged: (value) => _notes = value),
          const SizedBox(height: 14),
          Card(color: _color.withValues(alpha: 0.09), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hazır mısın?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            Text('“${_titleController.text.isEmpty ? 'Yeni yarışma' : _titleController.text}” · ${_format.title} · ${_selected.length} takım'),
            Text(_format.hasKnockout ? 'Kupa haritası otomatik oluşacak.' : 'Fikstür ve puan tablosu otomatik oluşacak.'),
          ]))),
        ],
      );

  Widget _scoreSelect(String label, int value, void Function(int) onChanged) => Expanded(child: Column(children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), DropdownButton<int>(isExpanded: true, value: value, items: [0, 1, 2, 3, 4, 5].map((item) => DropdownMenuItem(value: item, child: Text('$item'))).toList(), onChanged: (newValue) => setState(() => onChanged(newValue ?? value))) ]));

  Future<void> _create() async {
    if (!_validate(1) || !_validate(2)) return;
    setState(() => _saving = true);
    final error = await context.read<AppState>().createLeagueAndSchedule(
      title: _titleController.text,
      format: _format,
      teamIds: List.of(_selected),
      startDate: _start!,
      startHour: _hours.start.toInt(),
      endHour: _hours.end.toInt(),
      daysBetweenRounds: _roundGap,
      minGap: Duration(hours: _minRest),
      winPoints: _winPoints,
      drawPoints: _drawPoints,
      losePoints: _losePoints,
      leagueColorValue: _color.toARGB32(),
      groupCount: _groupCount,
      qualifiersPerGroup: _qualifiers,
      swissMatches: _swissMatches,
      icon: _icon,
      autoAdvance: _autoAdvance,
      allowExtraTime: _extraTime,
      allowPenalties: _penalties,
      randomizeDraw: _randomizeDraw,
      minRestHours: _minRest,
      thirdPlaceMatch: _thirdPlace,
      knockoutEntryStages: _customKnockoutEntries ? _selectedEntryStages() : const {},
      seededKnockoutDraw: _seededKnockoutDraw,
      notes: _notes,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      _toast(error);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yarışma oluşturuldu. Fikstür ve kupa haritası hazır.')));
  }
}
