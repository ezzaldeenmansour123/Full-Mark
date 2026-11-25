import 'package:flutter/material.dart';

import '../db/database.dart';
import '../exam/ministerial_exam_screen.dart';
import '../models/question.dart';
import 'worlds_screen.dart';

/// محاكاة الامتحان الوزاري — شاشة الإطلاق القابلة للتوجيه.
///
/// في v1 هذه شاشة هيكل صادقة: تعرض ما ستقدمه المحاكاة عند توفر أسئلة
/// وزارية موثّقة، وتعرض عدد الأسئلة المتوفرة فعليًا (صفر الآن).
/// لا تُعرض أسئلة مزيّفة على أنها أسئلة وزارية سابقة أبدًا.
///
/// عند توفر أسئلة في قاعدة البيانات، تعرض أزرار المواد؛ والضغط على
/// مادة يفتح شاشة الامتحان الحقيقية (`MinisterialExamScreen` في
/// `lib/exam/`) بأسئلة تلك المادة من قاعدة البيانات — لا زرّ هنا
/// وهمي: الزر المعطّل الوحيد هو زر البدء عند غياب الأسئلة، مع شرح
/// السبب تحته.
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  int _questionCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int count = await DatabaseHelper.instance.getTotalQuestions();
    if (!mounted) return;
    setState(() {
      _questionCount = count;
      _loading = false;
    });
  }

  Future<void> _startSubjectExam(WorldDef world) async {
    final List<Question> bank =
        await DatabaseHelper.instance.getQuestionsForSubject(world.id);
    if (!mounted) return;
    if (bank.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا توجد أسئلة موثّقة بعد في عالم ${world.name}.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MinisterialExamScreen(
          subject: world.id,
          subjectTitleAr: world.name,
          bank: bank,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
                  'قيد الإعداد — ستُبنى هذه المحاكاة من أسئلة وزارية سابقة '
                  'موثّقة المصدر فقط، بتوقيت الامتحان الحقيقي وتصحيح فوري '
                  'وتقرير أداء لكل مادة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'ما الذي ستتضمنه المحاكاة؟',
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
                    title: Text('أسئلة وزارية سابقة موثّقة المصدر'),
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
                if (_questionCount == 0) ...<Widget>[
                  const ElevatedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.play_arrow),
                    label: Text('ابدئي المحاكاة'),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'الزر معطّل حتى تتوفر أسئلة موثّقة — لن نمتحنك بأسئلة مخترعة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ] else ...<Widget>[
                  const Text(
                    'اختاري المادة لبدء المحاكاة:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final WorldDef world in kWorlds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.icon(
                        onPressed: () => _startSubjectExam(world),
                        icon: Icon(world.icon),
                        label: Text('محاكاة ${world.name}'),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
