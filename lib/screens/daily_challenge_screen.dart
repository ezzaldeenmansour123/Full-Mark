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
/// - إن كان بنك الأسئلة فارغًا، تعرض الشاشة بصراحة أنه لا توجد أسئلة
///   موثّقة بعد — بلا سؤال مزيّف.
/// - إن لعبتِ تحدي اليوم (محاولة تحدي يومي مسجلة اليوم)، تعرض الشاشة
///   أنك أكملتِه مع نتيجتك الأخيرة وزر لإعادته.
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  int _questionCount = 0;

  /// محاولات اليوم بوضع التحدي اليومي فقط — لا محاولات الأوضاع
  /// الأخرى (انظر `getTodayAttemptsCountForMode`).
  int _attemptsToday = 0;
  int? _lastDailyScore;
  String? _lastDailyDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final int questions = await db.getTotalQuestions();
    final int today =
        await db.getTodayAttemptsCountForMode('daily_challenge');
    final int? lastScore =
        int.tryParse(await db.getSetting('last_daily_score') ?? '');
    final String? lastDate = await db.getSetting('last_daily_date');
    if (!mounted) return;
    setState(() {
      _questionCount = questions;
      _attemptsToday = today;
      _lastDailyScore = lastScore;
      _lastDailyDate = lastDate;
      _loading = false;
    });
  }

  /// يحفظ نتيجة تحدي يومي مكتمل: محاولاته في جدول المحاولات بوضع
  /// `daily_challenge` (وهو ما يجعل عدّاد اليوم يعمل) + آخر نتيجة
  /// وتاريخها في الإعدادات لعرضهما في حالة الإكمال.
  Future<void> _saveDailyResult(
    GameResult result,
    List<Question> questions,
  ) async {
    final DatabaseHelper db = DatabaseHelper.instance;
    await db.recordGameResult(
      result: result,
      playedQuestions: questions,
      mode: 'daily_challenge',
    );
    await db.setSetting(
      'last_daily_score',
      '${result.accuracyPercent.round()}',
    );
    await db.setSetting(
      'last_daily_date',
      DateTime.now().toIso8601String(),
    );
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
          onFinished: (GameResult result) async {
            await _saveDailyResult(result, questions);
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
                    'لا توجد أسئلة موثّقة بعد',
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
                  if (_lastDailyScore != null)
                    Text(
                      'نتيجتك الأخيرة: $_lastDailyScore٪'
                      '${_lastDailyDate != null && _lastDailyDate!.length >= 10 ? ' — ${_lastDailyDate!.substring(0, 10)}' : ''}',
                      textAlign: TextAlign.center,
                    ),
                  Text(
                    'محاولات تحدي اليوم: $_attemptsToday. عودي غدًا لتحدٍّ جديد، أو أعيدي تحدي اليوم الآن.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startChallenge,
                    icon: const Icon(Icons.replay),
                    label: const Text('أعيدي تحدي اليوم'),
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
