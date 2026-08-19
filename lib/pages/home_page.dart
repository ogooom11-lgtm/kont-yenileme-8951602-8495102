import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'team_add_page.dart';
import 'league_add_page.dart';
import '../models/league.dart';
import 'live_matches_page.dart';
import 'team_details_page.dart';
import 'match_details_page.dart';
import 'league_details_page.dart'; // Yeni oluşturduğumuz sayfayı import et

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Hafif gri arka plan
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Row(
          children: [
            Icon(Icons.sports_soccer, color: Colors.blue),
            SizedBox(width: 8),
            Text('Lig Planlayıcı', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Canlı Maçlar',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveMatchesPage())),
            icon: const Icon(Icons.live_tv, color: Colors.red),
          ),
          IconButton(
            tooltip: 'Tema',
            onPressed: () => state.toggleTheme(),
            icon: const Icon(Icons.brightness_6),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOL MENÜ (Takımlar)
          if (isWide)
            SizedBox(
              width: 300,
              child: _SideBar(state: state),
            ),

          // ANA İÇERİK
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hoşgeldin Başlığı
                  Text("Hoş Geldiniz, Patron!", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text("Liglerinizi ve takımlarınızı buradan yönetin.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),

                  // Ligler Başlığı + Buton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Aktif Ligler ve Turnuvalar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeagueAddPage())),
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Lig Oluştur'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lig Kartları (Grid veya List)
                  if (state.leagues.isEmpty)
                    _buildEmptyState()
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive Grid: Ekrana göre 1, 2 veya 3 sütun
                        int crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 1.6, // Kart oranı
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: state.leagues.length,
                          itemBuilder: (ctx, i) {
                            return _LeagueDashboardCard(league: state.leagues[i]);
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Yaklaşan Maçlar
                  Text('Yaklaşan Maçlar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const _UpcomingMatchesList(),
                ],
              ),
            ),
          ),
        ],
      ),
      // Mobil için Drawer (Sidebar)
      drawer: !isWide ? Drawer(child: _SideBar(state: state)) : null,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('Henüz bir lig yok.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Sağ üstteki butonu kullanarak ilk liginizi oluşturun.'),
          ],
        ),
      ),
    );
  }
}

// YAN MENÜ BİLEŞENİ
class _SideBar extends StatelessWidget {
  final AppState state;
  const _SideBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Takımlar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 4),
                Text("${state.teams.length} Kayıtlı Takım", style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: state.teams.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, i) {
                final t = state.teams[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    child: Text(t.icon),
                  ),
                  title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Güç: ${t.teamPower.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamDetailsPage(teamId: t.id)));
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeamAddPage())),
                icon: const Icon(Icons.group_add),
                label: const Text('Yeni Takım Ekle'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// LİG KARTI (DASHBOARD TARZI)
class _LeagueDashboardCard extends StatelessWidget {
  final League league;
  const _LeagueDashboardCard({required this.league});

  @override
  Widget build(BuildContext context) {
    final finished = league.matches.where((m) => m.status == MatchStatus.finished).length;
    final total = league.matches.length;
    final progress = total == 0 ? 0.0 : finished / total;
    final color = Color(league.leagueColorValue);

    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // DETAY SAYFASINA GİT
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LeagueDetailsPage(leagueId: league.id),
            ),
          );
        },
        child: Column(
          children: [
            // Üst Renkli Alan
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: color,
                image: const DecorationImage(
                  image: NetworkImage("https://www.transparenttextures.com/patterns/cubes.png"), // Hafif doku (opsiyonel)
                  opacity: 0.1,
                  fit: BoxFit.cover,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: Icon(league.type == LeagueType.league ? Icons.grid_view : Icons.emoji_events, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      league.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // İçerik
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBadge(label: 'Maçlar', value: '$total'),
                        _StatBadge(label: 'Biten', value: '$finished'),
                        _StatBadge(label: 'Takım', value: '${league.teamIds.length}'),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("İlerleme", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          color: color,
                          backgroundColor: color.withOpacity(0.1),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// YAKLAŞAN MAÇLAR LİSTESİ (Eski kodu temizledim)
class _UpcomingMatchesList extends StatelessWidget {
  const _UpcomingMatchesList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final List<MatchGame> upcoming = [];

    for (final lg in state.leagues) {
      for (final m in lg.matches) {
        if (m.startTime == null) continue;
        if (m.status == MatchStatus.scheduled || m.status == MatchStatus.live) {
          upcoming.add(m);
        }
      }
    }
    // Sırala
    upcoming.sort((a, b) => a.startTime!.compareTo(b.startTime!));

    if (upcoming.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Yaklaşan maç yok.'))),
      );
    }

    // İlk 5 maçı göster
    return Column(
      children: upcoming.take(5).map((m) {
        final home = state.findTeam(m.homeTeamId);
        final away = state.findTeam(m.awayTeamId);
        final d = m.startTime!;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12)
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
            ),
            title: Row(
              children: [
                Text(home?.name ?? '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('vs', style: TextStyle(color: Colors.grey, fontSize: 12))),
                Text(away?.name ?? '?', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            subtitle: Text(
              '${d.day}.${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailsPage(matchId: m.id)));
            },
          ),
        );
      }).toList(),
    );
  }
}