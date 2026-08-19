import 'dart:convert';

/// 1.00 - 8.00 aralığı
bool isValidPower(double v) => v >= 1.0 && v <= 8.0;

/// Basit ikon temsili: emoji (şعار فريق). لاحقًا ممكن نعمل IconPicker.
class Team {
  final String id;
  String name;
  String icon; // emoji string, ör: "🦊"
  double teamPower; // 1.00 - 8.00
  List<Player> players;
  Coach coach;
  List<GoalKeeper> keepers;

  Team({
    required this.id,
    required this.name,
    required this.icon,
    required this.teamPower,
    required this.players,
    required this.coach,
    required this.keepers,
  });

  double get totalPlayersPower =>
      players.fold<double>(0, (s, p) => s + p.power);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'teamPower': teamPower,
    'players': players.map((e) => e.toMap()).toList(),
    'coach': coach.toMap(),
    'keepers': keepers.map((e) => e.toMap()).toList(),
  };

  factory Team.fromMap(Map<String, dynamic> m) => Team(
    id: m['id'],
    name: m['name'],
    icon: m['icon'],
    teamPower: (m['teamPower'] as num).toDouble(),
    players:
    (m['players'] as List).map((x) => Player.fromMap(x)).toList(),
    coach: Coach.fromMap(m['coach']),
    keepers:
    (m['keepers'] as List).map((x) => GoalKeeper.fromMap(x)).toList(),
  );

  String toJson() => jsonEncode(toMap());
  factory Team.fromJson(String s) => Team.fromMap(jsonDecode(s));
}

class Player {
  final String id;
  String fullName;
  double power; // 1.00 - 8.00

  Player({required this.id, required this.fullName, required this.power});

  Map<String, dynamic> toMap() =>
      {'id': id, 'fullName': fullName, 'power': power};

  factory Player.fromMap(Map<String, dynamic> m) => Player(
    id: m['id'],
    fullName: m['fullName'],
    power: (m['power'] as num).toDouble(),
  );
}

class Coach {
  final String id;
  String fullName;
  double iqPower; // 1.00 - 8.00

  Coach({required this.id, required this.fullName, required this.iqPower});

  Map<String, dynamic> toMap() =>
      {'id': id, 'fullName': fullName, 'iqPower': iqPower};

  factory Coach.fromMap(Map<String, dynamic> m) => Coach(
    id: m['id'],
    fullName: m['fullName'],
    iqPower: (m['iqPower'] as num).toDouble(),
  );
}
// أضفه في ملف models/models.dart أو ملف جديد models/league_table_item.dart

class LeagueTableItem {
  final String teamId;
  final String teamName;
  final String teamIcon;

  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get points => (won * 3) + (drawn * 1);
  int get goalDifference => goalsFor - goalsAgainst;

  LeagueTableItem({
    required this.teamId,
    required this.teamName,
    required this.teamIcon
  });
}
class GoalKeeper {
  final String id;
  String fullName;
  double keepingPower; // 1.00 - 8.00

  GoalKeeper(
      {required this.id, required this.fullName, required this.keepingPower});

  Map<String, dynamic> toMap() =>
      {'id': id, 'fullName': fullName, 'keepingPower': keepingPower};

  factory GoalKeeper.fromMap(Map<String, dynamic> m) => GoalKeeper(
    id: m['id'],
    fullName: m['fullName'],
    keepingPower: (m['keepingPower'] as num).toDouble(),
  );
}



/// لاحقاً سنضيف: League, Match, MatchEvent, … في مرحلة الدوري.

