// FULL MARK — GameResult: score, XP and stars for one finished game.
// Pure data + pure rules. No UI, no I/O.

/// Star rules (single source of truth — mirrored in tools/verify_logic.py):
///   >= 90% correct -> 3 stars
///   >= 70%         -> 2 stars
///   >= 50%         -> 1 star
///   <  50%         -> 0 stars + retry prompt.
int starsForAccuracy(double accuracyPercent) {
  if (accuracyPercent >= 90) return 3;
  if (accuracyPercent >= 70) return 2;
  if (accuracyPercent >= 50) return 1;
  return 0;
}

/// XP formula (single source of truth — mirrored in tools/verify_logic.py):
///   XP = 10 * correct + 5 * streakBonus
/// where streakBonus = number of correct answers given while the running
/// streak was >= 3 (i.e. the 3rd, 4th, ... consecutive correct answers
/// each earn +5). A lone correct answer earns 10 XP, no bonus.
int xpFor({required int correct, required int streakBonus}) =>
    10 * correct + 5 * streakBonus;

class GameResult {
  final String modeId;
  final String subject;
  final int totalQuestions;
  final int correct;
  final int wrong;
  final int skipped;

  /// Longest run of consecutive correct answers in this game.
  final int bestStreak;

  /// Count of correct answers earned with streak >= 3 (see [xpFor]).
  final int streakBonus;

  /// Total seconds the game took (sum of per-question time, or wall time
  /// as measured by the engine — see GameEngine.elapsedSeconds).
  final int elapsedSeconds;

  /// Per-question correctness, in play order: true = correct.
  final List<bool> perQuestionCorrect;

  /// Ids of questions answered wrongly (for the review plan).
  final List<String> wrongQuestionIds;

  /// Ids of the questions actually played in this game, in play order.
  /// Empty only when the game plays no bank questions at all (the
  /// Islamic ordering game). DatabaseHelper.recordGameResult uses it
  /// to skip questions that were NOT played — before, unplayed
  /// questions were recorded as correct attempts.
  final List<String> playedQuestionIds;

  /// Real per-question time, keyed by question id (seconds). Empty
  /// when the mode does not measure per-question time (sentence /
  /// ordering / memory games) — callers must store 0 ("not measured"),
  /// never a fabricated even spread of the total.
  final Map<String, int> secondsByQuestionId;

  const GameResult({
    required this.modeId,
    required this.subject,
    required this.totalQuestions,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.bestStreak,
    required this.streakBonus,
    required this.elapsedSeconds,
    required this.perQuestionCorrect,
    required this.wrongQuestionIds,
    this.playedQuestionIds = const <String>[],
    this.secondsByQuestionId = const <String, int>{},
  });

  double get accuracyPercent =>
      totalQuestions == 0 ? 0 : correct * 100.0 / totalQuestions;

  int get stars => starsForAccuracy(accuracyPercent);

  /// Streak bonus for a per-question correctness list, the same
  /// rule the engine uses (GameEngine: each correct answer given while
  /// the running streak is >= 3 earns +1 bonus). Shared so the
  /// sentence/ordering games record a real bonus instead of 0.
  static int streakBonusFor(List<bool> results) {
    var streak = 0;
    var bonus = 0;
    for (final bool v in results) {
      if (v) {
        streak++;
        if (streak >= 3) bonus++;
      } else {
        streak = 0;
      }
    }
    return bonus;
  }

  int get xpEarned => xpFor(correct: correct, streakBonus: streakBonus);

  /// Average seconds per answered question (0 when nothing was answered).
  double get avgSecondsPerQuestion {
    final answered = correct + wrong;
    return answered == 0 ? 0 : elapsedSeconds / answered;
  }

  bool get passed => stars >= 1;

  /// True when the player should be offered a retry (below 50%).
  bool get needsRetry => stars == 0 && totalQuestions > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'modeId': modeId,
        'subject': subject,
        'totalQuestions': totalQuestions,
        'correct': correct,
        'wrong': wrong,
        'skipped': skipped,
        'bestStreak': bestStreak,
        'streakBonus': streakBonus,
        'elapsedSeconds': elapsedSeconds,
        'accuracyPercent': accuracyPercent,
        'stars': stars,
        'xpEarned': xpEarned,
        'perQuestionCorrect': perQuestionCorrect,
        'wrongQuestionIds': wrongQuestionIds,
        'playedQuestionIds': playedQuestionIds,
        'secondsByQuestionId': secondsByQuestionId,
      };
}
