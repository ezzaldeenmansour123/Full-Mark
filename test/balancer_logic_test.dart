// ABQARIYA tests — balancer / gating logic: XP levels, badges,
// daily reward, exam gating.
// NOTE: NOT RUN HERE. No Flutter/Dart SDK is available in this
// environment, so these tests were written carefully but never executed.
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';

import 'package:abqariya/achievements/achievements.dart';
import 'package:abqariya/analytics/analytics_engine.dart';
import 'package:abqariya/exam/ministerial_exam.dart';
import 'package:abqariya/models/question.dart';

Question demoQ(String id, String subject) => Question(
      id: id,
      subject: subject,
      unit: 'u1',
      lesson: 'l1',
      type: QuestionType.mcq,
      text: 'سؤال $id؟',
      options: const ['أ', 'ب'],
      correctAnswer: 'أ',
      source: 'demo — not Yemeni curriculum',
    );

void main() {
  group('XP levels', () {
    test('level 1 at 0 XP, level 2 at 100 XP', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(99), 1);
      expect(levelForXp(100), 2);
      expect(xpForLevel(2), 100);
      expect(xpForLevel(3), 250); // 100 + 150
      expect(xpForLevel(4), 450); // + 200
    });

    test('progress inside a level', () {
      final (into, needed) = xpProgressInLevel(120);
      expect(into, 20);
      expect(needed, 150);
    });
  });

  group('badges', () {
    BadgeProgress progressWith({
      required double physicsMastery,
      required int physicsCorrect,
    }) =>
        BadgeProgress(
          totalXp: 0,
          level: 1,
          masteryBySubject: {'physics': physicsMastery},
          correctBySubject: {'physics': physicsCorrect},
          gamesFinished: 1,
          bestStreak: 0,
          activeDays: 1,
        );

    test('physics badge needs >=80% AND >=10 correct', () {
      expect(
        unlockedBadges(progressWith(physicsMastery: 100, physicsCorrect: 9))
            .any((b) => b.id == 'physics_genius'),
        false,
      );
      expect(
        unlockedBadges(progressWith(physicsMastery: 80, physicsCorrect: 10))
            .any((b) => b.id == 'physics_genius'),
        true,
      );
      expect(
        unlockedBadges(progressWith(physicsMastery: 79, physicsCorrect: 50))
            .any((b) => b.id == 'physics_genius'),
        false,
      );
    });

    test('first-game badge unlocks after one game', () {
      const p = BadgeProgress(
        totalXp: 0,
        level: 1,
        masteryBySubject: {},
        correctBySubject: {},
        gamesFinished: 1,
        bestStreak: 0,
        activeDays: 1,
      );
      expect(unlockedBadges(p).any((b) => b.id == 'first_game'), true);
    });

    test('no badges with zero progress', () {
      const p = BadgeProgress(
        totalXp: 0,
        level: 1,
        masteryBySubject: {},
        correctBySubject: {},
        gamesFinished: 0,
        bestStreak: 0,
        activeDays: 0,
      );
      expect(unlockedBadges(p), isEmpty);
    });
  });

  group('daily reward', () {
    test('can claim once per local day, streak grows on consecutive days', () {
      final day1 = DateTime(2026, 11, 25);
      const state = DailyRewardState();
      expect(state.canClaimToday(now: day1), true);
      final (after1, xp1) = state.claim(now: day1);
      expect(xp1, 20);
      expect(after1.canClaimToday(now: day1), false);
      expect(after1.claim(now: day1).$2, 0); // second claim same day: 0
      final (after2, xp2) = after1.claim(now: DateTime(2026, 11, 26));
      expect(xp2, 25); // consecutive day: 20 + 5
      expect(after2.streakDays, 2);
    });

    test('skipping a day resets the streak, reward capped at 50', () {
      final (s, _) =
          const DailyRewardState().claim(now: DateTime(2026, 11, 25));
      final (s2, xp) = s.claim(now: DateTime(2026, 11, 28));
      expect(s2.streakDays, 1);
      expect(xp, 20);
    });
  });

  group('exam gating', () {
    test('empty bank refuses to start', () {
      expect(
        () => ExamSession.start(subject: 'physics', units: [], bank: []),
        throwsStateError,
      );
    });

    test('demo bank starts as a demo exam, never labelled real', () {
      final session = ExamSession.start(
        subject: 'physics',
        units: [],
        bank: [demoQ('q1', 'physics'), demoQ('q2', 'physics')],
      );
      expect(session.isDemoExam, true);
      expect(session.examLabel, 'محاكاة تجريبية');
    });

    test('auto-grading counts correct / wrong / unanswered', () {
      final session = ExamSession.start(
        subject: 'physics',
        units: [],
        bank: [demoQ('q1', 'physics'), demoQ('q2', 'physics')],
      );
      session.answerCurrent('أ'); // correct
      session.next();
      session.answerCurrent('ب'); // wrong
      final result = session.submit();
      expect(result.correct, 1);
      expect(result.wrong, 1);
      expect(result.unanswered, 0);
      expect(result.accuracyPercent, 50);
      expect(result.isDemoExam, true);
    });

    test('mark-for-review toggles and survives navigation', () {
      final session = ExamSession.start(
        subject: 'physics',
        units: [],
        bank: [demoQ('q1', 'physics'), demoQ('q2', 'physics')],
      );
      session.toggleMarkForReview();
      expect(session.isMarked(0), true);
      session.next();
      session.previous();
      expect(session.isMarked(0), true);
    });

    test('timer expiry is detected', () {
      final session = ExamSession.start(
        subject: 'physics',
        units: [],
        bank: [demoQ('q1', 'physics')],
        totalSeconds: 2,
      );
      expect(session.tick(), false);
      expect(session.tick(), true);
      expect(session.isTimeUp, true);
    });
  });

  group('attempts from result', () {
    test('readiness indicator is null below 5 attempts', () {
      final summary = AnalyticsEngine.summarize(const []);
      expect(summary.readinessIndicator, isNull);
    });
  });
}
