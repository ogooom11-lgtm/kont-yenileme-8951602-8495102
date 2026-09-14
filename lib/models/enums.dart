/// Gerçekçi turnuva formatları.
enum LeagueFormat {
  /// Tek devre lig — herkes herkesle bir kez (La Liga tek devre / yaz turnuvası).
  leagueSingle,

  /// Çift devre lig — ev + deplasman (Süper Lig, Premier Lig).
  leagueDouble,

  /// Tek maç eleme kupası (Türkiye Kupası, FA Cup).
  cupSingle,

  /// Rövanşlı eleme (eski Şampiyonlar Ligi eleme turları).
  cupTwoLegged,

  /// Sadece grup aşaması (hazırlık turnuvası, lig grubu).
  groupsOnly,

  /// Dünya Kupası: gruplar + tek maç eleme.
  worldCup,

  /// Şampiyonlar Ligi klasik: gruplar + rövanşlı eleme (final tek maç).
  championsLeague,

  /// Swiss / sabit maç: her takım N rakiple oynar.
  swiss,
}

extension LeagueFormatX on LeagueFormat {
  String get title => switch (this) {
        LeagueFormat.leagueSingle => 'Tek Devre Lig',
        LeagueFormat.leagueDouble => 'Çift Devre Lig',
        LeagueFormat.cupSingle => 'Kupa (Tek Maç)',
        LeagueFormat.cupTwoLegged => 'Rövanşlı Eleme',
        LeagueFormat.groupsOnly => 'Grup Turnuvası',
        LeagueFormat.worldCup => 'Dünya Kupası',
        LeagueFormat.championsLeague => 'Şampiyonlar Ligi',
        LeagueFormat.swiss => 'Swiss / Sabit Maç',
      };

  String get subtitle => switch (this) {
        LeagueFormat.leagueSingle =>
          'Herkes herkesle bir kez. Puan tablosu ile sıralama.',
        LeagueFormat.leagueDouble =>
          'Ev-deplasman. Gerçek lig sezonu gibi çift devre.',
        LeagueFormat.cupSingle =>
          'Tek maç eleme. Beraberlikte penaltı. Sonraki tur otomatik.',
        LeagueFormat.cupTwoLegged =>
          'İki maçlı eleme. Toplam skora göre kazanan, gerekirse penaltı.',
        LeagueFormat.groupsOnly =>
          'Takımlar gruplara ayrılır, her grup kendi mini ligini oynar.',
        LeagueFormat.worldCup =>
          'Gruplar + tek maç eleme. Gruptan çıkanlar kupa oynar.',
        LeagueFormat.championsLeague =>
          'Gruplar + rövanşlı eleme. Final tek maç oynanır.',
        LeagueFormat.swiss =>
          'Her takım belirlenen sayıda maç oynar. Puan tablosu tutulur.',
      };

  String get example => switch (this) {
        LeagueFormat.leagueSingle => 'Yaz kupası, kısa sezon',
        LeagueFormat.leagueDouble => 'Süper Lig, Premier Lig',
        LeagueFormat.cupSingle => 'Türkiye Kupası, FA Cup',
        LeagueFormat.cupTwoLegged => 'ŞL play-off, Avrupa Ligi eleme',
        LeagueFormat.groupsOnly => 'Hazırlık grubu, lig etabı',
        LeagueFormat.worldCup => 'Dünya Kupası, EURO',
        LeagueFormat.championsLeague => 'Klasik Şampiyonlar Ligi',
        LeagueFormat.swiss => 'Dünya Kupası eleme, Swiss sistem',
      };

  bool get hasTable => switch (this) {
        LeagueFormat.cupSingle || LeagueFormat.cupTwoLegged => false,
        _ => true,
      };

  bool get hasGroups => switch (this) {
        LeagueFormat.groupsOnly ||
        LeagueFormat.worldCup ||
        LeagueFormat.championsLeague =>
          true,
        _ => false,
      };

  bool get hasKnockout => switch (this) {
        LeagueFormat.cupSingle ||
        LeagueFormat.cupTwoLegged ||
        LeagueFormat.worldCup ||
        LeagueFormat.championsLeague =>
          true,
        _ => false,
      };

  bool get isTwoLeggedKnockout => switch (this) {
        LeagueFormat.cupTwoLegged || LeagueFormat.championsLeague => true,
        _ => false,
      };

  bool get usesPoints => hasTable;

  int get minTeams => switch (this) {
        LeagueFormat.groupsOnly ||
        LeagueFormat.worldCup ||
        LeagueFormat.championsLeague =>
          4,
        LeagueFormat.swiss => 4,
        _ => 2,
      };

  static LeagueFormat fromStored(String? name) {
    if (name == null) return LeagueFormat.leagueDouble;
    for (final v in LeagueFormat.values) {
      if (v.name == name) return v;
    }
    // Eski sürüm uyumu
    return switch (name) {
      'league' => LeagueFormat.leagueDouble,
      'elimination' => LeagueFormat.cupSingle,
      'fixedMatches' => LeagueFormat.swiss,
      _ => LeagueFormat.leagueDouble,
    };
  }
}

enum MatchStatus { scheduled, live, finished }

/// Sıralama eşitliklerinde uygulanacak resmi öncelik sırası.
/// `headToHead` için mevcut karşılaşmaların puan/averajı kullanılır.
enum StandingsTieBreaker {
  points,
  goalDifference,
  goalsFor,
  wins,
  headToHead,
  fairPlay,
}

extension StandingsTieBreakerX on StandingsTieBreaker {
  String get label => switch (this) {
        StandingsTieBreaker.points => 'Puan',
        StandingsTieBreaker.goalDifference => 'Averaj',
        StandingsTieBreaker.goalsFor => 'Atılan gol',
        StandingsTieBreaker.wins => 'Galibiyet',
        StandingsTieBreaker.headToHead => 'İkili averaj',
        StandingsTieBreaker.fairPlay => 'Fair-play',
      };

  static StandingsTieBreaker fromStored(String? value) {
    return StandingsTieBreaker.values.firstWhere(
      (item) => item.name == value,
      orElse: () => StandingsTieBreaker.goalDifference,
    );
  }
}

enum MatchStage {
  leagueRound,
  group,
  roundOf32,
  roundOf16,
  quarterFinal,
  semiFinal,
  thirdPlace,
  finalMatch,
}

extension MatchStageX on MatchStage {
  String label({int week = 1, String? groupName}) {
    return switch (this) {
      MatchStage.leagueRound => '$week. Hafta',
      MatchStage.group =>
        groupName == null ? 'Grup' : 'Grup $groupName · $week. Hafta',
      MatchStage.roundOf32 => 'Son 32',
      MatchStage.roundOf16 => 'Son 16',
      MatchStage.quarterFinal => 'Çeyrek Final',
      MatchStage.semiFinal => 'Yarı Final',
      MatchStage.thirdPlace => 'Üçüncülük',
      MatchStage.finalMatch => 'Final',
    };
  }

  bool get isKnockout => switch (this) {
        MatchStage.leagueRound || MatchStage.group => false,
        _ => true,
      };

  static MatchStage fromTeamCount(int remaining) {
    return switch (remaining) {
      2 => MatchStage.finalMatch,
      4 => MatchStage.semiFinal,
      8 => MatchStage.quarterFinal,
      16 => MatchStage.roundOf16,
      _ => MatchStage.roundOf32,
    };
  }
}

enum EventType { goal, ownGoal, penaltyGoal, yellow, red, save }

extension EventTypeX on EventType {
  String get label => switch (this) {
        EventType.goal => 'Gol',
        EventType.ownGoal => 'Kendi kalesine',
        EventType.penaltyGoal => 'Penaltı golü',
        EventType.yellow => 'Sarı kart',
        EventType.red => 'Kırmızı kart',
        EventType.save => 'Kurtarış',
      };
}
