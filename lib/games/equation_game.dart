// FULL MARK — EquationGameScreen: the «أكمل المعادلة» (complete the
// equation) game mode, playable for real.
//
// The player balances each of the 4 verified equations in
// [kEquationItems] by choosing coefficients (1..4) with steppers.
// Correctness = the canonical smallest whole-number coefficients:
// a merely balanced set (e.g. 4H₂ + 2O₂ → 4H₂O) is shown as balanced
// but not accepted, with the canonical answer explained — that is
// the chemistry, not a quirk of the game.
//
// Scoring goes through [DatabaseHelper.recordGameResult] with mode
// 'complete_equation' (see the caller's onFinished): each item maps
// to its source bank question, so attempts and review entries are
// real. The water item has no bank question (lab-only), so its
// attempt is recorded anonymously via recordAttempt(questionId: null)
// and it never enters the review queue (review_queue.question_id is
// a foreign key — a lab-only id could never be reviewed).

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../db/database.dart';
import '../models/game_result.dart';
import '../models/question.dart';
import 'equation_items.dart';

/// A finished equation game. [waterCorrect] is the water item's
/// outcome (it has no bank question, so the caller records it as an
/// anonymous attempt instead of a question attempt).
typedef EquationGameFinished = Future<void> Function(
  GameResult result,
  bool waterCorrect,
);

class EquationGameScreen extends StatefulWidget {
  const EquationGameScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    this.stageId,
    required this.sourceQuestions,
    required this.onFinished,
  });

  /// Lesson id (e.g. 'chemistry-u1-l2') for progress / continue.
  final String lessonId;
  final String lessonTitle;

  /// Stage id for progress records; defaults to [lessonId].
  final String? stageId;

  /// The bank questions the items are taken from (by
  /// [EquationItem.sourceQuestionId]). Used only by the caller's
  /// recordGameResult — this screen never invents question rows.
  final List<Question> sourceQuestions;

  /// Awaited before the result dialog appears. Required: the result
  /// (stars/XP) must never be displayed without being saved.
  final EquationGameFinished onFinished;

  @override
  State<EquationGameScreen> createState() => _EquationGameScreenState();
}

class _EquationGameScreenState extends State<EquationGameScreen> {
  late final List<EquationItem> _items;
  int _index = 0;
  late List<int> _coeffs;
  bool _showFeedback = false;
  bool _lastCorrect = false;
  bool _balancedButNotMinimal = false;
  final List<bool> _perItemCorrect = <bool>[];
  bool _waterCorrect = false;
  DateTime? _startedAt;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _items = List<EquationItem>.from(kEquationItems)
      ..shuffle();
    _coeffs = List<int>.filled(_items.first.allTerms.length, 1);
    _startedAt = DateTime.now();
    unawaited(DatabaseHelper.instance.setLastStage(
      widget.stageId ?? widget.lessonId,
      widget.lessonTitle,
    ));
  }

  EquationItem get _item => _items[_index];

  /// Longest run of consecutive correct items.
  int _longestTrueRun(List<bool> values) {
    var best = 0;
    var run = 0;
    for (final bool v in values) {
      run = v ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }

  /// Streak bonus, same rule as the engine: each correct answer given
  /// while the running streak is >= 3 earns +5 XP (see GameResult.xpFor).
  int _streakBonusFor(List<bool> values) {
    var streak = 0;
    var bonus = 0;
    for (final bool v in values) {
      if (v) {
        streak++;
        if (streak >= 3) bonus++;
      } else {
        streak = 0;
      }
    }
    return bonus;
  }

  void _check() {
    if (_showFeedback) return;
    final bool canonical = isCanonical(_item, _coeffs);
    final bool balanced = coefficientsBalance(_item, _coeffs);
    setState(() {
      _showFeedback = true;
      _lastCorrect = canonical;
      _balancedButNotMinimal = !canonical && balanced;
      _perItemCorrect.add(canonical);
      if (_item.id == 'eq-water') _waterCorrect = canonical;
    });
  }

  Future<void> _advanceOrFinish() async {
    if (_index + 1 >= _items.length) {
      await _finishGame();
      return;
    }
    setState(() {
      _index++;
      _coeffs = List<int>.filled(_items[_index].allTerms.length, 1);
      _showFeedback = false;
      _lastCorrect = false;
      _balancedButNotMinimal = false;
    });
  }

  Future<void> _finishGame() async {
    if (_saved) return;
    _saved = true;
    final int correct = _perItemCorrect.where((bool v) => v).length;
    final int total = _items.length;
    final List<String> wrongIds = <String>[];
    for (var i = 0; i < _items.length; i++) {
      final String? qid = _items[i].sourceQuestionId;
      if (qid != null && (i >= _perItemCorrect.length || !_perItemCorrect[i])) {
        wrongIds.add(qid);
      }
    }
    final int elapsed = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    final GameResult result = GameResult(
      modeId: 'complete_equation',
      subject: 'chemistry',
      totalQuestions: total,
      correct: correct,
      wrong: total - correct,
      skipped: 0,
      bestStreak: _longestTrueRun(_perItemCorrect),
      streakBonus: _streakBonusFor(_perItemCorrect),
      elapsedSeconds: elapsed,
      perQuestionCorrect: List<bool>.unmodifiable(_perItemCorrect),
      wrongQuestionIds: wrongIds,
    );
    await DatabaseHelper.instance.setLastStage(
      widget.stageId ?? widget.lessonId,
      widget.lessonTitle,
    );
    await widget.onFinished(result, _waterCorrect);
    if (!mounted) return;
    // The dialog returns true when the player chose replay: only then
    // do we stay; any other choice pops the screen. (Before, the
    // screen popped unconditionally after the dialog, so "إعادة اللعب"
    // reset the game and then immediately closed it.)
    final bool replay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('نتيجة «أكمل المعادلة»'),
        content: Text(
          'أكملت $correct من $total معادلات بشكل صحيح '
          '(${(correct * 100 / total).round()}٪)\n'
          'النجوم: ${result.stars} من 3\n'
          'النقاط (XP): ${result.xpEarned}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إعادة اللعب'),
          ),
        ],
      ),
    ) ?? false;
    if (!mounted) return;
    if (replay) {
      setState(() {
        _items.shuffle();
        _index = 0;
        _coeffs = List<int>.filled(_items.first.allTerms.length, 1);
        _showFeedback = false;
        _lastCorrect = false;
        _balancedButNotMinimal = false;
        _perItemCorrect.clear();
        _waterCorrect = false;
        _startedAt = DateTime.now();
        _saved = false;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _coeffStepper(int termIndex) {
    final int value = _coeffs[termIndex];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: const Icon(Icons.remove),
        onPressed: _showFeedback || value <= 1
            ? null
            : () => setState(() => _coeffs[termIndex] = value - 1),
      ),
      Container(
        width: 34,
        alignment: Alignment.center,
        child: Text(
          '$value',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: _showFeedback || value >= 4
            ? null
            : () => setState(() => _coeffs[termIndex] = value + 1),
      ),
    ]);
  }

  String _renderedEquation() {
    String side(List<EquationTerm> terms, List<int> coeffs) {
      final List<String> parts = <String>[];
      for (var i = 0; i < terms.length; i++) {
        parts.add('${coeffs[i] > 1 ? coeffs[i] : ''}${terms[i].formula}');
      }
      return parts.join(' + ');
    }

    final String left = side(
      _item.leftTerms,
      _coeffs.sublist(0, _item.leftTerms.length),
    );
    final String right =
        side(_item.rightTerms, _coeffs.sublist(_item.leftTerms.length));
    return '$left  →  $right';
  }

  String _atomCountsLine() {
    String side(List<EquationTerm> terms, List<int> coeffs) {
      final Map<String, int> counts = countSideAtoms(terms, coeffs);
      if (counts.isEmpty) return '—';
      return counts.entries.map((e) => '${e.key} = ${e.value}').join(' ، ');
    }

    final List<int> leftCoeffs =
        _coeffs.sublist(0, _item.leftTerms.length);
    final List<int> rightCoeffs = _coeffs.sublist(_item.leftTerms.length);
    return 'الطرف الأيسر: ${side(_item.leftTerms, leftCoeffs)}'
        '    |    الطرف الأيمن: ${side(_item.rightTerms, rightCoeffs)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<EquationTerm> terms = _item.allTerms;
    return Scaffold(
      appBar: AppBar(
        title: Text('أكمل المعادلة — ${widget.lessonTitle}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: _index / _items.length),
            const SizedBox(height: 8),
            Text(
              'المعادلة ${_index + 1} من ${_items.length}  •  ${_item.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'غيّري المعاملات (1–4) حتى تتساوى ذرات كل عنصر '
                      'في الطرفين، وبأصغر معاملات صحيحة ممكنة.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      runSpacing: 8,
                      children: <Widget>[
                        for (var i = 0; i < terms.length; i++) ...<Widget>[
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _coeffStepper(i),
                              Text(
                                terms[i].formula,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (i < terms.length - 1)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                i == _item.leftTerms.length - 1 ? '→' : '+',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _renderedEquation(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _atomCountsLine(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!_showFeedback)
              FilledButton(
                onPressed: _check,
                child: const Text('تحقق من الموازنة'),
              ),
            if (_showFeedback) ...[
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
                      _lastCorrect
                          ? 'موازنة صحيحة ✓ — بأصغر المعاملات'
                          : _balancedButNotMinimal
                              ? 'المعادلة متوازنة، لكن المعاملات ليست الأصغر ✗'
                              : 'غير متوازنة بعد ✗',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المعاملات الصحيحة: '
                      '${_item.correctCoefficients.join(' ، ')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_item.explanation),
                    const SizedBox(height: 4),
                    Text(
                      'المصدر: ${_item.source}'
                      '${_item.sourcePage != null ? ' — ص ${_item.sourcePage}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _advanceOrFinish,
                child: Text(_index + 1 >= _items.length
                    ? 'عرض النتيجة'
                    : 'المعادلة التالية'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'قانون حفظ الكتلة: في التفاعل الكيميائي لا تُفقد الذرات '
              'ولا تُستحدث؛ بل يعاد ترتيبها فقط — لذلك يجب أن تتساوى '
              'أعدادها في الطرفين.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
