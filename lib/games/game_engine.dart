// ABQARIYA — GameEngine: pure game logic, no UI, no I/O, no network.
// Works with ANY list of [Question]s, including an EMPTY list (the screen
// then shows the honest «قيد الإعداد» empty state — the engine never
// invents questions). Seeded shuffling makes a game reproducible.
// Mirrored in Python in tools/verify_logic.py (scoring / stars / XP).

import '../models/game_result.dart';
import '../models/question.dart';

/// One answer event, recorded for analytics / review.
class AnswerRecord {
  final String questionId;
  final String givenAnswer;
  final bool correct;
  final int secondsTaken;
  final int streakAfter;

  const AnswerRecord({
    required this.questionId,
    required this.givenAnswer,
    required this.correct,
    required this.secondsTaken,
    required this.streakAfter,
  });
}

class GameEngine {
  final String modeId;
  final String subject;

  /// Questions in play order (already shuffled if [seed] was given).
  final List<Question> questions;

  /// Seconds allowed per question, 0 = no per-question limit.
  final int secondsPerQuestion;

  int _index = 0;
  int _correct = 0;
  int _wrong = 0;
  int _skipped = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _streakBonus = 0;
  int _elapsedSeconds = 0;
  bool _answeredCurrent = false;
  final List<bool> _perQuestionCorrect = [];
  final List<String> _wrongIds = [];
  final List<AnswerRecord> _history = [];

  GameEngine({
    required this.modeId,
    required this.subject,
    required List<Question> questions,
    this.secondsPerQuestion = 0,
    int? seed,
  }) : questions = List<Question>.unmodifiable(
          _shuffled(List<Question>.from(questions), seed),
        );

  static List<Question> _shuffled(List<Question> list, int? seed) {
    if (seed == null) return list;
    // Fisher-Yates with a seeded Random — same seed, same order.
    final random = _SeededRandom(seed);
    for (var i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }

  /// Convenience constructor used by screens: startGame(questions).
  factory GameEngine.startGame({
    required String modeId,
    required String subject,
    required List<Question> questions,
    int secondsPerQuestion = 0,
    int? seed,
  }) =>
      GameEngine(
        modeId: modeId,
        subject: subject,
        questions: questions,
        secondsPerQuestion: secondsPerQuestion,
        seed: seed,
      );

  bool get isEmpty => questions.isEmpty;
  bool get isFinished => _index >= questions.length;
  int get currentIndex => _index;
  int get totalQuestions => questions.length;
  int get correct => _correct;
  int get wrong => _wrong;
  int get skipped => _skipped;
  int get streak => _streak;
  int get bestStreak => _bestStreak;
  int get streakBonus => _streakBonus;
  int get elapsedSeconds => _elapsedSeconds;
  int get xpSoFar => xpFor(correct: _correct, streakBonus: _streakBonus);
  List<AnswerRecord> get history => List.unmodifiable(_history);

  Question? get currentQuestion =>
      isFinished ? null : questions[_index];

  /// 0.0 - 1.0 progress through the game.
  double get progress =>
      totalQuestions == 0 ? 0 : _index / totalQuestions;

  /// Whether the current question already has an answer (feedback showing).
  bool get answeredCurrent => _answeredCurrent;

  /// Answer the current question. Returns true when correct.
  /// [secondsTaken] is the time spent on this question; it accumulates
  /// into [elapsedSeconds]. A second call for the same question is
  /// ignored (returns the recorded correctness) so double-taps cannot
  /// inflate the score.
  bool answer(String givenAnswer, {int secondsTaken = 0}) {
    final q = currentQuestion;
    if (q == null || _answeredCurrent) {
      return _history.isEmpty ? false : _history.last.correct;
    }
    final normalizedGiven = givenAnswer.trim();
    final correct = _isCorrect(q, normalizedGiven);
    _answeredCurrent = true;
    _elapsedSeconds += secondsTaken < 0 ? 0 : secondsTaken;
    if (correct) {
      _correct++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      // Bonus: 3rd and later consecutive correct answers earn +5 XP.
      if (_streak >= 3) _streakBonus++;
    } else {
      _wrong++;
      _streak = 0;
      _wrongIds.add(q.id);
    }
    _perQuestionCorrect.add(correct);
    _history.add(AnswerRecord(
      questionId: q.id,
      givenAnswer: normalizedGiven,
      correct: correct,
      secondsTaken: secondsTaken < 0 ? 0 : secondsTaken,
      streakAfter: _streak,
    ));
    return correct;
  }

  /// Skip the current question (counts as neither correct nor wrong,
  /// but breaks the streak). Moves to the next question.
  void skipCurrent({int secondsTaken = 0}) {
    if (currentQuestion == null || _answeredCurrent) return;
    _skipped++;
    _streak = 0;
    _elapsedSeconds += secondsTaken < 0 ? 0 : secondsTaken;
    _perQuestionCorrect.add(false);
    _history.add(AnswerRecord(
      questionId: currentQuestion!.id,
      givenAnswer: '',
      correct: false,
      secondsTaken: secondsTaken < 0 ? 0 : secondsTaken,
      streakAfter: 0,
    ));
    _index++;
  }

  /// Advance after feedback has been shown. No-op if not yet answered.
  void next() {
    if (!_answeredCurrent) return;
    _answeredCurrent = false;
    _index++;
  }

  /// True when the per-question timer has run out for this question.
  /// The screen owns the actual countdown; this is the rule it checks.
  bool isTimeUp(int secondsSpentOnQuestion) =>
      secondsPerQuestion > 0 && secondsSpentOnQuestion >= secondsPerQuestion;

  GameResult finish() => GameResult(
        modeId: modeId,
        subject: subject,
        totalQuestions: totalQuestions,
        correct: _correct,
        wrong: _wrong,
        skipped: _skipped,
        bestStreak: _bestStreak,
        streakBonus: _streakBonus,
        elapsedSeconds: _elapsedSeconds,
        perQuestionCorrect: List.unmodifiable(_perQuestionCorrect),
        wrongQuestionIds: List.unmodifiable(_wrongIds),
      );

  static bool _isCorrect(Question q, String given) {
    switch (q.type) {
      case QuestionType.mcq:
      case QuestionType.trueFalse:
        return given == q.correctAnswer.trim();
      case QuestionType.fill:
        // Case/whitespace-insensitive comparison for fill-in answers.
        return given.toLowerCase() == q.correctAnswer.trim().toLowerCase();
      case QuestionType.ordering:
        // Given answer is the player's order joined with " | ".
        return given == q.correctAnswer.trim();
      case QuestionType.match:
        return given == q.correctAnswer.trim();
    }
  }
}

/// Minimal seeded PRNG (xorshift32) so shuffling does not depend on
/// dart:math's Random seed behaviour across platforms.
class _SeededRandom {
  int _state;
  _SeededRandom(int seed) : _state = seed == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  int nextInt(int max) {
    // xorshift32
    _state ^= (_state << 13) & 0xFFFFFFFF;
    _state ^= _state >> 17;
    _state ^= (_state << 5) & 0xFFFFFFFF;
    _state &= 0xFFFFFFFF;
    return _state % max;
  }
}
