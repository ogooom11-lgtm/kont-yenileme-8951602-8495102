import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/league.dart';
import '../models/models.dart';

class LeagueAddPage extends StatefulWidget {
  const LeagueAddPage({super.key});

  @override
  State<LeagueAddPage> createState() => _LeagueAddPageState();
}

class _LeagueAddPageState extends State<LeagueAddPage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // --- Temel Bilgiler ---
  final _titleCtrl = TextEditingController(text: '');
  Color _leagueColor = Colors.blue;
  String _leagueIcon = '🏆';

  // --- Format ve Kurallar ---
  LeagueType _type = LeagueType.league;
  int _roundsCount = 2; // كم مرة يلعب ضد الخصم (1=Tek, 2=Çift)
  List<RankDefinition> _rankRules = [];

  int _winPoints = 3;
  int _drawPoints = 1;
  int _losePoints = 0;
  int _rankMin = 1;
  int _rankMax = 1;
  String _rankLabel = '';
  Color _rankColor = Colors.green;
  int _substitutionCount = 5;

  // --- Takım Seçimi ---
  final List<String> _selectedTeamIds = []; // حولتها لقائمة للحفاظ على الترتيب (للقرعة)
  String _searchQuery = '';

  // --- Zamanlama ---
  DateTime? _start;
  int _daysBetweenMatches = 3;
  RangeValues _timeRange = const RangeValues(14, 22); // من الساعة 14 إلى 22

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) {
      setState(() => _start = d);
    }
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lig Rengi Seç'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Colors.blue, Colors.red, Colors.green, Colors.orange,
            Colors.purple, Colors.teal, Colors.black, Colors.indigo, Colors.amber
          ].map((c) => GestureDetector(
            onTap: () {
              setState(() => _leagueColor = c);
              Navigator.pop(ctx);
            },
            child: CircleAvatar(backgroundColor: c, radius: 24),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allTeams = appState.teams;

    // تصفية الفرق للعرض فقط
    final filteredDisplayTeams = allTeams.where((t) {
      final q = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Lig / Turnuva'),
        backgroundColor: _leagueColor.withOpacity(0.2),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Form(
            key: _formKey,
            child: Stepper(
              type: StepperType.vertical,
              physics: const ClampingScrollPhysics(),
              currentStep: _currentStep,
              onStepContinue: () {
                // تحديد رقم الخطوة الأخيرة بناءً على النوع
                // في الكأس (elimination) تكون 3، في الدوري (league/fixed) تكون 4
                final int lastStep = _type == LeagueType.elimination ? 3 : 4;

                if (_currentStep < 4) {
                  setState(() => _currentStep += 1);
                } else {
                  _createLeague();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                } else {
                  Navigator.pop(context);
                }
              },
              controlsBuilder: (context, details) {
                final bool isLastStep = _currentStep == 4; // آخر خطوة هي 4 دائماً

                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _leagueColor),
                        onPressed: details.onStepContinue,
                        icon: Icon(isLastStep ? Icons.check : Icons.arrow_forward),
                        label: Text(isLastStep ? 'Oluştur' : 'Devam Et'),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Geri'),
                        ),
                    ],
                  ),
                );
              },

              steps: [
                // --- ADIM 1 ---
                Step(
                  title: const Text('Temel Bilgiler'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.editing,
                  content: Column(
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Turnuva Adı',
                          hintText: 'Örn: Ramazan Kupası',
                          prefixIcon: const Icon(Icons.emoji_events),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Lütfen bir isim girin' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickColor,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(backgroundColor: _leagueColor, radius: 12),
                                    const SizedBox(width: 10),
                                    const Text('Renk Teması'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _leagueIcon,
                              decoration: InputDecoration(
                                labelText: 'Logo',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: ['🏆', '⚽', '🌍', '⚡', '🌟', '🔥', '🛡️'].map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, style: const TextStyle(fontSize: 22)),
                              )).toList(),
                              onChanged: (v) => setState(() => _leagueIcon = v!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- ADIM 2: Format ---
                Step(
                  title: const Text('Format ve Kurallar'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.editing,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SegmentedButton<LeagueType>(
                          segments: const [
                            ButtonSegment(
                              value: LeagueType.league,
                              label: Text('Lig'),
                              icon: Icon(Icons.list),
                            ),
                            ButtonSegment(
                              value: LeagueType.fixedMatches, // <--- الخيار الجديد
                              label: Text('Grup/Sabit'),
                              icon: Icon(Icons.grid_view),
                            ),
                            ButtonSegment(
                              value: LeagueType.elimination,
                              label: Text('Kupa'),
                              icon: Icon(Icons.emoji_events),
                            ),
                          ],



                          selected: {_type},
                          onSelectionChanged: (Set<LeagueType> newSelection) {
                            setState(() {
                              _type = newSelection.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // إذا كان دوري أو عدد ثابت من المباريات، نظهر إعدادات النقاط
                      if (_type == LeagueType.league || _type == LeagueType.fixedMatches) ...[
                        const SizedBox(height: 20),

                        // نص مختلف حسب النوع
                        Text(
                            _type == LeagueType.league
                                ? 'Her takım rakipleriyle kaç kez oynasın? (Devre Sayısı)'
                                : 'Her takım toplam kaç maç yapsın?',
                            style: const TextStyle(fontWeight: FontWeight.bold)
                        ),

                        Slider(
                          value: _roundsCount.toDouble(),
                          min: 1,
                          // في الدوري الحد الأقصى 6 دورات، في المباريات الثابتة الحد الأقصى 10 مباريات (أو حسب الرغبة)
                          max: _type == LeagueType.league ? 6 : 15,
                          divisions: _type == LeagueType.league ? 5 : 14,
                          label: '$_roundsCount ${_type == LeagueType.league ? 'Devre' : 'Maç'}',
                          activeColor: _leagueColor,
                          onChanged: (v) => setState(() => _roundsCount = v.toInt()),
                        ),

                        if (_type == LeagueType.league)
                          const Center(child: Text('1 = Tek Devre, 2 = Rövanşlı', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        else
                          const Center(child: Text('Dikkat: Takım sayısı maç sayısından fazla olmalı ve matematiksel olarak eşleşme mümkün olmalı.', style: TextStyle(color: Colors.redAccent, fontSize: 12))),

                        const SizedBox(height: 20),
                        const Text('Puanlama', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            _buildNumberInput('Galibiyet', _winPoints, (v) => _winPoints = v),
                            const SizedBox(width: 10),
                            _buildNumberInput('Beraberlik', _drawPoints, (v) => _drawPoints = v),
                            const SizedBox(width: 10),
                            _buildNumberInput('Yenilgi', _losePoints, (v) => _losePoints = v),
                          ],
                        ),
                      ] else ...[
                        // إعدادات الكأس (Elimination) تبقى كما هي
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange),
                              SizedBox(width: 10),
                              Expanded(child: Text('Eleme usulünde takımlar listedeki sıraya göre eşleşir. "Kura Çek" butonunu kullanın.')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // --- ADIM 3: Takımlar ve Kura ---
                Step(
                  title: const Text('Takımlar و Kura'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.editing,
                  content: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Takım ara...',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // زر القرعة الجديد
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white
                            ),
                            icon: const Icon(Icons.shuffle),
                            label: const Text('Kura Çek'),
                            onPressed: _selectedTeamIds.length < 2 ? null : () {
                              setState(() {
                                _selectedTeamIds.shuffle();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Takımlar karıştırıldı (Kura Çekildi)!')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // القائمتين: المتاحة والمختارة
                      SizedBox(
                        height: 350,
                        child: Row(
                          children: [
                            // اليسار: الفرق المتاحة
                            Expanded(
                              child: Card(
                                child: Column(
                                  children: [
                                    const Padding(padding: EdgeInsets.all(8), child: Text('Tüm Takımlar', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: filteredDisplayTeams.length,
                                        itemBuilder: (ctx, i) {
                                          final team = filteredDisplayTeams[i];
                                          final isSelected = _selectedTeamIds.contains(team.id);
                                          if (isSelected) return const SizedBox.shrink(); // أخفها إذا اختيرت

                                          return ListTile(
                                            leading: Text(team.icon),
                                            title: Text(team.name, overflow: TextOverflow.ellipsis),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.add_circle, color: Colors.green),
                                              onPressed: () => setState(() => _selectedTeamIds.add(team.id)),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // اليمين: الفرق المختارة (الترتيب مهم)
                            Expanded(
                              child: Card(
                                color: Colors.grey.shade50,
                                child: Column(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(8),
                                        child: Text('Seçilenler (${_selectedTeamIds.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: ReorderableListView(
                                        onReorder: (oldIndex, newIndex) {
                                          setState(() {
                                            if (oldIndex < newIndex) newIndex -= 1;
                                            final item = _selectedTeamIds.removeAt(oldIndex);
                                            _selectedTeamIds.insert(newIndex, item);
                                          });
                                        },
                                        children: [
                                          for (final id in _selectedTeamIds)
                                            ListTile(
                                              key: ValueKey(id),
                                              tileColor: Colors.white,
                                              leading: Text('${_selectedTeamIds.indexOf(id) + 1}'),
                                              title: Text(appState.findTeam(id)?.name ?? '???'),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                                onPressed: () => setState(() => _selectedTeamIds.remove(id)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // steps: [...] listesinin içine, Takımlar adımından SONRA, Zamanlama adımından ÖNCE ekle:

// --- YENİ ADIM: SIRALAMA KURALLARI ---
                if (_type != LeagueType.elimination) // Sadece Lig ve Grup modunda göster
                  Step(
                    title: const Text('Tablo Renkleri & Kurallar'),
                    isActive: _currentStep >= 3,
                    state: _currentStep > 3 ? StepState.complete : StepState.editing,
                    content: _type == LeagueType.elimination
                        ? const Text("Bu adım Kupa modunda gerekli değildir, 'Devam Et'e basın.")
                        : Column(
                      children: [
                        const Text("Puan tablosunda belirli sıraları renklendirin."),
                        const SizedBox(height: 10),

                        // -- Kural Ekleme Alanı --
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      decoration: const InputDecoration(labelText: 'Başlık (Örn: Şampiyon)'),
                                      onChanged: (v) => _rankLabel = v,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () async {
                                      // Basit renk seçimi
                                      final c = await showDialog<Color>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Renk Seç"),
                                            content: Wrap(
                                              children: [Colors.green, Colors.red, Colors.blue, Colors.orange, Colors.purple, Colors.teal]
                                                  .map((cl) => GestureDetector(
                                                onTap: () => Navigator.pop(ctx, cl),
                                                child: Container(width: 40, height: 40, margin: const EdgeInsets.all(4), color: cl),
                                              )).toList(),
                                            ),
                                          )
                                      );
                                      if (c != null) setState(() => _rankColor = c);
                                    },
                                    child: Container(
                                      width: 40, height: 40,
                                      color: _rankColor,
                                      child: const Icon(Icons.colorize, color: Colors.white),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text("Sıra Aralığı: "),
                                  DropdownButton<int>(
                                    value: _rankMin,
                                    items: List.generate(20, (i) => i + 1).map((e) => DropdownMenuItem(value: e, child: Text("$e"))).toList(),
                                    onChanged: (v) => setState(() => _rankMin = v!),
                                  ),
                                  const Text(" - "),
                                  DropdownButton<int>(
                                    value: _rankMax,
                                    items: List.generate(20, (i) => i + 1).map((e) => DropdownMenuItem(value: e, child: Text("$e"))).toList(),
                                    onChanged: (v) => setState(() => _rankMax = v!),
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_rankLabel.isEmpty) return;
                                      setState(() {
                                        _rankRules.add(RankDefinition(
                                          minRank: _rankMin,
                                          maxRank: _rankMax,
                                          colorValue: _rankColor.value,
                                          label: _rankLabel,
                                        ));
                                      });
                                    },
                                    child: const Text("Ekle"),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // -- Eklenen Kurallar Listesi --
                        if (_rankRules.isNotEmpty)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _rankRules.length,
                            itemBuilder: (ctx, i) {
                              final r = _rankRules[i];
                              return ListTile(
                                leading: CircleAvatar(backgroundColor: Color(r.colorValue), radius: 10),
                                title: Text(r.label),
                                subtitle: Text("Sıralama: ${r.minRank} - ${r.maxRank}"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => setState(() => _rankRules.removeAt(i)),
                                ),
                              );
                            },
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Henüz kural eklenmedi.", style: TextStyle(color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),

                // --- ADIM 4: Zamanlama (Gelişmiş) ---
                Step(
                  title: const Text('Zamanlama'),
                  isActive: _currentStep >= 4,
                  state: _currentStep > 4 ? StepState.complete : StepState.editing,
                  content: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Başlangıç Tarihi'),
                        subtitle: Text(_start == null ? 'Seçilmedi' : '${_start!.day}.${_start!.month}.${_start!.year}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const Divider(),


                      // Maç Saati Aralığı
                      const SizedBox(height: 10),
                      Text(
                        'Maç Saatleri: ${_timeRange.start.toInt()}:00 - ${_timeRange.end.toInt()}:00',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RangeSlider(
                        values: _timeRange,
                        min: 0, max: 24, divisions: 24,
                        labels: RangeLabels(
                            '${_timeRange.start.toInt()}:00',
                            '${_timeRange.end.toInt()}:00'
                        ),
                        activeColor: _leagueColor,
                        onChanged: (v) {
                          if (v.end - v.start >= 2) { // على الأقل ساعتين فرق
                            setState(() => _timeRange = v);
                          }
                        },
                      ),
                      const Text('Sadece bu saat aralığına maç atanır.', style: TextStyle(fontSize: 12, color: Colors.grey)),

                      const SizedBox(height: 20),
                      Text('Maç Sıklığı (Her $_daysBetweenMatches günde bir)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: _daysBetweenMatches.toDouble(),
                        min: 1, max: 7, divisions: 6,
                        activeColor: _leagueColor,
                        label: '$_daysBetweenMatches Gün',
                        onChanged: (v) => setState(() => _daysBetweenMatches = v.toInt()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberInput(String label, int value, Function(int) onChanged) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              items: [0, 1, 2, 3, 4, 5, 10].map((e) => DropdownMenuItem(value: e, child: Center(child: Text(e.toString())))).toList(),
              onChanged: (v) => setState(() => onChanged(v!)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Başlangıç tarihi seçin.')));
      return;
    }
    if (_selectedTeamIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az 2 takım seçin.')));
      return;
    }

    // --- تحقق خاص بوضع المباريات الثابتة ---
    if (_type == LeagueType.fixedMatches) {
      // 1. لا يمكن للفريق أن يلعب مباريات أكثر من عدد الخصوم المتاحين
      if (_roundsCount >= _selectedTeamIds.length) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: ${_selectedTeamIds.length} takım var, bir takım en fazla ${_selectedTeamIds.length - 1} maç yapabilir.')));
        return;
      }
      // 2. لضمان عدالة التوزيع في هذه الخوارزمية البسيطة، يفضل عدد زوجي من الفرق
      if (_selectedTeamIds.length % 2 != 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hata: "Grup/Sabit Maç" modunda eşit dağılım için Takım Sayısı ÇİFT (2, 4, 6...) olmalıdır.')));
        return;
      }
    }

    // ... باقي الكود كما هو ...
    final err = await context.read<AppState>().createLeagueAndSchedule(
      title: _titleCtrl.text,
      type: _type,
      teamIds: _selectedTeamIds,
      startDate: _start!,
      rounds: _roundsCount, // سيتم استخدامه كعدد المباريات في الوضع الجديد
      startHour: _timeRange.start.toInt(),
      endHour: _timeRange.end.toInt(),
      minGap: Duration(hours: (_daysBetweenMatches * 24) - 12),
      winPoints: _winPoints,
      drawPoints: _drawPoints,
      losePoints: _losePoints,
      leagueColorValue: _leagueColor.value,
      rankDefinitions: _rankRules, // <--- BURAYI EKLE
    );
    // ...

    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }
}