import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'leagues_page.dart';
import 'live_matches_page.dart';
import 'matches_page.dart';
import 'teams_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final liveCount = state.leagues
        .expand((l) => l.matches)
        .where((m) => m.status.name == 'live')
        .length;

    final pages = const [
      LeaguesPage(),
      MatchesPage(),
      TeamsPage(),
      LiveMatchesPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ligler',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Maçlar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Takımlar',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: liveCount > 0,
              label: Text('$liveCount'),
              child: const Icon(Icons.sensors_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: liveCount > 0,
              label: Text('$liveCount'),
              child: const Icon(Icons.sensors),
            ),
            label: 'Canlı',
          ),
        ],
      ),
    );
  }
}

/// Eski giriş noktası.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const HomeShell();
}
