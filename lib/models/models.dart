import 'dart:convert';

/// A team intentionally has only the identity needed by the app: a name and
/// an icon. Match simulation derives a neutral strength from the name.
class Team {
  final String id;
  String name;
  String icon;

  Team({
    required this.id,
    required this.name,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
      };

  factory Team.fromMap(Map<String, dynamic> m) => Team(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? '⚽',
      );

  String toJson() => jsonEncode(toMap());
  factory Team.fromJson(String s) => Team.fromMap(jsonDecode(s));
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
  int fairPlay = 0;

  int get goalDifference => goalsFor - goalsAgainst;

  LeagueTableItem({
    required this.teamId,
    required this.teamName,
    required this.teamIcon,
    this.groupId,
  });
}
