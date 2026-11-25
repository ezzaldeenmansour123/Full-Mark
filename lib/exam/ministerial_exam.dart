// ABQARIYA — MinisterialExam: exam session logic (pure, no UI).
// A timed session with navigation, mark-for-review, submit, auto-grading
// and per-question review.
// HONESTY: demo questions must NEVER be labelled real ministerial
// questions. If every question is demo, [isDemoExam] is true and the
// screen must show "محاكاة تجريبية". If the bank is empty, the session
// cannot start ([ExamStartError.emptyBank]).

import '../models/question.dart';

enum ExamStartError { emptyBank, noMatchingQuestions }

class ExamSession {
  final String subject;
  final List<String> units;
  final List<Question> questions;
  final int totalSeconds;

  /// True when all questions are demo — the UI must label the exam
  /// "محاكاة تجريبية" and never call it a real ministerial exam.
  final bool isDemoExam;

  /// True when SOME (not all) questions are demo — the exam is a
  /// partial simulation and must be labelled "محاكاة تجريبية (جزئياً)".
  /// (Before, a mixed pool was labelled a full ministerial simulation.)
  final bool isPartialDemoExam;

  /// Size of the matching pool BEFORE the 20-question cap, so the UI
  /// can say honestly when every sitting reuses the same questions.
  final int poolSize;

  int _index = 0;
  final Map<int, String> _answers = {};
  final Set<int> _markedForReview = {};
  int _secondsUsed = 0;
  bool _submitted = false;
  DateTime? _startedAt;

  ExamSession._({
    required this.subject,
    required this.units,
    required this.questions,
    required this.totalSeconds,
    required this.isDemoExam,
    required this.isPartialDemoExam,
    required this.poolSize,
  });

  /// Start a session. Throws [ExamStartError] (as a StateError carrying
  /// the enum name) when there is nothing to examine on.
  /// [bank] is the full question bank; it is filtered by subject/units
  /// and by [types] when given. [seed] shuffles reproducibly.
  factory ExamSession.start({
    required String subject,
    required List<String> units,
    required List<Question> bank,
    int totalSeconds = 3600,
    List<QuestionType>? types,
    int? seed,
    int maxQuestions = 20,
  }) {
    var pool = bank.where((q) => q.subject == subject).toList();
    if (units.isNotEmpty) {
      pool = pool.where((q) => units.contains(q.unit)).toList();
    }
    if (types != null && types.isNotEmpty) {
      pool = pool.where((q) => types.contains(q.type)).toList();
    }
    if (bank.isEmpty) {
      throw StateError('ExamStartError.emptyBank');
    }
    if (pool.isEmpty) {
      throw StateError('ExamStartError.noMatchingQuestions');
    }
    if (seed != null) {
      final random = _SeededRandom(seed);
      for (var i = pool.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final tmp = pool[i];
        pool[i] = pool[j];
        pool[j] = tmp;
      }
    }
    final int fullPoolSize = pool.length;
    if (pool.length > maxQuestions) pool = pool.sublist(0, maxQuestions);
    return ExamSession._(
      subject: subject,
      units: List.unmodifiable(units),
      questions: List.unmodifiable(pool),
      totalSeconds: totalSeconds,
      isDemoExam: pool.every((q) => q.isDemo),
      isPartialDemoExam:
          pool.any((q) => q.isDemo) && !pool.every((q) => q.isDemo),
      poolSize: fullPoolSize,
    ).._startedAt = DateTime.now();
  }

  bool get isEmpty => questions.isEmpty;
  bool get isSubmitted => _submitted;
  int get currentIndex => _index;
  int get totalQuestions => questions.length;
  int get secondsUsed => _secondsUsed;
  int get secondsRemaining =>
      (totalSeconds - _secondsUsed).clamp(0, totalSeconds);
  bool get isTimeUp => totalSeconds > 0 && _secondsUsed >= totalSeconds;
  DateTime? get startedAt => _startedAt;

  Question get currentQuestion => questions[_index];
  String? answerFor(int index) => _answers[index];
  bool isMarked(int index) => _markedForReview.contains(index);
  int get answeredCount => _answers.length;
  int get markedCount => _markedForReview.length;
  int get unansweredCount => totalQuestions - answeredCount;

  /// Record / replace the answer for the current question.
  void answerCurrent(String answer) {
    if (_submitted) return;
    _answers[_index] = answer;
  }

  void goTo(int index) {
    if (index < 0 || index >= questions.length) return;
    _index = index;
  }

  void next() => goTo(_index + 1);
  void previous() => goTo(_index - 1);

  void toggleMarkForReview([int? index]) {
    final i = index ?? _index;
    if (_markedForReview.contains(i)) {
      _markedForReview.remove(i);
    } else {
      _markedForReview.add(i);
    }
  }

  /// Advance the clock (the screen's timer calls this once per second).
  /// Returns true when time has just run out.
  bool tick([int seconds = 1]) {
    if (_submitted) return isTimeUp;
    _secondsUsed += seconds;
    return isTimeUp;
  }

  /// Submit and auto-grade. After this, answers are frozen.
  ExamResult submit() {
    _submitted = true;
    var correct = 0;
    final perQuestion = <ExamQuestionReview>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final given = _answers[i];
      final isCorrect = given != null && given.trim() == q.correctAnswer.trim();
      if (isCorrect) correct++;
      perQuestion.add(ExamQuestionReview(
        index: i,
        question: q,
        givenAnswer: given,
        correct: isCorrect,
        wasMarked: _markedForReview.contains(i),
      ));
    }
    return ExamResult(
      subject: subject,
      totalQuestions: questions.length,
      correct: correct,
      // `wrong` counts answered-but-wrong only; unanswered questions
      // are reported separately (before, they were double-counted
      // inside `wrong`).
      wrong: questions.length - correct - unansweredCount,
      unanswered: unansweredCount,
      secondsUsed: _secondsUsed,
      perQuestion: perQuestion,
      isDemoExam: isDemoExam,
      isPartialDemoExam: isPartialDemoExam,
    );
  }

  /// Human-readable label for the exam type — never claims demo is real.
  String get examLabel => isDemoExam
      ? 'محاكاة تجريبية'
      : isPartialDemoExam
          ? 'محاكاة تجريبية (جزئياً)'
          : 'محاكاة الامتحان الوزاري';
}

class ExamQuestionReview {
  final int index;
  final Question question;
  final String? givenAnswer;
  final bool correct;
  final bool wasMarked;

  const ExamQuestionReview({
    required this.index,
    required this.question,
    required this.givenAnswer,
    required this.correct,
    required this.wasMarked,
  });
}

class ExamResult {
  final String subject;
  final int totalQuestions;
  final int correct;
  final int wrong;
  final int unanswered;
  final int secondsUsed;
  final List<ExamQuestionReview> perQuestion;
  final bool isDemoExam;
  final bool isPartialDemoExam;

  const ExamResult({
    required this.subject,
    required this.totalQuestions,
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.secondsUsed,
    required this.perQuestion,
    required this.isDemoExam,
    this.isPartialDemoExam = false,
  });

  double get accuracyPercent =>
      totalQuestions == 0 ? 0 : correct * 100.0 / totalQuestions;

  String get gradeLabel {
    final p = accuracyPercent;
    if (p >= 90) return 'ممتاز';
    if (p >= 80) return 'جيد جداً';
    if (p >= 70) return 'جيد';
    if (p >= 50) return 'مقبول';
    return 'يحتاج مراجعة';
  }

  /// Per-unit breakdown: unit -> (correct, total). Units come from the
  /// questions themselves; unknown unit is grouped as "".
  Map<String, (int, int)> get breakdownByUnit {
    final map = <String, (int, int)>{};
    for (final r in perQuestion) {
      final unit = r.question.unit;
      final prev = map[unit] ?? (0, 0);
      map[unit] = (prev.$1 + (r.correct ? 1 : 0), prev.$2 + 1);
    }
    return map;
  }
}

class _SeededRandom {
  int _state;
  _SeededRandom(int seed) : _state = seed == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;
  int nextInt(int max) {
    _state ^= (_state << 13) & 0xFFFFFFFF;
    _state ^= _state >> 17;
    _state ^= (_state << 5) & 0xFFFFFFFF;
    _state &= 0xFFFFFFFF;
    return _state % max;
  }
}
