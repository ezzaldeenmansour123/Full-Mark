import 'package:material_ui/material_ui.dart';

import '../core/progress_store.dart';
import '../core/routes.dart';
import '../db/database.dart';
import 'worlds_screen.dart';

/// التحليلات الذكية المحلية: أرقام حقيقية من قاعدة البيانات فقط.
///
/// لا رسوم بيانية وهمية ولا بيانات تجريبية. إن لم تلعبي أي مرحلة بعد،
/// تعرض الشاشة: «لا توجد بيانات بعد — العب مرحلة أولاً».
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  PlayerProgress _progress = PlayerProgress.empty();
  Map<String, int> _perSubject = <String, int>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SqliteProgressStore store = SqliteProgressStore();
    final PlayerProgress progress = await store.loadProgress();
    final Map<String, int> perSubject =
        await DatabaseHelper.instance.getAttemptsPerSubject();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _perSubject = perSubject;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('التحليلات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _progress.totalAttempts == 0
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      _buildSummaryCard(theme),
                      const SizedBox(height: 16),
                      Text(
                        'المحاولات لكل مادة',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...kWorlds.map((WorldDef world) {
                        final int count = _perSubject[world.id] ?? 0;
                        final int maxCount = _perSubject.values.isEmpty
                            ? 1
                            : _perSubject.values
                                .reduce((int a, int b) => a > b ? a : b);
                        return Card(
                          child: ListTile(
                            leading: Icon(world.icon, color: world.color),
                            title: Text(world.name),
                            subtitle: LinearProgressIndicator(
                              value: maxCount == 0
                                  ? 0
                                  : count / maxCount,
                              color: world.color,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            trailing: Text('$count'),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      const Text(
                        'كل التحليلات تُحسب على جهازك فقط من محاولاتك الحقيقية — '
                        'لا بيانات تُرسل إلى أي مكان.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
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
              Icons.bar_chart,
              size: 72,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات بعد — العب مرحلة أولاً',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ستظهر هنا إحصاءاتك الحقيقية — الدقة، ونقاط القوة والضعف '
              'لكل مادة — فور لعبك أول مرحلة.',
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

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _SummaryRow(
              label: 'إجمالي المحاولات',
              value: '${_progress.totalAttempts}',
            ),
            _SummaryRow(
              label: 'الإجابات الصحيحة',
              value: '${_progress.correctAttempts}',
            ),
            _SummaryRow(
              label: 'الدقة',
              value: '${(_progress.accuracy * 100).round()}%',
            ),
            _SummaryRow(
              label: 'نقاط الخبرة',
              value: '${_progress.xp}',
            ),
            _SummaryRow(
              label: 'النجوم',
              value: '${_progress.stars}',
            ),
            _SummaryRow(
              label: 'المستوى',
              value: '${_progress.level}',
            ),
            _SummaryRow(
              label: 'نسبة الإنجاز',
              value: '${(_progress.completionPercent * 100).round()}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
