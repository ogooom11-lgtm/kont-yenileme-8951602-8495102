import 'dart:math';

import '../models/league.dart';
import '../utils/helpers.dart';

class PlannedMatch {
  final String homeId;
  final String awayId;
  final int week;
  final MatchStage stage;
  final String? groupId;
  final String? groupName;
  final String? tieId;
  final int leg;

  PlannedMatch({
    required this.homeId,
    required this.awayId,
    required this.week,
    required this.stage,
    this.groupId,
    this.groupName,
    this.tieId,
    this.leg = 1,
  });
}

class ScheduleConfig {
  final DateTime startDate;
  final int startHour;
  final int endHour;
  final int daysBetweenRounds;
  final Duration minGap;
  final List<MatchGame> existingMatches;

  ScheduleConfig({
    required this.startDate,
    required this.startHour,
    required this.endHour,
    required this.daysBetweenRounds,
    required this.minGap,
    this.existingMatches = const [],
  });
}

class FixtureEngine {
  final Random _rng;

  FixtureEngine({int? seed}) : _rng = Random(seed);

  /// Berger / circle method. Odd team count gets a bye (null).
  List<List<(String, String)>> roundRobinRounds(List<String> teamIds) {
    final teams = List<String?>.from(teamIds);
    if (teams.length % 2 == 1) teams.add(null);
    final n = teams.length;
    final rounds = n - 1;
    final half = n ~/ 2;
    final rotating = List<String?>.from(teams);
    final result = <List<(String, String)>>[];

    for (var r = 0; r < rounds; r++) {
      final matches = <(String, String)>[];
      for (var i = 0; i < half; i++) {
        final a = rotating[i];
        final b = rotating[n - 1 - i];
        if (a == null || b == null) continue;
        if (r % 2 == 0) {
          matches.add((a, b));
        } else {
          matches.add((b, a));
        }
      }
      result.add(matches);
      if (rotating.length > 2) {
        final last = rotating.removeLast();
        rotating.insert(1, last);
      }
    }
    return result;
  }

  List<PlannedMatch> generateLeague({
    required List<String> teamIds,
    required int legs,
  }) {
    final one = roundRobinRounds(teamIds);
    final planned = <PlannedMatch>[];
    var week = 1;
    for (final round in one) {
      for (final p in round) {
        planned.add(PlannedMatch(
          homeId: p.$1,
          awayId: p.$2,
          week: week,
          stage: MatchStage.leagueRound,
        ));
      }
      week++;
    }
    if (legs >= 2) {
      for (final round in one) {
        for (final p in round) {
          planned.add(PlannedMatch(
            homeId: p.$2,
            awayId: p.$1,
            week: week,
            stage: MatchStage.leagueRound,
            leg: 2,
          ));
        }
        week++;
      }
    }
    return planned;
  }

  /// Sabit maçlı Swiss fikstürü.
  ///
  /// Sonuçlar girildikten sonra gerçek Swiss eşleşmelerini kurmak teorik
  /// olarak mümkündür; ancak tüm fikstürü baştan göstermek isteyen kullanıcı
  /// için burada her takımın birbiriyle en fazla bir kez karşılaştığı Berger
  /// turlarını kullanıyoruz. Böylece aynı rakip iki kez üretilmez ve her takım
  /// her turda en fazla bir maç oynar.
  List<PlannedMatch> generateSwiss({
    required List<String> teamIds,
    required int matchesPerTeam,
  }) {
    final one = roundRobinRounds(teamIds);
    final take = matchesPerTeam.clamp(1, one.length).toInt();
    final planned = <PlannedMatch>[];
    for (var w = 0; w < take; w++) {
      for (final p in one[w]) {
        planned.add(PlannedMatch(
          homeId: w.isEven ? p.$1 : p.$2,
          awayId: w.isEven ? p.$2 : p.$1,
          week: w + 1,
          stage: MatchStage.leagueRound,
        ));
      }
    }
    return planned;
  }

  List<GroupInfo> makeGroups({
    required List<String> teamIds,
    required int groupCount,
    bool shuffle = true,
  }) {
    final ids = List<String>.from(teamIds);
    if (shuffle) ids.shuffle(_rng);
    final count = groupCount.clamp(1, ids.length).toInt();
    final buckets = List.generate(count, (_) => <String>[]);
    // Yılan dağıtımı: A B C D D C B A ...
    var dir = 1;
    var gi = 0;
    for (final id in ids) {
      buckets[gi].add(id);
      gi += dir;
      if (gi == count) {
        dir = -1;
        gi = count - 1;
      } else if (gi < 0) {
        dir = 1;
        gi = 0;
      }
    }
    return [
      for (var i = 0; i < count; i++)
        GroupInfo(
          id: 'G${groupLetter(i)}',
          name: groupLetter(i),
          teamIds: buckets[i],
        ),
    ];
  }

  List<PlannedMatch> generateGroupMatches({
    required List<GroupInfo> groups,
    required int legs,
  }) {
    final planned = <PlannedMatch>[];
    for (final g in groups) {
      final rounds = generateLeague(teamIds: g.teamIds, legs: legs);
      for (final p in rounds) {
        planned.add(PlannedMatch(
          homeId: p.homeId,
          awayId: p.awayId,
          week: p.week,
          stage: MatchStage.group,
          groupId: g.id,
          groupName: g.name,
          leg: p.leg,
        ));
      }
    }
    planned.sort((a, b) {
      final w = a.week.compareTo(b.week);
      if (w != 0) return w;
      return (a.groupName ?? '').compareTo(b.groupName ?? '');
    });
    return planned;
  }

  List<PlannedMatch> generateThirdPlace({
    required List<String> teamIds,
  }) {
    if (teamIds.length != 2) return [];
    return [
      PlannedMatch(
        homeId: teamIds.first,
        awayId: teamIds.last,
        week: 1,
        stage: MatchStage.thirdPlace,
      ),
    ];
  }

  List<PlannedMatch> generateKnockoutRound({
    required List<String> teamIds,
    required bool twoLegged,
    required bool isFinalSingle,
    MatchStage? stageOverride,
    int? targetWinners,
    bool seeded = false,
    bool shuffle = false,
  }) {
    if (teamIds.isEmpty) return [];
    var ids = List<String>.from(teamIds);
    if (shuffle && !seeded) ids.shuffle(_rng);
    if (seeded && ids.length == nextPowerOfTwo(ids.length)) {
      ids = _seededBracketOrder(ids);
    }

    final pow2 = nextPowerOfTwo(ids.length);
    final stage = stageOverride ?? MatchStageX.fromTeamCount(pow2);
    if (ids.length == 1) {
      return [
        PlannedMatch(
          homeId: ids.first,
          awayId: 'BYE',
          week: 1,
          stage: stage,
        ),
      ];
    }

    final defaultWinners = pow2 ~/ 2;
    final winnersTarget = (targetWinners ?? defaultWinners)
        .clamp((ids.length + 1) ~/ 2, ids.length)
        .toInt();
    final byeCount = (winnersTarget * 2 - ids.length).clamp(0, ids.length).toInt();
    final byeTeams = ids.take(byeCount).toList();
    final playing = ids.skip(byeCount).toList();
    final planned = <PlannedMatch>[];
    var week = 1;

    // Bye'lar otomatik geçer — sanal maç üretmiyoruz, kazanan listesine eklenir.
    // İlk tur eşleşmeleri:
    for (var i = 0; i + 1 < playing.length; i += 2) {
      final a = playing[i];
      final b = playing[i + 1];
      final tieId = newId();
      final useTwo = twoLegged && !(isFinalSingle && stage == MatchStage.finalMatch);
      planned.add(PlannedMatch(
        homeId: a,
        awayId: b,
        week: week,
        stage: stage,
        tieId: useTwo ? tieId : null,
        leg: 1,
      ));
      if (useTwo) {
        planned.add(PlannedMatch(
          homeId: b,
          awayId: a,
          week: week + 1,
          stage: stage,
          tieId: tieId,
          leg: 2,
        ));
      }
    }

    // Bye bilgisi PlannedMatch olarak işaretlenmez; çağıran taraf byeTeams'i
    // sonraki tura taşımak için ayrıca alır.
    // Burada bye takımlarını "kazanmış" gibi kaydetmek için sahte BYE maçı:
    for (final t in byeTeams) {
      planned.add(PlannedMatch(
        homeId: t,
        awayId: 'BYE',
        week: week,
        stage: stage,
        leg: 1,
      ));
    }
    return planned;
  }

  List<String> _seededBracketOrder(List<String> ids) {
    final size = ids.length;
    var positions = <int>[1];
    var bracketSize = 1;
    while (bracketSize < size) {
      final next = <int>[];
      for (final position in positions) {
        next.add(position);
        next.add(bracketSize * 2 + 1 - position);
      }
      positions = next;
      bracketSize *= 2;
    }
    return positions.map((position) => ids[position - 1]).toList();
  }

  List<String> firstRoundByeWinners(List<PlannedMatch> round) =>
      round.where((m) => m.awayId == 'BYE').map((m) => m.homeId).toList();

  /// Maçları gün / saat dilimlerine yerleştirir.
  List<MatchGame> schedule({
    required String leagueId,
    required List<PlannedMatch> planned,
    required ScheduleConfig cfg,
  }) {
    if (planned.isEmpty) return [];

    final slotsPerDay = _dailySlots(cfg);
    if (slotsPerDay.isEmpty) {
      // En az bir slot garantile
      slotsPerDay.add(18);
    }

    final ordered = List<PlannedMatch>.from(planned)
      ..sort((a, b) {
        final week = a.week.compareTo(b.week);
        if (week != 0) return week;
        final stage = a.stage.index.compareTo(b.stage.index);
        if (stage != 0) return stage;
        final group = (a.groupName ?? '').compareTo(b.groupName ?? '');
        if (group != 0) return group;
        return a.leg.compareTo(b.leg);
      });
    DateTime day = dateOnly(cfg.startDate);
    var slotIdx = 0;
    var currentWeek = ordered.first.week;
    final lastPlayed = <String, DateTime>{};
    final games = <MatchGame>[];

    DateTime nextSlot() {
      if (slotIdx >= slotsPerDay.length) {
        day = day.add(const Duration(days: 1));
        slotIdx = 0;
      }
      final h = slotsPerDay[slotIdx];
      slotIdx++;
      return DateTime(day.year, day.month, day.day, h, 0);
    }

    bool busy(String teamId, DateTime when) {
      if (teamId == 'BYE') return false;
      final last = lastPlayed[teamId];
      if (last != null) {
        if (dateOnly(last) == dateOnly(when)) return true;
        if (when.difference(last).abs() < cfg.minGap) return true;
      }
      for (final m in cfg.existingMatches) {
        final st = m.startTime;
        if (st == null) continue;
        if (m.homeTeamId != teamId && m.awayTeamId != teamId) continue;
        if (dateOnly(st) == dateOnly(when)) return true;
        if (when.difference(st).abs() < cfg.minGap) return true;
      }
      return false;
    }

    for (final p in ordered) {
      if (p.week != currentWeek) {
        day = dateOnly(day).add(Duration(days: cfg.daysBetweenRounds));
        slotIdx = 0;
        currentWeek = p.week;
      }

      if (p.awayId == 'BYE') {
        games.add(MatchGame(
          id: newId(),
          leagueId: leagueId,
          homeTeamId: p.homeId,
          awayTeamId: p.awayId,
          startTime: DateTime(day.year, day.month, day.day, slotsPerDay.first, 0),
          status: MatchStatus.finished,
          homeGoals: 1,
          awayGoals: 0,
          finalized: true,
          week: p.week,
          stage: p.stage,
          groupId: p.groupId,
          groupName: p.groupName,
          tieId: p.tieId,
          leg: p.leg,
          winnerTeamId: p.homeId,
        ));
        continue;
      }

      var attempts = 0;
      DateTime slot = nextSlot();
      while ((busy(p.homeId, slot) || busy(p.awayId, slot)) && attempts < 400) {
        slot = nextSlot();
        attempts++;
      }

      games.add(MatchGame(
        id: newId(),
        leagueId: leagueId,
        homeTeamId: p.homeId,
        awayTeamId: p.awayId,
        startTime: slot,
        status: MatchStatus.scheduled,
        week: p.week,
        stage: p.stage,
        groupId: p.groupId,
        groupName: p.groupName,
        tieId: p.tieId,
        leg: p.leg,
      ));
      lastPlayed[p.homeId] = slot;
      lastPlayed[p.awayId] = slot;
    }

    games.sort((a, b) {
      final sa = a.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final sb = b.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return sa.compareTo(sb);
    });
    return games;
  }

  List<int> _dailySlots(ScheduleConfig cfg) {
    final hours = <int>[];
    var start = cfg.startHour.clamp(0, 23).toInt();
    var end = cfg.endHour.clamp(1, 24).toInt();
    if (end <= start) end = start + 2;
    for (var h = start; h < end; h += 2) {
      hours.add(h);
    }
    if (hours.isEmpty) hours.add(start);
    return hours;
  }

  String? validate({
    required LeagueFormat format,
    required List<String> teamIds,
    required int groupCount,
    required int qualifiersPerGroup,
    required int swissMatches,
    Map<String, MatchStage> knockoutEntryStages = const {},
  }) {
    if (teamIds.length < format.minTeams) {
      return 'Bu format için en az ${format.minTeams} takım gerekir.';
    }
    if ((format == LeagueFormat.cupSingle || format == LeagueFormat.cupTwoLegged) &&
        teamIds.length > 64) {
      return 'Bu kupa formatında şimdilik en fazla 64 takım destekleniyor.';
    }
    final unique = teamIds.toSet();
    if (unique.length != teamIds.length) {
      return 'Aynı takım birden fazla seçilemez.';
    }

    if (format.hasKnockout && knockoutEntryStages.isNotEmpty) {
      if (knockoutEntryStages.length != teamIds.length ||
          !teamIds.every(knockoutEntryStages.containsKey)) {
        return 'Özel başlangıç düzeninde her takım için bir giriş turu seçilmelidir.';
      }
      var activeTeams = 0;
      for (final stage in knockoutStageOrder) {
        final entrants = knockoutEntryStages.values
            .where((entryStage) => entryStage == stage)
            .length;
        final participants = activeTeams + entrants;
        if (stage == MatchStage.finalMatch) {
          if (participants != 2) {
            return 'Finale tam iki takım kalmalı. Giriş turlarını yeniden dağıtın.';
          }
          activeTeams = participants;
          continue;
        }
        final stageIndex = knockoutStageOrder.indexOf(stage);
        final nextStage = knockoutStageOrder[stageIndex + 1];
        final nextEntrants = knockoutEntryStages.values
            .where((entryStage) => entryStage == nextStage)
            .length;
        final availableCapacity = nextStage.teamCapacity - nextEntrants;
        final minimumWinners = (participants + 1) ~/ 2;
        if (participants == 0) {
          activeTeams = 0;
        } else if (availableCapacity < minimumWinners || availableCapacity < 1) {
          return '${stage.label()} ile sonraki turdaki doğrudan girişler birbiriyle uyumsuz.';
        } else {
          activeTeams = min(participants, availableCapacity);
        }
        if (activeTeams > stage.teamCapacity) {
          return '${stage.label()} için çok fazla takım var. Daha erken bir tur seçin.';
        }
      }
      if (activeTeams != 2) {
        return 'Bu giriş turları finalde iki takım bırakmıyor. Takımların başlangıç turlarını yeniden dağıtın.';
      }
    }

    if (format == LeagueFormat.swiss) {
      if (teamIds.length % 2 != 0) {
        return 'Swiss / sabit maç için takım sayısı çift olmalı.';
      }
      if (swissMatches < 1 || swissMatches >= teamIds.length) {
        return 'Her takım en fazla ${teamIds.length - 1} maç oynayabilir.';
      }
    }

    if (format.hasGroups) {
      if (groupCount < 2) return 'En az 2 grup olmalı.';
      if (groupCount > teamIds.length ~/ 2) {
        return 'Her grupta en az 2 takım olmalı. Grup sayısını azaltın.';
      }
      if (format.hasKnockout) {
        if (qualifiersPerGroup < 1) {
          return 'Gruptan çıkan takım sayısı 1 veya daha fazla olmalı.';
        }
        if (qualifiersPerGroup != 2) {
          return 'Gruplu eleme formatında gerçekçi eşleşme için her gruptan 2 takım çıkmalıdır.';
        }
        final maxPerGroup =
            (teamIds.length + groupCount - 1) ~/ groupCount;
        if (qualifiersPerGroup > maxPerGroup) {
          return 'Gruptan çıkan takım sayısı, grup başına takım sayısını aşamaz.';
        }
        final advancers = groupCount * qualifiersPerGroup;
        if (advancers < 2) {
          return 'Eleme turu için gruptan en az 2 takım çıkmalı.';
        }
      }
    }
    return null;
  }
}
