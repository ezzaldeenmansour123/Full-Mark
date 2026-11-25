import 'package:material_ui/material_ui.dart';

import '../core/progress_store.dart';
import '../core/routes.dart';
import '../core/theme.dart';

/// الشاشة الرئيسية: الشعار، اسم اللاعبة، المستوى والخبرة والنجوم ونسبة
/// الإنجاز، زر متابعة آخر مرحلة، وأزرار كل أقسام التطبيق.
///
/// كل زر ينتقل إلى شاشة حقيقية. لا أزرار ميتة في هذا التطبيق.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _nameController;
  PlayerProgress _progress = PlayerProgress.empty();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final PlayerProgress progress = await widget.store.loadProgress();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _nameController.text = progress.playerName ?? '';
      _loading = false;
    });
  }

  Future<void> _saveName() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    await widget.store.setPlayerName(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ اسمك على جهازك')),
    );
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('عبقرية'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRoutes.settings)
                .then((_) => _load()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  _buildHeader(theme),
                  const SizedBox(height: 20),
                  _buildNameField(theme),
                  const SizedBox(height: 20),
                  _buildStatsCard(theme),
                  const SizedBox(height: 20),
                  _buildContinueButton(theme),
                  const SizedBox(height: 24),
                  Text(
                    'أقسام المنصة',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuGrid(),
                  const SizedBox(height: 16),
                  const Text(
                    'كل تقدّمك محفوظ على جهازك فقط — بلا حسابات وبلا إنترنت.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AbqariyaColors.muted),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: <Widget>[
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: AbqariyaColors.navy,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'ع',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: AbqariyaColors.goldSoft,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'عَبْقَرِيّة',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AbqariyaColors.navy,
          ),
        ),
        Text(
          'افهم، جرّب، اكتشف، وتفوّق',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return TextField(
      controller: _nameController,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _saveName(),
      decoration: InputDecoration(
        labelText: 'اسمك',
        hintText: 'اكتبي اسمك ليُحفظ على جهازك',
        prefixIcon: const Icon(Icons.person),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check),
          tooltip: 'حفظ الاسم',
          onPressed: _saveName,
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final int xpInLevel = _progress.xp % 500;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _StatItem(
                  icon: Icons.military_tech,
                  label: 'المستوى',
                  value: '${_progress.level}',
                ),
                _StatItem(
                  icon: Icons.bolt,
                  label: 'نقاط الخبرة',
                  value: '${_progress.xp}',
                ),
                _StatItem(
                  icon: Icons.star,
                  label: 'النجوم',
                  value: '${_progress.stars}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('نسبة الإنجاز'),
                Text(
                  '${(_progress.completionPercent * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _progress.completionPercent,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 8),
            Text(
              'المستوى ${_progress.level} — $xpInLevel / 500 نقطة للمستوى التالي',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(ThemeData theme) {
    final bool hasLastStage = _progress.lastStageId != null &&
        _progress.lastStageTitle != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (hasLastStage) {
            // المرحلة نفسها تُبنى من المحتوى؛ حتى تتوفر، نفتح خريطة العوالم.
            Navigator.of(context).pushNamed(AppRoutes.worlds);
          } else {
            Navigator.of(context).pushNamed(AppRoutes.worlds);
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: Text(
          hasLastStage
              ? 'متابعة: ${_progress.lastStageTitle}'
              : 'ابدئي أول مرحلة',
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    const List<_MenuEntry> entries = <_MenuEntry>[
      _MenuEntry(
        title: 'خريطة العوالم',
        subtitle: 'المواد السبع',
        icon: Icons.map,
        route: AppRoutes.worlds,
      ),
      _MenuEntry(
        title: 'المختبرات',
        subtitle: 'تجارب تفاعلية',
        icon: Icons.science,
        route: AppRoutes.labs,
      ),
      _MenuEntry(
        title: 'التحدي اليومي',
        subtitle: 'سؤال كل يوم',
        icon: Icons.calendar_today,
        route: AppRoutes.dailyChallenge,
      ),
      _MenuEntry(
        title: 'الامتحان الوزاري',
        subtitle: 'محاكاة الامتحان',
        icon: Icons.school,
        route: AppRoutes.exam,
      ),
      _MenuEntry(
        title: 'التحليلات',
        subtitle: 'تقدّمك بالأرقام',
        icon: Icons.bar_chart,
        route: AppRoutes.analytics,
      ),
      _MenuEntry(
        title: 'الإنجازات',
        subtitle: 'الشارات والجوائز',
        icon: Icons.emoji_events,
        route: AppRoutes.achievements,
      ),
      _MenuEntry(
        title: 'المراجعة الذكية',
        subtitle: 'ثبّتي ما تعلمتِه',
        icon: Icons.replay,
        route: AppRoutes.review,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final _MenuEntry entry = entries[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).pushNamed(entry.route),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    entry.icon,
                    size: 34,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    entry.subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: AbqariyaColors.gold, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
