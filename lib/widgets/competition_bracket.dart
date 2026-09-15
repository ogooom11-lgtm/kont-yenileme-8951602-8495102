import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../pages/match_details_page.dart';
import '../providers/app_state.dart';

/// Kupayı liste yerine bir turnuva haritası olarak gösterir.
/// Her kolon bir turu, her kart bir eşleşmeyi, kazanan rozeti de bir sonraki
/// tura ilerleyen takımı anlatır.
class CompetitionBracket extends StatelessWidget {
  final League league;
  const CompetitionBracket({super.key, required this.league});

  static const _stages = [
    MatchStage.roundOf64,
    MatchStage.roundOf32,
    MatchStage.roundOf16,
    MatchStage.quarterFinal,
    MatchStage.semiFinal,
    MatchStage.finalMatch,
    MatchStage.thirdPlace,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stages = _stages
        .map((stage) => (stage: stage, matches: league.matches.where((m) => m.stage == stage).toList()))
        .where((entry) =>
            entry.matches.isNotEmpty ||
            league.knockoutEntryStages.values.contains(entry.stage))
        .toList();
    if (stages.isEmpty) {
      return const _BracketEmpty();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(Icons.account_tree_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Kupa haritası', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Spacer(),
              Text('${stages.length} tur', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                _StageColumn(
                  stage: stages[index].stage,
                  matches: stages[index].matches,
                  state: state,
                  league: league,
                ),
                if (index < stages.length - 1)
                  const SizedBox(width: 18, child: Padding(padding: EdgeInsets.only(top: 88), child: Icon(Icons.arrow_forward, color: Colors.grey))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StageColumn extends StatelessWidget {
  final MatchStage stage;
  final List<MatchGame> matches;
  final AppState state;
  final League league;
  const _StageColumn({
    required this.stage,
    required this.matches,
    required this.state,
    required this.league,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<MatchGame>.from(matches)..sort((a, b) => a.week.compareTo(b.week));
    final directEntries = league.knockoutEntryStages.entries.where((entry) {
      final hasMatch = matches.any((match) =>
          match.homeTeamId == entry.key || match.awayTeamId == entry.key);
      return entry.value == stage && !hasMatch;
    }).toList();
    return SizedBox(
      width: 224,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stage.label(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ..._ties(sorted).map((tie) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _TieCard(matches: tie, state: state))),
          ...directEntries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DirectEntryCard(team: state.findTeam(entry.key)?.name ?? '?', icon: state.findTeam(entry.key)?.icon ?? '⚽'),
              )),
        ],
      ),
    );
  }

  List<List<MatchGame>> _ties(List<MatchGame> source) {
    final result = <List<MatchGame>>[];
    final byTie = <String, List<MatchGame>>{};
    for (final match in source) {
      if (match.tieId == null) {
        result.add([match]);
      } else {
        byTie.putIfAbsent(match.tieId!, () => []).add(match);
      }
    }
    result.addAll(byTie.values);
    return result;
  }
}

class _DirectEntryCard extends StatelessWidget {
  final String team;
  final String icon;
  const _DirectEntryCard({required this.team, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 7),
              Expanded(child: Text(team, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              const Icon(Icons.login, size: 16),
            ],
          ),
        ),
      );
}

class _TieCard extends StatelessWidget {
  final List<MatchGame> matches;
  final AppState state;
  const _TieCard({required this.matches, required this.state});

  @override
  Widget build(BuildContext context) {
    final first = matches.first;
    final home = state.findTeam(first.homeTeamId);
    final away = first.isBye ? null : state.findTeam(first.awayTeamId);
    final winner = matches.map((m) => m.winnerTeamId).firstWhere((id) => id != null, orElse: () => null);
    final finished = matches.every((m) => m.status == MatchStatus.finished);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: first.isBye ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailsPage(matchId: first.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(first.tieId == null ? 'Tek maç' : 'Eşleşme', style: Theme.of(context).textTheme.labelSmall),
                  const Spacer(),
                  if (finished) const Icon(Icons.check_circle, size: 16, color: Colors.green),
                ],
              ),
              const SizedBox(height: 7),
              _TeamLine(name: home?.name ?? '?', icon: home?.icon ?? '⚽', score: _scoreFor(first, first.homeTeamId)),
              const SizedBox(height: 5),
              _TeamLine(name: first.isBye ? 'Bay geçişi' : (away?.name ?? '?'), icon: away?.icon ?? '—', score: first.isBye ? null : _scoreFor(first, first.awayTeamId)),
              if (matches.length > 1) ...[
                const Divider(height: 14),
                for (final leg in matches.skip(1))
                  Text('R${leg.leg}: ${_scoreFor(leg, leg.homeTeamId)} - ${_scoreFor(leg, leg.awayTeamId)}', style: Theme.of(context).textTheme.labelSmall),
              ],
              if (winner != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('✓ ${state.findTeam(winner)?.name ?? winner} turu geçti', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
              if (first.isBye)
                const Padding(padding: EdgeInsets.only(top: 7), child: Text('Otomatik olarak bir sonraki tura geçti', style: TextStyle(fontSize: 10, color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }

  String _scoreFor(MatchGame match, String teamId) {
    if (match.status == MatchStatus.scheduled) return '—';
    return teamId == match.homeTeamId ? '${match.homeGoals}' : '${match.awayGoals}';
  }
}

class _TeamLine extends StatelessWidget {
  final String name;
  final String icon;
  final String? score;
  const _TeamLine({required this.name, required this.icon, required this.score});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 19)),
          const SizedBox(width: 7),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          if (score != null) Text(score!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      );
}

class _BracketEmpty extends StatelessWidget {
  const _BracketEmpty();

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.account_tree_outlined, size: 42, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 8),
              const Text('Kupa haritası henüz hazır değil', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Grup maçları tamamlandığında veya ilk kupa maçı oluşturulduğunda burada görünür.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
