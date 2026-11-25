// ABQARIYA — AnalyticsEngine: pure local analytics logic.
// Input is real attempt data passed in by the caller (from local storage).
// Honesty rules:
//  - Fewer than 5 attempts overall -> "insufficient data" (see
//    [AnalyticsSummary.hasEnoughData]); nothing is presented as a trend.
//  - Output is a READINESS INDICATOR only. It NEVER predicts exam
//    results. Every screen using this must label it as such.
//  - No fake data: with zero attempts every mastery is 0 / "no data".

import '../models/game_result.dart';

/// One recorded attempt on one question (local storage only).
class Attempt {
  final String questionId;
  final String subject;
  final String unit;
  final bool correct;
  final int secondsTaken;
  final DateTime at;

  const Attempt({
    required this.questionId,
    required this.subject,
    required this.unit,
    required this.correct,
    required this.secondsTaken,
    required this.at,
  });
}

class MasteryEntry {
  final String key; // subject or "subject / unit"
  final String subject;
  final String unit;
  final int attempts;
  final int correct;
  double get accuracyPercent =>
      attempts == 0 ? 0 : correct * 100.0 / attempts;

  const MasteryEntry({
    required this.key,
    required this.subject,
    required this.unit,
    required this.attempts,
    required this.correct,
  });
}

class AnalyticsSummary {
  final int totalAttempts;
  final int totalCorrect;
  final List<MasteryEntry> masteryBySubject;
  final List<MasteryEntry> masteryByUnit;

  /// Weakest 3 units (by accuracy, min 3 attempts each). Empty when
  /// there is not enough data.
  final List<MasteryEntry> weakestUnits;
  final List<MasteryEntry> strongestUnits;

  /// Overall accuracy, or null when there is no data.
  final double? overallAccuracy;

  /// Mean seconds per question, or null when there is no data.
  final double? avgSecondsPerQuestion;

  /// Accuracy per day (last 7 days with data), oldest -> newest.
  /// Empty when there is not enough data.
  final List<double> accuracyTrend;

  /// The calendar date of each entry in [accuracyTrend], same order.
  /// Empty together with the trend. (v0.1.4: rows used to read
  /// «اليوم 1/2» with no date — now each row shows its real date.)
  final List<DateTime> trendDates;

  const AnalyticsSummary({
    required this.totalAttempts,
    required this.totalCorrect,
    required this.masteryBySubject,
    required this.masteryByUnit,
    required this.weakestUnits,
    required this.strongestUnits,
    required this.overallAccuracy,
    required this.avgSecondsPerQuestion,
    required this.accuracyTrend,
    required this.trendDates,
  });

  /// True only with >= 5 attempts. Below that, screens must show
  /// "بيانات غير كافية" instead of any trend / strength claim.
  bool get hasEnoughData => totalAttempts >= 5;

  /// Readiness indicator ONLY — never an exam prediction.
  /// 0-100, or null when there is not enough data.
  double? get readinessIndicator {
    if (!hasEnoughData || overallAccuracy == null) return null;
    return overallAccuracy;
  }
}

/// Simplified SM-2 spaced-repetition state for one question.
class ReviewState {
  final String questionId;

  /// Successful reviews in a row (0 after a failure).
  final int repetitions;

  /// Ease factor, starts at 2.5, never below 1.3.
  final double easeFactor;

  /// Days until the next review.
  final int intervalDays;
  final DateTime nextReview;

  const ReviewState({
    required this.questionId,
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.nextReview,
  });

  ReviewState copyWith({
    int? repetitions,
    double? easeFactor,
    int? intervalDays,
    DateTime? nextReview,
  }) =>
      ReviewState(
        questionId: questionId,
        repetitions: repetitions ?? this.repetitions,
        easeFactor: easeFactor ?? this.easeFactor,
        intervalDays: intervalDays ?? this.intervalDays,
        nextReview: nextReview ?? this.nextReview,
      );
}

/// Simplified SM-2 intervals (days) by repetition number:
/// 1st success -> 1 day, 2nd -> 3, 3rd -> 7, 4th -> 14, 5th+ -> 30.
const List<int> kSm2Intervals = <int>[1, 3, 7, 14, 30];

int sm2IntervalForRepetitions(int repetitions) {
  if (repetitions <= 0) return 1;
  final index = repetitions - 1;
  return kSm2Intervals[index < kSm2Intervals.length ? index : kSm2Intervals.length - 1];
}

double sm2EaseAfter({required double ease, required int quality}) {
  // quality 0-5 (5 = perfect, <3 = failed). Standard SM-2 formula.
  final q = quality.clamp(0, 5);
  var next = ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (next < 1.3) next = 1.3;
  return next;
}

/// Apply one review to [state]. [quality] 0-5; a correct answer is
/// quality 4 (or 5 if answered fast — caller decides), wrong is 0-2.
/// Returns the new state; [now] is injected for testability.
ReviewState sm2Review(ReviewState state, int quality, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final q = quality.clamp(0, 5);
  final ease = sm2EaseAfter(ease: state.easeFactor, quality: q);
  if (q < 3) {
    // Failed: reset repetitions, review again tomorrow.
    return ReviewState(
      questionId: state.questionId,
      repetitions: 0,
      easeFactor: ease,
      intervalDays: 1,
      nextReview: current.add(const Duration(days: 1)),
    );
  }
  final repetitions = state.repetitions + 1;
  final interval = sm2IntervalForRepetitions(repetitions);
  return ReviewState(
    questionId: state.questionId,
    repetitions: repetitions,
    easeFactor: ease,
    intervalDays: interval,
    nextReview: current.add(Duration(days: interval)),
  );
}

ReviewState initialReviewState(String questionId, {DateTime? now}) {
  final current = now ?? DateTime.now();
  return ReviewState(
    questionId: questionId,
    repetitions: 0,
    easeFactor: 2.5,
    intervalDays: 1,
    nextReview: current.add(const Duration(days: 1)),
  );
}

class AnalyticsEngine {
  static const int kMinAttempts = 5;

  static AnalyticsSummary summarize(List<Attempt> attempts) {
    final total = attempts.length;
    final correct = attempts.where((a) => a.correct).length;

    MasteryEntry build(String key, String subject, String unit,
        List<Attempt> group) {
      final c = group.where((a) => a.correct).length;
      return MasteryEntry(
        key: key,
        subject: subject,
        unit: unit,
        attempts: group.length,
        correct: c,
      );
    }

    final bySubject = <String, List<Attempt>>{};
    final byUnit = <String, List<Attempt>>{};
    for (final a in attempts) {
      bySubject.putIfAbsent(a.subject, () => []).add(a);
      byUnit.putIfAbsent('${a.subject} / ${a.unit}', () => []).add(a);
    }
    final masteryBySubject = bySubject.entries
        .map((e) => build(e.key, e.key, '', e.value))
        .toList()
      ..sort((a, b) => b.accuracyPercent.compareTo(a.accuracyPercent));
    final masteryByUnit = byUnit.entries.map((e) {
      final parts = e.key.split(' / ');
      return build(e.key, parts.first, parts.length > 1 ? parts[1] : '',
          e.value);
    }).toList()
      ..sort((a, b) => b.accuracyPercent.compareTo(a.accuracyPercent));

    // Weakest / strongest units need at least 3 attempts each to be
    // meaningful; otherwise the lists stay empty (honest, not guessed).
    final unitsWithData =
        masteryByUnit.where((m) => m.attempts >= 3).toList();
    final weakest = unitsWithData.length >= 2
        ? (List<MasteryEntry>.from(unitsWithData)
              ..sort((a, b) =>
                  a.accuracyPercent.compareTo(b.accuracyPercent)))
            .take(3)
            .toList()
        : <MasteryEntry>[];
    final strongest = unitsWithData.length >= 2
        ? (List<MasteryEntry>.from(unitsWithData)
              ..sort((a, b) =>
                  b.accuracyPercent.compareTo(a.accuracyPercent)))
            .take(3)
            .toList()
        : <MasteryEntry>[];

    // Average over MEASURED attempts only (secondsTaken > 0). Attempts
    // whose time was never measured store 0 and must not drag the
    // average down to a fake "0 s per question".
    final measured =
        attempts.where((Attempt a) => a.secondsTaken > 0).toList();
    final double? avgSeconds = measured.isEmpty
        ? null
        : measured.fold<int>(0, (int s, Attempt a) => s + a.secondsTaken) /
            measured.length;

    // Trend: accuracy per calendar day, last 7 days that have data.
    final byDay = <String, List<Attempt>>{};
    for (final a in attempts) {
      final day =
          '${a.at.year}-${a.at.month.toString().padLeft(2, '0')}-${a.at.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(day, () => []).add(a);
    }
    final days = byDay.keys.toList()..sort();
    final List<String> trendDays =
        days.skip(days.length > 7 ? days.length - 7 : 0).toList();
    final trend = trendDays.map((d) {
      final g = byDay[d]!;
      return g.where((a) => a.correct).length * 100.0 / g.length;
    }).toList();
    final trendDates = trendDays
        .map((d) {
          final parts = d.split('-');
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        })
        .toList();

    return AnalyticsSummary(
      totalAttempts: total,
      totalCorrect: correct,
      masteryBySubject: masteryBySubject,
      masteryByUnit: masteryByUnit,
      weakestUnits: total >= kMinAttempts ? weakest : const [],
      strongestUnits: total >= kMinAttempts ? strongest : const [],
      overallAccuracy: total == 0 ? null : correct * 100.0 / total,
      avgSecondsPerQuestion: avgSeconds,
      accuracyTrend: total >= kMinAttempts ? trend : const [],
      trendDates: total >= kMinAttempts ? trendDates : const [],
    );
  }

  /// Build a review plan: question ids due for review on/before [on],
  /// weakest units first, at most [maxItems]. Returns an empty list when
  /// there is nothing due — never invents items.
  static List<String> reviewPlan({
    required Map<String, ReviewState> states,
    required List<Attempt> attempts,
    DateTime? on,
    int maxItems = 10,
  }) {
    final day = on ?? DateTime.now();
    final due = states.values
        .where((s) =>
            s.nextReview.isBefore(day) ||
            s.nextReview.isAtSameMomentAs(day))
        .toList();
    // Weakest units first: rank by unit accuracy (ascending).
    final summary = summarize(attempts);
    final unitRank = <String, double>{};
    for (final m in summary.masteryByUnit) {
      unitRank[m.key] = m.accuracyPercent;
    }
    final unitOf = <String, String>{};
    for (final a in attempts) {
      unitOf[a.questionId] = '${a.subject} / ${a.unit}';
    }
    due.sort((a, b) {
      final ra = unitRank[unitOf[a.questionId] ?? ''] ?? 50.0;
      final rb = unitRank[unitOf[b.questionId] ?? ''] ?? 50.0;
      return ra.compareTo(rb);
    });
    return due.take(maxItems).map((s) => s.questionId).toList();
  }
}


