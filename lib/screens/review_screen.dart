import 'package:material_ui/material_ui.dart';

import '../core/routes.dart';
import '../db/database.dart';

/// المراجعة الذكية: تعيد عرض الأسئلة التي أخطأتِ فيها أو التي حان
/// وقت مراجعتها (جدول review_queue).
///
/// في v1: إن كانت القائمة فارغة — وهي كذلك قبل أي لعب — تعرض الشاشة
/// حالة فراغ صادقة. لا أسئلة وهمية ولا عناصر مراجعة مخترعة.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _dueCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int count = await DatabaseHelper.instance.getReviewQueueCount();
    if (!mounted) return;
    setState(() {
      _dueCount = count;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('المراجعة الذكية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dueCount == 0
              ? _buildEmptyState(theme)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.replay),
                        title: const Text('عناصر مستحقة للمراجعة'),
                        trailing: Text(
                          '$_dueCount',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // يُربط بجلسة المراجعة عندما يبني وكيل اللعب منطقه.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'جلسة المراجعة قيد الربط ببنك الأسئلة — عودي قريبًا',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('ابدئي المراجعة'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تعتمد المراجعة على أخطائك الحقيقية في المراحل، '
                      'وتعيد عرض كل سؤال في الوقت الأنسب لتثبيته.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
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
            Text(
              'لا توجد عناصر للمراجعة بعد',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'عندما تلعبين مراحل وتخطئين في بعض الأسئلة، ستظهر هنا '
              'للمراجعة في الوقت المناسب — ليثبت التعلم ولا يُنسى.',
              textAlign: TextAlign.center,
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
}
