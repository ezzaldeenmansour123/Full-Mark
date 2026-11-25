import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../content/question_packs.dart';
import '../models/question.dart';
import 'schema.dart';

/// مساعد قاعدة البيانات المحلية — نقطة الوصول الوحيدة إلى SQLite.
///
/// CANONICAL (merge pass 2026-11-25): هذا الملف هو التنفيذ الوحيد لمخطط
/// `lib/db/schema.dart` (v2). كان يوجد تنفيذ ثانٍ مبسّط ومتعارض في هذا
/// الملف نفسه (جداول بأعمدة مختلفة: subjects بدون name_ar، وأسئلة
/// stage_id/stem/options، وجدول settings بدل app_meta، وتقدّم من صف
/// واحد) — أُزيل بالكامل واستُبدل بهذا التنفيذ المتوافق مع المخطط.
///
/// مبادئ:
/// - كل البيانات على الجهاز فقط. لا إنترنت ولا خوادم ولا حسابات.
/// - الإصدار 2. الترقية v1 -> v2 في [_onUpgrade] فقط، مع الحفاظ على
///   تقدّم اللاعب (انظر التعليق هناك — v1 لم تُشحن على أي جهاز، لذا
///   الترقية دفاعية وتجمّع المحاولات القديمة في عدّادات بدل إسقاطها).
/// - إعدادات اللاعب وإجمالياته في جدول `app_meta` (لا جدول `settings`).
/// - هيكل المنهج (صنعاء 2027) يُزرع عبر [seedCurriculumRows] من
///   `CurriculumData.seedRows()`؛ ويستدعيه `main()` عبر
///   [seedCurriculumIfEmpty] عند أول تشغيل فقط (لا زرع في onCreate،
///   حتى لا يعتمد فتح قاعدة البيانات على أصول Flutter).
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String dbName = kDatabaseName;
  static const int dbVersion = kDatabaseVersion;

  // أسماء الجداول — يشار إليها من بقية التطبيق بهذه الثوابت.
  static const String tableSubjects = 'subjects';
  static const String tableUnits = 'units';
  static const String tableLessons = 'lessons';
  static const String tableStages = 'stages';
  static const String tableQuestions = 'questions';
  static const String tableAttempts = 'attempts';
  static const String tableProgress = 'progress';
  static const String tableAchievements = 'achievements';
  static const String tableReviewQueue = 'review_queue';
  static const String tableExamResults = 'exam_results';
  static const String tableAppMeta = 'app_meta';

  /// صف التقدم الوحيد (لاعب واحد محلي، بلا حساب).
  /// في المخطط الرسمي لا يوجد صف لاعب في جدول progress (هو لكل كيان)؛
  /// إجماليات اللاعب تُحفظ في app_meta بهذه المفاتيح.
  static const String playerRowId = 'player';

  Database? _db;

  Future<Database> get database async {
    final Database? existing = _db;
    if (existing != null) return existing;
    final Database db = await _init();
    _db = db;
    return db;
  }

  Future<Database> _init() async {
    final String databasesPath = await getDatabasesPath();
    final String path = p.join(databasesPath, dbName);
    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final Batch batch = db.batch();
    for (final String statement in kCreateAllStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
    await _seedAchievements(db);
    await _seedAppMetaDefaults(db);
  }

  // ---------------------------------------------------------- ترقية v1 -> v2

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateV1ToV2(db);
    }
  }

  /// ترقية v1 (التنفيذ المبسّط القديم) إلى المخطط الرسمي v2.
  ///
  /// حقيقة مهمة: v1 لم تُشحن أبداً على جهاز حقيقي (لا APK بُني بعد)،
  /// فلا توجد بيانات مستخدم حقيقية متوقعة. مع ذلك لا تُسقَط بيانات
  /// بصمت: تُقرأ بيانات v1 أولاً، ثم تُعاد كتابتها في المخطط الجديد:
  /// - الإعدادات (player_name/sound_enabled/dark_mode) تُنقل كما هي.
  /// - إجماليات اللاعب (XP/نجوم/آخر مرحلة) تُنقل إلى app_meta.
  /// - الإنجازات المفتوحة تُنقل (بعد زرع كتالوج الإنجازات).
  /// - المحاولات: صفوف v1 تشير إلى أسئلة بجدول أسئلة قديم أُزيل، ولا
  ///   يمكن ربطها بمفاتيح أجنبية في المخطط الجديد، فتُجمَّع في عدّادات
  ///   app_meta (legacy_attempts_total/correct/xp) بدل حذفها، وتُسجَّل
  ///   أعدادها في app_meta للتدقيق.
  /// - قائمة المراجعة: لا يمكن ربط صفوفها بأسئلة غير موجودة، فتُسجَّل
  ///   أعدادها المسقَطة في app_meta (migration_review_dropped).
  Future<void> _migrateV1ToV2(Database db) async {
    // 1) اكتشاف: هل هذه فعلاً قاعدة v1 القديمة؟ علامتاها: جدول
    // `settings`، أو جدول subjects بلا عمود name_ar.
    bool isLegacy = false;
    int legacyAttempts = 0;
    int legacyCorrect = 0;
    int legacyXp = 0;
    int legacyReview = 0;
    int playerXp = 0;
    int playerStars = 0;
    String? lastStageId;
    String? lastStageTitle;
    final Map<String, String> legacySettings = <String, String>{};
    final List<String> legacyAchievementIds = <String>[];
    try {
      final List<Map<String, Object?>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('settings','subjects')",
      );
      final Set<String> names =
          tables.map((Map<String, Object?> r) => r['name'] as String).toSet();
      if (names.contains('settings')) {
        isLegacy = true;
      } else if (names.contains('subjects')) {
        final List<Map<String, Object?>> cols =
            await db.rawQuery('PRAGMA table_info(subjects)');
        final bool hasNameAr = cols.any(
            (Map<String, Object?> c) => c['name'] == 'name_ar');
        isLegacy = !hasNameAr;
      }
      if (isLegacy) {
        final List<Map<String, Object?>> settingsRows = await db.query('settings');
        for (final Map<String, Object?> row in settingsRows) {
          legacySettings[row['key'] as String] =
              row['value']?.toString() ?? '';
        }
        final List<Map<String, Object?>> progressRows =
            await db.query('progress', limit: 1);
        if (progressRows.isNotEmpty) {
          final Map<String, Object?> row = progressRows.first;
          playerXp = (row['xp'] as int? ?? 0);
          playerStars = (row['stars'] as int? ?? 0);
          lastStageId = row['last_stage_id'] as String?;
          lastStageTitle = row['last_stage_title'] as String?;
        }
        final List<Map<String, Object?>> attemptRows =
            await db.rawQuery(
                'SELECT is_correct, xp_earned FROM attempts');
        legacyAttempts = attemptRows.length;
        for (final Map<String, Object?> row in attemptRows) {
          if ((row['is_correct'] as int? ?? 0) == 1) legacyCorrect++;
          legacyXp += (row['xp_earned'] as int? ?? 0);
        }
        final List<Map<String, Object?>> achRows =
            await db.query('achievements');
        legacyAchievementIds.addAll(
            achRows.map((Map<String, Object?> r) => r['id'] as String));
        final List<Map<String, Object?>> reviewRows =
            await db.rawQuery('SELECT COUNT(*) AS c FROM review_queue');
        legacyReview = (reviewRows.first['c'] as int? ?? 0);
      }
    } catch (_) {
      // أي فشل في القراءة يعني قاعدة غير مكتملة/تالفة جزئياً: نعاملها
      // كقاعدة جديدة (الجداول الرسمية ستُنشأ أدناه) دون حذف صامت
      // لبيانات لم نستطع قراءتها — تُسجَّل الحالة في app_meta.
      isLegacy = false;
    }

    // 2) إسقاط جداول v1 (بعد نسخ ما يمكن نسخه) وإنشاء المخطط الرسمي.
    await db.transaction((Transaction txn) async {
      for (final String t in <String>[
        'attempts', 'review_queue', 'exam_results', 'progress',
        'achievements', 'questions', 'stages', 'lessons', 'units',
        'subjects', 'settings',
      ]) {
        await txn.execute('DROP TABLE IF EXISTS $t;');
      }
      for (final String statement in kCreateAllStatements) {
        await txn.execute(statement);
      }
    });
    await _seedAchievements(db);
    await _seedAppMetaDefaults(db);

    // 3) استعادة ما نُسخ.
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (isLegacy) {
      await db.transaction((Transaction txn) async {
        for (final MapEntry<String, String> e in legacySettings.entries) {
          if (e.key == 'player_name' ||
              e.key == 'sound_enabled' ||
              e.key == 'dark_mode') {
            await txn.insert(
              tableAppMeta,
              <String, Object>{
                'key': e.key,
                'value': e.value,
                'updated_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await txn.insert(
          tableAppMeta,
          <String, Object>{
            'key': 'player_xp',
            'value': '$playerXp',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          tableAppMeta,
          <String, Object>{
            'key': 'player_stars',
            'value': '$playerStars',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (lastStageId != null) {
          await txn.insert(
            tableAppMeta,
            <String, Object>{
              'key': 'last_stage_id',
              'value': lastStageId,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (lastStageTitle != null) {
          await txn.insert(
            tableAppMeta,
            <String, Object>{
              'key': 'last_stage_title',
              'value': lastStageTitle,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await txn.insert(
          tableAppMeta,
          <String, Object>{
            'key': 'legacy_attempts_total',
            'value': '$legacyAttempts',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          tableAppMeta,
          <String, Object>{
            'key': 'legacy_attempts_correct',
            'value': '$legacyCorrect',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          tableAppMeta,
          <String, Object>{
            'key': 'legacy_attempts_xp',
            'value': '$legacyXp',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          tableAppMeta,
          <String, Object>{
            'key': 'migration_review_dropped',
            'value': '$legacyReview',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          tableAppMeta,
          <String, Object>{
            'key': 'migration_from_version',
            'value': '1',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final String id in legacyAchievementIds) {
          await txn.update(
            tableAchievements,
            <String, Object>{
              'is_unlocked': 1,
              'unlocked_at': now,
            },
            where: 'id = ?',
            whereArgs: <Object?>[id],
          );
        }
      });
    }
  }

  // ------------------------------------------------------------------- زرع

  /// كتالوج الإنجازات — مطابق لتعريفات `lib/screens/achievements_screen.dart`
  /// (kAchievementDefs) حتى لا يختلف الشرط في الواجهة عن المُخزَّن.
  static const List<Map<String, Object>> _achievementCatalogue =
      <Map<String, Object>>[
    <String, Object>{
      'id': 'first_attempt',
      'title_ar': 'الخطوة الأولى',
      'description_ar': 'أكملي أول محاولة في أي مرحلة.',
      'icon_key': 'flag',
      'condition_type': 'attempts',
      'condition_value': 1,
    },
    <String, Object>{
      'id': 'ten_attempts',
      'title_ar': 'مثابرة',
      'description_ar': 'أكملي 10 محاولات.',
      'icon_key': 'fitness_center',
      'condition_type': 'attempts',
      'condition_value': 10,
    },
    <String, Object>{
      'id': 'fifty_attempts',
      'title_ar': 'عبقرية صاعدة',
      'description_ar': 'أكملي 50 محاولة.',
      'icon_key': 'trending_up',
      'condition_type': 'attempts',
      'condition_value': 50,
    },
    <String, Object>{
      'id': 'xp_100',
      'title_ar': '100 نقطة خبرة',
      'description_ar': 'اجمعي 100 نقطة خبرة.',
      'icon_key': 'bolt',
      'condition_type': 'xp',
      'condition_value': 100,
    },
    <String, Object>{
      'id': 'xp_500',
      'title_ar': '500 نقطة خبرة',
      'description_ar': 'اجمعي 500 نقطة خبرة واصعدي مستوى.',
      'icon_key': 'military_tech',
      'condition_type': 'xp',
      'condition_value': 500,
    },
    <String, Object>{
      'id': 'first_star',
      'title_ar': 'أول نجمة',
      'description_ar': 'احصلي على أول نجمة بإكمال مرحلة بإتقان.',
      'icon_key': 'star',
      'condition_type': 'stars',
      'condition_value': 1,
    },
    <String, Object>{
      'id': 'accuracy_80',
      'title_ar': 'دقة عالية',
      'description_ar': 'حافظي على دقة 80% أو أكثر بعد 10 محاولات على الأقل.',
      'icon_key': 'gps_fixed',
      'condition_type': 'accuracy',
      'condition_value': 80,
    },
  ];

  Future<void> _seedAchievements(DatabaseExecutor db) async {
    for (final Map<String, Object> def in _achievementCatalogue) {
      await db.insert(
        tableAchievements,
        <String, Object?>{
          'id': def['id'],
          'title_ar': def['title_ar'],
          'description_ar': def['description_ar'],
          'icon_key': def['icon_key'],
          'condition_type': def['condition_type'],
          'condition_value': def['condition_value'],
          'is_unlocked': 0,
          'unlocked_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _seedAppMetaDefaults(DatabaseExecutor db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final MapEntry<String, String> e
        in <String, String>{
          'db_version': '$dbVersion',
          'demo_visible': '1',
          'dark_mode': '0',
          'sound_enabled': '1',
          'onboarding_done': '0',
          'player_xp': '0',
          'player_stars': '0',
        }.entries) {
      await db.insert(
        tableAppMeta,
        <String, Object>{'key': e.key, 'value': e.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// يزرع هيكل المنهج (مواد/وحدات/دروس — بلا أسئلة) من صفوف
  /// `CurriculumData.seedRows()`. آمن لإعادة التشغيل (INSERT OR REPLACE).
  /// يسجّل حزمة محتوى `sanaa-2027` بعدد أسئلة صفر — الأسئلة «قيد الإعداد».
  Future<void> seedCurriculumRows(List<Map<String, Object>> rows) async {
    final Database db = await database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      for (final Map<String, Object> row in rows) {
        final String table = row['table'] as String;
        final Map<String, Object?> values =
            Map<String, Object?>.from(row)..remove('table');
        await txn.insert(
          table,
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'content_packs',
        <String, Object?>{
          'id': 'sanaa-2027',
          'title_ar': 'المنهج اليمني — نسخة صنعاء 2027 (هيكل فقط)',
          'source': 'yemenbooks / yembooks — فهارس الكتب الرسمية',
          'is_demo': 0,
          'schema_version': 1,
          'question_count': 0,
          'file_sha256': null,
          'status': 'imported',
          'imported_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        tableAppMeta,
        <String, Object>{
          'key': 'curriculum_edition',
          'value': 'sanaa',
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        tableAppMeta,
        <String, Object>{
          'key': 'curriculum_seeded_at',
          'value': '$now',
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// يزرع هيكل المنهج عند أول تشغيل فقط (جدول الوحدات فارغ).
  /// يُستدعى من `main()` بعد فتح قاعدة البيانات؛ أي فشل في تحميل
  /// الأصل لا يمنع تشغيل التطبيق (يلتقطه main ويتجاهله بصمت).
  Future<void> seedCurriculumIfEmpty(
    Future<List<Map<String, Object>>> Function() loadRows,
  ) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM $tableUnits');
    if ((rows.first['c'] as int? ?? 0) > 0) return;
    final List<Map<String, Object>> seedRows = await loadRows();
    await seedCurriculumRows(seedRows);
  }

  /// يزرع حزم الأسئلة الموثقة بعد زرع هيكل المنهج (مفاتيح أجنبية).
  /// آمن لإعادة التشغيل: الحزمة التي سُجّلت في `content_packs` بنفس
  /// عدد الأسئلة تُتخطَّى، وغيرها تُستبدل صفوفها (INSERT OR REPLACE)
  /// في معاملة واحدة — لا حزمة نصف مستوردة أبداً. يحدّث إجمالي
  /// أسئلة حزمة `sanaa-2027`. يُستدعى من `main()` بعد زرع المنهج؛
  /// أي فشل لا يمنع التشغيل (تبقى الأسئلة «قيد الإعداد»).
  Future<void> seedQuestionPacks(List<QuestionPackSeed> packs) async {
    final Database db = await database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final QuestionPackSeed pack in packs) {
      if (pack.rows.isEmpty) continue;
      final List<Map<String, Object?>> existing = await db.query(
        'content_packs',
        columns: <String>['question_count'],
        where: 'id = ?',
        whereArgs: <Object?>[pack.packId],
        limit: 1,
      );
      if (existing.isNotEmpty &&
          (existing.first['question_count'] as int? ?? -1) ==
              pack.rows.length) {
        continue;
      }
      await db.transaction((Transaction txn) async {
        for (final Map<String, Object?> row in pack.rows) {
          await txn.insert(
            tableQuestions,
            <String, Object?>{...row, 'created_at': now, 'updated_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await txn.insert(
          'content_packs',
          <String, Object?>{
            'id': pack.packId,
            'title_ar': pack.titleAr,
            'source': pack.source,
            'is_demo': 0,
            'schema_version': 1,
            'question_count': pack.rows.length,
            'file_sha256': null,
            'status': 'imported',
            'imported_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    }
    final int total = await getTotalQuestions();
    await db.update(
      'content_packs',
      <String, Object>{'question_count': total},
      where: 'id = ?',
      whereArgs: <Object?>['sanaa-2027'],
    );
  }

  // ------------------------------------------------------------- app_meta

  Future<String?> _getMeta(String key) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      tableAppMeta,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _setMeta(String key, String value) async {
    final Database db = await database;
    await db.insert(
      tableAppMeta,
      <String, Object>{
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> _getMetaInt(String key) async {
    final String? value = await _getMeta(key);
    return int.tryParse(value ?? '') ?? 0;
  }

  // ---------------------------------------------------------------- إعدادات

  Future<String?> getSetting(String key) => _getMeta(key);

  Future<void> setSetting(String key, String value) => _setMeta(key, value);

  // ------------------------------------------------------------------ تقدّم

  Future<Map<String, Object?>> getProgressRow() async {
    final int xp = await _getMetaInt('player_xp');
    final int stars = await _getMetaInt('player_stars');
    return <String, Object?>{
      'id': playerRowId,
      'xp': xp,
      'stars': stars,
      'last_stage_id': await _getMeta('last_stage_id'),
      'last_stage_title': await _getMeta('last_stage_title'),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> addXp(int xp, {int stars = 0}) async {
    final int newXp = await _getMetaInt('player_xp') + xp;
    final int newStars = await _getMetaInt('player_stars') + stars;
    await _setMeta('player_xp', '$newXp');
    await _setMeta('player_stars', '$newStars');
  }

  Future<void> setLastStage(String stageId, String stageTitle) async {
    await _setMeta('last_stage_id', stageId);
    await _setMeta('last_stage_title', stageTitle);
  }

  Future<void> _upsertProgress({
    required String entityType,
    required String entityId,
    int xp = 0,
    int stars = 0,
    int bestScore = 0,
  }) async {
    final Database db = await database;
    final String id = '$entityType:$entityId';
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, Object?>> existing = await db.query(
      tableProgress,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(tableProgress, <String, Object?>{
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'xp': xp,
        'stars': stars,
        'best_score': bestScore,
        'attempts_count': 0,
        'correct_count': 0,
        'mastery_pct': 0,
        'last_played_at': now,
        'updated_at': now,
      });
    } else {
      final Map<String, Object?> row = existing.first;
      await db.update(
        tableProgress,
        <String, Object>{
          'xp': (row['xp'] as int? ?? 0) + xp,
          'stars': stars > (row['stars'] as int? ?? 0)
              ? stars
              : (row['stars'] as int? ?? 0),
          'best_score': bestScore > (row['best_score'] as int? ?? 0)
              ? bestScore
              : (row['best_score'] as int? ?? 0),
          'last_played_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }
  }

  /// نسبة الإنجاز = المراحل المكتملة (نجمة واحدة على الأقل) / كل المراحل.
  /// صفر عند غياب المحتوى.
  Future<double> getCompletionPercent() async {
    final Database db = await database;
    final List<Map<String, Object?>> total = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableStages',
    );
    final int totalCount = (total.first['c'] as int? ?? 0);
    if (totalCount == 0) return 0;
    final List<Map<String, Object?>> done = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM $tableProgress "
      "WHERE entity_type = 'stage' AND stars >= 1",
    );
    final int doneCount = (done.first['c'] as int? ?? 0);
    return doneCount / totalCount;
  }

  /// نسبة إنجاز عالم واحد (0 عند غياب مراحله).
  Future<double> getSubjectCompletion(String subjectId) async {
    final Database db = await database;
    final List<Map<String, Object?>> total = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM $tableStages s
      JOIN $tableLessons l ON l.id = s.lesson_id
      JOIN $tableUnits u ON u.id = l.unit_id
      WHERE u.subject_id = ?
      ''',
      <Object?>[subjectId],
    );
    final int totalCount = (total.first['c'] as int? ?? 0);
    if (totalCount == 0) return 0;
    final List<Map<String, Object?>> done = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM $tableStages s
      JOIN $tableLessons l ON l.id = s.lesson_id
      JOIN $tableUnits u ON u.id = l.unit_id
      JOIN $tableProgress p ON p.entity_type = 'stage' AND p.entity_id = s.id
      WHERE u.subject_id = ? AND p.stars >= 1
      ''',
      <Object?>[subjectId],
    );
    final int doneCount = (done.first['c'] as int? ?? 0);
    return doneCount / totalCount;
  }

  /// عدد مراحل المختبر المكتملة (mode = 'lab' ونجمة واحدة على الأقل).
  Future<int> getCompletedLabStagesCount() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM $tableStages s
      JOIN $tableProgress p ON p.entity_type = 'stage' AND p.entity_id = s.id
      WHERE s.mode = 'lab' AND p.stars >= 1
      ''',
    );
    return (rows.first['c'] as int? ?? 0);
  }

  Future<void> markStageCompleted(String stageId) async {
    await _upsertProgress(
        entityType: 'stage', entityId: stageId, stars: 1);
  }

  // ------------------------------------------------------------------ محاولات

  Future<int> recordAttempt({
    String? stageId,
    String? questionId,
    required bool isCorrect,
    int xpEarned = 0,
    String mode = 'quiz',
    String? sessionId,
    int timeMs = 0,
  }) async {
    final Database db = await database;
    final String session =
        sessionId ?? 'session-${DateTime.now().millisecondsSinceEpoch}';
    int attemptId = -1;
    // المخطط الرسمي يشترط question_id غير فارغ ومرتبطاً بجدول الأسئلة.
    // محاولة بلا سؤال (توافق قديم) لا تُسجَّل كصف، بل تُجمَّع في عدّادات
    // app_meta حتى لا تضيع من الإحصاءات.
    if (questionId != null && questionId.isNotEmpty) {
      attemptId = await db.insert(tableAttempts, <String, Object?>{
        'question_id': questionId,
        'stage_id': stageId,
        'exam_id': null,
        'mode': mode,
        'session_id': session,
        'is_correct': isCorrect ? 1 : 0,
        'time_ms': timeMs,
        'xp_earned': xpEarned,
        'answered_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      final int total = await _getMetaInt('attempts_anonymous_total') + 1;
      final int correct =
          await _getMetaInt('attempts_anonymous_correct') + (isCorrect ? 1 : 0);
      await _setMeta('attempts_anonymous_total', '$total');
      await _setMeta('attempts_anonymous_correct', '$correct');
    }
    if (xpEarned > 0) {
      await addXp(xpEarned);
    }
    return attemptId;
  }

  Future<Map<String, int>> getAttemptStats() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total,
             COALESCE(SUM(is_correct), 0) AS correct,
             COALESCE(SUM(xp_earned), 0) AS xp
      FROM $tableAttempts
      ''',
    );
    final Map<String, Object?> row = rows.first;
    final int legacyTotal = await _getMetaInt('legacy_attempts_total');
    final int legacyCorrect = await _getMetaInt('legacy_attempts_correct');
    final int anonTotal = await _getMetaInt('attempts_anonymous_total');
    final int anonCorrect = await _getMetaInt('attempts_anonymous_correct');
    return <String, int>{
      'total': (row['total'] as int? ?? 0) + legacyTotal + anonTotal,
      'correct': (row['correct'] as int? ?? 0) + legacyCorrect + anonCorrect,
      'xp': (row['xp'] as int? ?? 0) + await _getMetaInt('legacy_attempts_xp'),
    };
  }

  /// عدد المحاولات لكل مادة (عبر جدول الأسئلة).
  Future<Map<String, int>> getAttemptsPerSubject() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT q.subject_id AS subject_id, COUNT(*) AS c
      FROM $tableAttempts a
      JOIN $tableQuestions q ON q.id = a.question_id
      GROUP BY q.subject_id
      ''',
    );
    final Map<String, int> result = <String, int>{};
    for (final Map<String, Object?> row in rows) {
      result[row['subject_id'] as String] = (row['c'] as int? ?? 0);
    }
    return result;
  }

  Future<int> getAttemptsTodayCount() async {
    final Database db = await database;
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableAttempts WHERE answered_at >= ?',
      <Object?>[startOfDay.millisecondsSinceEpoch],
    );
    return (rows.first['c'] as int? ?? 0);
  }

  Future<int> getTotalQuestions() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableQuestions',
    );
    return (rows.first['c'] as int? ?? 0);
  }

  /// كل أسئلة مادة واحدة كنماذج [Question] (لمحاكاة الامتحان).
  /// صف تالف يُتخطَّى بصمت مع بقاء بقية الصفوف — لا سؤال بلا مصدر
  /// يصل إلى اللاعب أبداً (يفرضه Question.fromJson).
  Future<List<Question>> getQuestionsForSubject(String subjectId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT q.*, u.title_ar AS unit_title, l.title_ar AS lesson_title
      FROM $tableQuestions q
      JOIN $tableUnits u ON u.id = q.unit_id
      JOIN $tableLessons l ON l.id = q.lesson_id
      WHERE q.subject_id = ?
      ORDER BY q.unit_id, q.lesson_id, q.id
      ''',
      <Object?>[subjectId],
    );
    final List<Question> out = <Question>[];
    for (final Map<String, Object?> row in rows) {
      try {
        out.add(_questionFromRow(row));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Question _questionFromRow(Map<String, Object?> row) {
    final String type = (row['type'] as String?) ?? 'mcq';
    final List<String> options;
    String correctAnswer;
    if (type == 'mcq') {
      final List<dynamic> decoded =
          jsonDecode((row['options_json'] as String?) ?? '[]') as List<dynamic>;
      options = decoded.map((dynamic e) => e.toString()).toList();
      final int idx = (row['correct_option_index'] as int?) ?? 0;
      correctAnswer = options[idx];
    } else if (type == 'true_false') {
      options = const <String>['صح', 'خطأ'];
      correctAnswer = (row['correct_answer'] as String?) ?? '';
    } else {
      options = const <String>[];
      correctAnswer = (row['correct_answer'] as String?) ?? '';
    }
    return Question.fromJson(<String, dynamic>{
      'id': row['id'],
      'subject': row['subject_id'],
      'unit': row['unit_title'],
      'lesson': row['lesson_title'],
      'type': type == 'fill_blank'
          ? 'fill'
          : type == 'equation'
              ? 'fill'
              : type,
      'text': row['question_text'],
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': (row['explanation'] as String?) ?? '',
      'difficulty': (row['difficulty'] as int?) ?? 2,
      'source': row['source'],
      'sourcePage': row['source_page'],
    });
  }

  // ------------------------------------------------------------ إنجازات ومراجعة

  Future<List<String>> getUnlockedAchievementIds() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      tableAchievements,
      columns: <String>['id'],
      where: 'is_unlocked = 1',
    );
    return rows.map((Map<String, Object?> r) => r['id'] as String).toList();
  }

  Future<void> unlockAchievement(String id) async {
    final Database db = await database;
    final int changed = await db.update(
      tableAchievements,
      <String, Object>{
        'is_unlocked': 1,
        'unlocked_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (changed == 0) {
      // إنجاز غير معروف في الكتالوج: يُسجَّل كصف مخصّص بدل إسقاطه.
      await db.insert(
        tableAchievements,
        <String, Object?>{
          'id': id,
          'title_ar': id,
          'description_ar': 'إنجاز مخصّص.',
          'icon_key': 'badge',
          'condition_type': 'custom',
          'condition_value': 0,
          'is_unlocked': 1,
          'unlocked_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<int> getReviewQueueCount() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableReviewQueue WHERE next_review_at <= ?',
      <Object?>[DateTime.now().millisecondsSinceEpoch],
    );
    return (rows.first['c'] as int? ?? 0);
  }

  Future<List<Map<String, Object?>>> getDueReviewItems() async {
    final Database db = await database;
    return db.query(
      tableReviewQueue,
      where: 'next_review_at <= ?',
      whereArgs: <Object?>[DateTime.now().millisecondsSinceEpoch],
      orderBy: 'next_review_at ASC',
    );
  }

  // -------------------------------------------------------------- إعادة تعيين

  /// يمسح التقدّم والمحاولات والإنجازات وقائمة المراجعة فقط.
  /// لا يمسح المحتوى (المواد/الوحدات/الدروس/الأسئلة) ولا الإعدادات.
  Future<void> clearAllProgress() async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete(tableAttempts);
      await txn.update(
        tableAchievements,
        <String, Object?>{
          'is_unlocked': 0,
          'unlocked_at': null,
        },
      );
      await txn.delete(tableReviewQueue);
      await txn.delete(tableProgress);
      await txn.insert(
        tableAppMeta,
        <String, Object>{
          'key': 'player_xp',
          'value': '0',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        tableAppMeta,
        <String, Object>{
          'key': 'player_stars',
          'value': '0',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        tableAppMeta,
        where: 'key IN (?, ?, ?, ?)',
        whereArgs: <Object?>[
          'last_stage_id',
          'last_stage_title',
          'attempts_anonymous_total',
          'attempts_anonymous_correct',
        ],
      );
    });
  }

  Future<void> close() async {
    final Database? db = _db;
    _db = null;
    await db?.close();
  }
}
