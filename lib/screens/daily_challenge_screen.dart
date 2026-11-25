import 'package:flutter/material.dart';

import '../db/database.dart';

/// التحدي اليومي: سؤال/مرحلة قصيرة كل يوم.
///
/// السلوك الحقيقي في v1:
/// - إن كان بنك الأسئلة فارغًا (الحال الآن)، تعرض الشاشة بصراحة أن
///   التحدي قيد الإعداد وأنه سيُفعّل فور وصول محتوى موثّق — بلا سؤال مزيّف.
/// - إن لعبتِ تحدي اليوم، تعرض الشاشة أنك أكملتِه (من جدول المحاولات).
/// منطق اختيار سؤال اليوم يملكه وكيل المحتوى/الأسئلة عند توفر البنك.
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
                    onPressed: () {
                      // يُربط بمرحلة التحدي عندما يبني وكيل اللعب منطقه.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('مرحلة التحدي قيد الربط — عودي قريبًا'),
                        ),
                      );
                    },
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
