import '../db/database.dart';

/// نقاط الخبرة اللازمة لكل مستوى: المستوى 1 من 0، ثم كل 500 نقطة مستوى جديد.
/// دالة نقية — قابلة للاختبار دون قاعدة بيانات.
int levelForXp(int xp) {
  if (xp < 0) return 1;
  return 1 + xp ~/ 500;
}

/// نقاط الخبرة المتبقية للوصول إلى المستوى التالي.
int xpToNextLevel(int xp) {
  final int level = levelForXp(xp);
  return level * 500 - xp;
}

/// لقطة تقدّم اللاعب المعروضة في الواجهة.
class PlayerProgress {
  const PlayerProgress({
    required this.xp,
    required this.stars,
    required this.level,
    required this.completionPercent,
    required this.totalAttempts,
    required this.correctAttempts,
    this.lastStageId,
    this.lastStageTitle,
    this.playerName,
  });

  final int xp;
  final int stars;
  final int level;
  final double completionPercent; // 0.0 .. 1.0
  final int totalAttempts;
  final int correctAttempts;
  final String? lastStageId;
  final String? lastStageTitle;
  final String? playerName;

  double get accuracy =>
      totalAttempts == 0 ? 0 : correctAttempts / totalAttempts;

  factory PlayerProgress.empty() => const PlayerProgress(
        xp: 0,
        stars: 0,
        level: 1,
        completionPercent: 0,
        totalAttempts: 0,
        correctAttempts: 0,
      );
}

/// واجهة التقدّم المجرّدة — تفصل الشاشات عن SQLite.
/// التطبيق الحالي يستخدم [SqliteProgressStore]؛ ويمكن استبداله بتخزين
/// آخر دون تغيير أي شاشة.
abstract class ProgressStore {
  Future<void> init();
  Future<PlayerProgress> loadProgress();
  Future<void> addXp(int xp, {int stars = 0});
  Future<void> saveLastStage(String stageId, String stageTitle);
  Future<void> recordAttempt({
    String? stageId,
    String? questionId,
    required bool isCorrect,
    int xpEarned = 0,
  });
  Future<void> resetAll();
  Future<String?> getPlayerName();
  Future<void> setPlayerName(String name);
  Future<bool> isSoundEnabled();
  Future<void> setSoundEnabled(bool enabled);
  Future<bool> isDarkMode();
  Future<void> setDarkMode(bool enabled);
}

/// التنفيذ الافتراضي فوق SQLite عبر [DatabaseHelper].
class SqliteProgressStore implements ProgressStore {
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  Future<void> init() async {
    // فتح قاعدة البيانات ينشئ الجداول ويزرع المواد وصف اللاعب.
    await _db.database;
  }

  @override
  Future<PlayerProgress> loadProgress() async {
    final Map<String, Object?> row = await _db.getProgressRow();
    final Map<String, int> stats = await _db.getAttemptStats();
    final double completion = await _db.getCompletionPercent();
    final String? name = await getPlayerName();
    final int xp = (row['xp'] as int? ?? 0);
    return PlayerProgress(
      xp: xp,
      stars: (row['stars'] as int? ?? 0),
      level: levelForXp(xp),
      completionPercent: completion,
      totalAttempts: stats['total'] ?? 0,
      correctAttempts: stats['correct'] ?? 0,
      lastStageId: row['last_stage_id'] as String?,
      lastStageTitle: row['last_stage_title'] as String?,
      playerName: name,
    );
  }

  @override
  Future<void> addXp(int xp, {int stars = 0}) =>
      _db.addXp(xp, stars: stars);

  @override
  Future<void> saveLastStage(String stageId, String stageTitle) =>
      _db.setLastStage(stageId, stageTitle);

  @override
  Future<void> recordAttempt({
    String? stageId,
    String? questionId,
    required bool isCorrect,
    int xpEarned = 0,
  }) =>
      _db.recordAttempt(
        stageId: stageId,
        questionId: questionId,
        isCorrect: isCorrect,
        xpEarned: xpEarned,
      );

  @override
  Future<void> resetAll() => _db.clearAllProgress();

  @override
  Future<String?> getPlayerName() => _db.getSetting('player_name');

  @override
  Future<void> setPlayerName(String name) =>
      _db.setSetting('player_name', name.trim());

  @override
  Future<bool> isSoundEnabled() async {
    final String? value = await _db.getSetting('sound_enabled');
    return value != '0'; // الافتراضي: الصوت مفعّل.
  }

  @override
  Future<void> setSoundEnabled(bool enabled) =>
      _db.setSetting('sound_enabled', enabled ? '1' : '0');

  @override
  Future<bool> isDarkMode() async {
    final String? value = await _db.getSetting('dark_mode');
    return value == '1'; // الافتراضي: الوضع الفاتح.
  }

  @override
  Future<void> setDarkMode(bool enabled) =>
      _db.setSetting('dark_mode', enabled ? '1' : '0');
}
