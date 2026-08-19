import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/league.dart';
import '../models/models.dart';
import 'match_details_page.dart';

class LeagueDetailsPage extends StatelessWidget {
  final String leagueId;

  const LeagueDetailsPage({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Ligi bul, yoksa hata gösterme
    final league = state.leagues.firstWhere(
          (l) => l.id == leagueId,
      orElse: () => throw Exception("Lig bulunamadı"),
    );

    final color = Color(league.leagueColorValue);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: color,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(league.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                      )),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withOpacity(0.8), color],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        league.type == LeagueType.league
                            ? Icons.table_chart
                            : Icons.emoji_events,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                bottom: const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(icon: Icon(Icons.dashboard), text: "Genel"),
                    Tab(icon: Icon(Icons.list), text: "Fikstür"),
                    Tab(icon: Icon(Icons.show_chart), text: "Durum"),
                    Tab(icon: Icon(Icons.analytics), text: "İstatistik"),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      // Buraya lig ayarları veya silme işlemi eklenebilir
                      _showSettingsDialog(context, state, league);
                    },
                  )
                ],
              ),
            ];
          },
          body: TabBarView(
            children: [
              _OverviewTab(league: league),
              _MatchesListTab(league: league),
              league.type != LeagueType.elimination // Eşleşme değilse (Lig veya Grup ise) Tablo göster
                  ? _StandingsTab(league: league)
                  : _CupBracketTab(league: league),
              _StatsTab(league: league),
            ],
          ),
        ),
      ),
    );
  }

  // في ملف league_details_page.dart
// استبدل الدالة القديمة _showSettingsDialog بهذا الكود الجديد:

  void _showSettingsDialog(BuildContext context, AppState state, League league) {
    final nameController = TextEditingController(text: league.title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lig Ayarları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // حقل تعديل الاسم
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Turnuva Adı',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 20),
            // رسالة تحذير للحذف
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ligi sildiğinizde tüm maçlar ve istatistikler kalıcı olarak silinir.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // زر الحذف (أحمر)
          TextButton.icon(
            onPressed: () async {
              // تأكيد الحذف مرة أخرى
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (c) => AlertDialog(
                  title: const Text('Emin misiniz?'),
                  content: const Text('Bu işlem geri alınamaz!'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Evet, Sil')),
                  ],
                ),
              );

              if (confirm == true) {
                // 1. أغلق الـ Dialog
                Navigator.pop(ctx);
                // 2. عد للصفحة الرئيسية لتجنب الخطأ لأن الدوري سيختفي
                Navigator.pop(context);
                // 3. نفذ الحذف
                state.deleteLeague(league.id);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lig başarıyla silindi.')),
                );
              }
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Ligi Sil', style: TextStyle(color: Colors.red)),
          ),

          // زر الإلغاء
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),

          // زر الحفظ (لتغيير الاسم)
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                state.updateLeagueName(league.id, nameController.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('İsim güncellendi.')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

// --- TAB 1: GENEL BAKIŞ ---
class _OverviewTab extends StatelessWidget {
  final League league;
  const _OverviewTab({required this.league});

  @override

  Widget build(BuildContext context) {
    final totalMatches = league.matches.length;
    final finishedMatches = league.matches.where((m) => m.status == MatchStatus.finished).length;
    final progress = totalMatches == 0 ? 0.0 : finishedMatches / totalMatches;

    // Bir sonraki maç
    final upcoming = league.matches
        .where((m) => m.status == MatchStatus.scheduled || m.status == MatchStatus.live)
        .toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));

    final nextMatch = upcoming.isNotEmpty ? upcoming.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İlerleme Kartı
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Turnuva İlerlemesi', style: Theme.of(context).textTheme.titleMedium),
                      Text('%${(progress * 100).toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    color: Color(league.leagueColorValue),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 10),
                  Text('$finishedMatches / $totalMatches Maç Tamamlandı', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sıradaki Maç
          Text('Sıradaki Maç', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (nextMatch != null)
            _MatchCard(match: nextMatch, showDate: true)
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text("Planlanmış maç kalmadı, turnuva tamamlandı!")),
              ),
            ),
        ],
      ),
    );
  }
}

// --- TAB 2: MAÇ LİSTESİ ---
class _MatchesListTab extends StatelessWidget {
  final League league;
  const _MatchesListTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final matches = List<MatchGame>.from(league.matches);
    // Tarihe göre sırala
    matches.sort((a, b) => (a.startTime ?? DateTime.now()).compareTo(b.startTime ?? DateTime.now()));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: matches.length,
      itemBuilder: (ctx, i) {
        return _MatchCard(match: matches[i], showDate: true);
      },
    );
  }
}

// --- TAB 3 (LİG): PUAN DURUMU ---
// --- TAB 3 (LİG): PUAN DURUMU ---
class _StandingsTab extends StatelessWidget {
  final League league;
  const _StandingsTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Puan Durumu Hesaplama Mantığı
    List<LeagueTableItem> table = [];

    for (var teamId in league.teamIds) {
      final team = state.findTeam(teamId);
      if (team == null) continue;

      final item = LeagueTableItem(
          teamId: team.id,
          teamName: team.name,
          teamIcon: team.icon
      );

      // Maçları tara
      for (var m in league.matches) {
        if (m.status != MatchStatus.finished) continue;

        if (m.homeTeamId == teamId) {
          item.played++;
          item.goalsFor += m.homeGoals;
          item.goalsAgainst += m.awayGoals;
          if (m.homeGoals > m.awayGoals) item.won++;
          else if (m.homeGoals == m.awayGoals) item.drawn++;
          else item.lost++;
        } else if (m.awayTeamId == teamId) {
          item.played++;
          item.goalsFor += m.awayGoals;
          item.goalsAgainst += m.homeGoals;
          if (m.awayGoals > m.homeGoals) item.won++;
          else if (m.awayGoals == m.homeGoals) item.drawn++;
          else item.lost++;
        }
      }
      table.add(item);
    }

    // Sıralama (Puan > Averaj > Atılan Gol)
    table.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
      return b.goalsFor.compareTo(a.goalsFor);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Takım', style: TextStyle(fontWeight: FontWeight.bold))),
            // DÜZELTME BURADA YAPILDI: tooltip parametresi DataColumn'a taşındı
            DataColumn(label: Text('O'), tooltip: 'Oynadığı'),
            DataColumn(label: Text('G'), tooltip: 'Galibiyet'),
            DataColumn(label: Text('B'), tooltip: 'Beraberlik'),
            DataColumn(label: Text('M'), tooltip: 'Mağlubiyet'),
            DataColumn(label: Text('A'), tooltip: 'Atılan'),
            DataColumn(label: Text('Y'), tooltip: 'Yenen'),
            DataColumn(label: Text('Av'), tooltip: 'Averaj'),
            DataColumn(label: Text('P', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
          ],
          // _StandingsTab sınıfının içindeki rows: List.generate kısmını şununla değiştir:

          rows: List.generate(table.length, (index) {
            final row = table[index];
            final rank = index + 1; // Sıralama (1'den başlar)

            // -- RENK KONTROLÜ --
            Color? rowColor;
            // Ligin içindeki özel kurallara bak
            for (var rule in league.rankDefinitions) {
              if (rank >= rule.minRank && rank <= rule.maxRank) {
                rowColor = Color(rule.colorValue).withOpacity(0.15); // Hafif şeffaf yap
                break;
              }
            }
            // Eğer özel kural yoksa ve ilk 3 ise varsayılan yeşil kalsın (opsiyonel)
            if (rowColor == null && index < 3 && league.rankDefinitions.isEmpty) {
              rowColor = Colors.green.withOpacity(0.05);
            }
            // -------------------

            return DataRow(
              color: rowColor != null ? WidgetStateProperty.all(rowColor) : null, // Rengi buraya ver
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Row(
                  children: [
                    Text(row.teamIcon),
                    const SizedBox(width: 8),
                    Text(row.teamName, style: const TextStyle(fontWeight: FontWeight.w500))
                  ],
                )),
                // ... Diğer hücreler aynı kalsın ...
                DataCell(Text('${row.played}')),
                DataCell(Text('${row.won}')),
                DataCell(Text('${row.drawn}')),
                DataCell(Text('${row.lost}')),
                DataCell(Text('${row.goalsFor}')),
                DataCell(Text('${row.goalsAgainst}')),
                DataCell(Text('${row.goalDifference}')),
                DataCell(Text('${row.points}', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            );
          }),
        ),
      ),
    );
  }
}


// --- TAB 3 (KUPA): EŞLEŞME AĞACI (Basitleştirilmiş) ---
class _CupBracketTab extends StatelessWidget {
  final League league;
  const _CupBracketTab({required this.league});

  @override
  Widget build(BuildContext context) {
    // Kupada maçları tarihe göre gruplayarak "Tur" mantığı oluşturabiliriz
    // Gerçek bir ağaç çizimi için harici paket gerekir, bu yüzden "Aşama Aşama" liste yapacağız.

    final sortedMatches = List<MatchGame>.from(league.matches)
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));

    if (sortedMatches.isEmpty) return const Center(child: Text("Henüz eşleşme yok."));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Eşleşmeler ve Sonuçlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        for (var match in sortedMatches)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _MatchCard(match: match, showDate: true),
          ),
      ],
    );
  }
}

// --- TAB 4: İSTATİSTİKLER (GOL KRALLIĞI) ---
class _StatsTab extends StatelessWidget {
  final League league;
  const _StatsTab({required this.league});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Golleri say
    Map<String, int> playerGoals = {};
    for (var m in league.matches) {
      if (m.status == MatchStatus.finished) {
        for (var entry in m.goalsByPlayer.entries) {
          playerGoals.update(entry.key, (v) => v + entry.value, ifAbsent: () => entry.value);
        }
      }
    }

    if (playerGoals.isEmpty) {
      return const Center(child: Text("Henüz gol istatistiği oluşmadı."));
    }

    // Sırala
    final sortedPlayers = playerGoals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Gol Krallığı', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (int i = 0; i < sortedPlayers.length; i++)
                Builder(builder: (ctx) {
                  final pId = sortedPlayers[i].key;
                  final count = sortedPlayers[i].value;

                  // Oyuncuyu bulmak biraz zor çünkü hangi takımda olduğunu bilmiyoruz direkt ID'den.
                  // Tüm takımları aramak gerekir (performans için ideal değil ama çalışır)
                  String pName = "Bilinmeyen Oyuncu";
                  String tIcon = "";

                  for(var t in state.teams) {
                    final p = t.players.firstWhere((pl) => pl.id == pId, orElse: () => Player(id: '', fullName: '', power: 0));
                    if (p.id.isNotEmpty) {
                      pName = p.fullName;
                      tIcon = t.icon;
                      break;
                    }
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i == 0 ? Colors.amber : Colors.grey.shade200,
                      child: Text('${i+1}', style: TextStyle(color: i == 0 ? Colors.white : Colors.black)),
                    ),
                    title: Text(pName),
                    subtitle: Text(tIcon),
                    trailing: Text('$count Gol', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                }),
            ],
          ),
        )
      ],
    );
  }
}

// --- YARDIMCI WIDGET: MATCH CARD ---
class _MatchCard extends StatelessWidget {
  final MatchGame match;
  final bool showDate;

  const _MatchCard({required this.match, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final home = state.findTeam(match.homeTeamId);
    final away = state.findTeam(match.awayTeamId);

    // Tarih formatı
    final d = match.startTime!;
    final dateStr = '${d.day}.${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchDetailsPage(matchId: match.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              if (showDate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
              Row(
                children: [
                  // Ev Sahibi
                  Expanded(
                    child: Column(
                      children: [
                        Text(home?.icon ?? '?', style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(home?.name ?? '???', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  // Skor
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                        color: match.status == MatchStatus.finished
                            ? Colors.grey.shade200
                            : (match.status == MatchStatus.live ? Colors.red.withOpacity(0.1) : Colors.transparent),
                        borderRadius: BorderRadius.circular(20),
                        border: match.status == MatchStatus.scheduled ? Border.all(color: Colors.grey.shade300) : null
                    ),
                    child: Text(
                      match.status == MatchStatus.scheduled ? 'VS' : '${match.homeGoals} - ${match.awayGoals}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: match.status == MatchStatus.live ? Colors.red : Colors.black87
                      ),
                    ),
                  ),

                  // Deplasman
                  Expanded(
                    child: Column(
                      children: [
                        Text(away?.icon ?? '?', style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(away?.name ?? '???', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              if (match.status == MatchStatus.live)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("• CANLI •", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                )
            ],
          ),
        ),
      ),
    );
  }
}