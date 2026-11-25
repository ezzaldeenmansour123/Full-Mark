import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../analytics/analytics_engine.dart';
import '../core/routes.dart';
import '../db/database.dart';
import '../models/question.dart';

/// المراجعة الذكية: جلسة مراجعة حقيقية بأسئلة مستحقة من جدول
/// review_queue، تُحمَّل نصوصها من بنك الأسئلة (لا يُخترع نص سؤال
/// أبداً)، وتُصحَّح فوراً، ويُحدَّث بعد كل إجابة جدول المراجعة
/// بخوارزمية SM-2 ([sm2Review]: صحيحة = جودة 5، خاطئة = جودة 0).
///
/// - لا شيء مستحق: حالة فراغ صادقة، بلا جلسة وهمية.
/// - سؤال بلا نص في البنك (صف تالف): يُتخطَّى ولا يُعرض.
/// - أنواع الأسئلة: اختيار من متعدد / صح-خطأ بأزرار خيارات،
///   «أكمل» بحقل نصي، و«رتّب»/«اربط» بتقييم ذاتي بعد إظهار الإجابة
///   (التقييم الذاتي هو أصل SM-2).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewEntry {
  final Map<String, Object?> row;
  final Question question;

  _ReviewEntry(this.row, this.question);

  String get questionId => row['question_id'] as String;
  int get repetitions => (row['repetitions'] as int?) ?? 0;
  double get easeFactor =>
      (row['ease_factor'] as num?)?.toDouble() ?? 2.5;
  int get intervalDays => (row['interval_days'] as int?) ?? 0;
  int get lapses => (row['lapses'] as int?) ?? 0;
  DateTime get nextReview => DateTime.fromMillisecondsSinceEpoch(
        (row['next_review_at'] as int?) ??
            DateTime.now().millisecondsSinceEpoch,
      );
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<_ReviewEntry> _entries = <_ReviewEntry>[];
  bool _loading = true;
  bool _inSession = false;
  bool _finished = false;
  int _index = 0;
  int _correctCount = 0;

  // حالة السؤال الحالي.
  bool _graded = false;
  bool _wasCorrect = false;
  String? _givenAnswer;
  String? _revealedAnswer;
  final TextEditingController _fillController = TextEditingController();

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Map<String, Object?>> rows =
        await DatabaseHelper.instance.getDueReviewItems();
    final List<_ReviewEntry> entries = <_ReviewEntry>[];
    for (final Map<String, Object?> row in rows) {
      final String questionId = (row['question_id'] as String?) ?? '';
      if (questionId.isEmpty) continue;
      final Question? question =
          await DatabaseHelper.instance.getQuestionById(questionId);
      if (question == null) continue;
      entries.add(_ReviewEntry(row, question));
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
      _inSession = false;
      _finished = false;
      _index = 0;
      _correctCount = 0;
    });
  }

  void _startSession() {
    setState(() {
      _inSession = true;
      _finished = false;
      _index = 0;
      _correctCount = 0;
      _resetQuestionState();
    });
  }

  void _resetQuestionState() {
    _graded = false;
    _wasCorrect = false;
    _givenAnswer = null;
    _revealedAnswer = null;
    _fillController.clear();
  }

  /// يصحّح إجابة واحدة ويحفظ تحديث SM-2 فوراً. [correct] صحيحة
  /// تعني جودة 5، وخاطئة تعني جودة 0.
  Future<void> _grade(bool correct, String givenAnswer) async {
    if (_graded) return;
    // تُثبَّت حالة التصحيح فوراً (قبل انتظار قاعدة البيانات) حتى لا
    // تُحتسب ضغطة مزدوجة إجابتين.
    setState(() {
      _graded = true;
      _wasCorrect = correct;
      _givenAnswer = givenAnswer;
      if (correct) _correctCount++;
    });
    final _ReviewEntry entry = _entries[_index];
    final ReviewState state = ReviewState(
      questionId: entry.questionId,
      repetitions: entry.repetitions,
      easeFactor: entry.easeFactor,
      intervalDays: entry.intervalDays,
      nextReview: entry.nextReview,
    );
    final ReviewState next = sm2Review(state, correct ? 5 : 0);
    await DatabaseHelper.instance.updateReviewItem(
      questionId: entry.questionId,
      easeFactor: next.easeFactor,
      intervalDays: next.intervalDays,
      repetitions: next.repetitions,
      lapses: correct ? entry.lapses : entry.lapses + 1,
      nextReviewAt: next.nextReview.millisecondsSinceEpoch,
    );
  }

  void _answerOption(String option) {
    final Question q = _entries[_index].question;
    final bool correct = option.trim() == q.correctAnswer.trim();
    unawaited(_grade(correct, option));
  }

  void _answerFill() {
    final String given = _fillController.text.trim();
    if (given.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتبي إجابتك أولاً ثم تحققي منها.')),
      );
      return;
    }
    final Question q = _entries[_index].question;
    final bool correct =
        given.toLowerCase() == q.correctAnswer.trim().toLowerCase();
    unawaited(_grade(correct, given));
  }

  void _revealSelfGraded() {
    setState(() {
      _revealedAnswer = _entries[_index].question.correctAnswer;
    });
  }

  void _answerSelfGraded(bool correct) {
    unawaited(_grade(
      correct,
      correct ? 'تذكّرتها' : 'لم أتذكّرها',
    ));
  }

  void _next() {
    if (_index + 1 >= _entries.length) {
      setState(() {
        _finished = true;
        _inSession = false;
      });
      return;
    }
    setState(() {
      _index++;
      _resetQuestionState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('المراجعة الذكية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _finished
              ? _buildSummary(theme)
              : _inSession
                  ? _buildSession(theme)
                  : _entries.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildIntro(theme),
    );
  }

  Widget _buildIntro(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          child: ListTile(
            leading: const Icon(Icons.replay),
            title: const Text('أسئلة مستحقة للمراجعة'),
            trailing: Text(
              '${_entries.length}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _startSession,
          icon: const Icon(Icons.play_arrow),
          label: const Text('ابدئي جلسة المراجعة'),
        ),
        const SizedBox(height: 12),
        const Text(
          'تعتمد المراجعة على أخطائك الحقيقية في المراحل، '
          'وتعيد عرض كل سؤال في الوقت الأنسب لتثبيته. '
          'كل إجابة تُصحَّح فوراً وتُحدِّد موعد المراجعة التالية.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.replay,
              size: 72,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد أسئلة مستحقة للمراجعة الآن — العبي دروساً وستظهر '
              'هنا الأسئلة التي أخطأتِ فيها',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.worlds),
              icon: const Icon(Icons.play_arrow),
              label: const Text('ابدئي أول مرحلة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSession(ThemeData theme) {
    final _ReviewEntry entry = _entries[_index];
    final Question q = entry.question;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'السؤال ${_index + 1} من ${_entries.length}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_index + (_graded ? 1 : 0)) / _entries.length,
        ),
        const SizedBox(height: 16),
        Text(q.text, style: theme.textTheme.titleLarge),
        if (q.isDemo)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'سؤال تجريبي — ليس من المنهج اليمني.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        const SizedBox(height: 16),
        if (q.type == QuestionType.mcq ||
            q.type == QuestionType.trueFalse)
          ...q.options.map((String opt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () {
                    if (_graded) return;
                    _answerOption(opt);
                  },
                  style: _graded
                      ? OutlinedButton.styleFrom(
                          backgroundColor: opt.trim() ==
                                  q.correctAnswer.trim()
                              ? Colors.green.withValues(alpha: 0.25)
                              : opt == _givenAnswer
                                  ? Colors.red.withValues(alpha: 0.25)
                                  : null,
                        )
                      : null,
                  child: Text(opt),
                ),
              ))
        else if (q.type == QuestionType.fill)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _fillController,
                enabled: !_graded,
                decoration: const InputDecoration(
                  labelText: 'اكتبي الإجابة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (_graded) return;
                  _answerFill();
                },
                child: const Text('تحققي من الإجابة'),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_revealedAnswer == null)
                FilledButton(
                  onPressed: _revealSelfGraded,
                  child: const Text('أظهري الإجابة الصحيحة'),
                )
              else ...<Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('الإجابة الصحيحة: $_revealedAnswer'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'هل تذكّرتِ الإجابة قبل إظهارها؟ قيّمي نفسك بصدق — '
                  'التقييم الصادق هو ما يثبّت الحفظ.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (_graded) return;
                    _answerSelfGraded(true);
                  },
                  child: const Text('تذكّرتها — صحيحة'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    if (_graded) return;
                    _answerSelfGraded(false);
                  },
                  child: const Text('لم أتذكّرها — خاطئة'),
                ),
              ],
            ],
          ),
        if (_graded) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            color: _wasCorrect
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _wasCorrect
                        ? 'إجابة صحيحة ✓'
                        : 'إجابة خاطئة ✗ — الإجابة الصحيحة: ${q.correctAnswer}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (q.explanation.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('الشرح: ${q.explanation}'),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'المصدر: ${q.source}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _next,
            child: Text(
              _index + 1 >= _entries.length
                  ? 'إنهاء الجلسة'
                  : 'السؤال التالي',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final int total = _entries.length;
    final int pct =
        total == 0 ? 0 : (_correctCount * 100 / total).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.check_circle,
              size: 72,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'أنهيتِ جلسة المراجعة',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أجبتِ صحيحةً عن $_correctCount من $total ($pct٪). '
              'حُدِّد موعد المراجعة التالية لكل سؤال حسب إجابتك.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.worlds),
              icon: const Icon(Icons.play_arrow),
              label: const Text('العودة إلى العوالم'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('تحديث قائمة المراجعة'),
            ),
          ],
        ),
      ),
    );
  }
}
