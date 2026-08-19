import '../models/league.dart';
import '../models/models.dart';

class StandingsService {
  static List<LeagueTableItem> build({
    required League league,
    required Team? Function(String id) findTeam,
    String? groupId,
    bool groupMatchesOnly = false,
  }) {
    final ids = groupId == null
        ? league.teamIds
        : (league.groups
                .where((g) => g.id == groupId)
                .map((g) => g.teamIds)
                .expand((e) => e)
                .toList());

    final table = <LeagueTableItem>[];
    for (final teamId in ids) {
      final team = findTeam(teamId);
      if (team == null) continue;
      final item = LeagueTableItem(
        teamId: team.id,
        teamName: team.name,
        teamIcon: team.icon,
        groupId: groupId,
      );

      for (final m in league.matches) {
        if (m.status != MatchStatus.finished) continue;
        if (m.isBye) continue;
        if (groupMatchesOnly && m.stage != MatchStage.group) continue;
        if (groupId != null && m.groupId != groupId) continue;
        if (m.stage.isKnockout) continue;

        final isHome = m.homeTeamId == teamId;
        final isAway = m.awayTeamId == teamId;
        if (!isHome && !isAway) continue;

        item.played++;
        final my = isHome ? m.homeGoals : m.awayGoals;
        final opp = isHome ? m.awayGoals : m.homeGoals;
        item.goalsFor += my;
        item.goalsAgainst += opp;
        if (my > opp) {
          item.won++;
        } else if (my == opp) {
          item.drawn++;
        } else {
          item.lost++;
        }
      }

      item.points = (item.won * league.winPoints) +
          (item.drawn * league.drawPoints) +
          (item.lost * league.losePoints);
      table.add(item);
    }

    table.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDifference != a.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
      return a.teamName.compareTo(b.teamName);
    });
    return table;
  }

  static Map<String, List<LeagueTableItem>> byGroup({
    required League league,
    required Team? Function(String id) findTeam,
  }) {
    final map = <String, List<LeagueTableItem>>{};
    for (final g in league.groups) {
      map[g.id] = build(
        league: league,
        findTeam: findTeam,
        groupId: g.id,
        groupMatchesOnly: true,
      );
    }
    return map;
  }
}
