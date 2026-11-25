// FULL MARK — GameScreen: real playable Flutter screen.
// Playable for real: quiz, true_false, time_race, memory_match,
// boss_20, concept_match, unlock. complete_equation has its own
// screen (EquationGameScreen) — it plays equations, not Question
// rows. The 4 non-playable modes (lab / aim / smart_memory /
// ministerial_exam) are refused here with an honest screen instead
// of silently playing a mislabelled quiz (v0.1.4 follow-up); the
// mode picker only offers playable modes, and ministerial_exam
// links to ExamScreen. Unknown route ids get an honest screen too.
// Empty bank: honest message, never invented questions. Demo questions
// (is_demo rows) show a visible «تجريبي» badge — real curriculum
// questions never do. Offline only. No network, no accounts, no ads.
// Route: GameScreen(modeRouteId: 'quiz', subject: 'physics', questions: [...])
// The caller passes the question list (from JSON/DB); this screen never
// invents questions. [onFinished] is awaited before the result screen
// appears, so the caller's recordGameResult save always lands first.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/routes.dart';
import '../db/database.dart';
import '../models/game_result.dart';
import '../models/question.dart';
import 'game_engine.dart';
import 'game_modes.dart';

class GameScreen extends StatefulWidget {
  /// Route id from GameModeConfig, e.g. 'quiz', 'time_race', 'boss_20'.
  final String modeRouteId;
  final String subject;
  final String subjectTitleAr;

  /// Questions supplied by the caller (JSON/DB). May be empty.
  final List<Question> questions;

  /// Lesson id (e.g. 'physics-u1-l2') for "continue where you left off".
  /// When set, the lesson is saved as the last stage on game start and
  /// again on finish.
  final String? lessonId;

  /// Stage id for progress records; defaults to [lessonId].
  final String? stageId;

  /// Called with the finished result (for saving XP / analytics locally).
  /// Awaited by this screen before the result summary is shown.
  /// Required (not optional): displayed stars/XP must never be unsaved
  /// because a caller forgot the callback.
  final Future<void> Function(GameResult result) onFinished;

  const GameScreen({
    super.key,
    required this.modeRouteId,
    required this.subject,
    required this.subjectTitleAr,
    required this.questions,
    this.lessonId,
    this.stageId,
    required this.onFinished,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameModeConfig _mode;
  late final GameEngine _engine;

  /// Questions whose type this mode cannot play (e.g. `match`). They
  /// are excluded at load time and reported honestly — never silently
  /// dropped, never offered as a broken game.
  late final List<Question> _excludedQuestions;
  Timer? _timer;
  int _secondsLeft = 0;
  int _secondsOnQuestion = 0;
  String? _selectedAnswer;
  bool _showFeedback = false;
  bool _lastCorrect = false;
  bool _timedOut = false;
  GameResult? _result;
  bool _finishing = false;

  // --- unlock mode state ---
  // Every 3 consecutive correct answers opens one lock (4 locks per
  // round). A wrong answer resets the streak but never closes a lock
  // that is already open.
  static const int kUnlockLocks = 4;
  int _unlockStreak = 0;
  int _locksOpened = 0;

  // --- pause state (timed question modes only) ---
  bool _paused = false;

  // --- fill / ordering state ---
  // Ordering picks are INDICES into the question's options, not values:
  // a repeated option value used to make the round unfinishable (picking
  // it once removed both copies from the choices).
  final TextEditingController _fillController = TextEditingController();
  final List<int> _pickedOrdering = <int>[];

  // --- memory_match state ---
  List<_MemoryCard> _cards = [];
  int? _firstFlippedIndex;
  bool _memoryLock = false;
  int _memoryMatches = 0;
  int _memoryTries = 0;
  // Ids of questions whose pair was matched on the FIRST try (no prior
  // failed flip of that pair). This is the honest per-question record:
  // the result marks exactly these questions correct — never "first N".
  final Set<String> _memoryFirstTryKeys = {};
  final Set<String> _memoryFailedKeys = {};
  int _memoryStreak = 0;
  int _memoryBestStreak = 0;
  DateTime? _memoryStartedAt;
  Timer? _memoryTimer;
  // Outcome of each completed pair, in completion order (true = first
  // try): feeds the streak bonus exactly like the engine does.
  final List<bool> _memoryOutcomeSequence = <bool>[];

  // --- concept_match state ---
  // Rounds of at most 5 pairs; no round contains two questions with
  // the same correct answer (otherwise one answer tile would match two
  // stems and the board would be ambiguous). Correctness is per
  // question, first-try only — exactly like memory_match.
  late final List<List<Question>> _conceptRounds;
  int _conceptRoundIndex = 0;
  late List<String> _conceptAnswers;
  String? _conceptSelectedStemId;
  final Set<String> _conceptMatchedRoundIds = <String>{};
  final Set<String> _conceptFailedIds = <String>{};
  final Map<String, bool> _conceptCorrectById = <String, bool>{};
  final List<bool> _conceptOutcomeSequence = <bool>[];
  String? _conceptMessage;
  DateTime? _conceptStartedAt;

  @override
  void initState() {
    super.initState();
    _mode = modeConfigByRouteId(widget.modeRouteId);
    final allowed = questionTypesForMode(_mode.id);
    final List<Question> usableAll = widget.questions
        .where((q) => allowed.contains(q.type))
        .toList()
      ..shuffle();
    // Enforce the mode's questionCount (the config was dead before:
    // every mode played the whole lesson). The result only covers
    // these questions, and recordGameResult filters by played ids
    // (GameResult.playedQuestionIds), so unplayed questions are never
    // recorded as correct attempts.
    final List<Question> usable =
        usableAll.length <= _mode.questionCount
            ? usableAll
            : usableAll.sublist(0, _mode.questionCount);
    _excludedQuestions = widget.questions
        .where((q) => !allowed.contains(q.type))
        .toList();
    _engine = GameEngine.startGame(
      modeId: _mode.routeId,
      subject: widget.subject,
      questions: usable,
      secondsPerQuestion: _mode.secondsPerQuestion,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    if (_mode.id == GameModeId.memoryMatch) {
      _buildMemoryCards();
      _memoryStartedAt = DateTime.now();
      // Overall limit from the config (was fiction: no timer existed).
      // On expiry the game finishes with the pairs matched so far.
      if (_mode.totalSeconds > 0) {
        _memoryTimer = Timer(
          Duration(seconds: _mode.totalSeconds),
          () {
            if (mounted && _result == null) _finishMemoryGame();
          },
        );
      }
    }
    if (_mode.id == GameModeId.conceptMatch) {
      _conceptRounds = _buildConceptRounds(_engine.questions);
      _conceptStartedAt = DateTime.now();
      // Empty rounds (no usable MCQ) used to crash here with a
      // RangeError before build()'s empty state could show.
      _conceptAnswers =
          _conceptRounds.isEmpty ? <String>[] : _answersForRound(0);
    }
    // Game start: remember this lesson as the last stage (the caller
    // also saves it before pushing; this covers direct launches).
    final String? lessonId = widget.lessonId;
    if (lessonId != null) {
      unawaited(DatabaseHelper.instance.setLastStage(
        lessonId,
        widget.subjectTitleAr,
      ));
    }
    _startQuestionTimer();
  }

  void _buildMemoryCards() {
    final cards = <_MemoryCard>[];
    for (final q in _engine.questions) {
      // Pair = question text <-> correct answer. Only mcq questions
      // reach here (filtered in initState).
      cards.add(_MemoryCard(key: q.id, label: q.text, isQuestion: true));
      cards.add(_MemoryCard(key: q.id, label: q.correctAnswer, isQuestion: false));
    }
    cards.shuffle();
    _cards = cards;
  }

  /// Split questions into rounds of at most 5, guaranteeing that no
  /// round contains two questions with the same correct answer
  /// (otherwise one answer tile would match two stems). Every question
  /// lands in exactly one round — nothing is dropped.
  static List<List<Question>> _buildConceptRounds(
    List<Question> questions,
  ) {
    final List<List<Question>> rounds = <List<Question>>[];
    for (final Question q in questions) {
      List<Question>? target;
      for (final List<Question> round in rounds) {
        if (round.length < 5 &&
            !round.any((Question o) => o.correctAnswer == q.correctAnswer)) {
          target = round;
          break;
        }
      }
      target ??= <Question>[];
      if (!rounds.contains(target)) rounds.add(target);
      target.add(q);
    }
    return rounds;
  }

  List<String> _answersForRound(int roundIndex) {
    final List<String> answers = _conceptRounds[roundIndex]
        .map((Question q) => q.correctAnswer)
        .toList(growable: false)
      ..shuffle();
    return answers;
  }

  void _onConceptStemTap(String questionId) {
    if (_result != null || _conceptMatchedRoundIds.contains(questionId)) {
      return;
    }
    setState(() {
      _conceptSelectedStemId = questionId;
      _conceptMessage = null;
    });
  }

  Future<void> _onConceptAnswerTap(String answer) async {
    if (_result != null) return;
    final String? stemId = _conceptSelectedStemId;
    if (stemId == null) {
      setState(() => _conceptMessage = 'اختاري سؤالاً أولاً، ثم إجابته.');
      return;
    }
    final List<Question> round = _conceptRounds[_conceptRoundIndex];
    final Question stem =
        round.firstWhere((Question q) => q.id == stemId);
    if (stem.correctAnswer == answer) {
      final bool firstTry = !_conceptFailedIds.contains(stemId);
      setState(() {
        _conceptMatchedRoundIds.add(stemId);
        _conceptCorrectById[stemId] = firstTry;
        _conceptOutcomeSequence.add(firstTry);
        _conceptSelectedStemId = null;
        _conceptMessage = firstTry
            ? 'تطابق صحيح ✓'
            : 'تطابق صحيح، لكن بعد محاولة خاطئة — يُحسب خطأً في النتيجة.';
      });
      if (_conceptMatchedRoundIds.length >= round.length) {
        // Let the player see the final green pair before moving on.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        if (_conceptRoundIndex + 1 < _conceptRounds.length) {
          setState(() {
            _conceptRoundIndex++;
            _conceptMatchedRoundIds.clear();
            _conceptAnswers = _answersForRound(_conceptRoundIndex);
            _conceptMessage = null;
          });
        } else {
          await _finishConceptGame();
        }
      }
    } else {
      setState(() {
        _conceptFailedIds.add(stemId);
        _conceptSelectedStemId = null;
        _conceptMessage =
            'هذه الإجابة لا تطابق السؤال المحدد — جرّبي إجابة أخرى.';
      });
    }
  }

  Future<void> _finishConceptGame() async {
    final List<Question> questions = _engine.questions;
    final List<bool> perQuestionCorrect = questions
        .map((Question q) => _conceptCorrectById[q.id] ?? false)
        .toList(growable: false);
    final List<String> wrongIds = questions
        .where((Question q) => !(_conceptCorrectById[q.id] ?? false))
        .map((Question q) => q.id)
        .toList(growable: false);
    final int correct = perQuestionCorrect.where((bool v) => v).length;
    final int elapsed = _conceptStartedAt == null
        ? 0
        : DateTime.now().difference(_conceptStartedAt!).inSeconds;
    var streak = 0;
    var bestStreak = 0;
    var streakBonus = 0;
    for (final bool v in _conceptOutcomeSequence) {
      if (v) {
        streak++;
        if (streak > bestStreak) bestStreak = streak;
        if (streak >= 3) streakBonus++;
      } else {
        streak = 0;
      }
    }
    await _finishGame(GameResult(
      modeId: _mode.routeId,
      subject: widget.subject,
      totalQuestions: questions.length,
      correct: correct,
      wrong: questions.length - correct,
      skipped: 0,
      bestStreak: bestStreak,
      streakBonus: streakBonus,
      playedQuestionIds:
          questions.map((Question q) => q.id).toList(growable: false),
      elapsedSeconds: elapsed,
      perQuestionCorrect: perQuestionCorrect,
      wrongQuestionIds: wrongIds,
    ));
  }

  void _startQuestionTimer() {
    _secondsOnQuestion = 0;
    _secondsLeft = _mode.secondsPerQuestion;
    _resumeTimer();
  }

  /// (Re)start the per-question countdown from the CURRENT
  /// [_secondsLeft] — used by pause/resume so resuming never refills
  /// the question's time.
  void _resumeTimer() {
    _timer?.cancel();
    if (_secondsLeft <= 0 || _paused) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _result != null || _showFeedback || _paused) return;
      setState(() {
        _secondsLeft--;
        _secondsOnQuestion++;
      });
      if (_secondsLeft <= 0) {
        // Time up: record a wrong answer, then STOP on the feedback
        // panel (correct answer + explanation) until the player taps
        // "التالي" — never auto-advance past feedback.
        _timer?.cancel();
        _engine.answer('', secondsTaken: _secondsOnQuestion);
        _updateUnlock(false);
        setState(() {
          _selectedAnswer = null;
          _showFeedback = true;
          _lastCorrect = false;
          _timedOut = true;
        });
      }
    });
  }

  /// Pause / resume the per-question timer (timed modes only). The
  /// exam screen deliberately has no pause: it simulates a real
  /// timed exam. While paused the question is hidden behind an
  /// overlay so the timer cannot be cheated by reading on.
  void _togglePause() {
    if (_mode.secondsPerQuestion <= 0 || _result != null) return;
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _timer?.cancel();
      } else {
        _resumeTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _memoryTimer?.cancel();
    _fillController.dispose();
    super.dispose();
  }

  void _choose(String answer) {
    if (_showFeedback || _engine.isFinished) return;
    final correct = _engine.answer(answer, secondsTaken: _secondsOnQuestion);
    _updateUnlock(correct);
    _timer?.cancel(); // stop the countdown while feedback is shown
    setState(() {
      _selectedAnswer = answer;
      _showFeedback = true;
      _lastCorrect = correct;
      _timedOut = false;
    });
  }

  void _chooseFill() {
    final answer = _fillController.text.trim();
    if (answer.isEmpty) return;
    _choose(answer);
  }

  void _chooseOrdering() {
    if (_pickedOrdering.isEmpty) return;
    final Question? q = _engine.currentQuestion;
    if (q == null) return;
    _choose(
      _pickedOrdering.map((int i) => q.options[i]).join(' | '),
    );
  }

  Future<void> _advanceOrFinish() async {
    _timer?.cancel();
    _engine.next();
    if (_engine.isFinished) {
      await _finishGame(_engine.finish());
    } else {
      setState(() {
        _selectedAnswer = null;
        _showFeedback = false;
        _timedOut = false;
        _fillController.clear();
        _pickedOrdering.clear();
      });
      _startQuestionTimer();
    }
  }

  void _updateUnlock(bool correct) {
    if (_mode.id != GameModeId.unlock) return;
    if (correct) {
      _unlockStreak++;
      if (_unlockStreak >= 3) {
        _unlockStreak = 0;
        if (_locksOpened < kUnlockLocks) _locksOpened++;
      }
    } else {
      _unlockStreak = 0;
    }
  }

  /// Shared finish path: save the last stage, await the caller's
  /// recordGameResult (via [onFinished]), then show the summary.
  Future<void> _finishGame(GameResult result) async {
    if (_finishing || _result != null) return;
    _finishing = true;
    final String? lessonId = widget.lessonId;
    if (lessonId != null) {
      await DatabaseHelper.instance.setLastStage(
        lessonId,
        widget.subjectTitleAr,
      );
    }
    await widget.onFinished(result);
    if (!mounted) return;
    setState(() => _result = result);
  }

  /// Streak bonus — delegates to the shared engine rule
  /// (GameResult.streakBonusFor) so the rule lives in one place.
  static int _streakBonusFor(List<bool> values) =>
      GameResult.streakBonusFor(values);

  /// Finish a memory_match game from the pairs matched so far — used
  /// both when the board is complete and when the overall timer
  /// (180 s) expires. Correctness is per-question: exactly the pairs
  /// matched on the first try are correct, the rest are wrong.
  /// No fabricated "first N correct", no automatic 100%.
  Future<void> _finishMemoryGame() async {
    if (_result != null || _finishing) return;
    _memoryTimer?.cancel();
    final List<Question> questions = _engine.questions;
    final List<bool> perQuestionCorrect = questions
        .map((Question q) => _memoryFirstTryKeys.contains(q.id))
        .toList(growable: false);
    final List<String> wrongIds = questions
        .where((Question q) => !_memoryFirstTryKeys.contains(q.id))
        .map((Question q) => q.id)
        .toList(growable: false);
    final int elapsed = _memoryStartedAt == null
        ? 0
        : DateTime.now().difference(_memoryStartedAt!).inSeconds;
    final GameResult result = GameResult(
      modeId: _mode.routeId,
      subject: widget.subject,
      totalQuestions: questions.length,
      correct: _memoryFirstTryKeys.length,
      wrong: questions.length - _memoryFirstTryKeys.length,
      skipped: 0,
      bestStreak: _memoryBestStreak,
      streakBonus: _streakBonusFor(_memoryOutcomeSequence),
      elapsedSeconds: elapsed,
      perQuestionCorrect: perQuestionCorrect,
      wrongQuestionIds: wrongIds,
      playedQuestionIds:
          questions.map((Question q) => q.id).toList(growable: false),
    );
    await _finishGame(result);
  }

  Future<void> _onMemoryTap(int index) async {
    if (_memoryLock || _result != null) return;
    final card = _cards[index];
    if (card.flipped || card.matched) return;
    setState(() => _cards[index] = card.copyWith(flipped: true));
    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
      return;
    }
    final first = _cards[_firstFlippedIndex!];
    _memoryTries++;
    if (first.key == card.key && first.isQuestion != card.isQuestion) {
      // Match!
      final firstTry = !_memoryFailedKeys.contains(card.key);
      setState(() {
        _cards[_firstFlippedIndex!] =
            first.copyWith(matched: true, flipped: true);
        _cards[index] = card.copyWith(matched: true, flipped: true);
        _memoryMatches++;
        if (firstTry) {
          _memoryFirstTryKeys.add(card.key);
          _memoryStreak++;
          if (_memoryStreak > _memoryBestStreak) {
            _memoryBestStreak = _memoryStreak;
          }
        } else {
          _memoryStreak = 0;
        }
        _memoryOutcomeSequence.add(firstTry);
        _firstFlippedIndex = null;
      });
      if (_memoryMatches * 2 >= _cards.length) {
        await _finishMemoryGame();
      }
    } else {
      _memoryLock = true;
      _memoryFailedKeys.add(first.key);
      _memoryFailedKeys.add(card.key);
      _memoryStreak = 0;
      final firstIndex = _firstFlippedIndex!;
      _firstFlippedIndex = null;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _cards[firstIndex] = _cards[firstIndex].copyWith(flipped: false);
          _cards[index] = _cards[index].copyWith(flipped: false);
          _memoryLock = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) Ministerial exam has its own screen — link there, never a
    // dead end. (The picker never sends this id here; this is a guard
    // for direct launches.)
    if (_mode.id == GameModeId.ministerialExam) {
      return Scaffold(
        appBar: AppBar(title: Text(_mode.titleAr)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _mode.descriptionAr,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.exam),
                  child: const Text('فتح محاكاة الامتحان الوزاري'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('رجوع'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 1b) Unknown route id: never silently play a quiz instead.
    if (!isKnownRouteId(widget.modeRouteId)) {
      return _guardScaffold(
        context,
        title: 'نمط غير معروف',
        message: 'النمط «${widget.modeRouteId}» غير موجود في هذه النسخة — '
            'ارجعي واختاري نمطاً من القائمة.',
      );
    }
    // 1c) A mode the registry marks unplayable (lab / aim /
    // smart_memory): never play it as a mislabelled quiz.
    if (!_mode.isPlayable) {
      return _guardScaffold(
        context,
        title: _mode.titleAr,
        message: 'نمط «${_mode.titleAr}» غير متاح للعب بعد. ${_mode.descriptionAr}',
      );
    }
    // 1d) complete_equation has its own screen (steppers, not a quiz).
    if (_mode.id == GameModeId.completeEquation) {
      return _guardScaffold(
        context,
        title: _mode.titleAr,
        message: 'نمط «أكمل المعادلة» له شاشة خاصة بالمعادلات — ارجعي '
            'إلى منتقي الدرس واختاريه من هناك.',
      );
    }
    // 2) Questions were supplied but none of them can be played in
    // this mode — say exactly why, naming the unsupported type(s).
    if (_engine.isEmpty && _excludedQuestions.isNotEmpty) {
      final types = _excludedQuestions
          .map((q) => questionTypeLabelAr(q.type))
          .toSet()
          .join('، ');
      return Scaffold(
        appBar: AppBar(title: Text(_mode.titleAr)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'أسئلة هذا الدرس من نوع «$types»، وهذا النوع غير مدعوم '
                  'في نمط «${_mode.titleAr}» بعد — جرّبي نمطاً آخر أو درساً آخر.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('رجوع'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 3) Empty bank — honest state.
    if (_engine.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_mode.titleAr)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'لا توجد أسئلة متاحة لهذا الدرس بعد.\n'
                  'ستظهر الأسئلة هنا فور إضافتها من الكتب المعتمدة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('رجوع'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 4) Finished — summary.
    if (_result != null) return _buildSummary(context, _result!);
    // 5) Memory-match board.
    if (_mode.id == GameModeId.memoryMatch) return _buildMemoryBoard(context);
    // 5b) Concept-match board (stems <-> answers, visible lists).
    if (_mode.id == GameModeId.conceptMatch) {
      return _buildConceptBoard(context);
    }
    // 6) Normal question flow (quiz / true_false / time_race / boss_20).
    return _buildQuestion(context);
  }

  /// Honest dead-end screen for modes this screen refuses to play
  /// (unknown id / unplayable / wrong screen) — always with a back
  /// button, never a silent quiz under the wrong title.
  Widget _guardScaffold(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('رجوع'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final q = _engine.currentQuestion!;
    final theme = Theme.of(context);
    if (_paused) {
      return Scaffold(
        appBar: AppBar(title: Text('${_mode.titleAr} — ${widget.subjectTitleAr}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.pause_circle_filled, size: 64),
                const SizedBox(height: 12),
                const Text(
                  'اللعبة متوقفة مؤقتاً — المؤقت متوقف ولن تخسري وقتاً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _togglePause,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('استئناف'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${_mode.titleAr} — ${widget.subjectTitleAr}'),
        actions: [
          if (_mode.secondsPerQuestion > 0)
            IconButton(
              icon: const Icon(Icons.pause),
              tooltip: 'إيقاف مؤقت',
              onPressed: _togglePause,
            ),
          if (q.isDemo)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Chip(label: Text('تجريبي')),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: _engine.progress),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('السؤال ${_engine.currentIndex + 1} من ${_engine.totalQuestions}'),
                if (_mode.secondsPerQuestion > 0)
                  Text('⏱ $_secondsLeft ث',
                      style: TextStyle(
                        color: _secondsLeft <= 5 ? Colors.red : null,
                        fontWeight: FontWeight.bold,
                      )),
                Text('🔥 سلسلة: ${_engine.streak}'),
              ],
            ),
            if (_mode.id == GameModeId.unlock) ...[
              const SizedBox(height: 12),
              _buildUnlockRow(),
            ],
            const SizedBox(height: 16),
            Text(q.text, style: theme.textTheme.titleLarge),
            if (q.isDemo)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('سؤال تجريبي — ليس من المنهج اليمني.',
                    style: TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 16),
            if (q.type == QuestionType.fill) _buildFillInput(q),
            if (q.type == QuestionType.ordering) _buildOrderingInput(q),
            if (q.type == QuestionType.mcq ||
                q.type == QuestionType.trueFalse)
              ...q.options.map((opt) {
                Color? color;
                if (_showFeedback) {
                  if (opt == q.correctAnswer) {
                    color = Colors.green;
                  } else if (opt == _selectedAnswer) {
                    color = Colors.red;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _showFeedback ? null : () => _choose(opt),
                    child: Text(opt, textAlign: TextAlign.center),
                  ),
                );
              }),
            if (_showFeedback) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastCorrect
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timedOut
                          ? 'انتهى الوقت ⏱ — لم تُسجَّل إجابة'
                          : _lastCorrect
                              ? 'إجابة صحيحة ✓'
                              : 'إجابة خاطئة ✗',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!_lastCorrect) ...[
                      const SizedBox(height: 4),
                      Text('الإجابة الصحيحة: ${q.correctAnswer}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    if (q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(q.explanation),
                    ],
                    Text('المصدر: ${q.source}'
                        '${q.sourcePage != null ? ' — ص ${q.sourcePage}' : ''}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _advanceOrFinish,
                child: Text(_engine.currentIndex + 1 >= _engine.totalQuestions
                    ? 'عرض النتيجة'
                    : 'التالي'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < kUnlockLocks; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              i < _locksOpened ? Icons.lock_open : Icons.lock,
              color: i < _locksOpened ? Colors.green : Colors.grey,
              size: 28,
            ),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'الأقفال: $_locksOpened / $kUnlockLocks — كل 3 إجابات '
            'صحيحة متتالية تفتح قفلاً',
          ),
        ),
      ],
    );
  }

  /// Fill-in-the-blank: free text input, checked case-insensitively
  /// by the engine against [Question.correctAnswer].
  Widget _buildFillInput(Question q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _fillController,
          enabled: !_showFeedback,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _chooseFill(),
          decoration: const InputDecoration(
            labelText: 'اكتبي الإجابة هنا',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _showFeedback ? null : _chooseFill,
          child: const Text('تحقق'),
        ),
      ],
    );
  }

  /// Ordering: tap the options in the correct order, then check.
  /// The attempt is submitted as the options joined with " | ", which
  /// the engine compares with [Question.correctAnswer].
  Widget _buildOrderingInput(Question q) {
    // Indices, not values: a repeated option value used to make the
    // round unfinishable (see _pickedOrdering).
    final List<int> remaining = List<int>.generate(
      q.options.length,
      (int i) => i,
    ).where((int i) => !_pickedOrdering.contains(i)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('اضغطي على العناصر بالترتيب الصحيح:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _pickedOrdering
              .asMap()
              .entries
              .map((e) => Chip(
                    label: Text('${e.key + 1}. ${q.options[e.value]}'),
                    onDeleted: _showFeedback
                        ? null
                        : () => setState(
                            () => _pickedOrdering.removeAt(e.key)),
                  ))
              .toList(),
        ),
        const Divider(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: remaining
              .map((int i) => FilledButton.tonal(
                    onPressed: _showFeedback
                        ? null
                        : () => setState(() => _pickedOrdering.add(i)),
                    child: Text(q.options[i]),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed:
              _showFeedback || _pickedOrdering.isEmpty ? null : _chooseOrdering,
          child: const Text('تحقق'),
        ),
      ],
    );
  }

  Widget _buildConceptBoard(BuildContext context) {
    final List<Question> round = _conceptRounds[_conceptRoundIndex];
    final int matched = _conceptMatchedRoundIds.length;
    return Scaffold(
      appBar: AppBar(title: Text('${_mode.titleAr} — ${widget.subjectTitleAr}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'الجولة ${_conceptRoundIndex + 1} من ${_conceptRounds.length}'
              '  •  التطابقات: $matched / ${round.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'اضغطي على سؤال من العمود الأيمن، ثم على إجابته الصحيحة '
              'من العمود الأيسر.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('الأسئلة',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: [
                              for (final Question q in round)
                                _conceptTile(
                                  context,
                                  label: q.text,
                                  selected:
                                      _conceptSelectedStemId == q.id,
                                  matched: _conceptMatchedRoundIds
                                      .contains(q.id),
                                  onTap: () => _onConceptStemTap(q.id),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('الإجابات',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: [
                              for (final String answer in _conceptAnswers)
                                _conceptTile(
                                  context,
                                  label: answer,
                                  selected: false,
                                  matched: round.any((Question q) =>
                                      q.correctAnswer == answer &&
                                      _conceptMatchedRoundIds.contains(q.id)),
                                  onTap: () => _onConceptAnswerTap(answer),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_conceptMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _conceptMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _conceptMessage!.contains('✓')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _conceptTile(
    BuildContext context, {
    required String label,
    required bool selected,
    required bool matched,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: matched ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: matched
                ? Colors.green.withValues(alpha: 0.3)
                : selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildMemoryBoard(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_mode.titleAr} — ${widget.subjectTitleAr}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('التطابقات: $_memoryMatches / ${_cards.length ~/ 2}'
                '   •   المحاولات: $_memoryTries'),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, i) {
                  final card = _cards[i];
                  return InkWell(
                    onTap: () => _onMemoryTap(i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: card.matched
                            ? Colors.green.withValues(alpha: 0.3)
                            : card.flipped
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        card.flipped || card.matched ? card.label : '؟',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, GameResult r) {
    final stars = '★' * r.stars + '☆' * (3 - r.stars);
    return Scaffold(
      appBar: AppBar(title: const Text('النتيجة')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(stars,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 40, color: Colors.amber)),
              const SizedBox(height: 8),
              Text(
                'أجبت ${r.correct} من ${r.totalQuestions} إجابة صحيحة '
                '(${r.accuracyPercent.toStringAsFixed(0)}٪)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('النقاط (XP): ${r.xpEarned}   •   أفضل سلسلة: ${r.bestStreak}',
                  textAlign: TextAlign.center),
              if (_mode.id == GameModeId.unlock)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'الأقفال المفتوحة: $_locksOpened من $kUnlockLocks',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (r.needsRetry)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('النتيجة أقل من 50٪ — حاول مرة أخرى!',
                      textAlign: TextAlign.center),
                ),
              // Per-question review of the wrong answers (the data
              // existed but was never shown: the player could not see
              // what she got wrong after finishing).
              if (r.wrongQuestionIds.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                const Text(
                  'مراجعة الأخطاء',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._wrongReviewTiles(r),
              ],
              const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // Restart with a fresh engine via a new screen instance.
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      modeRouteId: widget.modeRouteId,
                      subject: widget.subject,
                      subjectTitleAr: widget.subjectTitleAr,
                      questions: widget.questions,
                      lessonId: widget.lessonId,
                      stageId: widget.stageId,
                      onFinished: widget.onFinished,
                    ),
                  ),
                );
              },
              child: const Text('إعادة اللعب'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(r),
              child: const Text('رجوع'),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Cards for the questions answered wrongly, in play order, with
  /// the correct answer, explanation and source + page.
  List<Widget> _wrongReviewTiles(GameResult r) {
    final List<Widget> tiles = <Widget>[];
    final List<Question> questions = _engine.questions;
    for (var i = 0;
        i < questions.length && i < r.perQuestionCorrect.length;
        i++) {
      if (r.perQuestionCorrect[i]) continue;
      final Question q = questions[i];
      tiles.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(q.text,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('الإجابة الصحيحة: ${q.correctAnswer}'),
              if (q.explanation.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(q.explanation),
              ],
              Text(
                'المصدر: ${q.source}'
                '${q.sourcePage != null ? ' — ص ${q.sourcePage}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ));
    }
    return tiles;
  }
}

class _MemoryCard {
  final String key;
  final String label;
  final bool isQuestion;
  final bool flipped;
  final bool matched;

  const _MemoryCard({
    required this.key,
    required this.label,
    required this.isQuestion,
    this.flipped = false,
    this.matched = false,
  });

  _MemoryCard copyWith({bool? flipped, bool? matched}) => _MemoryCard(
        key: key,
        label: label,
        isQuestion: isQuestion,
        flipped: flipped ?? this.flipped,
        matched: matched ?? this.matched,
      );
}
