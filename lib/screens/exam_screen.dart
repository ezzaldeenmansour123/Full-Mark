import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/routes.dart';
import '../db/database.dart';
import '../exam/ministerial_exam.dart';
import '../exam/ministerial_exam_screen.dart';
import '../models/question.dart';
import 'worlds_screen.dart';

/// محاكاة الامتحان الوزاري — شاشة الإطلاق القابلة للتوجيه.
///
/// تعرض المواد التي لديها أسئلة موثّقة فعلاً في قاعدة البيانات مع عدد
/// أسئلة كل مادة؛ والمواد بلا أسئلة لا تظهر أصلاً. الضغط على مادة
/// يفتح شاشة الامتحان الحقيقية (`MinisterialExamScreen`) بأسئلة تلك
/// المادة، وتُحفظ نتيجة كل امتحان مكتمل في جدول `exam_results` عبر
/// `recordExamResult`.
///
/// لا تُعرض أسئلة تجريبية على أنها أسئلة وزارية حقيقية أبداً: أي
/// سؤال تجريبي يظهر داخل المحاكاة بعلامة «تجريبي» واضحة.
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  int _questionCount = 0;
  Map<String, int> _countsBySubject = const <String, int>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final int total = await db.getTotalQuestions();
    final Map<String, int> counts = <String, int>{};
    for (final WorldDef world in kWorlds) {
      final List<Question> bank = await db.getQuestionsForSubject(world.id);
      counts[world.id] = bank.length;
    }
    if (!mounted) return;
    setState(() {
      _questionCount = total;
      _countsBySubject = counts;
      _loading = false;
    });
  }

  /// المواد التي لديها أسئلة فعلاً — فقط هذه تظهر كأزرار بدء.
  List<WorldDef> get _availableWorlds => kWorlds
      .where((WorldDef w) => (_countsBySubject[w.id] ?? 0) > 0)
      .toList();

  Future<void> _startSubjectExam(WorldDef world) async {
    final List<Question> bank =
        await DatabaseHelper.instance.getQuestionsForSubject(world.id);
    if (!mounted) return;
    if (bank.isEmpty) {
      // سباق نادر (حُذفت الأسئلة بعد عرض العدد): حدّثي القائمة فقط.
      await _load();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MinisterialExamScreen(
          subject: world.id,
          subjectTitleAr: world.name,
          bank: bank,
          onSubmitted: (ExamResult result) {
            // كل امتحان مكتمل يُحفظ في exam_results.
            unawaited(
              DatabaseHelper.instance.recordExamResult(
                examType: 'ministerial_exam',
                subjectId: world.id,
                totalQuestions: result.totalQuestions,
                correctCount: result.correct,
                scorePct: result.accuracyPercent.round(),
                durationMs: result.secondsUsed * 1000,
                isDemo: result.isDemoExam,
              ),
            );
          },
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<WorldDef> available = _availableWorlds;
    return Scaffold(
      appBar: AppBar(title: const Text('الامتحان الوزاري')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Icon(
                  Icons.school,
                  size: 64,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'محاكاة الامتحان الوزاري',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'محاكاة بتوقيت الامتحان الحقيقي وتصحيح فوري وتقرير '
                  'أداء لكل مادة، من أسئلة موثّقة المصدر فقط. الأسئلة '
                  'التجريبية — إن وُجدت — تظهر داخل المحاكاة بعلامة '
                  '«تجريبي» ولا تُقدَّم على أنها أسئلة وزارية حقيقية.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.amber.withValues(alpha: 0.25),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.warning_amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تنبيه مهم: هذه المحاكاة تستخدم أسئلة '
                            'تدريبية من بنك أسئلة المنهج فقط، وليست '
                            'أوراق امتحانات وزارية حقيقية من سنوات '
                            'سابقة. لا تتضمن هذه النسخة من التطبيق أي '
                            'أوراق وزارية سابقة موثّقة، ولا يُقدَّم أي '
                            'سؤال هنا على أنه سؤال وزاري حقيقي، ولا '
                            'تُقدَّم نتيجتك على أنها توقّع لنتيجة '
                            'الامتحان الرسمي.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ما الذي تتضمنه المحاكاة؟',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.timer),
                    title: Text('توقيت حقيقي مثل الامتحان الرسمي'),
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.assignment),
                    title: Text('أسئلة موثّقة المصدر'),
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.assessment),
                    title: Text('تقرير أداء ونقاط ضعف لكل مادة'),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.quiz),
                    title: const Text('أسئلة موثّقة متوفرة حاليًا'),
                    trailing: Text('$_questionCount'),
                  ),
                ),
                const SizedBox(height: 16),
                if (available.isEmpty) ...<Widget>[
                  const Text(
                    'لا توجد أسئلة موثّقة بعد في أي مادة، لذلك لا يمكن '
                    'بدء محاكاة حقيقية — لن نمتحنك بأسئلة مخترعة. '
                    'ستظهر المواد هنا فور توفر أسئلة موثّقة فيها.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppRoutes.worlds),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('تصفحي العوالم'),
                  ),
                ] else ...<Widget>[
                  const Text(
                    'اختاري المادة لبدء المحاكاة:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final WorldDef world in available)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.icon(
                        onPressed: () => _startSubjectExam(world),
                        icon: Icon(world.icon),
                        label: Text(
                          'محاكاة ${world.name} — '
                          '${_countsBySubject[world.id]} سؤالاً',
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
