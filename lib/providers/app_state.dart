import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/league.dart';
import '../models/models.dart';
import '../services/fixture_engine.dart';
import '../services/standings_service.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';

class AppState extends ChangeNotifier {
  final _storage = StorageService();
  final _engine = FixtureEngine();
  final _rng = Random();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  final List<Team> _teams = [];
  List<Team> get teams => List.unmodifiable(_teams);

  final List<League> _leagues = [];
  List<League> get leagues => List.unmodifiable(_leagues);

  Timer? _engineTimer;
  final Map<String, _LiveState> _live = {};

  bool _loaded = false;
  bool get loaded => _loaded;

  // ---------- Persistence ----------
  Future<void> load() async {
    final data = await _storage.load();
    if (data != null) {
      final tm = data['themeMode'] as String? ?? 'system';
      _themeMode = switch (tm) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _teams
        ..clear()
        ..addAll(((data['teams'] as List?) ?? [])
            .map((e) => Team.fromMap(Map<String, dynamic>.from(e))));
      _leagues
        ..clear()
        ..addAll(((data['leagues'] as List?) ?? [])
            .map((e) => League.fromMap(Map<String, dynamic>.from(e))));
    }
    _loaded = true;
    _startEngine();
    notifyListeners();
  }

  Future<void> save() async {
    await _storage.save({
      'themeMode': switch (_themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
      'teams': _teams.map((e) => e.toMap()).toList(),
      'leagues': _leagues.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> _save() => save();

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    save();
    notifyListeners();
  }

  @override
  void dispose() {
    _engineTimer?.cancel();
    super.dispose();
  }

  // ---------- Teams ----------
  Team? findTeam(String id) {
    for (final t in _teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> addTeam({
    required String name,
    required String icon,
    required double teamPower,
    required List<Player> players,
    required Coach coach,
    required List<GoalKeeper> keepers,
  }) async {
    _teams.add(Team(
      id: newId(),
      name: name.trim(),
      icon: icon,
      teamPower: teamPower,
      players: players,
      coach: coach,
      keepers: keepers,
    ));
    await save();
    notifyListeners();
  }

  Future<void> updateTeam(String teamId, String newName, String newIcon) async {
    final t = findTeam(teamId);
    if (t == null) return;
    t.name = newName.trim();
    t.icon = newIcon;
    await save();
    notifyListeners();
  }

  Future<String?> deleteTeam(String teamId) async {
    final used = _leagues.any((l) => l.teamIds.contains(teamId));
    if (used) {
      return 'Bu takım bir turnuvada yer alıyor. Önce turnuvayı silin.';
    }
    _teams.removeWhere((t) => t.id == teamId);
    await save();
    notifyListeners();
    return null;
  }

  Future<void> addPlayerToTeam(String teamId, Player player) async {
    findTeam(teamId)?.players.add(player);
    await save();
    notifyListeners();
  }

  Future<void> addKeeperToTeam(String teamId, GoalKeeper keeper) async {
    findTeam(teamId)?.keepers.add(keeper);
    await save();
    notifyListeners();
  }

  Future<void> removePlayer(String teamId, String playerId) async {
    findTeam(teamId)?.players.removeWhere((p) => p.id == playerId);
    await save();
    notifyListeners();
  }

  Future<void> removeKeeper(String teamId, String keeperId) async {
    findTeam(teamId)?.keepers.removeWhere((k) => k.id == keeperId);
    await save();
    notifyListeners();
  }

  // ---------- Leagues ----------
  League? findLeague(String id) {
    for (final l in _leagues) {
      if (l.id == id) return l;
    }
    return null;
  }

  Future<void> deleteLeague(String leagueId) async {
    _leagues.removeWhere((l) => l.id == leagueId);
    await save();
    notifyListeners();
  }

  Future<void> updateLeagueName(String leagueId, String newName) async {
    final l = findLeague(leagueId);
    if (l == null) return;
    l.title = newName.trim();
    await save();
    notifyListeners();
  }

  Future<String?> createLeagueAndSchedule({
    required String title,
    required LeagueFormat format,
    required List<String> teamIds,
    required DateTime startDate,
    required int startHour,
    required int endHour,
    required int daysBetweenRounds,
    required Duration minGap,
    int winPoints = 3,
    int drawPoints = 1,
    int losePoints = 0,
    int leagueColorValue = 0xFF0B6E4F,
    List<RankDefinition> rankDefinitions = const [],
    int groupCount = 2,
    int qualifiersPerGroup = 2,
    int swissMatches = 3,
    String icon = '🏆',
    // Eski imza uyumu
    LeagueType? type,
    int rounds = 2,
  }) async {
    // Eski çağrılar format göndermeden type kullanıyordu
    var fmt = format;
    if (type != null && format == LeagueFormat.leagueDouble) {
      fmt = switch (type) {
        LeagueType.elimination => LeagueFormat.cupSingle,
        LeagueType.fixedMatches => LeagueFormat.swiss,
        LeagueType.league =>
          rounds <= 1 ? LeagueFormat.leagueSingle : LeagueFormat.leagueDouble,
      };
    }

    final ids = List<String>.from(teamIds);
    final err = _engine.validate(
      format: fmt,
      teamIds: ids,
      groupCount: groupCount,
      qualifiersPerGroup: qualifiersPerGroup,
      swissMatches: swissMatches,
    );
    if (err != null) return err;

    final existing = _leagues.expand((l) => l.matches).toList();
    final cfg = ScheduleConfig(
      startDate: startDate,
      startHour: startHour,
      endHour: endHour,
      daysBetweenRounds: daysBetweenRounds.clamp(1, 14),
      minGap: minGap,
      existingMatches: existing,
    );

    final league = League(
      id: newId(),
      title: title.trim().isEmpty ? 'Yeni Turnuva' : title.trim(),
      format: fmt,
      teamIds: ids,
      startDate: startDate,
      endDate: startDate.add(const Duration(days: 30)),
      matches: [],
      winPoints: winPoints,
      drawPoints: drawPoints,
      losePoints: losePoints,
      leagueColorValue: leagueColorValue,
      rankDefinitions: List.of(rankDefinitions),
      groups: const [],
      qualifiersPerGroup: qualifiersPerGroup,
      swissMatches: swissMatches,
      legs: fmt == LeagueFormat.leagueDouble ? 2 : 1,
      icon: icon,
    );

    List<PlannedMatch> planned = [];

    switch (fmt) {
      case LeagueFormat.leagueSingle:
        planned = _engine.generateLeague(teamIds: ids, legs: 1);
        break;
      case LeagueFormat.leagueDouble:
        planned = _engine.generateLeague(teamIds: ids, legs: 2);
        break;
      case LeagueFormat.swiss:
        planned = _engine.generateSwiss(
          teamIds: ids,
          matchesPerTeam: swissMatches,
        );
        break;
      case LeagueFormat.groupsOnly:
      case LeagueFormat.worldCup:
      case LeagueFormat.championsLeague:
        final groups = _engine.makeGroups(
          teamIds: ids,
          groupCount: groupCount,
        );
        league.groups = groups;
        planned = _engine.generateGroupMatches(groups: groups, legs: 1);
        break;
      case LeagueFormat.cupSingle:
        planned = _engine.generateKnockoutRound(
          teamIds: ids,
          twoLegged: false,
          isFinalSingle: true,
        );
        break;
      case LeagueFormat.cupTwoLegged:
        planned = _engine.generateKnockoutRound(
          teamIds: ids,
          twoLegged: true,
          isFinalSingle: true,
        );
        break;
    }

    if (planned.isEmpty) {
      return 'Fikstür üretilemedi. Takım sayısı ve formatı kontrol edin.';
    }

    final games = _engine.schedule(
      leagueId: league.id,
      planned: planned,
      cfg: cfg,
    );
    league.matches.addAll(games);
    if (games.isNotEmpty) {
      final last = games.last.startTime ?? startDate;
      league.endDate = last;
    }

    _leagues.add(league);
    await save();
    notifyListeners();
    return null;
  }

  // ---------- Matches ----------
  MatchGame? findMatchById(String matchId) {
    for (final lg in _leagues) {
      for (final m in lg.matches) {
        if (m.id == matchId) return m;
      }
    }
    return null;
  }

  League? leagueOfMatch(String matchId) {
    for (final lg in _leagues) {
      if (lg.matches.any((m) => m.id == matchId)) return lg;
    }
    return null;
  }

  Future<void> setLineup({
    required String matchId,
    required bool isHome,
    required List<String> playerIds,
    required String? keeperId,
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return;
    final lu = Lineup(playerIds: List.of(playerIds), keeperId: keeperId);
    if (isHome) {
      m.homeLineup = lu;
    } else {
      m.awayLineup = lu;
    }
    await save();
    notifyListeners();
  }

  bool _violatesForTeamAt({
    required String teamId,
    required DateTime candidateKickoff,
    required Duration minGap,
    String? excludeMatchId,
  }) {
    for (final lg in _leagues) {
      for (final m in lg.matches) {
        if (excludeMatchId != null && m.id == excludeMatchId) continue;
        final st = m.startTime;
        if (st == null) continue;
        if (m.homeTeamId != teamId && m.awayTeamId != teamId) continue;
        if (dateOnly(st) == dateOnly(candidateKickoff)) return true;
        if (candidateKickoff.difference(st).abs() < minGap) return true;
      }
    }
    return false;
  }

  Future<String?> rescheduleMatch({
    required String matchId,
    required DateTime newStart,
    Duration minGap = const Duration(hours: 48),
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return 'Maç bulunamadı.';
    if (m.status != MatchStatus.scheduled) {
      return 'Sadece planlı maçların zamanı düzenlenebilir.';
    }
    final lg = findLeague(m.leagueId);
    if (lg == null) return 'Lig bulunamadı.';

    if (_violatesForTeamAt(
      teamId: m.homeTeamId,
      candidateKickoff: newStart,
      minGap: minGap,
      excludeMatchId: m.id,
    )) {
      return 'Ev sahibi için aynı gün veya yetersiz dinlenme süresi var.';
    }
    if (_violatesForTeamAt(
      teamId: m.awayTeamId,
      candidateKickoff: newStart,
      minGap: minGap,
      excludeMatchId: m.id,
    )) {
      return 'Deplasman için aynı gün veya yetersiz dinlenme süresi var.';
    }

    m.startTime = newStart;
    if (newStart.isAfter(lg.endDate)) lg.endDate = newStart;
    await save();
    notifyListeners();
    return null;
  }

  void undoMatchResult(String matchId) {
    final m = findMatchById(matchId);
    if (m == null || m.isBye) return;
    m.status = MatchStatus.scheduled;
    m.homeGoals = 0;
    m.awayGoals = 0;
    m.events.clear();
    m.goalsByPlayer.clear();
    m.finalized = false;
    m.endTime = null;
    m.winnerTeamId = null;
    m.usedPenalties = false;
    m.homePenalties = 0;
    m.awayPenalties = 0;
    _live.remove(matchId);
    notifyListeners();
    save();
  }

  Future<void> setMatchResult(
    String matchId,
    int homeScore,
    int awayScore, {
    int homePenalties = 0,
    int awayPenalties = 0,
    bool usedPenalties = false,
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return;
    m.homeGoals = homeScore.clamp(0, 99);
    m.awayGoals = awayScore.clamp(0, 99);
    m.status = MatchStatus.finished;
    m.endTime = DateTime.now();
    m.usedPenalties = usedPenalties;
    m.homePenalties = homePenalties;
    m.awayPenalties = awayPenalties;
    _resolveWinner(m);
    m.finalized = true;
    _applyPostMatchAdjustments(m);
    _tryAdvanceCompetition(m.leagueId);
    notifyListeners();
    await save();
  }

  Future<void> finishMatchAndFinalize({required String matchId}) async {
    final m = findMatchById(matchId);
    if (m == null) return;
    if (m.finalized) return;
    m.status = MatchStatus.finished;
    m.endTime ??= DateTime.now();
    final byPlayer = <String, int>{};
    for (final ev in m.events) {
      if (ev.playerId == null || ev.playerId!.isEmpty) continue;
      if (ev.type == EventType.goal || ev.type == EventType.penaltyGoal) {
        byPlayer.update(ev.playerId!, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    m.goalsByPlayer = byPlayer;
    _resolveWinner(m);
    m.finalized = true;
    _tryAdvanceCompetition(m.leagueId);
    await save();
    notifyListeners();
  }

  void _resolveWinner(MatchGame m) {
    if (m.isBye) {
      m.winnerTeamId = m.homeTeamId == 'BYE' ? m.awayTeamId : m.homeTeamId;
      return;
    }
    final lg = findLeague(m.leagueId);
    if (lg == null) return;

    if (!m.stage.isKnockout) {
      m.winnerTeamId = null;
      return;
    }

    if (m.tieId != null) {
      final legs = lg.matches.where((x) => x.tieId == m.tieId).toList();
      if (legs.any((x) => x.status != MatchStatus.finished)) {
        m.winnerTeamId = null;
        return;
      }
      var aGoals = 0;
      var bGoals = 0;
      final a = legs.first.homeTeamId;
      final b = legs.first.awayTeamId;
      for (final leg in legs) {
        if (leg.homeTeamId == a) {
          aGoals += leg.homeGoals;
          bGoals += leg.awayGoals;
        } else {
          aGoals += leg.awayGoals;
          bGoals += leg.homeGoals;
        }
      }
      if (aGoals != bGoals) {
        final winner = aGoals > bGoals ? a : b;
        for (final leg in legs) {
          leg.winnerTeamId = winner;
        }
        return;
      }
      final last = legs.reduce((x, y) => x.leg >= y.leg ? x : y);
      if (last.usedPenalties && last.homePenalties != last.awayPenalties) {
        final winner = last.homePenalties > last.awayPenalties
            ? last.homeTeamId
            : last.awayTeamId;
        for (final leg in legs) {
          leg.winnerTeamId = winner;
        }
        return;
      }
      return;
    }

    if (m.homeGoals != m.awayGoals) {
      m.winnerTeamId = m.homeGoals > m.awayGoals ? m.homeTeamId : m.awayTeamId;
      return;
    }
    if (m.usedPenalties && m.homePenalties != m.awayPenalties) {
      m.winnerTeamId =
          m.homePenalties > m.awayPenalties ? m.homeTeamId : m.awayTeamId;
    }
  }

  /// Gruplar bittiğinde veya eleme turu kapandığında sonraki turu üretir.
  void _tryAdvanceCompetition(String leagueId) {
    final lg = findLeague(leagueId);
    if (lg == null) return;
    if (!lg.format.hasKnockout) return;

    if (lg.format.hasGroups) {
      final groupMatches =
          lg.matches.where((m) => m.stage == MatchStage.group).toList();
      if (groupMatches.isEmpty) return;
      if (groupMatches.any((m) => m.status != MatchStatus.finished)) return;
      final hasKo = lg.matches.any((m) => m.stage.isKnockout);
      if (!hasKo) {
        _generateKnockoutFromGroups(lg);
        return;
      }
    }

    _advanceKnockoutRound(lg);
  }

  void _generateKnockoutFromGroups(League lg) {
    final tables = StandingsService.byGroup(league: lg, findTeam: findTeam);
    final seeds = <String>[];
    final seconds = <String>[];
    for (final g in lg.groups) {
      final table = tables[g.id] ?? [];
      for (var i = 0; i < lg.qualifiersPerGroup && i < table.length; i++) {
        if (i == 0) {
          seeds.add(table[i].teamId);
        } else {
          seconds.add(table[i].teamId);
        }
      }
    }
    // A1-B2, B1-A2, C1-D2... klasik eşleşme
    final paired = <String>[];
    final n = min(seeds.length, seconds.length);
    if (n >= 1 && seeds.length == seconds.length) {
      for (var i = 0; i < seeds.length; i++) {
        final opp = seconds[(i + 1) % seconds.length];
        paired.add(seeds[i]);
        paired.add(opp);
      }
    } else {
      paired.addAll([...seeds, ...seconds]);
    }

    final two = lg.format.isTwoLeggedKnockout;
    final planned = _engine.generateKnockoutRound(
      teamIds: paired,
      twoLegged: two,
      isFinalSingle: true,
    );
    if (planned.isEmpty) return;

    final last = lg.matches
        .map((m) => m.startTime)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final cfg = ScheduleConfig(
      startDate: (last ?? lg.endDate).add(const Duration(days: 3)),
      startHour: 18,
      endHour: 22,
      daysBetweenRounds: 3,
      minGap: const Duration(hours: 60),
      existingMatches: _leagues.expand((l) => l.matches).toList(),
    );
    final games = _engine.schedule(
      leagueId: lg.id,
      planned: planned,
      cfg: cfg,
    );
    lg.matches.addAll(games);
    if (games.isNotEmpty) {
      lg.endDate = games.last.startTime ?? lg.endDate;
    }
  }

  void _advanceKnockoutRound(League lg) {
    final ko = lg.matches.where((m) => m.stage.isKnockout && !m.isBye).toList();
    if (ko.isEmpty) return;

    const order = [
      MatchStage.roundOf32,
      MatchStage.roundOf16,
      MatchStage.quarterFinal,
      MatchStage.semiFinal,
      MatchStage.finalMatch,
    ];
    MatchStage? current;
    for (final s in order) {
      final ms = lg.matches.where((m) => m.stage == s).toList();
      if (ms.isEmpty) continue;
      if (ms.any((m) => m.status != MatchStatus.finished && !m.isBye)) {
        return;
      }
      current = s;
    }
    if (current == null || current == MatchStage.finalMatch) return;

    final alreadyNext = order.indexOf(current) + 1;
    if (alreadyNext >= order.length) return;
    final nextStage = order[alreadyNext];
    if (lg.matches.any((m) => m.stage == nextStage)) return;

    final winners = <String>[];
    final currentMatches = lg.matches.where((m) => m.stage == current).toList();
    final seenTies = <String>{};
    for (final m in currentMatches) {
      if (m.isBye) {
        if (m.winnerTeamId != null) winners.add(m.winnerTeamId!);
        continue;
      }
      if (m.tieId != null) {
        if (seenTies.contains(m.tieId)) continue;
        seenTies.add(m.tieId!);
        final w = m.winnerTeamId;
        if (w == null) return; // rövanş çözülmedi
        winners.add(w);
      } else {
        if (m.winnerTeamId == null) return;
        winners.add(m.winnerTeamId!);
      }
    }

    if (winners.length < 2) return;

    final two = lg.format.isTwoLeggedKnockout && nextStage != MatchStage.finalMatch;
    final planned = _engine.generateKnockoutRound(
      teamIds: winners,
      twoLegged: two,
      isFinalSingle: true,
    );
    final last = lg.matches
        .map((m) => m.startTime)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final cfg = ScheduleConfig(
      startDate: (last ?? DateTime.now()).add(const Duration(days: 3)),
      startHour: 18,
      endHour: 22,
      daysBetweenRounds: 3,
      minGap: const Duration(hours: 60),
      existingMatches: _leagues.expand((l) => l.matches).toList(),
    );
    final games = _engine.schedule(
      leagueId: lg.id,
      planned: planned,
      cfg: cfg,
    );
    lg.matches.addAll(games);
    if (games.isNotEmpty) {
      lg.endDate = games.last.startTime ?? lg.endDate;
    }
  }

  Future<String?> forceAdvance(String leagueId) async {
    final lg = findLeague(leagueId);
    if (lg == null) return 'Lig bulunamadı.';
    final before = lg.matches.length;
    _tryAdvanceCompetition(leagueId);
    if (lg.matches.length == before) {
      return 'Sonraki tur henüz üretilemez. Açık maçları bitirin.';
    }
    await save();
    notifyListeners();
    return null;
  }

  Future<void> recordKeeperSave({
    required String matchId,
    required bool byHomeKeeper,
  }) async {
    final m = findMatchById(matchId);
    if (m == null || m.status != MatchStatus.live) return;
    if (byHomeKeeper) {
      m.homeSaves += 1;
    } else {
      m.awaySaves += 1;
    }
    await save();
    notifyListeners();
  }

  int liveMinuteFor(String matchId) {
    final ls = _live[matchId];
    if (ls != null) return ls.currentMinute.clamp(0, 90);
    final m = findMatchById(matchId);
    if (m == null || m.startTime == null) return 0;
    return DateTime.now().difference(m.startTime!).inSeconds.clamp(0, 90);
  }

  Future<void> recordAiGoal({
    required String matchId,
    required bool isHome,
    int? minuteOverride,
  }) async {
    final m = findMatchById(matchId);
    if (m == null || m.status != MatchStatus.live) return;
    final minute = (minuteOverride ?? liveMinuteFor(matchId)).clamp(0, 90);
    _registerGoal(m, isHome: isHome, minute: minute);
    final ls = _live[matchId];
    if (ls != null) {
      if (isHome) {
        ls.cooldownHomeUntilMinute = (minute + 2).clamp(0, 90);
      } else {
        ls.cooldownAwayUntilMinute = (minute + 2).clamp(0, 90);
      }
    }
    await save();
    notifyListeners();
  }

  // ---------- Live engine ----------
  void _startEngine() {
    _engineTimer?.cancel();
    _engineTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _ensureAutoLineupsIfMissing(MatchGame m) {
    Lineup autoForTeam(Team t) {
      final playersSorted = List<Player>.from(t.players)
        ..sort((a, b) => b.power.compareTo(a.power));
      final starters = playersSorted.take(11).map((e) => e.id).toList();
      String? kId;
      if (t.keepers.isNotEmpty) {
        final ks = List<GoalKeeper>.from(t.keepers)
          ..sort((a, b) => b.keepingPower.compareTo(a.keepingPower));
        kId = ks.first.id;
      }
      return Lineup(playerIds: starters, keeperId: kId);
    }

    if (m.homeLineup == null) {
      final ht = findTeam(m.homeTeamId);
      if (ht != null) m.homeLineup = autoForTeam(ht);
    }
    if (m.awayLineup == null) {
      final at = findTeam(m.awayTeamId);
      if (at != null) m.awayLineup = autoForTeam(at);
    }
  }

  void _tick() {
    final now = DateTime.now();
    var changed = false;

    for (final lg in _leagues) {
      for (final m in lg.matches) {
        final st = m.startTime;
        if (st == null || m.isBye) continue;

        if (m.status == MatchStatus.scheduled && now.isAfter(st)) {
          _ensureAutoLineupsIfMissing(m);
          m.status = MatchStatus.live;
          _live[m.id] = _LiveState(startedAt: now, currentMinute: 0);
          changed = true;
        }

        if (m.status == MatchStatus.live) {
          final ls = _live[m.id] ??
              _LiveState(startedAt: now, currentMinute: 0);
          _live[m.id] = ls;
          final nextMinuteAt =
              ls.nextTickAt ?? now.add(const Duration(seconds: 1));
          if (now.isAfter(nextMinuteAt)) {
            ls.currentMinute += 1;
            ls.nextTickAt = now.add(const Duration(seconds: 1));
            changed = true;
            _maybeScore(m, minute: ls.currentMinute, live: ls);
            if (ls.currentMinute >= 90) {
              m.status = MatchStatus.finished;
              _applyPostMatchAdjustments(m);
              finishMatchAndFinalize(matchId: m.id);
              _live.remove(m.id);
              changed = true;
            }
          }
        }
      }
    }
    if (changed) notifyListeners();
  }

  double _effectiveStrength(Team t) {
    if (t.players.isEmpty) {
      return t.teamPower +
          t.coach.iqPower +
          (t.keepers.isNotEmpty ? t.keepers.first.keepingPower * .3 : 0);
    }
    final avgPlayers =
        t.players.fold<double>(0, (s, p) => s + p.power) / t.players.length;
    final bestKeeper = t.keepers.isEmpty
        ? 0.0
        : t.keepers.map((k) => k.keepingPower).reduce(max);
    return t.teamPower + (avgPlayers * 0.5) + t.coach.iqPower + (bestKeeper * 0.3);
  }

  void _maybeScore(MatchGame m,
      {required int minute, required _LiveState live}) {
    final home = findTeam(m.homeTeamId);
    final away = findTeam(m.awayTeamId);
    if (home == null || away == null) return;

    final sh = _effectiveStrength(home).clamp(1.0, 20.0);
    final sa = _effectiveStrength(away).clamp(1.0, 20.0);
    final total = sh + sa;
    const mu = 2.6 / 90.0;
    var ph = mu * (sh / total);
    var pa = mu * (sa / total);
    if (live.cooldownHomeUntilMinute != null &&
        minute <= live.cooldownHomeUntilMinute!) {
      ph *= 0.5;
    }
    if (live.cooldownAwayUntilMinute != null &&
        minute <= live.cooldownAwayUntilMinute!) {
      pa *= 0.5;
    }
    if (_rng.nextDouble() < ph) {
      _registerGoal(m, isHome: true, minute: minute);
      live.cooldownHomeUntilMinute = minute + 2;
    }
    if (_rng.nextDouble() < pa) {
      _registerGoal(m, isHome: false, minute: minute);
      live.cooldownAwayUntilMinute = minute + 2;
    }
  }

  void _registerGoal(MatchGame m, {required bool isHome, required int minute}) {
    if (isHome) {
      m.homeGoals += 1;
    } else {
      m.awayGoals += 1;
    }
    String? scorerId;
    final team = findTeam(isHome ? m.homeTeamId : m.awayTeamId);
    final lineup = isHome ? m.homeLineup : m.awayLineup;
    if (team != null) {
      var pool = <String>[];
      if (lineup != null && lineup.playerIds.isNotEmpty) {
        pool = lineup.playerIds;
      } else {
        pool = team.players.map((p) => p.id).toList();
      }
      if (pool.isNotEmpty) {
        scorerId = pool[_rng.nextInt(pool.length)];
      }
    }
    m.events.add(MatchEvent(
      minute: minute,
      teamId: isHome ? m.homeTeamId : m.awayTeamId,
      isHome: isHome,
      playerId: scorerId,
      type: EventType.goal,
    ));
  }

  void _applyPostMatchAdjustments(MatchGame m) {
    if (m.isBye) return;
    final ht = findTeam(m.homeTeamId);
    final at = findTeam(m.awayTeamId);
    if (ht == null || at == null) return;

    if (m.homeGoals > m.awayGoals) {
      ht.teamPower = (ht.teamPower + 0.02).clamp(1.0, 8.0);
      at.teamPower = (at.teamPower - 0.02).clamp(1.0, 8.0);
    } else if (m.awayGoals > m.homeGoals) {
      at.teamPower = (at.teamPower + 0.02).clamp(1.0, 8.0);
      ht.teamPower = (ht.teamPower - 0.02).clamp(1.0, 8.0);
    } else {
      ht.teamPower = (ht.teamPower + 0.005).clamp(1.0, 8.0);
      at.teamPower = (at.teamPower + 0.005).clamp(1.0, 8.0);
    }

    void buffScorers(Team t, String tid) {
      for (final e in m.events.where((e) => e.teamId == tid && e.playerId != null)) {
        final idx = t.players.indexWhere((p) => p.id == e.playerId);
        if (idx >= 0) {
          t.players[idx].power = (t.players[idx].power + 0.05).clamp(1.0, 8.0);
        }
      }
    }

    buffScorers(ht, ht.id);
    buffScorers(at, at.id);
  }

  TeamStats statsForTeam(String teamId) {
    var played = 0, win = 0, draw = 0, lose = 0, gf = 0, ga = 0;
    final games = <MatchGame>[];
    for (final lg in _leagues) {
      for (final m in lg.matches) {
        if (m.status != MatchStatus.finished || m.isBye) continue;
        if (m.homeTeamId != teamId && m.awayTeamId != teamId) continue;
        games.add(m);
        played++;
        final isHome = m.homeTeamId == teamId;
        final my = isHome ? m.homeGoals : m.awayGoals;
        final opp = isHome ? m.awayGoals : m.homeGoals;
        gf += my;
        ga += opp;
        if (my > opp) {
          win++;
        } else if (my == opp) {
          draw++;
        } else {
          lose++;
        }
      }
    }
    return TeamStats(
      played: played,
      win: win,
      draw: draw,
      lose: lose,
      goalsFor: gf,
      goalsAgainst: ga,
      matches: games,
    );
  }
}

class _LiveState {
  int currentMinute;
  DateTime startedAt;
  DateTime? nextTickAt;
  int? cooldownHomeUntilMinute;
  int? cooldownAwayUntilMinute;

  _LiveState({
    required this.startedAt,
    this.currentMinute = 0,
    this.nextTickAt,
    this.cooldownHomeUntilMinute,
    this.cooldownAwayUntilMinute,
  });
}

class TeamStats {
  final int played, win, draw, lose, goalsFor, goalsAgainst;
  final List<MatchGame> matches;
  TeamStats({
    required this.played,
    required this.win,
    required this.draw,
    required this.lose,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.matches,
  });
}
