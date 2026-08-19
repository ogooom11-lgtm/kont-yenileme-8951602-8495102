import 'dart:convert';

enum LeagueType {
  league,      // دوري كامل (ذهاب إياب)
  elimination, // كأس
  fixedMatches, // عدد محدد من المباريات (مرحلة مجموعات)
}

String leagueTypeLabel(LeagueType t) => switch (t) {
  LeagueType.league => 'Lig Usulü (Puanlı)',
  LeagueType.elimination => 'Eleme Usulü (Kupa)',
  LeagueType.fixedMatches => 'Grup / Sabit Maç',
};


enum MatchStatus { scheduled, live, finished }

class League {
  final String id;
  String title;
  LeagueType type;
  List<String> teamIds;
  DateTime startDate;
  DateTime endDate;
  List<MatchGame> matches;

  // --- حقول جديدة ---
  final int winPoints;
  final int drawPoints;
  final int losePoints;
  final int leagueColorValue; // سنحفظ اللون كرقم (int)
  final List<RankDefinition> rankDefinitions; // <--- YENİ EKLEME

  League({
    required this.id,
    required this.title,
    required this.type,
    required this.teamIds,
    required this.startDate,
    required this.endDate,
    required this.matches,
    // قيم افتراضية
    this.winPoints = 3,
    this.drawPoints = 1,
    this.losePoints = 0,
    this.leagueColorValue = 0xFF2196F3, // لون أزرق افتراضي
    this.rankDefinitions = const [], // <--- YENİ EKLEME (Varsayılan boş)
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type.name,
    'teamIds': teamIds,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'matches': matches.map((e) => e.toMap()).toList(),
    // --- حفظ الجديد ---
    'winPoints': winPoints,
    'drawPoints': drawPoints,
    'losePoints': losePoints,
    'leagueColorValue': leagueColorValue,
    'rankDefinitions': rankDefinitions.map((x) => x.toMap()).toList(), // <--- YENİ EKLEME
  };


  factory League.fromMap(Map<String, dynamic> m) => League(
    id: m['id'],
    title: m['title'],
    // ابحث عن هذا السطر وعدله
    type: LeagueType.values.firstWhere(
          (x) => x.name == m['type'],
      orElse: () => LeagueType.league, // إذا لم يجد الاسم القديم، اعتبره league تلقائياً
    ),
    teamIds: (m['teamIds'] as List).cast<String>(),
    startDate: DateTime.parse(m['startDate']),
    endDate: DateTime.parse(m['endDate']),
    matches: (m['matches'] as List).map((x) => MatchGame.fromMap(x)).toList(),
    // --- استرجاع الجديد ---
    winPoints: m['winPoints'] ?? 3,
    drawPoints: m['drawPoints'] ?? 1,
    losePoints: m['losePoints'] ?? 0,
    leagueColorValue: m['leagueColorValue'] ?? 0xFF2196F3,
    rankDefinitions: (m['rankDefinitions'] as List?) // <--- YENİ EKLEME
        ?.map((x) => RankDefinition.fromMap(x))
        .toList() ?? [],
  );


  String toJson() => jsonEncode(toMap());
  factory League.fromJson(String s) => League.fromMap(jsonDecode(s));
}

class MatchEvent {
  final int minute;
  final String teamId;
  final String? playerId;
  final bool isHome;

  MatchEvent({
    required this.minute,
    required this.teamId,
    required this.isHome,
    this.playerId,
  });

  Map<String, dynamic> toMap() => {
    'minute': minute,
    'teamId': teamId,
    'playerId': playerId,
    'isHome': isHome,
  };

  factory MatchEvent.fromMap(Map<String, dynamic> m) => MatchEvent(
    minute: (m['minute'] as num).toInt(),
    teamId: m['teamId'],
    playerId: m['playerId'],
    isHome: m['isHome'] as bool,
  );
}

/// تشكيلة مبسطة: 11 لاعب (IDs) + حارس واحد
class Lineup {
  List<String> playerIds; // 11 لاعب
  String? keeperId;       // حارس

  Lineup({List<String>? playerIds, this.keeperId})
      : playerIds = playerIds ?? [];

  Map<String, dynamic> toMap() =>
      {'playerIds': playerIds, 'keeperId': keeperId};

  factory Lineup.fromMap(Map<String, dynamic> m) => Lineup(
    playerIds: (m['playerIds'] as List?)?.cast<String>() ?? [],
    keeperId: m['keeperId'],
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

  /// تشكيلة الفريقين
  Lineup? homeLineup;
  Lineup? awayLineup;

  // NEW: عدادات رسمية للتصديات أثناء المباراة
  int homeSaves = 0; // تصديات فريق الـ Home (حارسه)
  int awaySaves = 0; // تصديات فريق الـ Away (حارسه)

  // NEW: ملخص نهائي للأهداف حسب اللاعب (playerId -> goals count)
  Map<String, int> goalsByPlayer = {};

  // NEW: ختم النهاية
  DateTime? endTime;
  bool finalized = false;

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
  }) : events = events ?? [];


  // أضف هذا الكود داخل كلاس MatchGame
  MatchGame copyWith({
    String? id,
    String? leagueId,
    String? homeTeamId,
    String? awayTeamId,
    DateTime? startTime,
    MatchStatus? status,
    int? homeGoals,
    int? awayGoals,
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
      events: this.events, // نحافظ على الأحداث القديمة كما هي
      homeLineup: this.homeLineup,
      awayLineup: this.awayLineup,
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
  };

  factory MatchGame.fromMap(Map<String, dynamic> m) => MatchGame(
    id: m['id'],
    leagueId: m['leagueId'],
    homeTeamId: m['homeTeamId'],
    awayTeamId: m['awayTeamId'],
    startTime:
    (m['startTime'] == null) ? null : DateTime.parse(m['startTime']),
    status: MatchStatus.values.firstWhere(
          (x) => x.name == m['status'],
      orElse: () => MatchStatus.scheduled,
    ),
    homeGoals: (m['homeGoals'] as num).toInt(),
    awayGoals: (m['awayGoals'] as num).toInt(),
    events: (m['events'] as List?)
        ?.map((e) => MatchEvent.fromMap(e))
        .toList() ??
        [],
    homeLineup: (m['homeLineup'] == null)
        ? null
        : Lineup.fromMap(m['homeLineup']),
    awayLineup: (m['awayLineup'] == null)
        ? null
        : Lineup.fromMap(m['awayLineup']),
  );
}
// league.dart dosyasının EN ALTINA ekle
class RankDefinition {
  final int minRank; // Örn: 1
  final int maxRank; // Örn: 4
  final int colorValue; // Renk
  final String label;   // Örn: "Şampiyonlar Ligi"

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

  factory RankDefinition.fromMap(Map<String, dynamic> map) {
    return RankDefinition(
      minRank: map['minRank'] ?? 0,
      maxRank: map['maxRank'] ?? 0,
      colorValue: map['colorValue'] ?? 0xFFCCCCCC,
      label: map['label'] ?? '',
    );
  }
}