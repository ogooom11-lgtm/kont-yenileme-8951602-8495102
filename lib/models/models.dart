import 'dart:convert';

bool isValidPower(double v) => v >= 1.0 && v <= 8.0;

class Team {
  final String id;
  String name;
  String icon;
  double teamPower;
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
        id: m['id'] as String,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? '⚽',
        teamPower: (m['teamPower'] as num?)?.toDouble() ?? 5.0,
        players: ((m['players'] as List?) ?? [])
            .map((x) => Player.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
        coach: m['coach'] == null
            ? Coach(id: 'c0', fullName: 'Teknik Direktör', iqPower: 5)
            : Coach.fromMap(Map<String, dynamic>.from(m['coach'])),
        keepers: ((m['keepers'] as List?) ?? [])
            .map((x) => GoalKeeper.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
      );

  String toJson() => jsonEncode(toMap());
  factory Team.fromJson(String s) => Team.fromMap(jsonDecode(s));
}

class Player {
  final String id;
  String fullName;
  double power;

  Player({required this.id, required this.fullName, required this.power});

  Map<String, dynamic> toMap() =>
      {'id': id, 'fullName': fullName, 'power': power};

  factory Player.fromMap(Map<String, dynamic> m) => Player(
        id: m['id'] as String,
        fullName: m['fullName'] as String,
        power: (m['power'] as num?)?.toDouble() ?? 5.0,
      );
}

class Coach {
  final String id;
  String fullName;
  double iqPower;

  Coach({required this.id, required this.fullName, required this.iqPower});

  Map<String, dynamic> toMap() =>
      {'id': id, 'fullName': fullName, 'iqPower': iqPower};

  factory Coach.fromMap(Map<String, dynamic> m) => Coach(
        id: m['id'] as String,
        fullName: m['fullName'] as String,
        iqPower: (m['iqPower'] as num?)?.toDouble() ?? 5.0,
      );
}

class GoalKeeper {
  final String id;
  String fullName;
  double keepingPower;

  GoalKeeper({
    required this.id,
    required this.fullName,
    required this.keepingPower,
  });

  Map<String, dynamic> toMap() =>
      {'id': id, 'fullName': fullName, 'keepingPower': keepingPower};

  factory GoalKeeper.fromMap(Map<String, dynamic> m) => GoalKeeper(
        id: m['id'] as String,
        fullName: m['fullName'] as String,
        keepingPower: (m['keepingPower'] as num?)?.toDouble() ?? 5.0,
      );
}

class LeagueTableItem {
  final String teamId;
  final String teamName;
  final String teamIcon;
  final String? groupId;

  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;

  int get goalDifference => goalsFor - goalsAgainst;

  LeagueTableItem({
    required this.teamId,
    required this.teamName,
    required this.teamIcon,
    this.groupId,
  });
}
