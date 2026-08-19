import 'dart:convert';

import 'enums.dart';

export 'enums.dart';

class RankDefinition {
  final int minRank;
  final int maxRank;
  final int colorValue;
  final String label;

  RankDefinition({
    required this.minRank,
    required this.maxRank,
    required this.colorValue,
    required this.label,
  });

  Map<String, dynamic> toMap() => {
        'minRank': minRank,
        'maxRank': maxRank,
        'colorValue': colorValue,
        'label': label,
      };

  factory RankDefinition.fromMap(Map<String, dynamic> map) => RankDefinition(
        minRank: map['minRank'] ?? 0,
        maxRank: map['maxRank'] ?? 0,
        colorValue: map['colorValue'] ?? 0xFFCCCCCC,
        label: map['label'] ?? '',
      );
}

class GroupInfo {
  final String id;
  final String name;
  final List<String> teamIds;

  GroupInfo({
    required this.id,
    required this.name,
    required this.teamIds,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'teamIds': teamIds,
      };

  factory GroupInfo.fromMap(Map<String, dynamic> m) => GroupInfo(
        id: m['id'] as String,
        name: m['name'] as String,
        teamIds: ((m['teamIds'] as List?) ?? []).cast<String>(),
      );
}

class League {
  final String id;
  String title;
  LeagueFormat format;
  List<String> teamIds;
  DateTime startDate;
  DateTime endDate;
  List<MatchGame> matches;
  int winPoints;
  int drawPoints;
  int losePoints;
  int leagueColorValue;
  List<RankDefinition> rankDefinitions;
  List<GroupInfo> groups;
  int qualifiersPerGroup;
  int swissMatches;
  int legs;
  String icon;

  League({
    required this.id,
    required this.title,
    required this.format,
    required this.teamIds,
    required this.startDate,
    required this.endDate,
    required this.matches,
    this.winPoints = 3,
    this.drawPoints = 1,
    this.losePoints = 0,
    this.leagueColorValue = 0xFF0B6E4F,
    this.rankDefinitions = const [],
    this.groups = const [],
    this.qualifiersPerGroup = 2,
    this.swissMatches = 3,
    this.legs = 1,
    this.icon = '🏆',
  });

  /// Eski `type` alanı ile uyumluluk.
  LeagueType get type => switch (format) {
        LeagueFormat.cupSingle || LeagueFormat.cupTwoLegged =>
          LeagueType.elimination,
        LeagueFormat.swiss ||
        LeagueFormat.groupsOnly ||
        LeagueFormat.worldCup ||
        LeagueFormat.championsLeague =>
          LeagueType.fixedMatches,
        _ => LeagueType.league,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'format': format.name,
        'type': type.name,
        'teamIds': teamIds,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'matches': matches.map((e) => e.toMap()).toList(),
        'winPoints': winPoints,
        'drawPoints': drawPoints,
        'losePoints': losePoints,
        'leagueColorValue': leagueColorValue,
        'rankDefinitions': rankDefinitions.map((x) => x.toMap()).toList(),
        'groups': groups.map((g) => g.toMap()).toList(),
        'qualifiersPerGroup': qualifiersPerGroup,
        'swissMatches': swissMatches,
        'legs': legs,
        'icon': icon,
      };

  factory League.fromMap(Map<String, dynamic> m) => League(
        id: m['id'] as String,
        title: m['title'] as String,
        format: LeagueFormatX.fromStored(
          (m['format'] as String?) ?? (m['type'] as String?),
        ),
        teamIds: ((m['teamIds'] as List?) ?? []).cast<String>(),
        startDate: DateTime.parse(m['startDate'] as String),
        endDate: DateTime.parse(m['endDate'] as String),
        matches: ((m['matches'] as List?) ?? [])
            .map((x) => MatchGame.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
        winPoints: m['winPoints'] ?? 3,
        drawPoints: m['drawPoints'] ?? 1,
        losePoints: m['losePoints'] ?? 0,
        leagueColorValue: m['leagueColorValue'] ?? 0xFF0B6E4F,
        rankDefinitions: ((m['rankDefinitions'] as List?) ?? [])
            .map((x) => RankDefinition.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
        groups: ((m['groups'] as List?) ?? [])
            .map((x) => GroupInfo.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
        qualifiersPerGroup: m['qualifiersPerGroup'] ?? 2,
        swissMatches: m['swissMatches'] ?? 3,
        legs: m['legs'] ?? 1,
        icon: (m['icon'] as String?) ?? '🏆',
      );

  String toJson() => jsonEncode(toMap());
  factory League.fromJson(String s) => League.fromMap(jsonDecode(s));
}

/// Eski API ile uyumluluk.
enum LeagueType { league, elimination, fixedMatches }

String leagueTypeLabel(LeagueType t) => switch (t) {
      LeagueType.league => 'Lig Usulü (Puanlı)',
      LeagueType.elimination => 'Eleme Usulü (Kupa)',
      LeagueType.fixedMatches => 'Grup / Sabit Maç',
    };

class MatchEvent {
  final int minute;
  final String teamId;
  final String? playerId;
  final bool isHome;
  final EventType type;

  MatchEvent({
    required this.minute,
    required this.teamId,
    required this.isHome,
    this.playerId,
    this.type = EventType.goal,
  });

  Map<String, dynamic> toMap() => {
        'minute': minute,
        'teamId': teamId,
        'playerId': playerId,
        'isHome': isHome,
        'type': type.name,
      };

  factory MatchEvent.fromMap(Map<String, dynamic> m) => MatchEvent(
        minute: (m['minute'] as num?)?.toInt() ?? 0,
        teamId: m['teamId'] as String,
        playerId: m['playerId'] as String?,
        isHome: m['isHome'] as bool? ?? true,
        type: EventType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => EventType.goal,
        ),
      );
}

class Lineup {
  List<String> playerIds;
  String? keeperId;

  Lineup({List<String>? playerIds, this.keeperId})
      : playerIds = playerIds ?? [];

  Map<String, dynamic> toMap() =>
      {'playerIds': playerIds, 'keeperId': keeperId};

  factory Lineup.fromMap(Map<String, dynamic> m) => Lineup(
        playerIds: ((m['playerIds'] as List?) ?? []).cast<String>(),
        keeperId: m['keeperId'] as String?,
      );
}

class MatchGame {
  final String id;
  final String leagueId;
  final String homeTeamId;
  final String awayTeamId;

  DateTime? startTime;
  MatchStatus status;
  int homeGoals;
  int awayGoals;
  List<MatchEvent> events;
  Lineup? homeLineup;
  Lineup? awayLineup;

  int homeSaves;
  int awaySaves;
  Map<String, int> goalsByPlayer;
  DateTime? endTime;
  bool finalized;

  int week;
  MatchStage stage;
  String? groupId;
  String? groupName;
  String? tieId;
  int leg;
  int homePenalties;
  int awayPenalties;
  bool usedPenalties;
  String? winnerTeamId;

  MatchGame({
    required this.id,
    required this.leagueId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.startTime,
    this.status = MatchStatus.scheduled,
    this.homeGoals = 0,
    this.awayGoals = 0,
    List<MatchEvent>? events,
    this.homeLineup,
    this.awayLineup,
    this.homeSaves = 0,
    this.awaySaves = 0,
    Map<String, int>? goalsByPlayer,
    this.endTime,
    this.finalized = false,
    this.week = 1,
    this.stage = MatchStage.leagueRound,
    this.groupId,
    this.groupName,
    this.tieId,
    this.leg = 1,
    this.homePenalties = 0,
    this.awayPenalties = 0,
    this.usedPenalties = false,
    this.winnerTeamId,
  })  : events = events ?? [],
        goalsByPlayer = goalsByPlayer ?? {};

  bool get isBye => awayTeamId == 'BYE' || homeTeamId == 'BYE';

  int get homeTotal => homeGoals;
  int get awayTotal => awayGoals;

  Map<String, int> get scorerMap {
    if (goalsByPlayer.isNotEmpty) return goalsByPlayer;
    final map = <String, int>{};
    for (final ev in events) {
      if (ev.playerId == null || ev.playerId!.isEmpty) continue;
      if (ev.type == EventType.goal || ev.type == EventType.penaltyGoal) {
        map.update(ev.playerId!, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return map;
  }

  MatchGame copyWith({
    String? id,
    String? leagueId,
    String? homeTeamId,
    String? awayTeamId,
    DateTime? startTime,
    MatchStatus? status,
    int? homeGoals,
    int? awayGoals,
    List<MatchEvent>? events,
    Lineup? homeLineup,
    Lineup? awayLineup,
    int? homeSaves,
    int? awaySaves,
    Map<String, int>? goalsByPlayer,
    DateTime? endTime,
    bool? finalized,
    int? week,
    MatchStage? stage,
    String? groupId,
    String? groupName,
    String? tieId,
    int? leg,
    int? homePenalties,
    int? awayPenalties,
    bool? usedPenalties,
    String? winnerTeamId,
  }) {
    return MatchGame(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      homeGoals: homeGoals ?? this.homeGoals,
      awayGoals: awayGoals ?? this.awayGoals,
      events: events ?? this.events,
      homeLineup: homeLineup ?? this.homeLineup,
      awayLineup: awayLineup ?? this.awayLineup,
      homeSaves: homeSaves ?? this.homeSaves,
      awaySaves: awaySaves ?? this.awaySaves,
      goalsByPlayer: goalsByPlayer ?? Map<String, int>.from(this.goalsByPlayer),
      endTime: endTime ?? this.endTime,
      finalized: finalized ?? this.finalized,
      week: week ?? this.week,
      stage: stage ?? this.stage,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      tieId: tieId ?? this.tieId,
      leg: leg ?? this.leg,
      homePenalties: homePenalties ?? this.homePenalties,
      awayPenalties: awayPenalties ?? this.awayPenalties,
      usedPenalties: usedPenalties ?? this.usedPenalties,
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'leagueId': leagueId,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'startTime': startTime?.toIso8601String(),
        'status': status.name,
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'events': events.map((e) => e.toMap()).toList(),
        'homeLineup': homeLineup?.toMap(),
        'awayLineup': awayLineup?.toMap(),
        'homeSaves': homeSaves,
        'awaySaves': awaySaves,
        'goalsByPlayer': goalsByPlayer,
        'endTime': endTime?.toIso8601String(),
        'finalized': finalized,
        'week': week,
        'stage': stage.name,
        'groupId': groupId,
        'groupName': groupName,
        'tieId': tieId,
        'leg': leg,
        'homePenalties': homePenalties,
        'awayPenalties': awayPenalties,
        'usedPenalties': usedPenalties,
        'winnerTeamId': winnerTeamId,
      };

  factory MatchGame.fromMap(Map<String, dynamic> m) {
    final gbp = <String, int>{};
    final raw = m['goalsByPlayer'];
    if (raw is Map) {
      raw.forEach((k, v) {
        gbp[k.toString()] = (v as num).toInt();
      });
    }
    return MatchGame(
      id: m['id'] as String,
      leagueId: m['leagueId'] as String,
      homeTeamId: m['homeTeamId'] as String,
      awayTeamId: m['awayTeamId'] as String,
      startTime:
          m['startTime'] == null ? null : DateTime.parse(m['startTime']),
      status: MatchStatus.values.firstWhere(
        (x) => x.name == m['status'],
        orElse: () => MatchStatus.scheduled,
      ),
      homeGoals: (m['homeGoals'] as num?)?.toInt() ?? 0,
      awayGoals: (m['awayGoals'] as num?)?.toInt() ?? 0,
      events: ((m['events'] as List?) ?? [])
          .map((e) => MatchEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      homeLineup: m['homeLineup'] == null
          ? null
          : Lineup.fromMap(Map<String, dynamic>.from(m['homeLineup'])),
      awayLineup: m['awayLineup'] == null
          ? null
          : Lineup.fromMap(Map<String, dynamic>.from(m['awayLineup'])),
      homeSaves: (m['homeSaves'] as num?)?.toInt() ?? 0,
      awaySaves: (m['awaySaves'] as num?)?.toInt() ?? 0,
      goalsByPlayer: gbp,
      endTime: m['endTime'] == null ? null : DateTime.parse(m['endTime']),
      finalized: m['finalized'] as bool? ?? false,
      week: (m['week'] as num?)?.toInt() ?? 1,
      stage: MatchStage.values.firstWhere(
        (x) => x.name == m['stage'],
        orElse: () => MatchStage.leagueRound,
      ),
      groupId: m['groupId'] as String?,
      groupName: m['groupName'] as String?,
      tieId: m['tieId'] as String?,
      leg: (m['leg'] as num?)?.toInt() ?? 1,
      homePenalties: (m['homePenalties'] as num?)?.toInt() ?? 0,
      awayPenalties: (m['awayPenalties'] as num?)?.toInt() ?? 0,
      usedPenalties: m['usedPenalties'] as bool? ?? false,
      winnerTeamId: m['winnerTeamId'] as String?,
    );
  }
}
