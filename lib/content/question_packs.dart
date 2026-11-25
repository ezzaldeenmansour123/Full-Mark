import 'dart:convert';

import 'package:flutter/services.dart';

/// محمّل حزم الأسئلة الموثقة (`assets/data/questions/*.json`).
///
/// كل حزمة ملف JSON واحد بصيغة `abqariya-content-pack` (انظر
/// `assets/schema/content_schema.json`)، موثقة دون اتصال بواسطة
/// `tools/validate_questions.py`. المحمّل يرفض أي حزمة تجريبية
/// (`is_demo == true`) وأي سؤال بلا مصدر، فلا يختلط المحتوى التجريبي
/// أبداً بأسئلة المنهج. الأسئلة تُزرع في جدول `questions` (مخطط v2)
/// بعد زرع هيكل المنهج، لأن مفاتيحها الأجنبية تشير إلى صفوف
/// المواد/الوحدات/الدروس المزروعة.
class QuestionPackSeed {
  const QuestionPackSeed({
    required this.packId,
    required this.titleAr,
    required this.source,
    required this.rows,
  });

  /// معرّف الحزمة كما في `content_packs` (مثال: `ye-chemistry-3sec-2027`).
  final String packId;
  final String titleAr;
  final String source;

  /// صفوف جاهزة لجدول `questions` (بدون `created_at`/`updated_at` —
  /// يضيفهما `DatabaseHelper` عند الزرع).
  final List<Map<String, Object?>> rows;
}

class QuestionPacks {
  QuestionPacks._();

  /// مسارات الحزم المضمّنة في التطبيق (مسجّلة أيضاً في `pubspec.yaml`).
  /// ملف مفقود أو تالف يُتخطَّى ويُسجَّل في [lastSkippedAssets] — التطبيق يعمل بلا أسئلة لتلك المادة
  /// («بلا أسئلة بعد») بدل أن يتعطّل.
  /// Assets skipped by the last [loadAll] call (missing file, corrupt
  /// JSON, demo pack, or a pack without id/source) — reported to the
  /// user via the home banner instead of being silently dropped.
  static List<String> lastSkippedAssets = <String>[],

  static const List<String> packAssets = <String>[
    'assets/data/questions/chemistry.json',
    'assets/data/questions/math.json',
    'assets/data/questions/physics.json',
    'assets/data/questions/biology.json',
    'assets/data/questions/arabic.json',
    'assets/data/questions/english.json',
    'assets/data/questions/islamic.json',
  ];

  /// يحمّل كل الحزم الموجودة ويحوّل أسئلتها إلى صفوف قاعدة بيانات.
  static Future<List<QuestionPackSeed>> loadAll() async {
    lastSkippedAssets = <String>[];
    final List<QuestionPackSeed> out = <QuestionPackSeed>[];
    for (final String asset in packAssets) {
      try {
        final String raw = await rootBundle.loadString(asset);
        final Map<String, dynamic> pack =
            jsonDecode(raw) as Map<String, dynamic>;
        final Map<String, dynamic> meta =
            (pack['pack'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        if (meta['is_demo'] == true) {
          lastSkippedAssets.add('$asset (تجريبية — مرفوضة)');
          continue;
        }
        final String packId = (meta['id'] as String?) ?? '';
        final String titleAr = (meta['title_ar'] as String?) ?? packId;
        final String source = (meta['source'] as String?) ?? '';
        if (packId.isEmpty || source.isEmpty) {
          lastSkippedAssets.add('$asset (بلا معرّف أو مصدر)');
          continue;
        }
        final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
        for (final dynamic q in (pack['questions'] as List<dynamic>? ?? <dynamic>[])) {
          final Map<String, dynamic> row = _questionToRow(q as Map<String, dynamic>);
          if (row.isNotEmpty) rows.add(row);
        }
        out.add(QuestionPackSeed(
          packId: packId,
          titleAr: titleAr,
          source: source,
          rows: rows,
        ));
      } catch (_) {
        // حزمة مفقودة أو تالفة: تُتخطَّى، وتبقى مادتها «بلا أسئلة بعد».
        lastSkippedAssets.add('$asset (ملف مفقود أو تالف)');
        continue;
      }
    }
    return out;
  }

  /// يحوّل سؤالاً بصيغة الحزمة إلى صف جدول `questions`.
  /// يرجع خريطة فارغة إن كان السؤال غير صالح (بلا مصدر، أو بلا صفحة
  /// مصدر في حزمة غير تجريبية) فيُتخطَّى بدل إدخال صف تالف.
  static Map<String, Object?> _questionToRow(Map<String, dynamic> q) {
    final String source = (q['source'] as String?)?.trim() ?? '';
    final int? sourcePage = (q['source_page'] as num?)?.toInt();
    if (source.isEmpty || sourcePage == null || sourcePage < 1) {
      return <String, Object?>{};
    }
    final String type = (q['type'] as String?)?.trim() ?? 'mcq';
    final List<dynamic> optionsRaw =
        (q['options'] as List<dynamic>?) ?? <dynamic>[];
    final List<String> options =
        optionsRaw.map((dynamic e) => e.toString()).toList();
    final int? correctIndex = (q['correct_option_index'] as num?)?.toInt();
    final String correctAnswer = (q['correct_answer'] as String?)?.trim() ?? '';
    if (type == 'mcq') {
      if (options.length < 2 ||
          correctIndex == null ||
          correctIndex < 0 ||
          correctIndex >= options.length ||
          correctAnswer != options[correctIndex]) {
        return <String, Object?>{};
      }
    } else if (type == 'true_false') {
      if (correctAnswer != 'صح' &&
          correctAnswer != 'خطأ' &&
          correctAnswer != 'True' &&
          correctAnswer != 'False') {
        return <String, Object?>{};
      }
    }
    final String text = (q['question_text'] as String?)?.trim() ?? '';
    final String explanation = (q['explanation'] as String?)?.trim() ?? '';
    if (text.isEmpty || explanation.isEmpty) return <String, Object?>{};
    final int difficulty = (q['difficulty'] as num?)?.toInt() ?? 2;
    if (difficulty < 1 || difficulty > 3) return <String, Object?>{};
    final String id = (q['id'] as String?)?.trim() ?? '';
    final String subjectId = (q['subject_id'] as String?)?.trim() ?? '';
    final String unitId = (q['unit_id'] as String?)?.trim() ?? '';
    final String lessonId = (q['lesson_id'] as String?)?.trim() ?? '';
    if (id.isEmpty || subjectId.isEmpty || unitId.isEmpty || lessonId.isEmpty) {
      return <String, Object?>{};
    }
    return <String, Object?>{
      'id': id,
      'type': type,
      'subject_id': subjectId,
      'unit_id': unitId,
      'lesson_id': lessonId,
      'difficulty': difficulty,
      'question_text': text,
      'options_json': type == 'mcq' ? jsonEncode(options) : null,
      'correct_option_index': type == 'mcq' ? correctIndex : null,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'time_limit_seconds': (q['time_limit_seconds'] as num?)?.toInt(),
      'tags_json': q['tags'] == null
          ? null
          : jsonEncode((q['tags'] as List<dynamic>)
              .map((dynamic e) => e.toString())
              .toList()),
      'media_ref': null,
      'search_text': _normalise(
        <String>[text, ...options, explanation].join(' '),
      ),
      'source': source,
      'source_page': sourcePage,
      'source_detail': (q['source_detail'] as String?)?.trim(),
      'is_demo': 0,
    };
  }

  /// تطبيع بسيط للبحث: إزالة التشكيل والتطويل وتوحيد الألف والتاء
  /// المربوطة والياء. (التطبيع الكامل للبحث العربي في `docs/CONTENT_IMPORT.md`.)
  static String _normalise(String input) {
    return input
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }
}
