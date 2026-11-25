// ABQARIYA — GameScreen: real playable Flutter screen.
// Playable for real: quiz, true_false, time_race, memory_match, boss_20.
// Other modes: honest «قيد الإعداد» state inside this screen — never a
// dead button. Empty bank: honest «قيد الإعداد — أسئلة المنهج اليمني
// لم تُضف بعد». Demo questions show a visible «تجريبي» badge.
// Offline only. No network, no accounts, no ads.
// Route: GameScreen(modeRouteId: 'quiz', subject: 'physics', questions: [...])
// The caller passes the question list (from JSON/DB); this screen never
// invents questions.

import 'dart:async';

import 'package:flutter/material.dart';

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

  /// Called with the finished result (for saving XP / analytics locally).
  final void Function(GameResult result)? onFinished;

  const GameScreen({
    super.key,
    required this.modeRouteId,
    required this.subject,
    required this.subjectTitleAr,
    required this.questions,
    this.onFinished,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameModeConfig _mode;
  late final GameEngine _engine;
  Timer? _timer;
  int _secondsLeft = 0;
  int _secondsOnQuestion = 0;
  String? _selectedAnswer;
  bool _showFeedback = false;
  bool _lastCorrect = false;
  GameResult? _result;

  // --- memory_match state ---
  List<_MemoryCard> _cards = [];
  int? _firstFlippedIndex;
  bool _memoryLock = false;
  int _memoryMatches = 0;
  int _memoryTries = 0;
  // Pairs matched on the first attempt (no prior failed flip of that
  // pair) — used for an honest accuracy, not an automatic 100%.
  int _memoryFirstTryMatches = 0;
  final Set<String> _memoryFailedKeys = {};

  @override
  void initState() {
    super.initState();
    _mode = modeConfigByRouteId(widget.modeRouteId);
    final allowed = questionTypesForMode(_mode.id);
    final usable = widget.questions
        .where((q) => allowed.contains(q.type))
        .toList();
    _engine = GameEngine.startGame(
      modeId: _mode.routeId,
      subject: widget.subject,
      questions: usable,
      secondsPerQuestion: _mode.secondsPerQuestion,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    if (_mode.id == GameModeId.memoryMatch) _buildMemoryCards();
    _startQuestionTimer();
  }

  void _buildMemoryCards() {
    final cards = <_MemoryCard>[];
    for (final q in _engine.questions) {
      // Pair = question text <-> correct answer. Only mcq/match questions
      // reach here (filtered in initState).
      cards.add(_MemoryCard(key: q.id, label: q.text, isQuestion: true));
      cards.add(_MemoryCard(key: q.id, label: q.correctAnswer, isQuestion: false));
    }
    cards.shuffle();
    _cards = cards;
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    _secondsOnQuestion = 0;
    _secondsLeft = _mode.secondsPerQuestion;
    if (_secondsLeft <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _result != null) return;
      setState(() {
        _secondsLeft--;
        _secondsOnQuestion++;
      });
      if (_secondsLeft <= 0) {
        // Time up: count as a wrong answer and move on.
        _engine.answer('', secondsTaken: _secondsOnQuestion);
        _advanceOrFinish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(String answer) {
    if (_showFeedback || _engine.isFinished) return;
    final correct = _engine.answer(answer, secondsTaken: _secondsOnQuestion);
    setState(() {
      _selectedAnswer = answer;
      _showFeedback = true;
      _lastCorrect = correct;
    });
  }

  void _advanceOrFinish() {
    _timer?.cancel();
    _engine.next();
    if (_engine.isFinished) {
      final result = _engine.finish();
      widget.onFinished?.call(result);
      setState(() => _result = result);
    } else {
      setState(() {
        _selectedAnswer = null;
        _showFeedback = false;
      });
      _startQuestionTimer();
    }
  }

  void _onMemoryTap(int index) {
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
        if (firstTry) _memoryFirstTryMatches++;
        _firstFlippedIndex = null;
      });
      if (_memoryMatches * 2 >= _cards.length) {
        // Finished: "correct" = pairs matched on the first try, so the
        // accuracy honestly reflects failed attempts (not an automatic
        // 100% just for finishing the board).
        final total = _engine.totalQuestions;
        final result = GameResult(
          modeId: _mode.routeId,
          subject: widget.subject,
          totalQuestions: total,
          correct: _memoryFirstTryMatches,
          wrong: total - _memoryFirstTryMatches,
          skipped: 0,
          bestStreak: _memoryFirstTryMatches,
          streakBonus: 0,
          elapsedSeconds: 0,
          perQuestionCorrect: List<bool>.generate(
              total, (i) => i < _memoryFirstTryMatches,
              growable: false),
          wrongQuestionIds: const [],
        );
        widget.onFinished?.call(result);
        setState(() => _result = result);
      }
    } else {
      _memoryLock = true;
      _memoryFailedKeys.add(first.key);
      _memoryFailedKeys.add(card.key);
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
    // 1) Mode not yet implemented — honest state, never a dead screen.
    if (!_mode.isPlayable && _mode.id != GameModeId.ministerialExam) {
      return Scaffold(
        appBar: AppBar(title: Text(_mode.titleAr)),
        body: _comingSoon(context, _mode),
      );
    }
    if (_mode.id == GameModeId.ministerialExam) {
      return Scaffold(
        appBar: AppBar(title: Text(_mode.titleAr)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'محاكاة الامتحان الوزاري لها شاشتها الخاصة (ExamScreen).\n'
              'استخدم زر «محاكاة الامتحان الوزاري» من الصفحة الرئيسية.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    // 2) Empty bank — honest state.
    if (_engine.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_mode.titleAr)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'قيد الإعداد — أسئلة المنهج اليمني لم تُضف بعد.\n'
              'ستظهر الأسئلة هنا فور إضافتها من الكتب المعتمدة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }
    // 3) Finished — summary.
    if (_result != null) return _buildSummary(context, _result!);
    // 4) Memory-match board.
    if (_mode.id == GameModeId.memoryMatch) return _buildMemoryBoard(context);
    // 5) Normal question flow (quiz / true_false / time_race / boss_20).
    return _buildQuestion(context);
  }

  Widget _comingSoon(BuildContext context, GameModeConfig mode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48),
            const SizedBox(height: 16),
            Text(mode.titleAr, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(mode.descriptionAr, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('قيد الإعداد — سيتوفر هذا النمط في تحديث قادم.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final q = _engine.currentQuestion!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_mode.titleAr} — ${widget.subjectTitleAr}'),
        actions: [
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
            const SizedBox(height: 16),
            Text(q.text, style: theme.textTheme.titleLarge),
            if (q.isDemo)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('سؤال تجريبي — ليس من المنهج اليمني.',
                    style: TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 16),
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
                      ? Colors.green.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_lastCorrect ? 'إجابة صحيحة ✓' : 'إجابة خاطئة ✗',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    : 'السؤال التالي'),
              ),
            ],
          ],
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
                            ? Colors.green.withOpacity(0.3)
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
      body: Padding(
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
            if (r.needsRetry)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('النتيجة أقل من 50٪ — حاول مرة أخرى!',
                    textAlign: TextAlign.center),
              ),
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
    );
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
