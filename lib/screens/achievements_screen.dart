import 'package:material_ui/material_ui.dart';

import '../core/progress_store.dart';
import '../db/database.dart';

/// تعريف إنجاز واحد. شروط الفتح تُحسب من بيانات حقيقية فقط
/// (نقاط خبرة / محاولات / نجوم) — لا إنجاز يُمنح دون تحقق.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(PlayerProgress progress) isUnlocked;
}

List<AchievementDef> kAchievementDefs = <AchievementDef>[
  AchievementDef(
    id: 'first_attempt',
    title: 'الخطوة الأولى',
    description: 'أكملي أول محاولة في أي مرحلة.',
    icon: Icons.flag,
    isUnlocked: (PlayerProgress p) => p.totalAttempts >= 1,
  ),
  AchievementDef(
    id: 'ten_attempts',
    title: 'مثابرة',
    description: 'أكملي 10 محاولات.',
    icon: Icons.fitness_center,
    isUnlocked: (PlayerProgress p) => p.totalAttempts >= 10,
  ),
  AchievementDef(
    id: 'fifty_attempts',
    title: 'عبقرية صاعدة',
    description: 'أكملي 50 محاولة.',
    icon: Icons.trending_up,
    isUnlocked: (PlayerProgress p) => p.totalAttempts >= 50,
  ),
  AchievementDef(
    id: 'xp_100',
    title: '100 نقطة خبرة',
    description: 'اجمعي 100 نقطة خبرة.',
    icon: Icons.bolt,
    isUnlocked: (PlayerProgress p) => p.xp >= 100,
  ),
  AchievementDef(
    id: 'xp_500',
    title: '500 نقطة خبرة',
    description: 'اجمعي 500 نقطة خبرة واصعدي مستوى.',
    icon: Icons.military_tech,
    isUnlocked: (PlayerProgress p) => p.xp >= 500,
  ),
  AchievementDef(
    id: 'first_star',
    title: 'أول نجمة',
    description: 'احصلي على أول نجمة بإكمال مرحلة بإتقان.',
    icon: Icons.star,
    isUnlocked: (PlayerProgress p) => p.stars >= 1,
  ),
  AchievementDef(
    id: 'accuracy_80',
    title: 'دقة عالية',
    description: 'حافظي على دقة 80% أو أكثر بعد 10 محاولات على الأقل.',
    icon: Icons.gps_fixed,
    isUnlocked: (PlayerProgress p) =>
        p.totalAttempts >= 10 && p.accuracy >= 0.8,
  ),
];

/// شاشة الإنجازات: تعرض كل إنجاز بحالته الحقيقية (مفتوح/مغلق)،
/// وتسجّل فتحه في جدول achievements عند تحقق شرطه.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  PlayerProgress _progress = PlayerProgress.empty();
  Set<String> _unlocked = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SqliteProgressStore store = SqliteProgressStore();
    final PlayerProgress progress = await store.loadProgress();
    final List<String> unlocked =
        await DatabaseHelper.instance.getUnlockedAchievementIds();
    // سجّل أي إنجاز تحقق شرطه الآن ولم يُسجَّل من قبل.
    for (final AchievementDef def in kAchievementDefs) {
      if (def.isUnlocked(progress) && !unlocked.contains(def.id)) {
        await DatabaseHelper.instance.unlockAchievement(def.id);
        unlocked.add(def.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _unlocked = unlocked.toSet();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الإنجازات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: const Text('إنجازاتك المفتوحة'),
                    trailing: Text(
                      '${_unlocked.length} / ${kAchievementDefs.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_progress.totalAttempts == 0)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'لم تفتحي أي إنجاز بعد — العبي أول مرحلة لتبدئي الجمع.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ...kAchievementDefs.map((AchievementDef def) {
                  final bool open = _unlocked.contains(def.id);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: open
                            ? Colors.amber
                            : theme.disabledColor.withValues(alpha: 0.2),
                        foregroundColor:
                            open ? Colors.white : theme.disabledColor,
                        child: Icon(open ? def.icon : Icons.lock),
                      ),
                      title: Text(
                        def.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: open ? null : theme.disabledColor,
                        ),
                      ),
                      subtitle: Text(def.description),
                      trailing: open
                          ? const Chip(label: Text('مفتوح'))
                          : const Chip(label: Text('مغلق')),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
