// ABQARIYA tests — analytics engine + SM-2 + mastery.
// NOTE: NOT RUN HERE. No Flutter/Dart SDK is available in this
// environment, so these tests were written carefully but never executed.
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';

import 'package:abqariya/analytics/analytics_engine.dart';

Attempt attempt({
  required String subject,
  required String unit,
  required bool correct,
  DateTime? at,
}) =>
    Attempt(
      questionId: '$subject-$unit-${correct ? 'c' : 'w'}-${DateTime.now().microsecondsSinceEpoch}',
      subject: subject,
      unit: unit,
      correct: correct,
      secondsTaken: 10,
      at: at ?? DateTime(2026, 11, 25),
    );

void main() {
  group('insufficient data', () {
    test('fewer than 5 attempts -> hasEnoughData false, no trend', () {
      final summary = AnalyticsEngine.summarize([
        attempt(subject: 'physics', unit: 'u1', correct: true),
        attempt(subject: 'physics', unit: 'u1', correct: true),
        attempt(subject: 'physics', unit: 'u1', correct: false),
        attempt(subject: 'physics', unit: 'u1', correct: true),
      ]);
      expect(summary.hasEnoughData, false);
      expect(summary.readinessIndicator, isNull);
      expect(summary.accuracyTrend, isEmpty);
      expect(summary.weakestUnits, isEmpty);
    });

    test('zero attempts -> empty, honest state', () {
      final summary = AnalyticsEngine.summarize(const []);
      expect(summary.totalAttempts, 0);
      expect(summary.overallAccuracy, isNull);
      expect(summary.hasEnoughData, false);
    });
  });

  group('mastery', () {
    test('mastery % per subject is correct', () {
      final summary = AnalyticsEngine.summarize([
        attempt(subject: 'physics', unit: 'u1', correct: true),
        attempt(subject: 'physics', unit: 'u1', correct: true),
        attempt(subject: 'physics', unit: 'u1', correct: false),
        attempt(subject: 'physics', unit: 'u1', correct: false),
        attempt(subject: 'math', unit: 'u1', correct: true),
        attempt(subject: 'math', unit: 'u1', correct: true),
      ]);
      expect(summary.totalAttempts, 6);
      expect(summary.overallAccuracy, closeTo(66.666, 0.01));
      final physics = summary.masteryBySubject
          .firstWhere((m) => m.subject == 'physics');
      expect(physics.accuracyPercent, 50);
      final math =
          summary.masteryBySubject.firstWhere((m) => m.subject == 'math');
      expect(math.accuracyPercent, 100);
    });

    test('weakest units are the lowest 3 with >=3 attempts', () {
      final attempts = <Attempt>[];
      // u1: 0/3, u2: 1/3, u3: 3/3, u4: 2/3  (12 attempts)
      for (var i = 0; i < 3; i++) {
        attempts.add(attempt(subject: 'physics', unit: 'u1', correct: false));
      }
      attempts.add(attempt(subject: 'physics', unit: 'u2', correct: true));
      for (var i = 0; i < 2; i++) {
        attempts.add(attempt(subject: 'physics', unit: 'u2', correct: false));
      }
      for (var i = 0; i < 3; i++) {
        attempts.add(attempt(subject: 'physics', unit: 'u3', correct: true));
      }
      attempts.add(attempt(subject: 'physics', unit: 'u4', correct: true));
      attempts.add(attempt(subject: 'physics', unit: 'u4', correct: true));
      attempts.add(attempt(subject: 'physics', unit: 'u4', correct: false));
      final summary = AnalyticsEngine.summarize(attempts);
      expect(summary.weakestUnits.length, 3);
      expect(summary.weakestUnits.first.unit, 'u1');
      expect(summary.weakestUnits[1].unit, 'u2');
    });
  });

  group('SM-2', () {
    test('intervals are 1, 3, 7, 14, 30', () {
      expect(sm2IntervalForRepetitions(1), 1);
      expect(sm2IntervalForRepetitions(2), 3);
      expect(sm2IntervalForRepetitions(3), 7);
      expect(sm2IntervalForRepetitions(4), 14);
      expect(sm2IntervalForRepetitions(5), 30);
      expect(sm2IntervalForRepetitions(9), 30);
    });

    test('successful review advances interval', () {
      final now = DateTime(2026, 11, 25);
      var state = initialReviewState('q1', now: now);
      state = sm2Review(state, 5, now: now);
      expect(state.repetitions, 1);
      expect(state.intervalDays, 1);
      state = sm2Review(state, 5, now: now);
      expect(state.repetitions, 2);
      expect(state.intervalDays, 3);
      state = sm2Review(state, 5, now: now);
      expect(state.intervalDays, 7);
    });

    test('failed review resets repetitions and ease never drops below 1.3', () {
      final now = DateTime(2026, 11, 25);
      var state = initialReviewState('q1', now: now);
      state = sm2Review(state, 5, now: now);
      state = sm2Review(state, 0, now: now);
      expect(state.repetitions, 0);
      expect(state.intervalDays, 1);
      expect(state.easeFactor, greaterThanOrEqualTo(1.3));
      // Repeated failures still floor at 1.3.
      for (var i = 0; i < 10; i++) {
        state = sm2Review(state, 0, now: now);
      }
      expect(state.easeFactor, 1.3);
    });

    test('review plan returns only due items, weakest first', () {
      final now = DateTime(2026, 11, 25);
      final states = <String, ReviewState>{
        'q1': ReviewState(
            questionId: 'q1',
            repetitions: 1,
            easeFactor: 2.5,
            intervalDays: 1,
            nextReview: DateTime(2026, 11, 20)),
        'q2': ReviewState(
            questionId: 'q2',
            repetitions: 1,
            easeFactor: 2.5,
            intervalDays: 1,
            nextReview: DateTime(2026, 12, 20)),
      };
      final plan = AnalyticsEngine.reviewPlan(
        states: states,
        attempts: const [],
        on: now,
      );
      expect(plan, ['q1']);
    });
  });
}
