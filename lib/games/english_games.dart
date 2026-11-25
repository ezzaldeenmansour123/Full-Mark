// ABQARIYA — English games: sentence building.
// PRONUNCIATION: removed — there is no audio/TTS in this app, so no
// speaker button is shown anywhere. Nothing here pretends audio exists.
// The sentence game below is fed by real database questions (see
// [EnglishSentenceGameScreen]). There is no vocabulary-matching game:
// the database holds no English↔Arabic word pairs, so that widget was
// deleted rather than shown with invented content.

import 'package:material_ui/material_ui.dart';

import '../db/database.dart';
import '../models/game_result.dart';
import '../models/question.dart';

/// Returns true when [attempt] matches [correctOrder] exactly.
bool checkEnglishSentenceOrder(
    List<String> correctOrder, List<String> attempt) {
  if (attempt.length != correctOrder.length) return false;
  for (var i = 0; i < attempt.length; i++) {
    if (attempt[i] != correctOrder[i]) return false;
  }
  return true;
}

/// English sentence-building widget: tap words in the correct order.
/// Shows a «تجريبي» badge ONLY when [isDemo] is true (real curriculum
/// sentences never show it). «Check» counts only the first check;
/// after answering, the button is disabled and «Next» reports the
/// (single) result once via [onFinished].
class EnglishSentenceGame extends StatefulWidget {
  final List<String> words;
  final List<String> correctOrder;
  final bool isDemo;

  /// Called exactly once per sentence, when the player taps «Next»
  /// after checking: true when the order was correct.
  final void Function(bool correct)? onFinished;

  const EnglishSentenceGame({
    super.key,
    required this.words,
    required this.correctOrder,
    this.isDemo = false,
    this.onFinished,
  });

  @override
  State<EnglishSentenceGame> createState() => _EnglishSentenceGameState();
}

class _EnglishSentenceGameState extends State<EnglishSentenceGame> {
  // Indices into widget.words, not values: a repeated word used to
  // make the round unfinishable (picking it once removed both copies).
  final List<int> _picked = [];
  String? _feedback;
  bool _answered = false;
  bool _lastCorrect = false;

  @override
  Widget build(BuildContext context) {
    final remaining = List<int>.generate(
      widget.words.length,
      (int i) => i,
    ).where((int i) => !_picked.contains(i)).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isDemo) const Chip(label: Text('تجريبي')),
          const Text('Arrange the words to make a correct sentence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _picked
                .map((int i) => Chip(label: Text(widget.words[i])))
                .toList(),
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: remaining
                .map((int i) => FilledButton.tonal(
                      onPressed: _answered
                          ? null
                          : () => setState(() => _picked.add(i)),
                      child: Text(widget.words[i]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          if (!_answered)
            FilledButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () {
                      final ok = checkEnglishSentenceOrder(
                          widget.correctOrder,
                          _picked
                              .map((int i) => widget.words[i])
                              .toList(growable: false));
                      setState(() {
                        _feedback =
                            ok ? 'Correct ✓' : 'Not correct ✗ — try again';
                        _answered = true;
                        _lastCorrect = ok;
                      });
                    },
              child: const Text('Check / تحقق'),
            ),
          if (_answered)
            FilledButton(
              onPressed: () => widget.onFinished?.call(_lastCorrect),
              child: const Text('Next / التالي'),
            ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(_feedback!),
          ],
        ],
      ),
    );
  }
}

/// لعبة بناء الجمل — اللغة الإنجليزية — fed by REAL database questions.
///
/// Each sentence is one real English question's correct answer text
/// (split into words, shuffled for display). Only answers of 3+ words
/// without '/' are usable. Finishing records a real [GameResult] via
/// [DatabaseHelper.recordGameResult] (mode 'english_sentence', with the
/// source questions as [playedQuestions]).
class EnglishSentenceGameScreen extends StatefulWidget {
  const EnglishSentenceGameScreen({super.key});

  @override
  State<EnglishSentenceGameScreen> createState() =>
      _EnglishSentenceGameScreenState();
}

class _EnglishSentenceGameScreenState
    extends State<EnglishSentenceGameScreen> {
  List<Question> _sourceQuestions = <Question>[];
  int _index = 0;
  final List<bool> _results = <bool>[];
  bool _loading = true;
  bool _saved = false;

  /// Display order per question id, shuffled ONCE in [_load].
  /// Shuffling in build() re-randomised the words on every rebuild
  /// (e.g. after every tap), so the buttons jumped under the player's
  /// finger.
  final Map<String, List<String>> _displayById = <String, List<String>>{};

  /// When the game started — the recorded time is measured, never 0.
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final questions =
        await DatabaseHelper.instance.getQuestionsForSubject('english');
    final usable = questions.where((q) {
      final words = q.correctAnswer.trim().split(' ');
      return words.length >= 3 && !q.correctAnswer.contains('/');
    }).toList()
      ..shuffle();
    final picked = usable.take(8).toList();
    for (final Question q in picked) {
      final List<String> words = q.correctAnswer.trim().split(' ');
      _displayById[q.id] = List<String>.from(words)..shuffle();
    }
    await DatabaseHelper.instance.setLastStage(
      'english',
      'لعبة بناء الجمل — اللغة الإنجليزية',
    );
    if (!mounted) return;
    setState(() {
      _sourceQuestions = picked;
      _loading = false;
    });
  }

  Future<void> _onSentenceFinished(bool correct) async {
    _results.add(correct);
    if (_index + 1 >= _sourceQuestions.length) {
      await _finish();
    } else {
      setState(() => _index++);
    }
  }

  Future<void> _finish() async {
    if (_saved || _results.isEmpty) return;
    _saved = true;
    final total = _results.length;
    final correct = _results.where((r) => r).length;
    final wrongIds = <String>[
      for (var i = 0; i < _sourceQuestions.length && i < total; i++)
        if (!_results[i]) _sourceQuestions[i].id,
    ];
    var bestStreak = 0;
    var run = 0;
    for (final ok in _results) {
      run = ok ? run + 1 : 0;
      if (run > bestStreak) bestStreak = run;
    }
    final result = GameResult(
      modeId: 'english_sentence',
      subject: 'english',
      totalQuestions: total,
      correct: correct,
      wrong: total - correct,
      skipped: 0,
      bestStreak: bestStreak,
      streakBonus: GameResult.streakBonusFor(_results),
      elapsedSeconds: _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inSeconds,
      perQuestionCorrect: List<bool>.unmodifiable(_results),
      wrongQuestionIds: wrongIds,
      playedQuestionIds: _sourceQuestions
          .map((Question q) => q.id)
          .toList(growable: false),
    );
    await DatabaseHelper.instance.recordGameResult(
      result: result,
      playedQuestions: _sourceQuestions,
      mode: 'english_sentence',
      stageId: 'english',
      lessonTitle: 'لعبة بناء الجمل — اللغة الإنجليزية',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sentence game result'),
        content: Text(
          'You answered $correct of $total sentences correctly '
          '(${(correct * 100 / total).round()}%)\n'
          'XP: ${result.xpEarned}',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('لعبة بناء الجمل — اللغة الإنجليزية')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_sourceQuestions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('لعبة بناء الجمل — اللغة الإنجليزية')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لا توجد جمل متاحة بعد من أسئلة اللغة الإنجليزية — '
              'ستُضاف فور توفرها من الكتاب المعتمد.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final q = _sourceQuestions[_index];
    final words = q.correctAnswer.trim().split(' ');
    final display = _displayById[q.id] ?? List<String>.from(words);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لعبة بناء الجمل — اللغة الإنجليزية (${_index + 1}/${_sourceQuestions.length})',
        ),
      ),
      body: EnglishSentenceGame(
        // New widget instance per sentence so its picked/answered state
        // resets (keyed by question id).
        key: ValueKey<String>(q.id),
        words: display,
        correctOrder: words,
        isDemo: q.isDemo,
        onFinished: _onSentenceFinished,
      ),
    );
  }
}
