import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/league.dart';
import '../models/models.dart';

class TeamDetailsPage extends StatelessWidget {
  final String teamId;
  const TeamDetailsPage({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final team = state.findTeam(teamId);

    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: const Center(child: Text('Takım bulunamadı.')),
      );
    }

    // اللون الخاص بالفريق (عشوائي أو ثابت) - هنا نستخدم لوناً افتراضياً جميلاً
    const teamColor = Colors.indigo;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // داخل TeamDetailsPage -> build -> NestedScrollView -> SliverAppBar

              SliverAppBar(
                expandedHeight: 220.0,
                floating: false,
                pinned: true,
                backgroundColor: teamColor,
                // --- أضف هذا الجزء (actions) ---
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: 'Takımı Düzenle',
                    onPressed: () => _showEditTeamDialog(context, state, team),
                  ),
                ],
                // -----------------------------
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,

                  title: Text(team.name,
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
                        colors: [teamColor.shade300, teamColor.shade900],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40), // مساحة للـ AppBar
                          Text(team.icon, style: const TextStyle(fontSize: 70)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Toplam Güç: ${team.teamPower.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ],
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
                    Tab(icon: Icon(Icons.people), text: "Kadro"),
                    Tab(icon: Icon(Icons.emoji_events), text: "Ligler"),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _OverviewTab(team: team),
              _SquadTab(team: team),
              _LeaguesTab(team: team),
            ],
          ),
        ),
      ),
    );
  }
  void _showEditTeamDialog(BuildContext context, AppState state, Team team) {
    final nameController = TextEditingController(text: team.name);
    final iconController = TextEditingController(text: team.icon);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takım Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // حقل الأيقونة (صغير)
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: iconController,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'İkon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // حقل الاسم (كبير)
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Takım Adı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && iconController.text.isNotEmpty) {
                // استدعاء دالة التحديث من AppState
                state.updateTeam(team.id, nameController.text, iconController.text);

                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Takım bilgileri güncellendi.')),
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

// --- TAB 1: GENEL BAKIŞ (نظرة عامة) ---
class _OverviewTab extends StatelessWidget {
  final Team team;
  const _OverviewTab({required this.team});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.statsForTeam(team.id);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بطاقة المدرب
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(team.coach.fullName),
            subtitle: Text('Teknik Direktör (IQ: ${team.coach.iqPower})'),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editCoach(context, state, team),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // إحصائيات عامة
        const Text("Genel İstatistikler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatBox(label: "Maç", value: "${stats.played}", color: Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(label: "Galibiyet", value: "${stats.win}", color: Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(label: "Mağlubiyet", value: "${stats.lose}", color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatBox(label: "Atılan", value: "${stats.goalsFor}", color: Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(label: "Yenen", value: "${stats.goalsAgainst}", color: Colors.deepOrange)),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(label: "Averaj", value: "${stats.goalsFor - stats.goalsAgainst}", color: Colors.grey)),
          ],
        ),

        const SizedBox(height: 24),
        const Text("Son Maçlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        if (stats.matches.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text("Henüz maç yapılmadı."))
        else
          ...stats.matches.reversed.take(10).map((m) {
            final isHome = m.homeTeamId == team.id;
            final oppId = isHome ? m.awayTeamId : m.homeTeamId;
            final oppTeam = state.findTeam(oppId);
            final myGoals = isHome ? m.homeGoals : m.awayGoals;
            final oppGoals = isHome ? m.awayGoals : m.homeGoals;

            Color resColor = Colors.grey;
            if (m.status == MatchStatus.finished) {
              if (myGoals > oppGoals) resColor = Colors.green;
              else if (myGoals < oppGoals) resColor = Colors.red;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 4, height: 40, color: resColor,
                ),
                title: Text('${team.name} vs ${oppTeam?.name ?? "???"}'),
                trailing: Text('$myGoals - $oppGoals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: resColor)),
                subtitle: Text(m.status == MatchStatus.finished ? "Bitti" : "Planlandı"),
              ),
            );
          }),
      ],
    );
  }

  void _editCoach(BuildContext context, AppState state, Team team) {
    final nameCtrl = TextEditingController(text: team.coach.fullName);
    double power = team.coach.iqPower;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Teknik Direktör Düzenle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "İsim")),
              const SizedBox(height: 16),
              Text("Taktik Zekası (IQ): ${power.toStringAsFixed(1)}"),
              Slider(
                value: power, min: 1, max: 8, divisions: 70,
                onChanged: (v) => setState(() => power = v),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
            FilledButton(
              onPressed: () {
                team.coach.fullName = nameCtrl.text;
                team.coach.iqPower = power;
                state.save(); // الحفظ
                state.notifyListeners(); // تحديث الواجهة
                Navigator.pop(ctx);
              },
              child: const Text("Kaydet"),
            )
          ],
        ),
      ),
    );
  }
}

// --- TAB 2: KADRO (اللاعبين + التعديل) ---
class _SquadTab extends StatelessWidget {
  final Team team;
  const _SquadTab({required this.team});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, "Kaleciler"),
        ...team.keepers.map((k) => Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.sports_handball, color: Colors.white)),
            title: Text(k.fullName),
            subtitle: Text("Güç: ${k.keepingPower.toStringAsFixed(1)}"),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editKeeper(context, state, k),
            ),
          ),
        )),

        const SizedBox(height: 20),
        _buildSectionHeader(context, "Oyuncular"),
        ...team.players.map((p) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPowerColor(p.power),
              child: Text(p.power.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            title: Text(p.fullName),
            subtitle: LinearProgressIndicator(value: p.power / 8.0, color: _getPowerColor(p.power), backgroundColor: Colors.grey.shade200),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editPlayer(context, state, p),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Color _getPowerColor(double p) {
    if (p >= 7) return Colors.green;
    if (p >= 5) return Colors.blue;
    if (p >= 3) return Colors.orange;
    return Colors.red;
  }

  // تعديل اللاعب
  void _editPlayer(BuildContext context, AppState state, Player p) {
    final nameCtrl = TextEditingController(text: p.fullName);
    double val = p.power;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Oyuncu Düzenle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "İsim")),
              const SizedBox(height: 16),
              Text("Güç: ${val.toStringAsFixed(1)}"),
              Slider(
                value: val, min: 1, max: 8, divisions: 70,
                onChanged: (v) => setState(() => val = v),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
            FilledButton(
              onPressed: () {
                p.fullName = nameCtrl.text;
                p.power = val;
                state.save();
                state.notifyListeners();
                Navigator.pop(ctx);
              },
              child: const Text("Kaydet"),
            )
          ],
        ),
      ),
    );
  }

  // تعديل الحارس
  void _editKeeper(BuildContext context, AppState state, GoalKeeper k) {
    final nameCtrl = TextEditingController(text: k.fullName);
    double val = k.keepingPower;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Kaleci Düzenle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "İsim")),
              const SizedBox(height: 16),
              Text("Güç: ${val.toStringAsFixed(1)}"),
              Slider(
                value: val, min: 1, max: 8, divisions: 70,
                onChanged: (v) => setState(() => val = v),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
            FilledButton(
              onPressed: () {
                k.fullName = nameCtrl.text;
                k.keepingPower = val;
                state.save();
                state.notifyListeners();
                Navigator.pop(ctx);
              },
              child: const Text("Kaydet"),
            )
          ],
        ),
      ),
    );
  }
}

// --- TAB 3: LİGLER (تفاصيل الدوريات المشترك فيها) ---
class _LeaguesTab extends StatelessWidget {
  final Team team;
  const _LeaguesTab({required this.team});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // جلب الدوريات التي يشارك فيها هذا الفريق فقط
    final myLeagues = state.leagues.where((l) => l.teamIds.contains(team.id)).toList();

    if (myLeagues.isEmpty) {
      return const Center(child: Text("Bu takım henüz bir ligde oynamıyor."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myLeagues.length,
      itemBuilder: (ctx, i) {
        final lg = myLeagues[i];
        final stats = _calculateLeagueStats(lg, team.id);

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // رأس البطاقة باسم الدوري
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(lg.leagueColorValue).withOpacity(0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(lg.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    Text(leagueTypeLabel(lg.type), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // إحصائيات هذا الدوري فقط
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LeagueStatItem(label: "Puan", value: "${stats['points']}", isMain: true),
                        _LeagueStatItem(label: "Oynanan", value: "${stats['played']}"),
                        _LeagueStatItem(label: "Galibiyet", value: "${stats['won']}"),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LeagueStatItem(label: "Gol Atılan", value: "${stats['gf']}"),
                        _LeagueStatItem(label: "Gol Yenen", value: "${stats['ga']}"),
                        _LeagueStatItem(label: "Averaj", value: "${stats['gd']}"),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // حساب الإحصائيات الخاصة بدوري واحد وفريق واحد
  Map<String, int> _calculateLeagueStats(League lg, String tid) {
    int played = 0, won = 0, drawn = 0, lost = 0, gf = 0, ga = 0;

    for (var m in lg.matches) {
      if (m.status != MatchStatus.finished) continue;
      final isHome = m.homeTeamId == tid;
      final isAway = m.awayTeamId == tid;

      if (!isHome && !isAway) continue;

      played++;
      final myGoals = isHome ? m.homeGoals : m.awayGoals;
      final oppGoals = isHome ? m.awayGoals : m.homeGoals;

      gf += myGoals;
      ga += oppGoals;

      if (myGoals > oppGoals) won++;
      else if (myGoals == oppGoals) drawn++;
      else lost++;
    }

    // حساب النقاط حسب قواعد الدوري
    int points = (won * lg.winPoints) + (drawn * lg.drawPoints) + (lost * lg.losePoints);

    return {
      'played': played,
      'won': won,
      'drawn': drawn,
      'lost': lost,
      'gf': gf,
      'ga': ga,
      'gd': gf - ga,
      'points': points
    };
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _LeagueStatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isMain;
  const _LeagueStatItem({required this.label, required this.value, this.isMain = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(
            fontSize: isMain ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: isMain ? Colors.indigo : Colors.black87
        )),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}