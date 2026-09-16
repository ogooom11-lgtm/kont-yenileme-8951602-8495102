import 'dart:async';
import 'dart:convert';
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

  // Kullanıcının uygulama davranışını turnuvalardan bağımsız özelleştirmesi.
  bool _autoLiveSimulation = true;
  bool _smartAutoAdvance = true;
  bool _confirmResults = true;
  bool _compactCards = false;
  bool get autoLiveSimulation => _autoLiveSimulation;
  bool get smartAutoAdvance => _smartAutoAdvance;
  bool get confirmResults => _confirmResults;
  bool get compactCards => _compactCards;

  final List<Team> _teams = [];
  List<Team> get teams => List.unmodifiable(_teams);

  final List<League> _leagues = [];
  List<League> get leagues => List.unmodifiable(_leagues);

  Timer? _engineTimer;
  final Map<String, _LiveState> _live = {};
  Future<void> _saveChain = Future<void>.value();

  bool _loaded = false;
  bool get loaded => _loaded;

  // ---------- Persistence ----------
  Future<void> load() async {
    final data = await _storage.load();
    if (data != null) {
      try {
        final tm = data['themeMode'] as String? ?? 'system';
      _themeMode = switch (tm) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _autoLiveSimulation = data['autoLiveSimulation'] as bool? ?? true;
      _smartAutoAdvance = data['smartAutoAdvance'] as bool? ?? true;
      _confirmResults = data['confirmResults'] as bool? ?? true;
      _compactCards = data['compactCards'] as bool? ?? false;
      _teams
        ..clear()
        ..addAll(((data['teams'] as List?) ?? []).whereType<Map>().map(
            (e) => Team.fromMap(Map<String, dynamic>.from(e))));
      _leagues
        ..clear()
        ..addAll(((data['leagues'] as List?) ?? []).whereType<Map>().map(
            (e) => League.fromMap(Map<String, dynamic>.from(e))));
      } catch (_) {
        // Bozuk/yarım bir yedek uygulamayı açılmaz hale getirmemeli.
        _teams.clear();
        _leagues.clear();
      }
    }
    _loaded = true;
    _startEngine();
    notifyListeners();
  }

  Future<void> save() {
    final snapshot = <String, dynamic>{
      'themeMode': switch (_themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
      'autoLiveSimulation': _autoLiveSimulation,
      'smartAutoAdvance': _smartAutoAdvance,
      'confirmResults': _confirmResults,
      'compactCards': _compactCards,
      'teams': _teams.map((e) => e.toMap()).toList(),
      'leagues': _leagues.map((e) => e.toMap()).toList(),
    };
    // Hızlı arka arkaya işlemler (gol, kart, ayar) eski snapshot'ın yeni
    // verinin üzerine yazmasını engellemek için sıraya alınır.
    _saveChain = _saveChain.then((_) => _storage.save(snapshot));
    return _saveChain;
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    save();
    notifyListeners();
  }

  void toggleTheme() {
    final next = switch (_themeMode) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
    };
    setThemeMode(next);
  }

  void setAutoLiveSimulation(bool value) {
    if (_autoLiveSimulation == value) return;
    _autoLiveSimulation = value;
    save();
    notifyListeners();
  }

  void setSmartAutoAdvance(bool value) {
    if (_smartAutoAdvance == value) return;
    _smartAutoAdvance = value;
    save();
    notifyListeners();
  }

  void setConfirmResults(bool value) {
    if (_confirmResults == value) return;
    _confirmResults = value;
    save();
    notifyListeners();
  }

  void setCompactCards(bool value) {
    if (_compactCards == value) return;
    _compactCards = value;
    save();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _live.clear();
    _teams.clear();
    _leagues.clear();
    await save();
    notifyListeners();
  }

  String exportJson() => jsonEncode({
        'schemaVersion': 3,
        'themeMode': switch (_themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          _ => 'system',
        },
        'autoLiveSimulation': _autoLiveSimulation,
        'smartAutoAdvance': _smartAutoAdvance,
        'confirmResults': _confirmResults,
        'compactCards': _compactCards,
        'teams': _teams.map((e) => e.toMap()).toList(),
        'leagues': _leagues.map((e) => e.toMap()).toList(),
      });

  Future<String?> importJson(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final importedTeams = ((data['teams'] as List?) ?? [])
          .map((e) => Team.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final importedLeagues = ((data['leagues'] as List?) ?? [])
          .map((e) => League.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final theme = data['themeMode'] as String?;
      _themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _autoLiveSimulation = data['autoLiveSimulation'] as bool? ?? true;
      _smartAutoAdvance = data['smartAutoAdvance'] as bool? ?? true;
      _confirmResults = data['confirmResults'] as bool? ?? true;
      _compactCards = data['compactCards'] as bool? ?? false;
      _live.clear();
      _teams
        ..clear()
        ..addAll(importedTeams);
      _leagues
        ..clear()
        ..addAll(importedLeagues);
      await save();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Yedek dosyası geçersiz veya bozuk.';
    }
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

  Future<String?> addTeam({
    required String name,
    required String icon,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return 'Takım adı boş bırakılamaz.';
    if (_teams.any((team) => team.name.trim().toLowerCase() == cleanName.toLowerCase())) {
      return 'Bu isimde bir takım zaten var.';
    }
    _teams.add(Team(
      id: newId(),
      name: cleanName,
      icon: icon.trim().isEmpty ? '⚽' : icon.trim(),
    ));
    await save();
    notifyListeners();
    return null;
  }

  Future<String?> updateTeam(String teamId, String newName, String newIcon) async {
    final t = findTeam(teamId);
    if (t == null) return 'Takım bulunamadı.';
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return 'Takım adı boş bırakılamaz.';
    if (_teams.any((team) => team.id != teamId && team.name.trim().toLowerCase() == cleanName.toLowerCase())) {
      return 'Bu isimde bir takım zaten var.';
    }
    t.name = cleanName;
    t.icon = newIcon.trim().isEmpty ? '⚽' : newIcon.trim();
    await save();
    notifyListeners();
    return null;
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

  Future<void> updateLeagueRules(
    String leagueId, {
    bool? autoAdvance,
    bool? allowExtraTime,
    bool? allowPenalties,
    int? minRestHours,
    bool? seededKnockoutDraw,
  }) async {
    final league = findLeague(leagueId);
    if (league == null) return;
    if (autoAdvance != null) league.autoAdvance = autoAdvance;
    if (allowExtraTime != null) league.allowExtraTime = allowExtraTime;
    if (allowPenalties != null) league.allowPenalties = allowPenalties;
    if (seededKnockoutDraw != null) league.seededKnockoutDraw = seededKnockoutDraw;
    if (minRestHours != null) {
      league.minRestHours = minRestHours.clamp(1, 240).toInt();
    }
    await save();
    notifyListeners();
  }

  MatchStage _initialKnockoutStage(
    Map<String, MatchStage> entries,
    List<String> teamIds,
  ) {
    for (final stage in knockoutStageOrder) {
      if (teamIds.any((id) => entries[id] == stage)) return stage;
    }
    return MatchStageX.fromTeamCount(nextPowerOfTwo(teamIds.length));
  }

  int _knockoutTargetWinners(
    League league,
    MatchStage stage,
    int participants,
  ) {
    if (participants <= 0) return 0;
    final index = knockoutStageOrder.indexOf(stage);
    if (index < 0 || index + 1 >= knockoutStageOrder.length) return 1;
    final nextStage = knockoutStageOrder[index + 1];
    final directNext = league.knockoutEntryStages.values
        .where((entryStage) => entryStage == nextStage)
        .length;
    return min(participants, nextStage.teamCapacity - directNext);
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
    bool autoAdvance = true,
    bool allowExtraTime = true,
    bool allowPenalties = true,
    bool randomizeDraw = true,
    int minRestHours = 48,
    bool thirdPlaceMatch = false,
    Map<String, MatchStage> knockoutEntryStages = const {},
    bool seededKnockoutDraw = true,
    List<StandingsTieBreaker> tieBreakers = const [
      StandingsTieBreaker.points,
      StandingsTieBreaker.goalDifference,
      StandingsTieBreaker.goalsFor,
      StandingsTieBreaker.wins,
      StandingsTieBreaker.headToHead,
    ],
    String notes = '',
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

    if (fmt.hasKnockout && !allowExtraTime && !allowPenalties) {
      return 'Eleme formatında en az uzatma veya penaltı kuralı açık olmalıdır.';
    }
    final ids = List<String>.from(teamIds);
    final missing = ids.where((id) => findTeam(id) == null).toList();
    if (missing.isNotEmpty) {
      return 'Seçilen takımlardan bazıları artık mevcut değil. Takım listesini yenileyin.';
    }
    final err = _engine.validate(
      format: fmt,
      teamIds: ids,
      groupCount: groupCount,
      qualifiersPerGroup: qualifiersPerGroup,
      swissMatches: swissMatches,
      knockoutEntryStages: fmt == LeagueFormat.cupSingle ||
              fmt == LeagueFormat.cupTwoLegged
          ? knockoutEntryStages
          : const {},
    );
    if (err != null) return err;

    final existing = _leagues.expand((l) => l.matches).toList();
    final cfg = ScheduleConfig(
      startDate: startDate,
      startHour: startHour,
      endHour: endHour,
      daysBetweenRounds: daysBetweenRounds.clamp(1, 14).toInt(),
      minGap: Duration(
          hours: (minRestHours > 0 ? minRestHours : minGap.inHours)
              .clamp(1, 240)
              .toInt()),
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
      autoAdvance: autoAdvance,
      allowExtraTime: allowExtraTime,
      allowPenalties: allowPenalties,
      randomizeDraw: randomizeDraw,
      minRestHours: minRestHours.clamp(1, 240).toInt(),
      thirdPlaceMatch: thirdPlaceMatch,
      tieBreakers: List.of(tieBreakers),
      notes: notes.trim(),
      knockoutEntryStages: fmt == LeagueFormat.cupSingle ||
              fmt == LeagueFormat.cupTwoLegged
          ? Map<String, MatchStage>.from(knockoutEntryStages)
          : const {},
      seededKnockoutDraw: seededKnockoutDraw,
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
          shuffle: randomizeDraw,
        );
        league.groups = groups;
        planned = _engine.generateGroupMatches(groups: groups, legs: 1);
        break;
      case LeagueFormat.cupSingle:
      case LeagueFormat.cupTwoLegged:
        final customEntries = knockoutEntryStages.isNotEmpty;
        final initialStage = customEntries
            ? _initialKnockoutStage(knockoutEntryStages, ids)
            : MatchStageX.fromTeamCount(nextPowerOfTwo(ids.length));
        final initialIds = customEntries
            ? ids.where((id) => knockoutEntryStages[id] == initialStage).toList()
            : ids;
        planned = _engine.generateKnockoutRound(
          teamIds: initialIds,
          twoLegged: fmt == LeagueFormat.cupTwoLegged,
          isFinalSingle: true,
          stageOverride: customEntries ? initialStage : null,
          targetWinners: _knockoutTargetWinners(league, initialStage, initialIds.length),
          seeded: seededKnockoutDraw,
          shuffle: randomizeDraw,
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
    if (league.knockoutEntryStages.isNotEmpty) {
      _tryAdvanceCompetition(league.id);
    }
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
    if (newStart.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      return 'Maç zamanı geçmişte olamaz.';
    }
    if (minGap == const Duration(hours: 48) && lg.minRestHours > 0) {
      minGap = Duration(hours: lg.minRestHours);
    }

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

  void _removeUnplayedFollowUps(League league, MatchGame source) {
    if (!league.format.hasKnockout) return;
    if (source.stage == MatchStage.group) {
      league.matches.removeWhere((m) =>
          m.stage.isKnockout &&
          m.status == MatchStatus.scheduled &&
          !m.finalized);
      return;
    }
    const order = [
      MatchStage.roundOf64,
      MatchStage.roundOf32,
      MatchStage.roundOf16,
      MatchStage.quarterFinal,
      MatchStage.semiFinal,
      MatchStage.finalMatch,
    ];
    final index = order.indexOf(source.stage);
    if (index < 0 || index + 1 >= order.length) return;
    final next = order[index + 1];
    league.matches.removeWhere((m) =>
        (m.stage == next ||
            (next == MatchStage.finalMatch && m.stage == MatchStage.thirdPlace)) &&
        m.status == MatchStatus.scheduled &&
        !m.finalized);
  }

  void undoMatchResult(String matchId) {
    final m = findMatchById(matchId);
    if (m == null || m.isBye) return;
    final league = findLeague(m.leagueId);
    if (league != null) _removeUnplayedFollowUps(league, m);
    m.status = MatchStatus.scheduled;
    // Geri alınan, geçmişte kalmış maç bir sonraki saniyede tekrar canlıya
    // dönmesin; kullanıcı bilinçli olarak yeni bir başlangıç saati seçebilir.
    if (m.startTime == null || !m.startTime!.isAfter(DateTime.now())) {
      m.startTime = DateTime.now().add(const Duration(minutes: 5));
    }
    m.homeGoals = 0;
    m.awayGoals = 0;
    m.events.clear();
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

  Future<String?> setMatchResult(
    String matchId,
    int homeScore,
    int awayScore, {
    int homePenalties = 0,
    int awayPenalties = 0,
    bool usedPenalties = false,
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return 'Maç bulunamadı.';
    if (m.isBye) return 'Bay geçişinin sonucu değiştirilemez.';
    if (m.status == MatchStatus.finished) {
      return 'Bu maç zaten tamamlandı. Düzeltmek için önce geri alın.';
    }
    if (homeScore < 0 || awayScore < 0 || homeScore > 99 || awayScore > 99) {
      return 'Skor 0 ile 99 arasında olmalıdır.';
    }
    if (homePenalties < 0 || awayPenalties < 0) {
      return 'Penaltı sayısı negatif olamaz.';
    }
    final league = findLeague(m.leagueId);
    if (league == null) return 'Lig bulunamadı.';
    if (usedPenalties && !m.stage.isKnockout) {
      return 'Lig ve grup maçlarında penaltı atışı kullanılamaz.';
    }
    if (usedPenalties && homePenalties == awayPenalties) {
      return 'Penaltı atışlarında kazanan belli olmalıdır.';
    }
    final isLastLeg = m.tieId == null ||
        m.leg >= league.matches
            .where((other) => other.tieId == m.tieId)
            .map((other) => other.leg)
            .fold<int>(0, (a, b) => a > b ? a : b);
    final aggregateDraw = _aggregateIsDrawAfter(m, homeScore, awayScore);
    if (usedPenalties && (!isLastLeg || !aggregateDraw)) {
      return 'Penaltı atışı yalnızca son ayakta toplam skor eşitse kullanılabilir.';
    }
    if (m.stage.isKnockout && isLastLeg && aggregateDraw && !usedPenalties) {
      return league.allowPenalties
          ? 'Eleme maçında eşitlik varsa penaltı atışını girin.'
          : 'Bu turnuvada eşitlik çözülemiyor; penaltı kuralını açın.';
    }

    // Manuel sonuç, simülasyonun ürettiği olayları sessizce taşımamalı.
    // Olaylar ayrı ayrı girilmediyse skor resmî kaynaktır.
    m.events.clear();
    m.homeGoals = homeScore;
    m.awayGoals = awayScore;
    m.status = MatchStatus.finished;
    m.endTime = DateTime.now();
    m.usedPenalties = usedPenalties;
    m.homePenalties = usedPenalties ? homePenalties : 0;
    m.awayPenalties = usedPenalties ? awayPenalties : 0;
    _live.remove(m.id);
    _resolveWinner(m);
    m.finalized = true;
    _tryAdvanceCompetition(m.leagueId);
    notifyListeners();
    await save();
    return null;
  }

  Future<void> finishMatchAndFinalize({required String matchId}) async {
    final m = findMatchById(matchId);
    if (m == null) return;
    if (m.finalized) return;
    m.status = MatchStatus.finished;
    m.endTime ??= DateTime.now();
    _resolveWinner(m);
    m.finalized = true;
    _tryAdvanceCompetition(m.leagueId);
    await save();
    notifyListeners();
  }

  bool _aggregateIsDrawAfter(MatchGame match, int homeScore, int awayScore) {
    if (match.tieId == null) return homeScore == awayScore;
    final league = findLeague(match.leagueId);
    if (league == null) return homeScore == awayScore;
    final legs = league.matches.where((m) => m.tieId == match.tieId).toList();
    if (legs.isEmpty) return homeScore == awayScore;
    final first = legs.first;
    var firstTotal = 0;
    var secondTotal = 0;
    for (final leg in legs) {
      final home = leg.id == match.id ? homeScore : leg.homeGoals;
      final away = leg.id == match.id ? awayScore : leg.awayGoals;
      if (leg.homeTeamId == first.homeTeamId) {
        firstTotal += home;
        secondTotal += away;
      } else {
        firstTotal += away;
        secondTotal += home;
      }
    }
    return firstTotal == secondTotal;
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
  void _tryAdvanceCompetition(String leagueId, {bool force = false}) {
    final lg = findLeague(leagueId);
    if (lg == null) return;
    if (!lg.format.hasKnockout) return;
    if (!force && (!_smartAutoAdvance || !lg.autoAdvance)) return;

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

    var guard = 0;
    while (guard++ < knockoutStageOrder.length) {
      final before = lg.matches.length;
      _advanceKnockoutRound(lg);
      if (lg.matches.length == before) break;
      final fresh = lg.matches.skip(before);
      if (fresh.any((match) => !match.isBye && match.status != MatchStatus.finished)) {
        break;
      }
    }
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
      targetWinners: _knockoutTargetWinners(
        lg,
        MatchStageX.fromTeamCount(nextPowerOfTwo(paired.length)),
        paired.length,
      ),
      seeded: lg.seededKnockoutDraw,
      shuffle: !lg.seededKnockoutDraw,
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
      minGap: Duration(hours: lg.minRestHours),
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
    final ko = lg.matches.where((m) => m.stage.isKnockout).toList();
    if (ko.isEmpty) return;

    const order = knockoutStageOrder;
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

    if (lg.knockoutEntryStages.isNotEmpty) {
      final alreadyIncluded = winners.toSet();
      for (final teamId in lg.teamIds) {
        if (lg.knockoutEntryStages[teamId] == nextStage &&
            alreadyIncluded.add(teamId)) {
          winners.add(teamId);
        }
      }
    }

    if (winners.isEmpty) return;

    final two = lg.format.isTwoLeggedKnockout && nextStage != MatchStage.finalMatch;
    final planned = _engine.generateKnockoutRound(
      teamIds: winners,
      twoLegged: two,
      isFinalSingle: true,
      stageOverride: nextStage,
      targetWinners: _knockoutTargetWinners(lg, nextStage, winners.length),
      seeded: lg.seededKnockoutDraw,
      shuffle: !lg.seededKnockoutDraw,
    );
    if (lg.thirdPlaceMatch && current == MatchStage.semiFinal) {
      final losers = <String>[];
      final seenLoserTies = <String>{};
      for (final match in currentMatches) {
        if (match.isBye) continue;
        if (match.tieId != null && !seenLoserTies.add(match.tieId!)) continue;
        final winner = match.winnerTeamId;
        if (winner == null) continue;
        final firstLeg = match.tieId == null
            ? match
            : lg.matches.firstWhere((item) => item.tieId == match.tieId && item.leg == 1);
        final loser = firstLeg.homeTeamId == winner
            ? firstLeg.awayTeamId
            : firstLeg.homeTeamId;
        losers.add(loser);
      }
      planned.addAll(_engine.generateThirdPlace(teamIds: losers));
    }
    final last = lg.matches
        .map((m) => m.startTime)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final cfg = ScheduleConfig(
      startDate: (last ?? DateTime.now()).add(const Duration(days: 3)),
      startHour: 18,
      endHour: 22,
      daysBetweenRounds: 3,
      minGap: Duration(hours: lg.minRestHours),
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
    _tryAdvanceCompetition(leagueId, force: true);
    if (lg.matches.length == before) {
      return 'Sonraki tur henüz üretilemez. Açık maçları bitirin.';
    }
    await save();
    notifyListeners();
    return null;
  }

  int liveMinuteFor(String matchId) {
    final ls = _live[matchId];
    if (ls != null) return ls.currentMinute.clamp(0, 90).toInt();
    final m = findMatchById(matchId);
    if (m == null || m.startTime == null) return 0;
    return DateTime.now().difference(m.startTime!).inSeconds.clamp(0, 90).toInt();
  }

  Future<void> recordAiGoal({
    required String matchId,
    required bool isHome,
    int? minuteOverride,
  }) async {
    final m = findMatchById(matchId);
    if (m == null || m.status != MatchStatus.live) return;
    final minute = (minuteOverride ?? liveMinuteFor(matchId)).clamp(0, 90).toInt();
    _registerGoal(m, isHome: isHome, minute: minute);
    final ls = _live[matchId];
    if (ls != null) {
      if (isHome) {
        ls.cooldownHomeUntilMinute = (minute + 2).clamp(0, 90).toInt();
      } else {
        ls.cooldownAwayUntilMinute = (minute + 2).clamp(0, 90).toInt();
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

  void _tick() {
    final now = DateTime.now();
    var changed = false;

    for (final lg in _leagues) {
      for (final m in lg.matches) {
        final st = m.startTime;
        if (st == null || m.isBye) continue;

        final withinKickoffWindow =
            !now.isBefore(st) && now.difference(st) <= const Duration(hours: 2);
        if (_autoLiveSimulation &&
            m.status == MatchStatus.scheduled &&
            withinKickoffWindow) {
          m.status = MatchStatus.live;
          _live[m.id] = _LiveState(startedAt: st, currentMinute: 0);
          changed = true;
        }

        if (m.status == MatchStatus.live) {
          final restoredMinute = now.difference(st).inSeconds.clamp(0, 89).toInt();
          final ls = _live[m.id] ??
              _LiveState(startedAt: st, currentMinute: restoredMinute);
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
              _simulateShootoutIfRequired(m);
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

  void _simulateShootoutIfRequired(MatchGame match) {
    if (!match.stage.isKnockout) return;
    final league = findLeague(match.leagueId);
    if (league == null || (!league.allowPenalties && !league.allowExtraTime)) return;
    final lastLeg = match.tieId == null ||
        match.leg >= league.matches
            .where((other) => other.tieId == match.tieId)
            .map((other) => other.leg)
            .fold<int>(0, (a, b) => a > b ? a : b);
    if (!lastLeg || !_aggregateIsDrawAfter(match, match.homeGoals, match.awayGoals)) {
      return;
    }
    if (!league.allowPenalties && league.allowExtraTime) {
      if (_rng.nextBool()) {
        _registerGoal(match, isHome: true, minute: 90);
      } else {
        _registerGoal(match, isHome: false, minute: 90);
      }
      return;
    }
    var home = 0;
    var away = 0;
    while (home == away) {
      home = 3 + _rng.nextInt(3);
      away = 3 + _rng.nextInt(3);
    }
    match.usedPenalties = true;
    match.homePenalties = home;
    match.awayPenalties = away;
  }

  double _effectiveStrength(Team team) {
    // Takımlar artık yalnızca ad ve ikonla tanımlanır. Simülasyonun tamamen
    // rastgele değil, aynı takımla tekrarlandığında tutarlı olması için ad
    // tabanlı küçük bir fark kullanıyoruz.
    var hash = 0;
    for (final code in team.name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return 4.7 + (hash % 7) / 10.0;
  }

  void _maybeScore(MatchGame m,
      {required int minute, required _LiveState live}) {
    final home = findTeam(m.homeTeamId);
    final away = findTeam(m.awayTeamId);
    if (home == null || away == null) return;

    final sh = _effectiveStrength(home).clamp(1.0, 20.0).toDouble();
    final sa = _effectiveStrength(away).clamp(1.0, 20.0).toDouble();
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

  void _registerGoal(MatchGame match, {required bool isHome, required int minute}) {
    if (isHome) {
      match.homeGoals += 1;
    } else {
      match.awayGoals += 1;
    }
    match.events.add(MatchEvent(
      minute: minute,
      teamId: isHome ? match.homeTeamId : match.awayTeamId,
      isHome: isHome,
      type: EventType.goal,
    ));
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
        if (m.stage.isKnockout && m.tieId == null && m.usedPenalties && m.winnerTeamId != null) {
          if (m.winnerTeamId == teamId) {
            win++;
          } else {
            lose++;
          }
        } else if (my > opp) {
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
