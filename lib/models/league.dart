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

Map<String, MatchStage> _decodeKnockoutEntryStages(dynamic raw) {
  if (raw is! Map) return {};
  final result = <String, MatchStage>{};
  raw.forEach((key, value) {
    final stage = MatchStage.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => MatchStage.roundOf32,
    );
    result[key.toString()] = stage;
  });
  return result;
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

  /// Turnuvanın saha içi ve otomasyon kuralları.
  bool autoAdvance;
  bool allowExtraTime;
  bool allowPenalties;
  bool randomizeDraw;
  int minRestHours;
  bool thirdPlaceMatch;
  List<StandingsTieBreaker> tieBreakers;
  String notes;

  /// Advanced knockout setup. The map is empty when every team starts in the
  /// automatically calculated first round.
  Map<String, MatchStage> knockoutEntryStages;
  bool seededKnockoutDraw;

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
    this.autoAdvance = true,
    this.allowExtraTime = true,
    this.allowPenalties = true,
    this.randomizeDraw = true,
    this.minRestHours = 48,
    this.thirdPlaceMatch = false,
    this.tieBreakers = const [
      StandingsTieBreaker.points,
      StandingsTieBreaker.goalDifference,
      StandingsTieBreaker.goalsFor,
      StandingsTieBreaker.wins,
      StandingsTieBreaker.headToHead,
    ],
    this.notes = '',
    this.knockoutEntryStages = const {},
    this.seededKnockoutDraw = true,
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
        'autoAdvance': autoAdvance,
        'allowExtraTime': allowExtraTime,
        'allowPenalties': allowPenalties,
        'randomizeDraw': randomizeDraw,
        'minRestHours': minRestHours,
        'thirdPlaceMatch': thirdPlaceMatch,
        'tieBreakers': tieBreakers.map((x) => x.name).toList(),
        'notes': notes,
        'knockoutEntryStages': knockoutEntryStages.map(
          (teamId, stage) => MapEntry(teamId, stage.name),
        ),
        'seededKnockoutDraw': seededKnockoutDraw,
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
        winPoints: (m['winPoints'] as num?)?.toInt() ?? 3,
        drawPoints: (m['drawPoints'] as num?)?.toInt() ?? 1,
        losePoints: (m['losePoints'] as num?)?.toInt() ?? 0,
        leagueColorValue:
            (m['leagueColorValue'] as num?)?.toInt() ?? 0xFF0B6E4F,
        rankDefinitions: ((m['rankDefinitions'] as List?) ?? [])
            .map((x) => RankDefinition.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
        groups: ((m['groups'] as List?) ?? [])
            .map((x) => GroupInfo.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
        qualifiersPerGroup:
            (m['qualifiersPerGroup'] as num?)?.toInt() ?? 2,
        swissMatches: (m['swissMatches'] as num?)?.toInt() ?? 3,
        legs: (m['legs'] as num?)?.toInt() ?? 1,
        icon: (m['icon'] as String?) ?? '🏆',
        autoAdvance: m['autoAdvance'] as bool? ?? true,
        allowExtraTime: m['allowExtraTime'] as bool? ?? true,
        allowPenalties: m['allowPenalties'] as bool? ?? true,
        randomizeDraw: m['randomizeDraw'] as bool? ?? true,
        minRestHours: (m['minRestHours'] as num?)?.toInt() ?? 48,
        thirdPlaceMatch: m['thirdPlaceMatch'] as bool? ?? false,
        tieBreakers: ((m['tieBreakers'] as List?) ?? [
          'points',
          'goalDifference',
          'goalsFor',
          'wins',
          'headToHead',
        ])
            .map((x) => StandingsTieBreakerX.fromStored(x.toString()))
            .toList(),
        notes: (m['notes'] as String?) ?? '',
        knockoutEntryStages: _decodeKnockoutEntryStages(m['knockoutEntryStages']),
        seededKnockoutDraw: m['seededKnockoutDraw'] as bool? ?? true,
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
  final bool isHome;
  final EventType type;

  MatchEvent({
    required this.minute,
    required this.teamId,
    required this.isHome,
    this.type = EventType.goal,
  });

  Map<String, dynamic> toMap() => {
        'minute': minute,
        'teamId': teamId,
        'isHome': isHome,
        'type': type.name,
      };

  factory MatchEvent.fromMap(Map<String, dynamic> m) => MatchEvent(
        minute: (m['minute'] as num?)?.toInt() ?? 0,
        teamId: m['teamId'] as String,
        isHome: m['isHome'] as bool? ?? true,
        type: EventType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => EventType.goal,
        ),
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
  }) : events = events ?? [];

  bool get isBye => awayTeamId == 'BYE' || homeTeamId == 'BYE';

  int get homeTotal => homeGoals;
  int get awayTotal => awayGoals;

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

  factory MatchGame.fromMap(Map<String, dynamic> m) => MatchGame(
        id: m['id'] as String,
        leagueId: m['leagueId'] as String,
        homeTeamId: m['homeTeamId'] as String,
        awayTeamId: m['awayTeamId'] as String,
        startTime: m['startTime'] == null ? null : DateTime.parse(m['startTime']),
        status: MatchStatus.values.firstWhere(
          (x) => x.name == m['status'],
          orElse: () => MatchStatus.scheduled,
        ),
        homeGoals: (m['homeGoals'] as num?)?.toInt() ?? 0,
        awayGoals: (m['awayGoals'] as num?)?.toInt() ?? 0,
        events: ((m['events'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => MatchEvent.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
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
