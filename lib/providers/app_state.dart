import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/league.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final _storage = StorageService();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  final List<Team> _teams = [];
  List<Team> get teams => List.unmodifiable(_teams);

  final List<League> _leagues = [];
  List<League> get leagues => List.unmodifiable(_leagues);



  Timer? _engineTimer;
  final Random _rng = Random();
  final Map<String, _LiveState> _live = {}; // matchId -> state

  // ---- Reschedule Helpers ----
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
        final involved = (m.homeTeamId == teamId) || (m.awayTeamId == teamId);
        if (!involved) continue;

        final sameDay = st.year == candidateKickoff.year &&
            st.month == candidateKickoff.month &&
            st.day == candidateKickoff.day;
        if (sameDay) return true;

        final diff = (st.isBefore(candidateKickoff))
            ? candidateKickoff.difference(st)
            : st.difference(candidateKickoff);
        if (diff < minGap) return true;
      }
    }
    return false;
  }









  /// تسجيل تصدّي الحارس/الدفاع أثناء المباراة (يُنادى من LiveAiPage عبر الكولباك)
  Future<void> recordKeeperSave({
    required String matchId,
    required bool byHomeKeeper, // true = تصدي فريق الـ Home
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return;
    if (m.status != MatchStatus.live) return;

    if (byHomeKeeper) {
      m.homeSaves += 1;
    } else {
      m.awaySaves += 1;
    }
    await save();
    notifyListeners();
  }


  // --- أضف هذا الكود داخل كلاس AppState في ملف app_state.dart ---

  // حذف الدوري ومبارياته
  Future<void> deleteLeague(String leagueId) async {
    _leagues.removeWhere((l) => l.id == leagueId);
    await save(); // حفظ التغييرات في الذاكرة الدائمة
    notifyListeners();
  }

  // تعديل اسم الدوري
  Future<void> updateLeagueName(String leagueId, String newName) async {
    final index = _leagues.indexWhere((l) => l.id == leagueId);
    if (index != -1) {
      _leagues[index].title = newName;
      await save();
      notifyListeners();
    }
  }

  // --- أضف هذا الكود داخل كلاس AppState في ملف app_state.dart ---

  // تعديل بيانات الفريق (الاسم والأيقونة)
  Future<void> updateTeam(String teamId, String newName, String newIcon) async {
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index != -1) {
      _teams[index].name = newName;
      _teams[index].icon = newIcon;
      await save(); // حفظ التغييرات
      notifyListeners(); // تحديث الواجهات
    }
  }

  // أضف هذه الدالة داخل كلاس AppState في ملف app_state.dart
  void undoMatchResult(String matchId) {
    for (final lg in _leagues) {
      final index = lg.matches.indexWhere((m) => m.id == matchId);
      if (index != -1) {
        lg.matches[index].status = MatchStatus.scheduled;
        lg.matches[index].homeGoals = 0;
        lg.matches[index].awayGoals = 0;
        notifyListeners();
        save();
        break;
      }
    }
  }

  /// ختم المباراة رسميًا: يعلّمها منتهية ويحفظ إحصاءات الأهداف لكل لاعب + التصديات
  Future<void> finishMatchAndFinalize({required String matchId}) async {
    final m = findMatchById(matchId);
    if (m == null) return;

    if (m.finalized == true) return; // لا تكرر
    if (m.status != MatchStatus.finished) {
      m.status = MatchStatus.finished;
    }

    m.endTime ??= DateTime.now();

    // احسب الأهداف لكل لاعب من سجل الأحداث الرسمي
    final Map<String, int> byPlayer = {};
    for (final ev in m.events) {
      // بافتراض أن الحدث يمثل "هدف" وبداخله playerId
      if (ev.playerId != null && ev.playerId!.isNotEmpty) {
        byPlayer.update(ev.playerId!, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    m.goalsByPlayer = byPlayer;

    // m.homeSaves / m.awaySaves تم تجميعها أثناء اللعب
    m.finalized = true;

    await save();
    notifyListeners();
  }








  /// تعطي الدقيقة الحية الحقيقية من المحرك إن كانت المباراة Live،
  /// وإلا تقدير محافظ من startTime (اختبار فقط).
  int liveMinuteFor(String matchId) {
    final ls = _live[matchId];
    if (ls != null) {
      return ls.currentMinute.clamp(0, 90);
    }
    final m = findMatchById(matchId);
    if (m == null || m.startTime == null) return 0;
    final secs = DateTime.now().difference(m.startTime!).inSeconds;
    final est = secs; // 1s(real) = 1'(sim)
    return est.clamp(0, 90);
  }

  /// يسجل هدفًا قادمًا من ذكاء واجهة (AI) ضمن المحرّك الرسمي.
  /// - يقبل isHome لتحديد الطرف المسجّل.
  /// - يختار دقيقة الحدث من liveMinuteFor(matchId) مع سقف 90.
  /// - يحدّث تبريد التسجيل لمنع التراكم غير الطبيعي (دقيقتان).
  Future<void> recordAiGoal({
    required String matchId,
    required bool isHome,
    int? minuteOverride,
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return;
    if (m.status != MatchStatus.live) return;

    // احصل على الدقيقة الحالية من المحرك (أدقّ من الزمن التقديري)
    int minute = (minuteOverride ?? liveMinuteFor(matchId)).clamp(0, 90);

    // زيادة النتيجة
    if (isHome) {
      m.homeGoals += 1;
    } else {
      m.awayGoals += 1;
    }

    // اختر هدّافًا (نفس منطق _registerGoal تقريبًا لكن مبسط هنا)
    String? scorerId;
    final team = findTeam(isHome ? m.homeTeamId : m.awayTeamId);
    final lineup = isHome ? m.homeLineup : m.awayLineup;
    if (team != null) {
      List<String> pool = [];
      if (lineup != null && lineup.playerIds.isNotEmpty) {
        pool = lineup.playerIds;
      } else {
        pool = team.players.map((p) => p.id).toList();
      }
      if (pool.isNotEmpty) {
        pool.shuffle();
        scorerId = pool.first;
      }
    }

    // أضف حدث الهدف
    m.events.add(MatchEvent(
      minute: minute,
      teamId: isHome ? m.homeTeamId : m.awayTeamId,
      isHome: isHome,
      playerId: scorerId,
    ));

    // حدّث تبريد التسجيل لمنع الأهداف المتتالية فورًا (دقيقتان)
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





  /// يعيد جدولة مباراة واحدة مع التحقق العالمي + ضمن نطاق تاريخ الدوري
  Future<String?> rescheduleMatch({
    required String matchId,
    required DateTime newStart,
    Duration minGap = const Duration(hours: 60),
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return 'Maç bulunamadı.';
    if (m.status != MatchStatus.scheduled) {
      return 'Sadece planlı maçların zamanı düzenlenebilir.';
    }

    // league window check
    final lg = _leagues.firstWhere((l) => l.id == m.leagueId);
    final startDay = DateTime(lg.startDate.year, lg.startDate.month, lg.startDate.day);
    final endDay = DateTime(lg.endDate.year, lg.endDate.month, lg.endDate.day, 23, 59, 59);
    if (newStart.isBefore(startDay) || newStart.isAfter(endDay)) {
      return 'Seçilen zaman lig tarih aralığının dışında.';
    }

    // global constraints (exclude this match)
    final homeBad = _violatesForTeamAt(
      teamId: m.homeTeamId,
      candidateKickoff: newStart,
      minGap: minGap,
      excludeMatchId: m.id,
    );
    if (homeBad) return 'Ev sahibi için zaman çakışması/60 saat kuralı ihlali.';

    final awayBad = _violatesForTeamAt(
      teamId: m.awayTeamId,
      candidateKickoff: newStart,
      minGap: minGap,
      excludeMatchId: m.id,
    );
    if (awayBad) return 'Deplasman için zaman çakışması/60 saat kuralı ihlali.';

    // ok → set and save
    m.startTime = newStart;
    await save();
    notifyListeners();
    return null;
  }


  Future<void> load() async {
    final data = await _storage.load();
    if (data != null) {
      final tm = data['themeMode'] as String? ?? 'system';
      _themeMode = switch (tm) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system
      };
      final lst = (data['teams'] as List?) ?? [];
      _teams..clear()..addAll(lst.map((e) => Team.fromMap(e)));
      final ll = (data['leagues'] as List?) ?? [];
      _leagues..clear()..addAll(ll.map((e) => League.fromMap(e)));
    }
    _startEngine();
    notifyListeners();
  }

  // دالة جديدة لإدخال النتيجة يدوياً وإنهاء المباراة
  Future<void> setMatchResult(String matchId, int homeScore, int awayScore) async {
    for (var lg in _leagues) {
      final index = lg.matches.indexWhere((m) => m.id == matchId);
      if (index != -1) {
        final oldMatch = lg.matches[index];

        // تحديث المباراة بالنتيجة الجديدة وتغيير حالتها إلى منتهية
        final newMatch = oldMatch.copyWith(
          homeGoals: homeScore,
          awayGoals: awayScore,
          status: MatchStatus.finished,
          // يمكنك هنا أيضاً تعيين وقت الانتهاء إذا كنت تخزنه
        );

        lg.matches[index] = newMatch;
        notifyListeners();
        await _save(); // حفظ التغييرات في التخزين
        return;
      }
    }
  }
  // دالة لحفظ البيانات (تستخدم toMap الموجودة في ملفاتك)
  Future<void> _save() async {
    final data = {
      'teams': _teams.map((t) => t.toMap()).toList(),
      'leagues': _leagues.map((l) => l.toMap()).toList(),
    };
    await _storage.save(data);
  }



  // بقية الدوال المساعدة (AddTeam, Reschedule, FindTeam) تبقى كما هي...

  //

  Future<void> save() async {
    await _storage.save({
      'themeMode': switch (_themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system'
      },
      'teams': _teams.map((e) => e.toMap()).toList(),
      'leagues': _leagues.map((e) => e.toMap()).toList(),
    });
  }

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

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString() +
      Random().nextInt(99999).toString();

  // ---------- Teams ----------
  Future<void> addTeam({
    required String name,
    required String icon,
    required double teamPower,
    required List<Player> players,
    required Coach coach,
    required List<GoalKeeper> keepers,
  }) async {
    _teams.add(Team(
      id: _genId(),
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

  Team? findTeam(String id) {
    try {
      return _teams.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------- Leagues & Scheduling ----------
  List<(String home, String away)> _generatePairs(List<String> teamIds, LeagueType type) {
    final pairs = <(String, String)>[];
    for (int i = 0; i < teamIds.length; i++) {
      for (int j = i + 1; j < teamIds.length; j++) {
        final a = teamIds[i];
        final b = teamIds[j];
        pairs.add((a, b));
        // استخدم المسميات الجديدة التي وضعتها في ملف league.dart
        if (type == LeagueType.league) {
          // منطق الدوري هنا
        } else if (type == LeagueType.elimination) {
          // منطق التصفيات هنا
        }
      }
    }
    pairs.shuffle(Random(teamIds.length));
    return pairs;
  }

  bool _violatesGlobalTeamConstraints({
    required String teamId,
    required DateTime candidateKickoff,
    required Duration minGap,
  }) {
    for (final lg in _leagues) {
      for (final m in lg.matches) {
        final st = m.startTime;
        if (st == null) continue;
        final involved = (m.homeTeamId == teamId) || (m.awayTeamId == teamId);
        if (!involved) continue;

        final sameDay = st.year == candidateKickoff.year &&
            st.month == candidateKickoff.month &&
            st.day == candidateKickoff.day;
        if (sameDay) return true;

        final diff = (st.isBefore(candidateKickoff))
            ? candidateKickoff.difference(st)
            : st.difference(candidateKickoff);
        if (diff < minGap) return true;
      }
    }
    return false;
  }

  List<DateTime> _dailySlots(DateTime day) => [
    DateTime(day.year, day.month, day.day, 18, 0),
    DateTime(day.year, day.month, day.day, 20, 30),
  ];

  bool _assignScheduleForLeague(League league, Duration minGap) {
    final pairs = _generatePairs(league.teamIds, league.type);
    final pending = List.of(pairs);

    DateTime cursor = DateTime(league.startDate.year, league.startDate.month, league.startDate.day);
    final lastDay = DateTime(league.endDate.year, league.endDate.month, league.endDate.day);

    league.matches.clear();
    final tempMatches = <MatchGame>[];
    final Map<String, DateTime> localLast = {};

    while (cursor.isBefore(lastDay.add(const Duration(days: 1)))) {
      final slots = _dailySlots(cursor);
      for (final slot in slots) {
        if (pending.isEmpty) break;
        (String, String)? chosen;
        for (final p in pending) {
          final a = p.$1, b = p.$2;
          bool violatesA = _violatesGlobalTeamConstraints(teamId: a, candidateKickoff: slot, minGap: minGap) ||
              (localLast[a] != null && slot.difference(localLast[a]!).abs() < minGap);
          bool violatesB = _violatesGlobalTeamConstraints(teamId: b, candidateKickoff: slot, minGap: minGap) ||
              (localLast[b] != null && slot.difference(localLast[b]!).abs() < minGap);
          if (violatesA || violatesB) continue;
          chosen = p; break;
        }
        if (chosen != null) {
          tempMatches.add(MatchGame(
            id: _genId(),
            leagueId: league.id,
            homeTeamId: chosen.$1,
            awayTeamId: chosen.$2,
            startTime: slot,
            status: MatchStatus.scheduled,
          ));
          localLast[chosen.$1] = slot;
          localLast[chosen.$2] = slot;
          pending.remove(chosen);
        }
      }
      if (pending.isEmpty) { league.matches.addAll(tempMatches); return true; }
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  // دالة إنشاء الدوري والجدولة
  // createLeagueAndSchedule fonksiyonunun parametre listesini ve içeriğini güncelle
  Future<String?> createLeagueAndSchedule({
    required String title,
    required LeagueType type,
    required List<String> teamIds,
    required DateTime startDate,
    required int rounds,
    required int startHour,
    required int endHour,
    required Duration minGap,
    int winPoints = 3,
    int drawPoints = 1,
    int losePoints = 0,
    int leagueColorValue = 0xFF2196F3,
    List<RankDefinition> rankDefinitions = const [], // <--- BURAYI EKLE (Parametre olarak)
    int topRankCount = 0,
    int bottomRankCount = 0,
  }) async {
    if (teamIds.length < 2) return 'En az iki takım seçin.';

    // إعداد الدوري
    final league = League(
      id: _genId(),
      title: title.trim().isEmpty ? 'Yeni Lig' : title.trim(),
      type: type,
      teamIds: List.of(teamIds),
      startDate: startDate,
      endDate: startDate.add(const Duration(days: 30)),
      matches: [],
      winPoints: winPoints,
      drawPoints: drawPoints,
      losePoints: losePoints,
      leagueColorValue: leagueColorValue,
      rankDefinitions: rankDefinitions, // <--- BURAYI EKLE (League oluştururken gönder)
    );

    // ... (Fonksiyonun geri kalanı aynı) ...



    // المنطق الجديد للجدولة
    List<(String, String)> pairs = [];

    if (type == LeagueType.elimination) {
      // 1. نظام الكأس
      for (int i = 0; i < teamIds.length - 1; i += 2) {
        pairs.add((teamIds[i], teamIds[i+1]));
      }
    }
    else if (type == LeagueType.fixedMatches) {
      // 2. نظام عدد مباريات ثابت (Grup / Swiss-like)
      // نستخدم خوارزمية Round Robin (Circle Method) لتوليد الجولات، ثم نأخذ أول N جولة فقط.
      // ملاحظة: تم التحقق في الواجهة أن عدد الفرق زوجي وأن الجولات < عدد الفرق.

      final List<String> pList = List.from(teamIds); // نسخة للتدوير
      int totalRounds = pList.length - 1; // الحد الأقصى للجولات الممكنة
      int numMatchesPerTeam = rounds; // العدد المطلوب من المستخدم

      // إذا طلب المستخدم مباريات أكثر من الممكن، نصححها تلقائياً
      if (numMatchesPerTeam > totalRounds) numMatchesPerTeam = totalRounds;

      for (int round = 0; round < numMatchesPerTeam; round++) {
        // في كل جولة، نزاوج الأول مع الأخير، الثاني مع قبل الأخير...
        int half = pList.length ~/ 2;
        for (int i = 0; i < half; i++) {
          String t1 = pList[i];
          String t2 = pList[pList.length - 1 - i];

          // تبديل المستضيف كل جولة للعدالة
          if (round % 2 == 0) {
            pairs.add((t1, t2));
          } else {
            pairs.add((t2, t1));
          }
        }

        // تدوير القائمة للجولة القادمة (ثبّت العنصر الأول، ودور الباقي)
        // [0, 1, 2, 3] -> [0, 3, 1, 2] -> [0, 2, 3, 1]
        if (pList.length > 2) {
          String last = pList.removeLast();
          pList.insert(1, last);
        }
      }
    }
    else {
      // 3. نظام الدوري الكامل (League)
      // جولة الذهاب (الكل ضد الكل)
      List<(String, String)> oneRoundPairs = [];
      for (int i = 0; i < teamIds.length; i++) {
        for (int j = i + 1; j < teamIds.length; j++) {
          oneRoundPairs.add((teamIds[i], teamIds[j]));
        }
      }

      // تكرار المباريات حسب عدد الدورات (ذهاب، إياب، إلخ)
      for (int r = 0; r < rounds; r++) {
        if (r % 2 == 0) {
          pairs.addAll(oneRoundPairs);
        } else {
          // في الإياب نعكس الفريقين
          pairs.addAll(oneRoundPairs.map((p) => (p.$2, p.$1)));
        }
      }
    }

    // توزيع المباريات على الساعات المحددة
    final tempMatches = <MatchGame>[];
    DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);
    final Map<String, DateTime> lastMatchTime = {};

    // حلقة لتوزيع المباريات
    while (pairs.isNotEmpty) {
      // توليد الساعات المتاحة في هذا اليوم (مثلاً من 18:00 إلى 22:00)
      for (int h = startHour; h < endHour; h += 2) { // كل ساعتين مباراة
        if (pairs.isEmpty) break;

        DateTime slot = DateTime(cursor.year, cursor.month, cursor.day, h, 0);

        // البحث عن زوج فرق متاح للعب في هذا الوقت
        (String, String)? selectedPair;
        for (final p in pairs) {
          final t1 = p.$1;
          final t2 = p.$2;

          // تحقق: هل لعبوا قريباً جداً؟
          bool t1Busy = lastMatchTime[t1] != null && slot.difference(lastMatchTime[t1]!).abs() < minGap;
          bool t2Busy = lastMatchTime[t2] != null && slot.difference(lastMatchTime[t2]!).abs() < minGap;

          if (!t1Busy && !t2Busy) {
            selectedPair = p;
            break;
          }
        }

        if (selectedPair != null) {
          tempMatches.add(MatchGame(
            id: _genId(),
            leagueId: league.id,
            homeTeamId: selectedPair.$1,
            awayTeamId: selectedPair.$2,
            startTime: slot,
            status: MatchStatus.scheduled,
          ));
          lastMatchTime[selectedPair.$1] = slot;
          lastMatchTime[selectedPair.$2] = slot;
          pairs.remove(selectedPair);
        }
      }
      // الانتقال لليوم التالي
      cursor = cursor.add(const Duration(days: 1));
      if (cursor.difference(startDate).inDays > 365) break; // حماية من التكرار اللانهائي
    }

    league.matches.addAll(tempMatches);
    if (tempMatches.isNotEmpty) {
      tempMatches.sort((a,b) => a.startTime!.compareTo(b.startTime!));
      league.endDate = tempMatches.last.startTime!;
    }

    _leagues.add(league);
    await save();
    notifyListeners();
    return null;
  }


  // ---------- Match access & lineups ----------
  MatchGame? findMatchById(String matchId) {
    for (final lg in _leagues) {
      for (final m in lg.matches) {
        if (m.id == matchId) return m;
      }
    }
    return null;
  }

  Future<void> setLineup({
    required String matchId,
    required bool isHome,
    required List<String> playerIds, // يجب أن تكون 11
    required String? keeperId,
  }) async {
    final m = findMatchById(matchId);
    if (m == null) return;
    final lu = Lineup(playerIds: List.of(playerIds), keeperId: keeperId);
    if (isHome) m.homeLineup = lu; else m.awayLineup = lu;
    await save();
    notifyListeners();
  }

  void _ensureAutoLineupsIfMissing(MatchGame m) {
    Lineup autoForTeam(Team t) {
      // أفضل 11 لاعب قوة
      final playersSorted = List<Player>.from(t.players)
        ..sort((a, b) => b.power.compareTo(a.power));
      final starters = playersSorted.take(11).map((e) => e.id).toList();

      // أفضل حارس
      String? kId;
      if (t.keepers.isNotEmpty) {
        t.keepers.sort((a, b) => b.keepingPower.compareTo(a.keepingPower));
        kId = t.keepers.first.id;
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

  // ---------- Match Engine ----------
  void _startEngine() {
    _engineTimer?.cancel();
    _engineTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    bool changed = false;

    for (final lg in _leagues) {
      for (final m in lg.matches) {
        final st = m.startTime;
        if (st == null) continue;

        if (m.status == MatchStatus.scheduled && now.isAfter(st)) {
          // تأكد من وجود تشكيلات قبل البدء
          _ensureAutoLineupsIfMissing(m);
          m.status = MatchStatus.live;
          _live[m.id] = _LiveState(startedAt: now, currentMinute: 0);
          changed = true;
        }

        if (m.status == MatchStatus.live) {
          final ls = _live[m.id];
          if (ls == null) {
            _live[m.id] = _LiveState(startedAt: now, currentMinute: 0);
          } else {
            final nextMinuteAt = ls.nextTickAt ?? now.add(const Duration(seconds: 1));
            if (now.isAfter(nextMinuteAt)) {
              ls.currentMinute += 1;
              ls.nextTickAt = now.add(const Duration(seconds: 1));
              changed = true;

              _maybeScore(m, minute: ls.currentMinute, live: ls);

              if (ls.currentMinute >= 90) {
                m.status = MatchStatus.finished;
                _applyPostMatchAdjustments(m);
                _live.remove(m.id);
                save();
                changed = true;
              }
            }
          }
        }
      }
    }

    if (changed) notifyListeners();
  }

  double _effectiveStrength(Team t) {
    if (t.players.isEmpty) {
      return t.teamPower + t.coach.iqPower + (t.keepers.isNotEmpty ? t.keepers.first.keepingPower * .3 : 0);
    }
    final avgPlayers = t.players.fold<double>(0, (s, p) => s + p.power) / t.players.length;
    final bestKeeper = t.keepers.isEmpty ? 0.0 : t.keepers.map((k) => k.keepingPower).reduce(max);
    return t.teamPower + (avgPlayers * 0.5) + (t.coach.iqPower) + (bestKeeper * 0.3);
  }


  void _maybeScore(MatchGame m, {required int minute, required _LiveState live}) {
    final home = findTeam(m.homeTeamId);
    final away = findTeam(m.awayTeamId);
    if (home == null || away == null) return;

    final sh = _effectiveStrength(home).clamp(1.0, 20.0);
    final sa = _effectiveStrength(away).clamp(1.0, 20.0);
    final total = sh + sa;

    const double mu = 2.6 / 90.0;
    double ph = mu * (sh / total);
    double pa = mu * (sa / total);

    if (live.cooldownHomeUntilMinute != null && minute <= live.cooldownHomeUntilMinute!) ph *= 0.5;
    if (live.cooldownAwayUntilMinute != null && minute <= live.cooldownAwayUntilMinute!) pa *= 0.5;

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
    if (isHome) m.homeGoals += 1; else m.awayGoals += 1;

    // اختر هدّافاً من التشكيلة الأساسية إن وُجدت
    String? scorerId;
    final team = findTeam(isHome ? m.homeTeamId : m.awayTeamId);
    final lineup = isHome ? m.homeLineup : m.awayLineup;
    if (team != null) {
      List<String> pool = [];
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
    ));
  }

  void _applyPostMatchAdjustments(MatchGame m) {
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

    // تعزيز هدّافين
    void buffScorers(Team t, String tid, List<MatchEvent> events) {
      for (final e in events.where((e) => e.teamId == tid && e.playerId != null)) {
        final idx = t.players.indexWhere((p) => p.id == e.playerId);
        if (idx >= 0) {
          final p = t.players[idx];
          p.power = (p.power + 0.05).clamp(1.0, 8.0);
        }
      }
    }

    buffScorers(ht, ht.id, m.events);
    buffScorers(at, at.id, m.events);
  }

  // ---------- Stats ----------
  TeamStats statsForTeam(String teamId) {
    int played = 0, win = 0, draw = 0, lose = 0, gf = 0, ga = 0;
    final games = <MatchGame>[];
    for (final lg in _leagues) {
      for (final m in lg.matches) {
        if (m.status != MatchStatus.finished) continue;
        final involved = (m.homeTeamId == teamId) || (m.awayTeamId == teamId);
        if (!involved) continue;
        games.add(m);
        played++;
        final isHome = m.homeTeamId == teamId;
        final my = isHome ? m.homeGoals : m.awayGoals;
        final opp = isHome ? m.awayGoals : m.homeGoals;
        gf += my; ga += opp;
        if (my > opp) win++; else if (my == opp) draw++; else lose++;
      }
    }
    return TeamStats(played: played, win: win, draw: draw, lose: lose, goalsFor: gf, goalsAgainst: ga, matches: games);
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

