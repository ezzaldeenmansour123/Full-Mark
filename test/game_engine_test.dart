// FULL MARK tests — game engine, scoring, stars, XP, gating.
// NOTE: NOT RUN HERE. No Flutter/Dart SDK is available in this
// environment, so these tests were written carefully but never executed.
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';

import 'package:abqariya/games/game_engine.dart';
import 'package:abqariya/games/game_modes.dart';
import 'package:abqariya/models/game_result.dart';
import 'package:abqariya/models/question.dart';

Question demoQuestion(String id, {String correct = 'ب'}) => Question(
      id: id,
      subject: 'physics',
      unit: 'الوحدة 1',
      lesson: 'الدرس 1',
      type: QuestionType.mcq,
      text: 'سؤال تجريبي $id؟',
      options: const ['أ', 'ب', 'ج'],
      correctAnswer: correct,
      difficulty: 2,
      source: 'demo — not Yemeni curriculum',
    );

void main() {
  group('stars', () {
    test('>=90% is 3 stars', () => expect(starsForAccuracy(90), 3));
    test('89% is 2 stars', () => expect(starsForAccuracy(89.9), 2));
    test('>=70% is 2 stars', () => expect(starsForAccuracy(70), 2));
    test('>=50% is 1 star', () => expect(starsForAccuracy(50), 1));
    test('49% is 0 stars + retry', () {
      expect(starsForAccuracy(49.9), 0);
      expect(starsForAccuracy(0), 0);
    });
  });

  group('XP formula', () {
    test('10 per correct, no bonus without a streak', () {
      expect(xpFor(correct: 5, streakBonus: 0), 50);
    });
    test('streak bonus adds 5 each', () {
      expect(xpFor(correct: 5, streakBonus: 3), 65);
    });
    test('zero correct is zero XP', () {
      expect(xpFor(correct: 0, streakBonus: 0), 0);
    });
  });

  group('GameEngine', () {
    test('empty bank: engine is empty and finishes with 0', () {
      final engine = GameEngine.startGame(
        modeId: 'quiz',
        subject: 'physics',
        questions: const [],
      );
      expect(engine.isEmpty, true);
      expect(engine.isFinished, true);
      final result = engine.finish();
      expect(result.totalQuestions, 0);
      expect(result.stars, 0);
      expect(result.xpEarned, 0);
    });

    test('correct answer scores, streak bonus starts at 3rd in a row', () {
      final engine = GameEngine.startGame(
        modeId: 'quiz',
        subject: 'physics',
        questions: [
          demoQuestion('q1'),
          demoQuestion('q2'),
          demoQuestion('q3'),
          demoQuestion('q4'),
        ],
      );
      expect(engine.answer('ب'), true);
      engine.next();
      expect(engine.answer('ب'), true);
      engine.next();
      expect(engine.answer('ب'), true); // streak 3 -> +1 bonus
      engine.next();
      expect(engine.answer('ب'), true); // streak 4 -> +1 bonus
      final result = engine.finish();
      expect(result.correct, 4);
      expect(result.streakBonus, 2);
      expect(result.xpEarned, 10 * 4 + 5 * 2);
      expect(result.stars, 3);
      expect(result.bestStreak, 4);
    });

    test('wrong answer breaks the streak', () {
      final engine = GameEngine.startGame(
        modeId: 'quiz',
        subject: 'physics',
        questions: [demoQuestion('q1'), demoQuestion('q2'), demoQuestion('q3')],
      );
      engine.answer('ب');
      engine.next();
      engine.answer('أ'); // wrong
      engine.next();
      engine.answer('ب');
      expect(engine.streak, 1);
      expect(engine.streakBonus, 0);
      expect(engine.finish().xpEarned, 20);
    });

    test('double answer on the same question is ignored', () {
      final engine = GameEngine.startGame(
        modeId: 'quiz',
        subject: 'physics',
        questions: [demoQuestion('q1')],
      );
      expect(engine.answer('ب'), true);
      expect(engine.answer('أ'), true); // ignored, still correct
      expect(engine.correct, 1);
    });

    test('seeded shuffle is reproducible', () {
      final qs = List.generate(10, (i) => demoQuestion('q$i'));
      final a = GameEngine.startGame(
          modeId: 'quiz', subject: 'physics', questions: qs, seed: 42);
      final b = GameEngine.startGame(
          modeId: 'quiz', subject: 'physics', questions: qs, seed: 42);
      expect(
        a.questions.map((q) => q.id).toList(),
        b.questions.map((q) => q.id).toList(),
      );
    });

    test('question without a source throws', () {
      expect(
        () => Question.fromJson(<String, dynamic>{
          'id': 'x',
          'subject': 'physics',
          'type': 'mcq',
          'text': '؟',
          'options': ['أ', 'ب'],
          'correctAnswer': 'أ',
          'source': '',
        }),
        throwsFormatException,
      );
    });

    test('demo question is flagged demo', () {
      expect(demoQuestion('q1').isDemo, true);
      expect(demoQuestion('q1').isCurriculum, false);
    });
  });

  group('game modes gating', () {
    test('exactly 8 modes are playable', () {
      final playable =
          kGameModes.where((m) => m.isPlayable).map((m) => m.routeId).toList();
      expect(playable.length, 8);
      expect(playable, containsAll(<String>[
        'quiz',
        'true_false',
        'time_race',
        'memory_match',
        'boss_20',
        'complete_equation',
        'concept_match',
        'unlock',
      ]));
    });

    test('other 4 modes are defined but not playable', () {
      expect(kGameModes.length, 12);
      expect(kGameModes.where((m) => !m.isPlayable).length, 4);
    });
  });
}
