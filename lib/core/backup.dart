// ABQARIYA — Backup: export / import of the player's progress as JSON.
//
// Offline only: the file is written by the player via the system save
// dialog and read back via the system file picker (file_picker);
// sharing uses the system share sheet (share_plus). No INTERNET
// permission is involved anywhere.
//
// Import NEVER deletes existing progress — it merges:
//   * attempts: dedup by (question_id, mode, answered_at); duplicates
//     are skipped and counted, never inserted twice.
//   * achievements: union — an unlocked badge stays unlocked.
//   * review queue: union by question_id (the existing row wins).
//   * exam results: dedup by (exam_type, subject_id, finished_at).
//   * progress rows: per-entity max merge (stars / best score /
//     counts never go down).
//   * settings: whitelisted keys only (see [kBackupSettingKeys]);
//     player_xp / player_stars take the max (never downgrade);
//     last_stage_* only from a newer backup (updated_at compare);
//     the rest replace.
// Validation happens BEFORE any write: a corrupt file changes
// nothing (FormatException with an Arabic message). The restore
// itself runs in one transaction, so a failure mid-restore rolls
// everything back.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/database.dart';

const String kBackupAppId = 'abqariya';
const int kBackupFormatVersion = 1;

/// Settings keys that a backup may carry. Anything else in the file
/// is ignored on import (forward compatibility, never a crash).
const List<String> kBackupSettingKeys = <String>[
  'player_name',
  'dark_mode',
  'sound_enabled',
  'last_stage_id',
  'last_stage_title',
  'last_daily_score',
  'last_daily_date',
  'player_xp',
  'player_stars',
];

/// What a backup import will add (preview) or added (result).
/// [isEmpty] is true when the file carries no restorable progress at
/// all — the UI then says so honestly and writes nothing.
class BackupImportSummary {
  const BackupImportSummary({
    required this.attemptsAdded,
    required this.attemptsSkippedDuplicate,
    required this.attemptsSkippedUnknownQuestion,
    required this.achievementsUnlocked,
    required this.reviewAdded,
    required this.reviewSkippedUnknownQuestion,
    required this.examsAdded,
    required this.examsSkipped,
    required this.progressRestored,
    required this.settingsRestored,
    this.darkModeValue,
  });

  final int attemptsAdded;
  final int attemptsSkippedDuplicate;
  final int attemptsSkippedUnknownQuestion;
  final int achievementsUnlocked;
  final int reviewAdded;
  final int reviewSkippedUnknownQuestion;
  final int examsAdded;
  final int examsSkipped;
  final int progressRestored;
  final int settingsRestored;

  /// Final dark-mode value after the import, when the backup carried
  /// one (the UI applies the theme from this). Null = not in the file.
  final bool? darkModeValue;

  bool get isEmpty =>
      attemptsAdded == 0 &&
      achievementsUnlocked == 0 &&
      reviewAdded == 0 &&
      examsAdded == 0 &&
      progressRestored == 0 &&
      settingsRestored == 0;

  /// Arabic lines for the confirmation dialog / success message.
  String describeAr() {
    final List<String> lines = <String>[];
    if (attemptsAdded > 0 || attemptsSkippedDuplicate > 0) {
      lines.add(
        '• محاولات جديدة: $attemptsAdded'
        ' (مكررة تُخطّت: $attemptsSkippedDuplicate'
        ', لسؤال غير موجود: $attemptsSkippedUnknownQuestion)',
      );
    }
    if (achievementsUnlocked > 0) {
      lines.add('• إنجازات تُفتح: $achievementsUnlocked');
    }
    if (reviewAdded > 0 || reviewSkippedUnknownQuestion > 0) {
      lines.add(
        '• عناصر مراجعة جديدة: $reviewAdded'
        ' (لسؤال غير موجود: $reviewSkippedUnknownQuestion)',
      );
    }
    if (examsAdded > 0 || examsSkipped > 0) {
      lines.add(
        '• نتائج امتحانات جديدة: $examsAdded'
        ' (مكررة تُخطّت: $examsSkipped)',
      );
    }
    if (progressRestored > 0) lines.add('• تقدّم دروس يُستعاد: $progressRestored');
    if (settingsRestored > 0) lines.add('• إعدادات تُستعاد: $settingsRestored');
    if (lines.isEmpty) {
      return 'الملف لا يحتوي على أي بيانات تقدّم — لم يتغيّر شيء.';
    }
    return lines.join('\n');
  }
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// Build the backup document for the current device state.
/// [appVersion] is informational only (e.g. '0.1.3+4').
Future<Map<String, Object?>> buildBackupData(
  DatabaseHelper db, {
  String appVersion = '',
}) async {
  final List<Map<String, Object?>> attempts = await db.getAllAttempts();
  final List<Map<String, Object?>> achievements =
      await db.getAllAchievements();
  final List<Map<String, Object?>> review = await db.getAllReviewItems();
  final List<Map<String, Object?>> exams = await db.getAllExamResults();
  final List<Map<String, Object?>> progress = await db.getAllProgressRows();
  final List<Map<String, Object?>> meta = await db.getAllAppMeta();

  final Map<String, String> settings = <String, String>{};
  final Map<String, int> settingsUpdatedAt = <String, int>{};
  for (final Map<String, Object?> row in meta) {
    final String key = (row['key'] as String?) ?? '';
    if (!kBackupSettingKeys.contains(key)) continue;
    settings[key] = row['value']?.toString() ?? '';
    settingsUpdatedAt[key] = (row['updated_at'] as int?) ?? 0;
  }

  final int correctAttempts = attempts
      .where((Map<String, Object?> r) => (r['is_correct'] as int? ?? 0) == 1)
      .length;
  final int attemptsXp = attempts.fold<int>(
    0,
    (int s, Map<String, Object?> r) => s + ((r['xp_earned'] as int?) ?? 0),
  );

  return <String, Object?>{
    'app': kBackupAppId,
    'format_version': kBackupFormatVersion,
    'exported_at': DateTime.now().toIso8601String(),
    'app_version': appVersion,
    'summary': <String, Object>{
      'total_attempts': attempts.length,
      'correct_attempts': correctAttempts,
      'attempts_xp': attemptsXp,
      'unlocked_achievements': achievements
          .where((Map<String, Object?> r) =>
              (r['is_unlocked'] as int? ?? 0) == 1)
          .length,
      'review_items': review.length,
      'exam_results': exams.length,
    },
    'settings': settings,
    'settings_updated_at': settingsUpdatedAt,
    'attempts': attempts,
    'achievements': achievements,
    'review_queue': review,
    'exam_results': exams,
    'progress': progress,
  };
}

/// Encode a backup document as indented JSON text.
String encodeBackupJson(Map<String, Object?> data) =>
    const JsonEncoder.withIndent('  ').convert(data);

/// Decode backup JSON text. Throws [FormatException] (Arabic message)
/// when the text is not JSON or not a backup document.
Map<String, dynamic> decodeBackupJson(String text) {
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const FormatException(
      'الملف ليس ملف JSON صالحاً — تأكد أنك اخترت ملف نسخة احتياطية من عبقرية.',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'الملف ليس نسخة احتياطية من عبقرية.',
    );
  }
  return decoded;
}

// ---------------------------------------------------------------------------
// Validation (pure — no database access, no writes)
// ---------------------------------------------------------------------------

class _ParsedBackup {
  _ParsedBackup({
    required this.attempts,
    required this.achievements,
    required this.review,
    required this.exams,
    required this.progress,
    required this.settings,
    required this.settingsUpdatedAt,
  });

  final List<Map<String, Object?>> attempts;
  final List<Map<String, Object?>> achievements;
  final List<Map<String, Object?>> review;
  final List<Map<String, Object?>> exams;
  final List<Map<String, Object?>> progress;
  final Map<String, String> settings;
  final Map<String, int> settingsUpdatedAt;
}

List<dynamic> _requireList(
  Map<String, dynamic> data,
  String key,
) {
  final Object? value = data[key];
  if (value is! List) {
    throw FormatException('الملف ناقص: الحقل «$key» مفقود أو ليس قائمة.');
  }
  return value;
}

Map<String, Object?> _requireRowMap(dynamic value, String where) {
  if (value is! Map) {
    throw FormatException('صف تالف في «$where»: ليس كائناً.');
  }
  return Map<String, Object?>.from(value);
}

int _requireInt(
  Map<String, Object?> row,
  String key,
  String where, {
  int? min,
  int? max,
}) {
  final Object? value = row[key];
  if (value is! int) {
    throw FormatException('صف تالف في «$where»: الحقل «$key» ليس عدداً.');
  }
  if ((min != null && value < min) || (max != null && value > max)) {
    throw FormatException(
      'صف تالف في «$where»: الحقل «$key» خارج النطاق المسموح.',
    );
  }
  return value;
}

int? _optionalInt(Map<String, Object?> row, String key) {
  final Object? value = row[key];
  if (value == null) return null;
  if (value is! int) return null;
  return value;
}

String _requireString(Map<String, Object?> row, String key, String where) {
  final Object? value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('صف تالف في «$where»: الحقل «$key» ليس نصاً.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> row, String key) {
  final Object? value = row[key];
  if (value is! String || value.isEmpty) return null;
  return value;
}

double _requireDouble(
  Map<String, Object?> row,
  String key,
  String where, {
  double? min,
}) {
  final Object? value = row[key];
  if (value is num) {
    final double d = value.toDouble();
    if (min != null && d < min) {
      throw FormatException(
        'صف تالف في «$where»: الحقل «$key» خارج النطاق المسموح.',
      );
    }
    return d;
  }
  throw FormatException('صف تالف في «$where»: الحقل «$key» ليس عدداً.');
}

/// Validate the whole document and return typed rows.
/// Throws [FormatException] (Arabic) on the first problem — and
/// writes nothing.
_ParsedBackup _parseBackup(Map<String, dynamic> data) {
  if (data['app'] != kBackupAppId) {
    throw const FormatException(
      'هذا الملف ليس نسخة احتياطية من عبقرية.',
    );
  }
  if (data['format_version'] != kBackupFormatVersion) {
    throw FormatException(
      'إصدار نسخة احتياطية غير مدعوم (${data['format_version']}) — '
      'هذه النسخة تقرأ الإصدار $kBackupFormatVersion فقط.',
    );
  }

  final List<Map<String, Object?>> attempts = <Map<String, Object?>>[];
  for (final dynamic raw in _requireList(data, 'attempts')) {
    final Map<String, Object?> row = _requireRowMap(raw, 'attempts');
    attempts.add(<String, Object?>{
      'question_id': _requireString(row, 'question_id', 'attempts'),
      'stage_id': _optionalString(row, 'stage_id'),
      'mode': _requireString(row, 'mode', 'attempts'),
      'session_id': _requireString(row, 'session_id', 'attempts'),
      'is_correct': _requireInt(row, 'is_correct', 'attempts', min: 0, max: 1),
      'time_ms': _requireInt(row, 'time_ms', 'attempts', min: 0),
      'xp_earned': _requireInt(row, 'xp_earned', 'attempts', min: 0),
      'answered_at': _requireInt(row, 'answered_at', 'attempts', min: 1),
    });
  }

  final List<Map<String, Object?>> achievements = <Map<String, Object?>>[];
  for (final dynamic raw in _requireList(data, 'achievements')) {
    final Map<String, Object?> row = _requireRowMap(raw, 'achievements');
    achievements.add(<String, Object?>{
      'id': _requireString(row, 'id', 'achievements'),
      'is_unlocked':
          _requireInt(row, 'is_unlocked', 'achievements', min: 0, max: 1),
      'unlocked_at': _optionalInt(row, 'unlocked_at'),
    });
  }

  final List<Map<String, Object?>> review = <Map<String, Object?>>[];
  for (final dynamic raw in _requireList(data, 'review_queue')) {
    final Map<String, Object?> row = _requireRowMap(raw, 'review_queue');
    review.add(<String, Object?>{
      'question_id': _requireString(row, 'question_id', 'review_queue'),
      'ease_factor':
          _requireDouble(row, 'ease_factor', 'review_queue', min: 1.3),
      'interval_days':
          _requireInt(row, 'interval_days', 'review_queue', min: 0),
      'repetitions': _requireInt(row, 'repetitions', 'review_queue', min: 0),
      'lapses': _requireInt(row, 'lapses', 'review_queue', min: 0),
      'next_review_at':
          _requireInt(row, 'next_review_at', 'review_queue', min: 0),
      'last_reviewed_at': _optionalInt(row, 'last_reviewed_at'),
    });
  }

  final List<Map<String, Object?>> exams = <Map<String, Object?>>[];
  for (final dynamic raw in _requireList(data, 'exam_results')) {
    final Map<String, Object?> row = _requireRowMap(raw, 'exam_results');
    final String examType = _requireString(row, 'exam_type', 'exam_results');
    if (examType != 'ministerial_exam' &&
        examType != 'boss' &&
        examType != 'unit_test') {
      throw FormatException(
        'صف تالف في «exam_results»: نوع امتحان غير معروف «$examType».',
      );
    }
    exams.add(<String, Object?>{
      'exam_type': examType,
      'subject_id': _optionalString(row, 'subject_id'),
      'unit_id': _optionalString(row, 'unit_id'),
      'total_questions':
          _requireInt(row, 'total_questions', 'exam_results', min: 1),
      'correct_count':
          _requireInt(row, 'correct_count', 'exam_results', min: 0),
      'score_pct': _requireInt(row, 'score_pct', 'exam_results', min: 0, max: 100),
      'duration_ms': _requireInt(row, 'duration_ms', 'exam_results', min: 0),
      'is_demo': _requireInt(row, 'is_demo', 'exam_results', min: 0, max: 1),
      'note': _optionalString(row, 'note'),
      'started_at': _requireInt(row, 'started_at', 'exam_results', min: 0),
      'finished_at': _requireInt(row, 'finished_at', 'exam_results', min: 0),
    });
  }

  final List<Map<String, Object?>> progress = <Map<String, Object?>>[];
  for (final dynamic raw in _requireList(data, 'progress')) {
    final Map<String, Object?> row = _requireRowMap(raw, 'progress');
    final String entityType =
        _requireString(row, 'entity_type', 'progress');
    if (entityType != 'subject' &&
        entityType != 'unit' &&
        entityType != 'lesson' &&
        entityType != 'stage') {
      throw FormatException(
        'صف تالف في «progress»: نوع كيان غير معروف «$entityType».',
      );
    }
    progress.add(<String, Object?>{
      'id': _requireString(row, 'id', 'progress'),
      'entity_type': entityType,
      'entity_id': _requireString(row, 'entity_id', 'progress'),
      'xp': _requireInt(row, 'xp', 'progress', min: 0),
      'stars': _requireInt(row, 'stars', 'progress', min: 0, max: 3),
      'best_score': _requireInt(row, 'best_score', 'progress', min: 0, max: 100),
      'attempts_count':
          _requireInt(row, 'attempts_count', 'progress', min: 0),
      'correct_count': _requireInt(row, 'correct_count', 'progress', min: 0),
      'mastery_pct': _requireInt(row, 'mastery_pct', 'progress', min: 0, max: 100),
      'last_played_at': _optionalInt(row, 'last_played_at'),
      'updated_at': _requireInt(row, 'updated_at', 'progress', min: 0),
    });
  }

  final Object? settingsRaw = data['settings'];
  if (settingsRaw is! Map) {
    throw const FormatException('الملف ناقص: الحقل «settings» مفقود.');
  }
  final Map<String, String> settings = <String, String>{};
  final Map<String, int> settingsUpdatedAt = <String, int>{};
  for (final MapEntry<dynamic, dynamic> e in settingsRaw.entries) {
    final String key = e.key.toString();
    if (!kBackupSettingKeys.contains(key)) continue;
    settings[key] = e.value?.toString() ?? '';
  }
  final Object? updatedRaw = data['settings_updated_at'];
  if (updatedRaw is Map) {
    for (final MapEntry<dynamic, dynamic> e in updatedRaw.entries) {
      final String key = e.key.toString();
      if (!kBackupSettingKeys.contains(key)) continue;
      final int? v = e.value is int
          ? e.value as int
          : int.tryParse('${e.value ?? ''}');
      if (v != null) settingsUpdatedAt[key] = v;
    }
  }

  return _ParsedBackup(
    attempts: attempts,
    achievements: achievements,
    review: review,
    exams: exams,
    progress: progress,
    settings: settings,
    settingsUpdatedAt: settingsUpdatedAt,
  );
}

// ---------------------------------------------------------------------------
// Planning (read-only) + applying (inside one transaction)
// ---------------------------------------------------------------------------

class _ImportPlan {
  _ImportPlan({
    required this.summary,
    required this.attemptsToInsert,
    required this.achievementsToUnlock,
    required this.reviewToInsert,
    required this.examsToInsert,
    required this.progressToMerge,
    required this.settingsToWrite,
  });

  final BackupImportSummary summary;
  final List<Map<String, Object?>> attemptsToInsert;
  final List<Map<String, Object?>> achievementsToUnlock;
  final List<Map<String, Object?>> reviewToInsert;
  final List<Map<String, Object?>> examsToInsert;
  final List<Map<String, Object?>> progressToMerge;

  /// Final (key → value) settings to write into app_meta.
  final Map<String, String> settingsToWrite;
}

Future<Set<String>> _idSet(
  DatabaseExecutor exec,
  String table,
  String column,
) async {
  final List<Map<String, Object?>> rows =
      await exec.query(table, columns: <String>[column]);
  return rows.map((Map<String, Object?> r) => '${r[column]}').toSet();
}

/// Compute what the import would do, from the current database state.
/// Read-only — used by the preview and (recomputed) by the restore.
Future<_ImportPlan> _computePlan(
  DatabaseExecutor exec,
  _ParsedBackup parsed,
) async {
  final Set<String> questionIds =
      await _idSet(exec, DatabaseHelper.tableQuestions, 'id');
  final Set<String> stageIds =
      await _idSet(exec, DatabaseHelper.tableStages, 'id');
  final Set<String> subjectIds =
      await _idSet(exec, DatabaseHelper.tableSubjects, 'id');
  final Set<String> unitIds =
      await _idSet(exec, DatabaseHelper.tableUnits, 'id');
  final Set<String> achievementIds =
      await _idSet(exec, DatabaseHelper.tableAchievements, 'id');

  final List<Map<String, Object?>> attemptsToInsert = <Map<String, Object?>>[];
  var attemptsSkippedDuplicate = 0;
  var attemptsSkippedUnknownQuestion = 0;
  for (final Map<String, Object?> row in parsed.attempts) {
    final String qid = row['question_id'] as String;
    if (!questionIds.contains(qid)) {
      attemptsSkippedUnknownQuestion++;
      continue;
    }
    final List<Map<String, Object?>> existing = await exec.query(
      DatabaseHelper.tableAttempts,
      columns: <String>['id'],
      where: 'question_id = ? AND mode = ? AND answered_at = ?',
      whereArgs: <Object?>[
        qid,
        row['mode'],
        row['answered_at'],
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      attemptsSkippedDuplicate++;
      continue;
    }
    final Map<String, Object?> insert =
        Map<String, Object?>.from(row);
    final String? stageId = insert['stage_id'] as String?;
    if (stageId != null && !stageIds.contains(stageId)) {
      insert['stage_id'] = null;
    }
    attemptsToInsert.add(insert);
  }

  final List<Map<String, Object?>> achievementsToUnlock =
      <Map<String, Object?>>[];
  for (final Map<String, Object?> row in parsed.achievements) {
    if ((row['is_unlocked'] as int? ?? 0) != 1) continue;
    final String id = row['id'] as String;
    if (!achievementIds.contains(id)) continue;
    final List<Map<String, Object?>> existing = await exec.query(
      DatabaseHelper.tableAchievements,
      columns: <String>['is_unlocked'],
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (existing.isNotEmpty && (existing.first['is_unlocked'] as int? ?? 0) == 1) {
      continue;
    }
    achievementsToUnlock.add(row);
  }

  final List<Map<String, Object?>> reviewToInsert = <Map<String, Object?>>[];
  var reviewSkippedUnknownQuestion = 0;
  for (final Map<String, Object?> row in parsed.review) {
    final String qid = row['question_id'] as String;
    if (!questionIds.contains(qid)) {
      reviewSkippedUnknownQuestion++;
      continue;
    }
    final List<Map<String, Object?>> existing = await exec.query(
      DatabaseHelper.tableReviewQueue,
      columns: <String>['question_id'],
      where: 'question_id = ?',
      whereArgs: <Object?>[qid],
      limit: 1,
    );
    if (existing.isNotEmpty) continue;
    reviewToInsert.add(row);
  }

  final List<Map<String, Object?>> examsToInsert = <Map<String, Object?>>[];
  var examsSkipped = 0;
  for (final Map<String, Object?> row in parsed.exams) {
    final String? subjectId = row['subject_id'] as String?;
    final String? unitId = row['unit_id'] as String?;
    if ((subjectId != null && !subjectIds.contains(subjectId)) ||
        (unitId != null && !unitIds.contains(unitId))) {
      examsSkipped++;
      continue;
    }
    final List<Map<String, Object?>> existing = await exec.query(
      DatabaseHelper.tableExamResults,
      columns: <String>['id'],
      where: 'exam_type = ? AND subject_id IS ? AND finished_at = ?',
      whereArgs: <Object?>[
        row['exam_type'],
        subjectId,
        row['finished_at'],
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      examsSkipped++;
      continue;
    }
    examsToInsert.add(row);
  }

  final List<Map<String, Object?>> progressToMerge = <Map<String, Object?>>[];
  for (final Map<String, Object?> row in parsed.progress) {
    final List<Map<String, Object?>> existing = await exec.query(
      DatabaseHelper.tableProgress,
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
      limit: 1,
    );
    if (existing.isEmpty) {
      progressToMerge.add(row);
      continue;
    }
    final Map<String, Object?> cur = existing.first;
    int maxInt(String key) {
      final int a = (cur[key] as int?) ?? 0;
      final int b = (row[key] as int?) ?? 0;
      return a > b ? a : b;
    }

    final int? curPlayed = cur['last_played_at'] as int?;
    final int? newPlayed = row['last_played_at'] as int?;
    final int? mergedPlayed = curPlayed == null
        ? newPlayed
        : (newPlayed == null
            ? curPlayed
            : (curPlayed > newPlayed ? curPlayed : newPlayed));
    final int curUpdated = (cur['updated_at'] as int?) ?? 0;
    final int newUpdated = (row['updated_at'] as int?) ?? 0;
    final Map<String, Object?> merged = <String, Object?>{
      'id': row['id'],
      'entity_type': row['entity_type'],
      'entity_id': row['entity_id'],
      'xp': maxInt('xp'),
      'stars': maxInt('stars'),
      'best_score': maxInt('best_score'),
      'attempts_count': maxInt('attempts_count'),
      'correct_count': maxInt('correct_count'),
      'mastery_pct': maxInt('mastery_pct'),
      'last_played_at': mergedPlayed,
      'updated_at': curUpdated > newUpdated ? curUpdated : newUpdated,
    };
    // Only write when the merge actually improves something.
    final bool improves = maxInt('stars') > ((cur['stars'] as int?) ?? 0) ||
        maxInt('best_score') > ((cur['best_score'] as int?) ?? 0) ||
        maxInt('attempts_count') > ((cur['attempts_count'] as int?) ?? 0) ||
        maxInt('correct_count') > ((cur['correct_count'] as int?) ?? 0) ||
        maxInt('mastery_pct') > ((cur['mastery_pct'] as int?) ?? 0) ||
        maxInt('xp') > ((cur['xp'] as int?) ?? 0);
    if (improves) progressToMerge.add(merged);
  }

  // Settings: current values + updated_at, to merge honestly.
  final Map<String, String> currentValues = <String, String>{};
  final Map<String, int> currentUpdatedAt = <String, int>{};
  final List<Map<String, Object?>> metaRows =
      await exec.query(DatabaseHelper.tableAppMeta);
  for (final Map<String, Object?> row in metaRows) {
    final String key = (row['key'] as String?) ?? '';
    if (!kBackupSettingKeys.contains(key)) continue;
    currentValues[key] = row['value']?.toString() ?? '';
    currentUpdatedAt[key] = (row['updated_at'] as int?) ?? 0;
  }
  final Map<String, String> settingsToWrite = <String, String>{};
  for (final MapEntry<String, String> e in parsed.settings.entries) {
    final String key = e.key;
    final String value = e.value;
    if (key == 'player_xp' || key == 'player_stars') {
      final int cur = int.tryParse(currentValues[key] ?? '') ?? 0;
      final int incoming = int.tryParse(value) ?? 0;
      if (incoming > cur) settingsToWrite[key] = '$incoming';
    } else if (key == 'last_stage_id' || key == 'last_stage_title') {
      final int curAt = currentUpdatedAt[key] ?? 0;
      final int incomingAt = parsed.settingsUpdatedAt[key] ?? 0;
      if (incomingAt > curAt || !currentValues.containsKey(key)) {
        settingsToWrite[key] = value;
      }
    } else if (key == 'last_daily_score' || key == 'last_daily_date') {
      // Daily pair: take the backup's when its date is not older.
      final String curDate = currentValues['last_daily_date'] ?? '';
      final String incomingDate = parsed.settings['last_daily_date'] ?? '';
      if (incomingDate.isEmpty ||
          curDate.isEmpty ||
          incomingDate.compareTo(curDate) >= 0) {
        settingsToWrite[key] = value;
      }
    } else {
      if (currentValues[key] != value) settingsToWrite[key] = value;
    }
  }
  // last_stage is a pair: apply both halves together or neither.
  if ((settingsToWrite.containsKey('last_stage_id') &&
          !settingsToWrite.containsKey('last_stage_title') &&
          parsed.settings.containsKey('last_stage_title')) ||
      (settingsToWrite.containsKey('last_stage_title') &&
          !settingsToWrite.containsKey('last_stage_id') &&
          parsed.settings.containsKey('last_stage_id'))) {
    settingsToWrite['last_stage_id'] =
        parsed.settings['last_stage_id'] ?? currentValues['last_stage_id'] ?? '';
    settingsToWrite['last_stage_title'] =
        parsed.settings['last_stage_title'] ??
            currentValues['last_stage_title'] ??
            '';
  }

  final bool? darkModeValue = settingsToWrite.containsKey('dark_mode')
      ? settingsToWrite['dark_mode'] == '1'
      : (parsed.settings.containsKey('dark_mode')
          ? parsed.settings['dark_mode'] == '1'
          : null);

  final BackupImportSummary summary = BackupImportSummary(
    attemptsAdded: attemptsToInsert.length,
    attemptsSkippedDuplicate: attemptsSkippedDuplicate,
    attemptsSkippedUnknownQuestion: attemptsSkippedUnknownQuestion,
    achievementsUnlocked: achievementsToUnlock.length,
    reviewAdded: reviewToInsert.length,
    reviewSkippedUnknownQuestion: reviewSkippedUnknownQuestion,
    examsAdded: examsToInsert.length,
    examsSkipped: examsSkipped,
    progressRestored: progressToMerge.length,
    settingsRestored: settingsToWrite.length,
    darkModeValue: darkModeValue,
  );

  return _ImportPlan(
    summary: summary,
    attemptsToInsert: attemptsToInsert,
    achievementsToUnlock: achievementsToUnlock,
    reviewToInsert: reviewToInsert,
    examsToInsert: examsToInsert,
    progressToMerge: progressToMerge,
    settingsToWrite: settingsToWrite,
  );
}

Future<void> _applyPlan(
  Transaction txn,
  _ImportPlan plan,
) async {
  final int now = DateTime.now().millisecondsSinceEpoch;
  for (final Map<String, Object?> row in plan.attemptsToInsert) {
    await txn.insert(DatabaseHelper.tableAttempts, <String, Object?>{
      'question_id': row['question_id'],
      'stage_id': row['stage_id'],
      'exam_id': null,
      'mode': row['mode'],
      'session_id': row['session_id'],
      'is_correct': row['is_correct'],
      'time_ms': row['time_ms'],
      'xp_earned': row['xp_earned'],
      'answered_at': row['answered_at'],
    });
  }
  for (final Map<String, Object?> row in plan.achievementsToUnlock) {
    await txn.update(
      DatabaseHelper.tableAchievements,
      <String, Object?>{
        'is_unlocked': 1,
        'unlocked_at': row['unlocked_at'] ?? now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
  }
  for (final Map<String, Object?> row in plan.reviewToInsert) {
    await txn.insert(
      DatabaseHelper.tableReviewQueue,
      <String, Object?>{
        'question_id': row['question_id'],
        'ease_factor': row['ease_factor'],
        'interval_days': row['interval_days'],
        'repetitions': row['repetitions'],
        'lapses': row['lapses'],
        'next_review_at': row['next_review_at'],
        'last_reviewed_at': row['last_reviewed_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  for (final Map<String, Object?> row in plan.examsToInsert) {
    await txn.insert(DatabaseHelper.tableExamResults, <String, Object?>{
      'exam_type': row['exam_type'],
      'subject_id': row['subject_id'],
      'unit_id': row['unit_id'],
      'total_questions': row['total_questions'],
      'correct_count': row['correct_count'],
      'score_pct': row['score_pct'],
      'duration_ms': row['duration_ms'],
      'is_demo': row['is_demo'],
      'note': row['note'],
      'started_at': row['started_at'],
      'finished_at': row['finished_at'],
    });
  }
  for (final Map<String, Object?> row in plan.progressToMerge) {
    await txn.insert(
      DatabaseHelper.tableProgress,
      Map<String, Object?>.from(row),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  for (final MapEntry<String, String> e in plan.settingsToWrite.entries) {
    await txn.insert(
      DatabaseHelper.tableAppMeta,
      <String, Object>{
        'key': e.key,
        'value': e.value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

// ---------------------------------------------------------------------------
// Public entry points
// ---------------------------------------------------------------------------

/// Preview what importing [data] would do. Validates first (throws
/// [FormatException] on a corrupt file) and writes NOTHING.
Future<BackupImportSummary> previewBackupImport(
  DatabaseHelper db,
  Map<String, dynamic> data,
) async {
  final _ParsedBackup parsed = _parseBackup(data);
  final Database sqldb = await db.database;
  final _ImportPlan plan = await _computePlan(sqldb, parsed);
  return plan.summary;
}

/// Validate + restore [data] in one transaction. Throws
/// [FormatException] (Arabic) on a corrupt file — nothing is written
/// in that case. Returns what was actually restored.
Future<BackupImportSummary> restoreBackupData(
  DatabaseHelper db,
  Map<String, dynamic> data,
) async {
  final _ParsedBackup parsed = _parseBackup(data);
  final Database sqldb = await db.database;
  return sqldb.transaction((Transaction txn) async {
    final _ImportPlan plan = await _computePlan(txn, parsed);
    await _applyPlan(txn, plan);
    return plan.summary;
  });
}
