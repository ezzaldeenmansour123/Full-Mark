import 'package:material_ui/material_ui.dart';

import '../analytics/analytics_engine.dart';
import '../core/progress_store.dart';
import '../core/routes.dart';
import '../db/database.dart';
import '../models/question.dart';
import 'worlds_screen.dart';

/// التحليلات الذكية المحلية: أرقام حقيقية من قاعدة البيانات فقط.
///
/// تُبنى من كل صفوف المحاولات ([DatabaseHelper.getAllAttempts]) عبر
/// [AnalyticsEngine.summarize] — الإتقان لكل مادة، وأضعف/أقوى الوحدات،
/// واتجاه الدقة اليومي لآخر 7 أيام بها بيانات. مع أقل من 5 محاولات
/// يظهر نص صادق بأن البيانات غير كافية، ولا يُعرض أي اتجاه أو ادعاء.
/// لا رسوم بيانية وهمية ولا بيانات تجريبية.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  PlayerProgress _progress = PlayerProgress.empty();
  Map<String, int> _perSubject = <String, int>{};
  AnalyticsSummary? _summary;
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
    final AnalyticsSummary summary = await _buildSummary();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _perSubject = perSubject;
      _summary = summary;
      _loading = false;
    });
  }

  /// Build the engine summary from raw attempt rows. Attempt rows hold
  /// only a question id, so subject/unit come from the question bank
  /// (one lookup per subject); seconds come from the row's time_ms.
  Future<AnalyticsSummary> _buildSummary() async {
    final List<Map<String, Object?>> rows =
        await DatabaseHelper.instance.getAllAttempts();
    final Map<String, Question> byId = <String, Question>{};
    for (final world in kWorlds) {
      final questions =
          await DatabaseHelper.instance.getQuestionsForSubject(world.id);
      for (final q in questions) {
        byId[q.id] = q;
      }
    }
    final attempts = <Attempt>[];
    for (final row in rows) {
      final questionId = row['question_id'] as String? ?? '';
      final q = byId[questionId];
      final answeredAt = row['answered_at'] as int? ?? 0;
      attempts.add(Attempt(
        questionId: questionId,
        subject: q?.subject ?? 'unknown',
        unit: q?.unit ?? '',
        correct: (row['is_correct'] as int? ?? 0) == 1,
        secondsTaken: ((row['time_ms'] as int? ?? 0) / 1000).round(),
        at: DateTime.fromMillisecondsSinceEpoch(answeredAt),
      ));
    }
    return AnalyticsEngine.summarize(attempts);
  }

  String _subjectName(String subjectId) {
    for (final world in kWorlds) {
      if (world.id == subjectId) return world.name;
    }
    return subjectId;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AnalyticsSummary? summary = _summary;
    return Scaffold(
      appBar: AppBar(title: const Text('التحليلات')),
      body: _loading || summary == null
          ? const Center(child: CircularProgressIndicator())
          : !summary.hasEnoughData
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      _buildSummaryCard(theme, summary),
                      const SizedBox(height: 16),
                      _buildMasterySection(theme, summary),
                      const SizedBox(height: 16),
                      _buildWeakStrongSection(theme, summary),
                      const SizedBox(height: 16),
                      _buildTrendSection(theme, summary),
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
              'لا توجد بيانات كافية بعد — العبي بعض الدروس وستظهر هنا التحليلات',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تظهر التحليلات بعد 5 محاولات على الأقل — الدقة، ونقاط '
              'القوة والضعف لكل مادة ووحدة، واتجاه آخر 7 أيام.',
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

  Widget _buildSummaryCard(ThemeData theme, AnalyticsSummary summary) {
    final double? readiness = summary.readinessIndicator;
    final double? avgSeconds = summary.avgSecondsPerQuestion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _SummaryRow(
              label: 'إجمالي المحاولات',
              value: '${summary.totalAttempts}',
            ),
            _SummaryRow(
              label: 'الإجابات الصحيحة',
              value: '${summary.totalCorrect}',
            ),
            _SummaryRow(
              label: 'الدقة',
              value: summary.overallAccuracy == null
                  ? '—'
                  : '${summary.overallAccuracy!.round()}%',
            ),
            if (readiness != null)
              _SummaryRow(
                label: 'مؤشر الجاهزية (وليس توقعاً للامتحان)',
                value: '${readiness.round()}%',
              ),
            if (avgSeconds != null && avgSeconds > 0)
              _SummaryRow(
                label: 'متوسط الوقت لكل سؤال',
                value: '${avgSeconds.toStringAsFixed(1)} ث',
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

  Widget _buildMasterySection(ThemeData theme, AnalyticsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'الإتقان لكل مادة',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...summary.masteryBySubject.map((MasteryEntry m) => Card(
              child: ListTile(
                title: Text(_subjectName(m.subject)),
                subtitle: LinearProgressIndicator(
                  value: m.accuracyPercent / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                trailing: Text(
                  '${m.accuracyPercent.round()}% (${m.correct}/${m.attempts})',
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildWeakStrongSection(
      ThemeData theme, AnalyticsSummary summary) {
    Widget unitList(String title, List<MasteryEntry> entries) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text('لا توجد وحدات بمحاولات كافية بعد (3 محاولات لكل وحدة).'),
          ...entries.map((MasteryEntry m) => Card(
                child: ListTile(
                  title: Text(m.key),
                  trailing: Text(
                    '${m.accuracyPercent.round()}% (${m.correct}/${m.attempts})',
                  ),
                ),
              )),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        unitList('أضعف الوحدات (تحتاج مراجعة)', summary.weakestUnits),
        const SizedBox(height: 16),
        unitList('أقوى الوحدات', summary.strongestUnits),
      ],
    );
  }

  Widget _buildTrendSection(ThemeData theme, AnalyticsSummary summary) {
    final List<double> trend = summary.accuracyTrend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'اتجاه الدقة اليومي (آخر الأيام التي لعبتِ فيها)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (trend.isEmpty)
          const Text('لا يوجد اتجاه بعد — يظهر بعد لعب أيام متعددة.'),
        ...trend.asMap().entries.map((entry) => Card(
              child: ListTile(
                title: Text('اليوم ${entry.key + 1}'),
                subtitle: LinearProgressIndicator(
                  value: entry.value / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                trailing: Text('${entry.value.round()}%'),
              ),
            )),
      ],
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
