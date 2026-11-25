import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../db/database.dart';
import '../games/game_screen.dart';
import '../models/game_result.dart';
import '../models/question.dart';

/// التحدي اليومي: 10 أسئلة كل يوم، اختيار حتمي حسب التاريخ
/// (نفس اليوم = نفس الأسئلة) ومخلوط عبر المواد، من بنك الأسئلة
/// الموثّق — عبر `DatabaseHelper.getDailyChallengeQuestions`.
/// يلعب في `GameScreen` (وضع quiz)، وتُسجَّل نتيجته في جدول
/// المحاولات فتظهر الشاشة حالة الإكمال بعد اللعب.
///
/// السلوك الحقيقي:
/// - إن كان بنك الأسئلة فارغًا، تعرض الشاشة بصراحة أن التحدي
///   قيد الإعداد — بلا سؤال مزيّف.
/// - إن لعبتِ تحدي اليوم (أي محاولة مسجلة اليوم)، تعرض الشاشة
///   أنك أكملتِه (من جدول المحاولات).
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  int _questionCount = 0;
  int _attemptsToday = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final int questions = await db.getTotalQuestions();
    final int today = await db.getAttemptsTodayCount();
    if (!mounted) return;
    setState(() {
      _questionCount = questions;
      _attemptsToday = today;
      _loading = false;
    });
  }

  /// يبدأ تحدي اليوم الحقيقي: 10 أسئلة حتمية من البنك، في لعبة
  /// quiz، وتُسجَّل النتيجة في المحاولات عند الانتهاء فتظهر حالة
  /// الإكمال بعد الرجوع. بنك فارغ: رسالة صادقة، بلا لعبة.
  Future<void> _startChallenge() async {
    final List<Question> questions = await DatabaseHelper.instance
        .getDailyChallengeQuestions(DateTime.now());
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد أسئلة موثّقة بعد لبدء التحدي.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          modeRouteId: 'quiz',
          subject: 'daily',
          subjectTitleAr: 'تحدي اليوم',
          questions: questions,
          onFinished: (GameResult result) {
            unawaited(
              DatabaseHelper.instance.recordGameResult(
                result: result,
                playedQuestions: questions,
                mode: 'daily_challenge',
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
    return Scaffold(
      appBar: AppBar(title: const Text('التحدي اليومي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Icon(
                  Icons.calendar_today,
                  size: 64,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'تحدي اليوم',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_questionCount == 0) ...<Widget>[
                  const Text(
                    'قيد الإعداد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'لا يوجد بنك أسئلة موثّق بعد، لذلك لا يمكن عرض تحدي '
                    'حقيقي اليوم. سيُفعّل التحدي اليومي تلقائيًا فور استيراد '
                    'أسئلة من الكتب الوزارية المعتمدة — ولن نعرض سؤالًا '
                    'مخترعًا على أنه من المنهج.',
                    textAlign: TextAlign.center,
                  ),
                ] else if (_attemptsToday > 0) ...<Widget>[
                  const Text(
                    'أكملتِ تحدي اليوم — أحسنتِ!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'محاولاتك اليوم: $_attemptsToday. عودي غدًا لتحدٍّ جديد.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...<Widget>[
                  const Text(
                    'تحدي اليوم جاهز — ابدئي الآن.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startChallenge,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ابدئي التحدي'),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.quiz),
                    title: const Text('أسئلة موثّقة في بنك الأسئلة'),
                    trailing: Text('$_questionCount'),
                  ),
                ),
              ],
            ),
    );
  }
}
