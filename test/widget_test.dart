import 'package:flutter_test/flutter_test.dart';
import 'package:kont/services/fixture_engine.dart';
import 'package:kont/models/enums.dart';

void main() {
  final engine = FixtureEngine(seed: 1);

  test('round robin even teams produces n-1 rounds', () {
    final teams = ['a', 'b', 'c', 'd'];
    final rounds = engine.roundRobinRounds(teams);
    expect(rounds.length, 3);
    final matches = rounds.expand((e) => e).toList();
    expect(matches.length, 6);
  });

  test('round robin odd teams skips byes', () {
    final teams = ['a', 'b', 'c'];
    final rounds = engine.roundRobinRounds(teams);
    expect(rounds.length, 3);
    expect(rounds.every((r) => r.length == 1), isTrue);
  });

  test('swiss validation rejects odd team count', () {
    final err = engine.validate(
      format: LeagueFormat.swiss,
      teamIds: ['a', 'b', 'c'],
      groupCount: 2,
      qualifiersPerGroup: 2,
      swissMatches: 2,
    );
    expect(err, isNotNull);
  });

  test('world cup requires at least 4 teams', () {
    final err = engine.validate(
      format: LeagueFormat.worldCup,
      teamIds: ['a', 'b'],
      groupCount: 2,
      qualifiersPerGroup: 2,
      swissMatches: 3,
    );
    expect(err, isNotNull);
  });

  test('double league generates home and away', () {
    final planned = engine.generateLeague(teamIds: ['a', 'b', 'c', 'd'], legs: 2);
    expect(planned.length, 12);
  });
}
