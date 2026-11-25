// ABQARIYA — MinisterialExamScreen: real exam UI wired to ExamSession.
// Timed session, question navigation, mark-for-review, submit,
// auto-grading, per-question review with explanations.
// Demo exams are labelled "محاكاة تجريبية" — never presented as a real
// ministerial exam. Empty bank: honest «قيد الإعداد» state.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/question.dart';
import 'ministerial_exam.dart';

class MinisterialExamScreen extends StatefulWidget {
  final String subject;
  final String subjectTitleAr;
  final List<String> units;

  /// Full question bank (JSON/DB). May be empty.
  final List<Question> bank;
  final int totalSeconds;
  final void Function(ExamResult result)? onSubmitted;

  const MinisterialExamScreen({
    super.key,
    required this.subject,
    required this.subjectTitleAr,
    this.units = const [],
    required this.bank,
    this.totalSeconds = 3600,
    this.onSubmitted,
  });

  @override
  State<MinisterialExamScreen> createState() => _MinisterialExamScreenState();
}

class _MinisterialExamScreenState extends State<MinisterialExamScreen> {
  ExamSession? _session;
  String? _startError;
  Timer? _timer;
  ExamResult? _result;
  String? _selected;
  bool _showReview = false;

  @override
  void initState() {
    super.initState();
    try {
      _session = ExamSession.start(
        subject: widget.subject,
        units: widget.units,
        bank: widget.bank,
        totalSeconds: widget.totalSeconds,
      );
      _selected = _session!.answerFor(0);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_session == null || _result != null) return;
        final up = _session!.tick();
        if (mounted) setState(() {});
        if (up) _submit(auto: true);
      });
    } on StateError catch (e) {
      _startError = e.message;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit({bool auto = false}) {
    final session = _session;
    if (session == null || _result != null) return;
    _timer?.cancel();
    final result = session.submit();
    widget.onSubmitted?.call(result);
    setState(() => _result = result);
    if (auto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتهى الوقت — تم تسليم الامتحان تلقائياً.')),
      );
    }
  }

  Future<bool> _confirmSubmit() async {
    final session = _session!;
    if (session.unansweredCount == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسليم الامتحان؟'),
        content: Text(
            'لديك ${session.unansweredCount} سؤالاً بدون إجابة. هل تريد التسليم؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('متابعة الإجابة')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تسليم')),
        ],
      ),
    );
    return ok ?? false;
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_startError != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('محاكاة الامتحان الوزاري')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'قيد الإعداد — أسئلة المنهج اليمني لم تُضف بعد.\n'
              'لا يمكن بدء محاكاة امتحان بدون أسئلة معتمدة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }
    if (_result != null) return _buildResult(context, _result!);
    return _buildExam(context, _session!);
  }

  Widget _buildExam(BuildContext context, ExamSession session) {
    final q = session.currentQuestion;
    final remaining = session.secondsRemaining;
    return Scaffold(
      appBar: AppBar(
        title: Text('${session.examLabel} — ${widget.subjectTitleAr}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text('⏱ ${_formatTime(remaining)}',
                  style: TextStyle(
                    color: remaining <= 300 ? Colors.red : null,
                    fontWeight: FontWeight.bold,
                  )),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session.isDemoExam)
              const Chip(label: Text('محاكاة تجريبية — ليست أسئلة وزارية حقيقية')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(session.totalQuestions, (i) {
                final answered = session.answerFor(i) != null;
                final marked = session.isMarked(i);
                return InkWell(
                  onTap: () => setState(() {
                    session.goTo(i);
                    _selected = session.answerFor(i);
                  }),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == session.currentIndex
                          ? Theme.of(context).colorScheme.primary
                          : answered
                              ? Colors.green.withValues(alpha: 0.4)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                      border: marked
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${i + 1}'),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text('السؤال ${session.currentIndex + 1} من ${session.totalQuestions}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(q.text, style: Theme.of(context).textTheme.titleLarge),
            if (q.isDemo)
              const Text('سؤال تجريبي — ليس من المنهج اليمني.',
                  style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (String? v) {
                if (v == null) return;
                setState(() => _selected = v);
                session.answerCurrent(v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ...q.options.map((opt) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<String>(
                          title: Text(opt),
                          value: opt,
                        ),
                      )),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                OutlinedButton(
                  onPressed: session.currentIndex == 0
                      ? null
                      : () => setState(() {
                            session.previous();
                            _selected = session.answerFor(session.currentIndex);
                          }),
                  child: const Text('السابق'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() => session.toggleMarkForReview()),
                  child: Text(session.isMarked(session.currentIndex)
                      ? 'إلغاء التمييز ⭐'
                      : 'تمييز للمراجعة ⭐'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: session.currentIndex + 1 >= session.totalQuestions
                      ? () async {
                          if (await _confirmSubmit()) _submit();
                        }
                      : () => setState(() {
                            session.next();
                            _selected = session.answerFor(session.currentIndex);
                          }),
                  child: Text(session.currentIndex + 1 >= session.totalQuestions
                      ? 'تسليم'
                      : 'التالي'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, ExamResult r) {
    return Scaffold(
      appBar: AppBar(title: Text(r.isDemoExam ? 'نتيجة المحاكاة التجريبية' : 'نتيجة المحاكاة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r.isDemoExam)
            const Chip(label: Text('محاكاة تجريبية — ليست أسئلة وزارية حقيقية')),
          const SizedBox(height: 8),
          Text(
            '${r.correct} / ${r.totalQuestions} صحيحة '
            '(${r.accuracyPercent.toStringAsFixed(0)}٪) — ${r.gradeLabel}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('بدون إجابة: ${r.unanswered}   •   الوقت المستغرق: ${_formatTime(r.secondsUsed)}'),
          const SizedBox(height: 12),
          Text('النتيجة حسب الوحدة:',
              style: Theme.of(context).textTheme.titleMedium),
          ...r.breakdownByUnit.entries.map((e) => ListTile(
                title: Text(e.key.isEmpty ? '(بدون وحدة)' : e.key),
                trailing: Text('${e.value.$1} / ${e.value.$2}'),
              )),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => setState(() => _showReview = !_showReview),
            child: Text(_showReview ? 'إخفاء المراجعة' : 'مراجعة كل سؤال'),
          ),
          if (_showReview)
            ...r.perQuestion.map((item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('سؤال ${item.index + 1}: ${item.question.text}'),
                        Text(item.correct
                            ? 'إجابتك صحيحة ✓'
                            : 'إجابتك: ${item.givenAnswer ?? '— بدون إجابة'} ✗'),
                        Text('الإجابة الصحيحة: ${item.question.correctAnswer}'),
                        if (item.question.explanation.isNotEmpty)
                          Text('الشرح: ${item.question.explanation}'),
                        Text('المصدر: ${item.question.source}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(r),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
  }
}
