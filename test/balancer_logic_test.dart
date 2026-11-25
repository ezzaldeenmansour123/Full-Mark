// ABQARIYA tests — balancer / gating logic: stars + XP rules,
// exam gating, analytics readiness.
// NOTE: NOT RUN HERE. No Flutter/Dart SDK is available in this
// environment, so these tests were written carefully but never executed.
// Run with: flutter test
//
// 2026-11-25 (v0.1.2 data layer): the dead `lib/achievements/`
// system was deleted — its XP-level curve (level 2 at 100 XP, level 3
// at 250, level 4 at 450, ...) conflicted with the canonical curve in
// `lib/core/progress_store.dart` (flat 500 XP per level, already locked
// by test/smoke_test.dart), and its badges / daily reward had no live
// caller (the achievements screen uses its own kAchievementDefs +
// DatabaseHelper.getUnlockedAchievementIds()). The XP assertions below
// now test the canonical per-game rules in
// `lib/models/game_result.dart` (starsForAccuracy / xpFor) instead.

import 'package:flutter_test/flutter_test.dart';

import 'package:abqariya/analytics/analytics_engine.dart';
import 'package:abqariya/exam/ministerial_exam.dart';
import 'package:abqariya/models/game_result.dart';
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

GameResult demoResult({
  required int totalQuestions,
  required int correct,
  int streakBonus = 0,
}) =>
    GameResult(
      modeId: 'quiz',
      subject: 'physics',
      totalQuestions: totalQuestions,
      correct: correct,
      wrong: totalQuestions - correct,
      skipped: 0,
      bestStreak: correct,
      streakBonus: streakBonus,
      elapsedSeconds: 60,
      perQuestionCorrect: List<bool>.filled(totalQuestions, true),
      wrongQuestionIds: const <String>[],
    );

void main() {
  group('stars (canonical: game_result.dart)', () {
    test('star thresholds: 90/70/50', () {
      expect(starsForAccuracy(100), 3);
      expect(starsForAccuracy(90), 3);
      expect(starsForAccuracy(89.9), 2);
      expect(starsForAccuracy(70), 2);
      expect(starsForAccuracy(69.9), 1);
      expect(starsForAccuracy(50), 1);
      expect(starsForAccuracy(49.9), 0);
      expect(starsForAccuracy(0), 0);
    });

    test('GameResult derives stars / passed from accuracy', () {
      final passed = demoResult(totalQuestions: 10, correct: 9);
      expect(passed.accuracyPercent, 90);
      expect(passed.stars, 3);
      expect(passed.passed, true);
      expect(passed.needsRetry, false);

      final failed = demoResult(totalQuestions: 10, correct: 4);
      expect(failed.accuracyPercent, 40);
      expect(failed.stars, 0);
      expect(failed.passed, false);
      expect(failed.needsRetry, true);
    });
  });

  group('XP (canonical: game_result.dart)', () {
    test('xpFor: 10 per correct + 5 per streak bonus', () {
      expect(xpFor(correct: 5, streakBonus: 0), 50);
      expect(xpFor(correct: 5, streakBonus: 3), 65);
      expect(xpFor(correct: 0, streakBonus: 0), 0);
      expect(xpFor(correct: 10, streakBonus: 8), 140);
    });

    test('GameResult.xpEarned follows xpFor', () {
      final result =
          demoResult(totalQuestions: 10, correct: 7, streakBonus: 5);
      expect(result.xpEarned, 70 + 25);
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

    test('unanswered questions are not counted as wrong', () {
      final session = ExamSession.start(
        subject: 'physics',
        units: [],
        bank: [
          demoQ('q1', 'physics'),
          demoQ('q2', 'physics'),
          demoQ('q3', 'physics'),
        ],
      );
      session.answerCurrent('أ'); // correct
      session.next();
      session.answerCurrent('ب'); // wrong
      session.next();
      // q3 left unanswered
      final result = session.submit();
      expect(result.correct, 1);
      expect(result.wrong, 1);
      expect(result.unanswered, 1);
      expect(result.totalQuestions, 3);
    });

    test('mixed demo/real pool is a partial demo, never a full simulation', () {
      final realQ = Question(
        id: 'r1',
        subject: 'physics',
        unit: 'u1',
        lesson: 'l1',
        type: QuestionType.mcq,
        text: 'سؤال حقيقي؟',
        options: const ['أ', 'ب'],
        correctAnswer: 'أ',
        source: 'كتاب الفيزياء — طبعة صنعاء 2027',
        sourcePage: 12,
      );
      final session = ExamSession.start(
        subject: 'physics',
        units: [],
        bank: [demoQ('q1', 'physics'), realQ],
      );
      expect(session.isDemoExam, false);
      expect(session.isPartialDemoExam, true);
      expect(session.examLabel, 'محاكاة تجريبية (جزئياً)');
    });

    test('types filter keeps only answerable types in the exam', () {
      final fillQ = Question(
        id: 'f1',
        subject: 'physics',
        unit: 'u1',
        lesson: 'l1',
        type: QuestionType.fill,
        text: 'أكمل: ...؟',
        options: const [],
        correctAnswer: 'شيء',
        source: 'demo — not Yemeni curriculum',
      );
      final session = ExamSession.start(
        subject: 'physics',
        units: [],
        bank: [demoQ('q1', 'physics'), fillQ],
        types: const <QuestionType>[QuestionType.mcq],
      );
      expect(session.questions.length, 1);
      expect(session.poolSize, 1);
      expect(session.questions.first.id, 'q1');
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
