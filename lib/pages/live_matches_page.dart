import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/league.dart';

class LiveMatchesPage extends StatefulWidget {
  const LiveMatchesPage({super.key});

  @override
  State<LiveMatchesPage> createState() => _LiveMatchesPageState();
}

class _LiveMatchesPageState extends State<LiveMatchesPage> {
  // لتخزين الـ IDs للمباريات التي في مرحلة الـ 5 ثواني قبل الاختفاء
  final Map<String, Timer> _pendingMatches = {};

  @override
  void dispose() {
    _pendingMatches.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();

    // 1. الفلترة: المباريات التي لم تلعب (أو التي سجلت تواً) وتاريخها اليوم أو قديم
    final matches = <MatchGame>[];
    final Map<String, String> matchToLeagueName = {};

    for (final lg in state.leagues) {
      for (final m in lg.matches) {
        if (m.startTime == null) continue;

        // شرط التاريخ: اليوم أو في الماضي
        bool isTodayOrPast = m.startTime!.isBefore(DateTime(now.year, now.month, now.day, 23, 59));

        // شرط الحالة: لم تنتهِ بعد، أو انتهت وتنتظر الـ 5 ثواني
        bool isLiveOrScheduled = m.status != MatchStatus.finished || _pendingMatches.containsKey(m.id);

        if (isTodayOrPast && isLiveOrScheduled) {
          matches.add(m);
          matchToLeagueName[m.id] = lg.title;
        }
      }
    }

    // ترتيب حسب الوقت
    matches.sort((a, b) => a.startTime!.compareTo(b.startTime!));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Günün Maçları', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: matches.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final m = matches[index];
          return _buildMatchCard(context, state, m, matchToLeagueName[m.id]!);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Bugün oynanacak maç bulunmuyor.', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, AppState state, MatchGame match, String leagueName) {
    final home = state.findTeam(match.homeTeamId);
    final away = state.findTeam(match.awayTeamId);
    final isPending = _pendingMatches.containsKey(match.id);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isPending ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 2,
        child: Column(
          children: [
            // شريط اسم الدوري العلوي
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(leagueName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(
                    "${match.startTime!.hour}:${match.startTime!.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildTeamInfo(home?.name ?? '?', home?.icon ?? '?', true),
                      _buildScoreArea(context, state, match, isPending),
                      _buildTeamInfo(away?.name ?? '?', away?.icon ?? '?', false),
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2), // شريط الـ 5 ثواني
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _pendingMatches[match.id]?.cancel();
                          _pendingMatches.remove(match.id);
                        });
                        state.undoMatchResult(match.id); // تراجع عن النتيجة
                      },
                      icon: const Icon(Icons.undo, size: 16, color: Colors.orange),
                      label: const Text('Geri Al (5s)', style: TextStyle(color: Colors.orange)),
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInfo(String name, String icon, bool isHome) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScoreArea(BuildContext context, AppState state, MatchGame match, bool isPending) {
    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Text("${match.homeGoals} - ${match.awayGoals}",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    }

    return InkWell(
      onTap: () => _showScoreInputDialog(context, state, match),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
        child: const Text("VS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
      ),
    );
  }

  void _showScoreInputDialog(BuildContext context, AppState state, MatchGame match) {
    final homeCtrl = TextEditingController();
    final awayCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Maç Sonucu'),
        content: Row(
          children: [
            Expanded(child: TextField(controller: homeCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: '0'))),
            const Padding(padding: EdgeInsets.all(8.0), child: Text('-')),
            Expanded(child: TextField(controller: awayCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: '0'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final h = int.tryParse(homeCtrl.text) ?? 0;
              final a = int.tryParse(awayCtrl.text) ?? 0;

              Navigator.pop(ctx);

              // 1. تحديث النتيجة في الـ State
              state.setMatchResult(match.id, h, a);

              // 2. تفعيل عداد الـ 5 ثواني للاختفاء
              setState(() {
                _pendingMatches[match.id] = Timer(const Duration(seconds: 5), () {
                  setState(() {
                    _pendingMatches.remove(match.id);
                  });
                });
              });
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}