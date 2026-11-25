// ABQARIYA — Arabic games: sentence building.
// The sentence game is fed by REAL Arabic database questions (see
// [ArabicSentenceGameScreen]); the built-in example below is explicitly
// marked demo and is a generic language exercise, not a curriculum
// sentence. There is no i'rab game: the database holds no verified
// i'rab data, so that widget was deleted rather than shown with
// invented content.

import 'package:material_ui/material_ui.dart';

import '../db/database.dart';
import '../models/game_result.dart';
import '../models/question.dart';

/// One sentence-building item: [words] in shuffled display order,
/// [correctOrder] the correct order (same words, correct sequence).
class SentenceItem {
  final String id;
  final List<String> words;
  final List<String> correctOrder;

  /// Must be "demo — not Yemeni curriculum" for all built-in items.
  final String source;

  const SentenceItem({
    required this.id,
    required this.words,
    required this.correctOrder,
    required this.source,
  });

  bool get isDemo => source.trim() == 'demo — not Yemeni curriculum';

  bool isCorrectOrder(List<String> attempt) {
    if (attempt.length != correctOrder.length) return false;
    for (var i = 0; i < attempt.length; i++) {
      if (attempt[i] != correctOrder[i]) return false;
    }
    return true;
  }
}

/// A single generic demo sentence, labelled demo. It is NOT curriculum.
/// Used only when the caller passes no data at all, so the widget never
/// renders an invented "curriculum" sentence.
const SentenceItem kDemoSentence = SentenceItem(
  id: 'demo-ar-sentence-001',
  words: <String>['العلمُ', 'نورٌ', 'يهدي', 'إلى', 'الحقِّ'],
  correctOrder: <String>['العلمُ', 'نورٌ', 'يهدي', 'إلى', 'الحقِّ'],
  source: 'demo — not Yemeni curriculum',
);

/// Sentence-building widget: tap words in order to build the sentence.
/// Shows a «تجريبي» badge ONLY on demo items (real curriculum items
/// never show it). The «تحقق» button counts only the FIRST check of each
/// sentence: repeated presses after an answer is submitted are ignored,
/// so a correct sentence can never be counted twice.
class ArabicSentenceGame extends StatefulWidget {
  final List<SentenceItem> items;

  /// (correct, total, per-item correctness in order, item ids in order).
  final void Function(
    int correct,
    int total,
    List<bool> perItemCorrect,
    List<String> itemIds,
  )? onFinished;

  const ArabicSentenceGame({
    super.key,
    this.items = const <SentenceItem>[kDemoSentence],
    this.onFinished,
  });

  @override
  State<ArabicSentenceGame> createState() => _ArabicSentenceGameState();
}

class _ArabicSentenceGameState extends State<ArabicSentenceGame> {
  int _index = 0;
  // Indices into item.words, not values: a sentence whose correct
  // answer repeats a word used to make the round unfinishable
  // (picking the word once removed both copies from `remaining`).
  final List<int> _picked = [];
  String? _feedback;
  int _correct = 0;

  /// True once the current sentence has been checked. While true the
  /// «تحقق» button is disabled and further presses cannot re-count.
  bool _answered = false;

  /// Per-item correctness, in play order. An item the player skips
  /// with «التالي» without checking counts as wrong (false).
  final List<bool> _perItemCorrect = <bool>[];

  void _recordCurrentItem(bool correct) {
    if (_perItemCorrect.length <= _index) {
      _perItemCorrect.add(correct);
    }
  }

  void _goNext() {
    if (!_answered) _recordCurrentItem(false);
    if (_index + 1 >= widget.items.length) {
      while (_perItemCorrect.length < widget.items.length) {
        _perItemCorrect.add(false);
      }
      // The result dialog in the screen already reports the score;
      // a SnackBar here would flash underneath it and never be read.
      widget.onFinished?.call(
        _correct,
        widget.items.length,
        List<bool>.unmodifiable(_perItemCorrect),
        widget.items.map((i) => i.id).toList(growable: false),
      );
    } else {
      setState(() {
        _index++;
        _picked.clear();
        _feedback = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text('لا توجد جمل متاحة بعد من أسئلة اللغة العربية.'),
      );
    }
    final item = widget.items[_index];
    final remaining = List<int>.generate(
      item.words.length,
      (int i) => i,
    ).where((int i) => !_picked.contains(i)).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.isDemo) const Chip(label: Text('تجريبي')),
          Text('رتّب الكلمات لتكوين جملة صحيحة',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('الجملة ${_index + 1} من ${widget.items.length}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _picked
                .map((int i) => Chip(label: Text(item.words[i])))
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
                      child: Text(item.words[i]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          if (_feedback != null) Text(_feedback!),
          Row(
            children: [
              FilledButton(
                onPressed: _picked.isEmpty || _answered
                    ? null
                    : () {
                        final ok = checkSentenceOrder(
                            item,
                            _picked
                                .map((int i) => item.words[i])
                                .toList(growable: false));
                        setState(() {
                          _feedback = ok ? 'صحيحة ✓' : 'غير صحيحة ✗ — حاول مجدداً';
                          _answered = true;
                          _recordCurrentItem(ok);
                          if (ok) _correct++;
                        });
                      },
                child: const Text('تحقق'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                // After an answer is submitted the attempt is final:
                // resetting is disabled so the same sentence cannot be
                // re-checked and counted twice.
                onPressed: _answered
                    ? null
                    : () => setState(() {
                          _picked.clear();
                          _feedback = null;
                        }),
                child: const Text('إعادة'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _goNext,
                child: const Text('التالي'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Longest run of `true` in [results] (best streak for a game result).
int _longestTrueRun(List<bool> results) {
  var best = 0;
  var run = 0;
  for (final ok in results) {
    run = ok ? run + 1 : 0;
    if (run > best) best = run;
  }
  return best;
}

/// لعبة بناء الجمل — اللغة العربية — fed by REAL database questions.
///
/// Each item is built from one real Arabic question: the sentence is
/// that question's correct answer text (split into words, shuffled for
/// display), so nothing is invented and the source shown is the
/// question's own source. Only answers of 3+ words are usable.
/// Finishing records a real [GameResult] via
/// [DatabaseHelper.recordGameResult] (mode 'arabic_sentence', with the
/// source questions as [playedQuestions] so each attempt maps to the
/// question whose answer the player ordered).
class ArabicSentenceGameScreen extends StatefulWidget {
  const ArabicSentenceGameScreen({super.key});

  @override
  State<ArabicSentenceGameScreen> createState() =>
      _ArabicSentenceGameScreenState();
}

class _ArabicSentenceGameScreenState extends State<ArabicSentenceGameScreen> {
  List<SentenceItem> _items = <SentenceItem>[];
  List<Question> _sourceQuestions = <Question>[];
  bool _loading = true;
  bool _saved = false;

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
        await DatabaseHelper.instance.getQuestionsForSubject('arabic');
    final usable = questions.where((q) {
      final words = q.correctAnswer.trim().split(' ');
      return words.length >= 3 && !q.correctAnswer.contains('/');
    }).toList()
      ..shuffle();
    final picked = usable.take(8).toList();
    final items = picked.map((q) {
      final words = q.correctAnswer.trim().split(' ');
      final display = List<String>.from(words)..shuffle();
      return SentenceItem(
        id: q.id,
        words: display,
        correctOrder: words,
        source: q.source,
      );
    }).toList(growable: false);
    // Game start: remember this as the last stage.
    await DatabaseHelper.instance.setLastStage(
      'arabic',
      'لعبة بناء الجمل — اللغة العربية',
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _sourceQuestions = picked;
      _loading = false;
    });
  }

  Future<void> _onFinished(
    int correct,
    int total,
    List<bool> perItemCorrect,
    List<String> itemIds,
  ) async {
    if (_saved || total == 0) return;
    _saved = true;
    final wrongIds = <String>[
      for (var i = 0; i < itemIds.length; i++)
        if (i >= perItemCorrect.length || !perItemCorrect[i]) itemIds[i],
    ];
    final result = GameResult(
      modeId: 'arabic_sentence',
      subject: 'arabic',
      totalQuestions: total,
      correct: correct,
      wrong: total - correct,
      skipped: 0,
      bestStreak: _longestTrueRun(perItemCorrect),
      streakBonus: GameResult.streakBonusFor(perItemCorrect),
      elapsedSeconds: _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inSeconds,
      perQuestionCorrect: List<bool>.unmodifiable(perItemCorrect),
      wrongQuestionIds: wrongIds,
      playedQuestionIds: _sourceQuestions
          .map((Question q) => q.id)
          .toList(growable: false),
    );
    await DatabaseHelper.instance.recordGameResult(
      result: result,
      playedQuestions: _sourceQuestions,
      mode: 'arabic_sentence',
      stageId: 'arabic',
      lessonTitle: 'لعبة بناء الجمل — اللغة العربية',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('نتيجة لعبة بناء الجمل'),
        content: Text(
          'أجبت $correct من $total جملة صحيحة '
          '(${(correct * 100 / total).round()}٪)\n'
          'النقاط (XP): ${result.xpEarned}',
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
    return Scaffold(
      appBar: AppBar(title: const Text('لعبة بناء الجمل — اللغة العربية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد جمل متاحة بعد من أسئلة اللغة العربية — '
                      'ستُضاف فور توفرها من الكتاب المعتمد.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ArabicSentenceGame(
                  items: _items,
                  onFinished: _onFinished,
                ),
    );
  }
}
