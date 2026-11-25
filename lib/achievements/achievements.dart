// ABQARIYA — Achievements: XP levels, badges, daily reward.
// All unlock rules are based on REAL mastery / XP thresholds computed
// from local attempt data. Nothing is unlocked by a timer or by opening
// a screen. Daily reward uses the LOCAL date only — no server, no
// account. Dates are compared by calendar day (yyyy-MM-dd, local time).

import '../analytics/analytics_engine.dart';

/// XP needed to reach [level] (level 1 starts at 0 XP).
/// Level thresholds: 0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200...
/// i.e. each level costs 50 more than the previous (100, 150, 200, ...).
int xpForLevel(int level) {
  if (level <= 1) return 0;
  var total = 0;
  var cost = 100;
  for (var l = 2; l <= level; l++) {
    total += cost;
    cost += 50;
  }
  return total;
}

/// Level for a given total XP.
int levelForXp(int totalXp) {
  var level = 1;
  while (totalXp >= xpForLevel(level + 1)) {
    level++;
  }
  return level;
}

/// XP progress inside the current level: (xpIntoLevel, xpNeededForNext).
(int, int) xpProgressInLevel(int totalXp) {
  final level = levelForXp(totalXp);
  final base = xpForLevel(level);
  final next = xpForLevel(level + 1);
  return (totalXp - base, next - base);
}

class Badge {
  final String id;
  final String titleAr;
  final String descriptionAr;

  /// Unlock rule, evaluated against real progress. Documented per badge.
  final bool Function(BadgeProgress progress) unlockRule;

  const Badge({
    required this.id,
    required this.titleAr,
    required this.descriptionAr,
    required this.unlockRule,
  });
}

/// Everything a badge rule may look at — all derived from real data.
class BadgeProgress {
  final int totalXp;
  final int level;

  /// Subject -> mastery % (0-100), from AnalyticsEngine.
  final Map<String, double> masteryBySubject;

  /// Subject -> number of questions answered correctly.
  final Map<String, int> correctBySubject;

  /// Total games finished.
  final int gamesFinished;

  /// Best streak ever (across games).
  final int bestStreak;

  /// Number of distinct days with at least one game (local dates).
  final int activeDays;

  const BadgeProgress({
    required this.totalXp,
    required this.level,
    required this.masteryBySubject,
    required this.correctBySubject,
    required this.gamesFinished,
    required this.bestStreak,
    required this.activeDays,
  });

  double mastery(String subject) => masteryBySubject[subject] ?? 0;
}

/// Subject badges: mastery >= 80% in that subject AND at least 10
/// correct answers in it (so a 1-question 100% cannot unlock a badge).
List<Badge> get kBadges => <Badge>[
      Badge(
        id: 'physics_genius',
        titleAr: 'عبقرية الفيزياء',
        descriptionAr: 'إتقان 80٪ أو أكثر في الفيزياء (10 إجابات صحيحة على الأقل).',
        unlockRule: (p) =>
            p.mastery('physics') >= 80 &&
            (p.correctBySubject['physics'] ?? 0) >= 10,
      ),
      Badge(
        id: 'chemistry_queen',
        titleAr: 'ملكة الكيمياء',
        descriptionAr: 'إتقان 80٪ أو أكثر في الكيمياء (10 إجابات صحيحة على الأقل).',
        unlockRule: (p) =>
            p.mastery('chemistry') >= 80 &&
            (p.correctBySubject['chemistry'] ?? 0) >= 10,
      ),
      Badge(
        id: 'biology_scientist',
        titleAr: 'عالمة الأحياء',
        descriptionAr: 'إتقان 80٪ أو أكثر في الأحياء (10 إجابات صحيحة على الأقل).',
        unlockRule: (p) =>
            p.mastery('biology') >= 80 &&
            (p.correctBySubject['biology'] ?? 0) >= 10,
      ),
      Badge(
        id: 'math_mistress',
        titleAr: 'سيدة الأرقام',
        descriptionAr: 'إتقان 80٪ أو أكثر في الرياضيات (10 إجابات صحيحة على الأقل).',
        unlockRule: (p) =>
            p.mastery('math') >= 80 &&
            (p.correctBySubject['math'] ?? 0) >= 10,
      ),
      Badge(
        id: 'arabic_star',
        titleAr: 'نجمة العربية',
        descriptionAr: 'إتقان 80٪ أو أكثر في اللغة العربية (10 إجابات صحيحة على الأقل).',
        unlockRule: (p) =>
            p.mastery('arabic') >= 80 &&
            (p.correctBySubject['arabic'] ?? 0) >= 10,
      ),
      Badge(
        id: 'english_expert',
        titleAr: 'خبيرة الإنجليزية',
        descriptionAr: 'إتقان 80٪ أو أكثر في اللغة الإنجليزية (10 إجابات صحيحة على الأقل).',
        unlockRule: (p) =>
            p.mastery('english') >= 80 &&
            (p.correctBySubject['english'] ?? 0) >= 10,
      ),
      Badge(
        id: 'streak_7',
        titleAr: 'سلسلة ذهبية',
        descriptionAr: 'سلسلة 7 إجابات صحيحة متتالية في لعبة واحدة.',
        unlockRule: (p) => p.bestStreak >= 7,
      ),
      Badge(
        id: 'first_game',
        titleAr: 'البداية',
        descriptionAr: 'أنهِ أول لعبة.',
        unlockRule: (p) => p.gamesFinished >= 1,
      ),
      Badge(
        id: 'ten_games',
        titleAr: 'المثابرة',
        descriptionAr: 'أنهِ 10 ألعاب.',
        unlockRule: (p) => p.gamesFinished >= 10,
      ),
      Badge(
        id: 'week_active',
        titleAr: 'أسبوع النشاط',
        descriptionAr: 'العب في 7 أيام مختلفة.',
        unlockRule: (p) => p.activeDays >= 7,
      ),
      Badge(
        id: 'level_5',
        titleAr: 'المستوى الخامس',
        descriptionAr: 'صل إلى المستوى 5.',
        unlockRule: (p) => p.level >= 5,
      ),
    ];

List<Badge> unlockedBadges(BadgeProgress progress) =>
    kBadges.where((b) => b.unlockRule(progress)).toList();

List<Badge> lockedBadges(BadgeProgress progress) =>
    kBadges.where((b) => !b.unlockRule(progress)).toList();

/// Build [BadgeProgress] from real attempt data + totals. The caller
/// supplies totals (XP, games, streak, active days) from local storage.
BadgeProgress progressFromAttempts({
  required List<Attempt> attempts,
  required int totalXp,
  required int gamesFinished,
  required int bestStreak,
  required int activeDays,
}) {
  final summary = AnalyticsEngine.summarize(attempts);
  final mastery = <String, double>{};
  final correctBy = <String, int>{};
  for (final m in summary.masteryBySubject) {
    mastery[m.subject] = m.accuracyPercent;
    correctBy[m.subject] = m.correct;
  }
  return BadgeProgress(
    totalXp: totalXp,
    level: levelForXp(totalXp),
    masteryBySubject: mastery,
    correctBySubject: correctBy,
    gamesFinished: gamesFinished,
    bestStreak: bestStreak,
    activeDays: activeDays,
  );
}

// ---------------------------------------------------------------------------
// Daily reward — local date only, no server.
// ---------------------------------------------------------------------------

/// A daily-reward claim record (stored locally by the app shell).
class DailyRewardState {
  /// Last claimed date, local calendar day, "yyyy-MM-dd". Null = never.
  final String? lastClaimedDay;

  /// Current consecutive-day streak (0 = none).
  final int streakDays;

  const DailyRewardState({this.lastClaimedDay, this.streakDays = 0});

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool canClaimToday({DateTime? now}) {
    final today = _dayKey(now ?? DateTime.now());
    return lastClaimedDay != today;
  }

  /// XP for today's claim: 20 base + 5 per consecutive day, capped at 50.
  int rewardXpForToday({DateTime? now}) {
    final today = now ?? DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final continuing = lastClaimedDay == _dayKey(yesterday);
    final streak = continuing ? streakDays + 1 : 1;
    final xp = 20 + 5 * (streak - 1);
    return xp > 50 ? 50 : xp;
  }

  /// Claim today's reward. Returns the new state + XP earned.
  /// Callers must persist the returned state locally.
  (DailyRewardState, int) claim({DateTime? now}) {
    final today = now ?? DateTime.now();
    if (!canClaimToday(now: today)) {
      return (this, 0);
    }
    final yesterday = today.subtract(const Duration(days: 1));
    final continuing = lastClaimedDay == _dayKey(yesterday);
    final streak = continuing ? streakDays + 1 : 1;
    final xp = rewardXpForToday(now: today);
    return (
      DailyRewardState(lastClaimedDay: _dayKey(today), streakDays: streak),
      xp,
    );
  }
}
