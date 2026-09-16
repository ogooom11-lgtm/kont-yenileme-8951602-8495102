import '../models/league.dart';
import '../models/models.dart';

/// Turnuva tablolarını tek bir yerde ve deterministik kurallarla hesaplar.
/// Sıralama, turnuvanın kaydettiği eşitlik bozma sırasını uygular.
class StandingsService {
  static const _defaultTieBreakers = [
    StandingsTieBreaker.points,
    StandingsTieBreaker.goalDifference,
    StandingsTieBreaker.goalsFor,
    StandingsTieBreaker.wins,
    StandingsTieBreaker.headToHead,
  ];

  static List<LeagueTableItem> build({
    required League league,
    required Team? Function(String id) findTeam,
    String? groupId,
    bool groupMatchesOnly = false,
  }) {
    final ids = groupId == null
        ? league.teamIds
        : league.groups
            .where((g) => g.id == groupId)
            .expand((g) => g.teamIds)
            .toList();

    final table = <LeagueTableItem>[];
    for (final teamId in ids.toSet()) {
      final team = findTeam(teamId);
      if (team == null) continue;
      final item = LeagueTableItem(
        teamId: team.id,
        teamName: team.name,
        teamIcon: team.icon,
        groupId: groupId,
      );

      for (final match in league.matches) {
        if (match.status != MatchStatus.finished || match.isBye) continue;
        if (groupMatchesOnly && match.stage != MatchStage.group) continue;
        if (groupId != null && match.groupId != groupId) continue;
        if (match.stage.isKnockout) continue;

        final isHome = match.homeTeamId == teamId;
        final isAway = match.awayTeamId == teamId;
        if (!isHome && !isAway) continue;

        item.played++;
        final scored = isHome ? match.homeGoals : match.awayGoals;
        final conceded = isHome ? match.awayGoals : match.homeGoals;
        item.goalsFor += scored;
        item.goalsAgainst += conceded;
        if (scored > conceded) {
          item.won++;
        } else if (scored == conceded) {
          item.drawn++;
        } else {
          item.lost++;
        }
        for (final event in match.events) {
          if (event.teamId != teamId) continue;
          if (event.type == EventType.yellow) item.fairPlay += 1;
          if (event.type == EventType.red) item.fairPlay += 3;
        }
      }

      item.points = item.won * league.winPoints +
          item.drawn * league.drawPoints +
          item.lost * league.losePoints;
      table.add(item);
    }

    final rules = league.tieBreakers.isEmpty
        ? _defaultTieBreakers
        : league.tieBreakers;
    table.sort((a, b) {
      for (final rule in rules) {
        final result = switch (rule) {
          StandingsTieBreaker.points => b.points.compareTo(a.points),
          StandingsTieBreaker.goalDifference =>
            b.goalDifference.compareTo(a.goalDifference),
          StandingsTieBreaker.goalsFor => b.goalsFor.compareTo(a.goalsFor),
          StandingsTieBreaker.wins => b.won.compareTo(a.won),
          StandingsTieBreaker.headToHead =>
            _headToHeadCompare(league, a.teamId, b.teamId, groupId),
          // Fair-play is a penalty total: fewer cards rank higher.
          StandingsTieBreaker.fairPlay =>
            a.fairPlay.compareTo(b.fairPlay),
        };
        if (result != 0) return result;
      }
      return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
    });
    return table;
  }

  static int _headToHeadCompare(
    League league,
    String firstId,
    String secondId,
    String? groupId,
  ) {
    var firstPoints = 0;
    var secondPoints = 0;
    var firstDiff = 0;
    var secondDiff = 0;
    var firstFor = 0;
    var secondFor = 0;

    for (final match in league.matches) {
      if (match.status != MatchStatus.finished || match.isBye) continue;
      if (match.stage.isKnockout) continue;
      if (groupId != null && match.groupId != groupId) continue;
      final isPair = (match.homeTeamId == firstId &&
              match.awayTeamId == secondId) ||
          (match.homeTeamId == secondId && match.awayTeamId == firstId);
      if (!isPair) continue;

      final firstHome = match.homeTeamId == firstId;
      final firstGoals = firstHome ? match.homeGoals : match.awayGoals;
      final secondGoals = firstHome ? match.awayGoals : match.homeGoals;
      firstFor += firstGoals;
      secondFor += secondGoals;
      firstDiff += firstGoals - secondGoals;
      secondDiff += secondGoals - firstGoals;
      if (firstGoals > secondGoals) {
        firstPoints += league.winPoints;
        secondPoints += league.losePoints;
      } else if (firstGoals < secondGoals) {
        firstPoints += league.losePoints;
        secondPoints += league.winPoints;
      } else {
        firstPoints += league.drawPoints;
        secondPoints += league.drawPoints;
      }
    }

    if (firstPoints != secondPoints) return secondPoints.compareTo(firstPoints);
    if (firstDiff != secondDiff) return secondDiff.compareTo(firstDiff);
    if (firstFor != secondFor) return secondFor.compareTo(firstFor);
    return 0;
  }

  static Map<String, List<LeagueTableItem>> byGroup({
    required League league,
    required Team? Function(String id) findTeam,
  }) {
    final map = <String, List<LeagueTableItem>>{};
    for (final group in league.groups) {
      map[group.id] = build(
        league: league,
        findTeam: findTeam,
        groupId: group.id,
        groupMatchesOnly: true,
      );
    }
    return map;
  }
}
