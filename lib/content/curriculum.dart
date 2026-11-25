import 'dart:convert';

import 'package:flutter/services.dart';

/// محمّل هيكل المنهج اليمني الموثّق (`assets/data/curriculum.json`).
///
/// ما يحويه الملف — وما لا يحويه:
/// - يحوي: هيكل المنهج فقط (عناوين الوحدات والدروس + مصدر وطبعة كل كتاب).
/// - لا يحوي: نصوص الدروس ولا أي سؤال من الكتب.
/// - الأسئلة تبقى «قيد الإعداد» حتى تصل الكتب المعتمدة أو إذن الوزارة.
///
/// المرجع الافتراضي: نسخة صنعاء 2027 (`default_edition: sanaa`) —
/// قرار المستخدم 2026-11-25. نسخة عدن مذكورة فقط كسطور مقارنة موثقة
/// (حقل `aden_comparison`) وليست محتوى رئيسياً. الكيمياء: حُسم الخلاف
/// السابق (7 مقابل 9 وحدات) — تصحيح 2026-11-25: ملف PDF نفسه 9 وحدات، فاعتُمدت 9 وحدات — نسخة صنعاء 2027.
/// الأحياء: حُسم الخلاف السابق (التغذية البشرية مقابل التقانة الحيوية) —
/// تصحيح 2026-11-25: ملف PDF نفسه يقول إن الوحدة 6 «التقانة الحيوية» (9 دروس)، فاعتُمدت — نسخة صنعاء 2027.
/// انظر `docs/CURRICULUM.md`.
class CurriculumLesson {
  const CurriculumLesson({required this.number, required this.title});

  final int number;
  final String title;
}

class CurriculumUnit {
  const CurriculumUnit({
    required this.number,
    required this.title,
    required this.lessons,
    this.book,
    this.semester,
    this.note,
  });

  final int number;
  final String title;
  final List<String> lessons;
  final String? book;
  final int? semester;
  final String? note;

  List<CurriculumLesson> get numberedLessons => <CurriculumLesson>[
        for (int i = 0; i < lessons.length; i++)
          CurriculumLesson(number: i + 1, title: lessons[i]),
      ];
}

class CurriculumVariant {
  const CurriculumVariant({
    required this.variantId,
    required this.nameAr,
    required this.units,
    this.sourceUrl,
    this.note,
  });

  final String variantId;
  final String nameAr;
  final List<CurriculumUnit> units;
  final String? sourceUrl;
  final String? note;
}

class CurriculumBook {
  const CurriculumBook({
    required this.titleAr,
    this.edition,
    this.pages,
    this.sourceUrl,
    this.note,
  });

  final String titleAr;
  final String? edition;
  final int? pages;
  final String? sourceUrl;
  final String? note;
}

class CurriculumSubject {
  const CurriculumSubject({
    required this.id,
    required this.nameAr,
    required this.books,
    required this.units,
    this.variants = const <CurriculumVariant>[],
    this.defaultVariantId,
    this.conflictNote,
    this.semesterDistribution,
    this.experiments = const <String>[],
    this.activities = const <String>[],
    this.activitiesNote,
    this.alternativeEdition,
    this.adenComparison,
  });

  final String id;
  final String nameAr;
  final List<CurriculumBook> books;
  final List<CurriculumUnit> units;
  final List<CurriculumVariant> variants;
  final String? defaultVariantId;
  final String? conflictNote;
  final String? semesterDistribution;
  final List<String> experiments;
  final List<String> activities;
  final String? activitiesNote;
  final Map<String, Object?>? alternativeEdition;

  /// سطر مقارنة موثق مع نسخة عدن (ليس محتوى رئيسياً).
  final String? adenComparison;

  /// الوحدات المعروضة افتراضياً: وحدات المادة نفسها. الكيمياء:
  /// 9 وحدات موثقة من ملف PDF نفسه (تصحيح 2026-11-25).
  List<CurriculumUnit> get defaultUnits {
    if (units.isNotEmpty) return units;
    final String? def = defaultVariantId;
    for (final CurriculumVariant v in variants) {
      if (v.variantId == def) return v.units;
    }
    return variants.isEmpty ? units : variants.first.units;
  }

  int get lessonCount =>
      defaultUnits.fold<int>(0, (int s, CurriculumUnit u) => s + u.lessons.length);
}

class CurriculumData {
  const CurriculumData({
    required this.defaultEdition,
    required this.questionsStatus,
    required this.copyright,
    required this.subjects,
    required this.unverifiedGaps,
  });

  final String defaultEdition;
  final String questionsStatus;
  final String copyright;
  final List<CurriculumSubject> subjects;
  final List<String> unverifiedGaps;

  static Future<CurriculumData> load() async {
    final String raw =
        await rootBundle.loadString('assets/data/curriculum.json');
    return CurriculumData.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  factory CurriculumData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta =
        (json['meta'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> rawSubjects =
        (json['subjects'] as List<dynamic>?) ?? <dynamic>[];
    return CurriculumData(
      defaultEdition: (meta['default_edition'] as String?) ?? 'sanaa',
      questionsStatus: (meta['questions_status'] as String?) ?? 'pending',
      copyright: (meta['copyright'] as String?) ?? '',
      subjects: rawSubjects
          .map((dynamic e) =>
              _subjectFromJson(e as Map<String, dynamic>))
          .toList(),
      unverifiedGaps: ((json['unverified_gaps'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
    );
  }

  static CurriculumSubject _subjectFromJson(Map<String, dynamic> json) {
    List<CurriculumUnit> parseUnits(List<dynamic>? raw) =>
        (raw ?? <dynamic>[])
            .map((dynamic e) => _unitFromJson(e as Map<String, dynamic>))
            .toList();
    final Map<String, dynamic>? conflict =
        json['conflict'] as Map<String, dynamic>?;
    return CurriculumSubject(
      id: (json['id'] as String?) ?? '',
      nameAr: (json['name_ar'] as String?) ?? '',
      books: ((json['books'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) {
        final Map<String, dynamic> b = e as Map<String, dynamic>;
        return CurriculumBook(
          titleAr: (b['title_ar'] as String?) ?? '',
          edition: b['edition'] as String?,
          pages: (b['pages'] as num?)?.toInt(),
          sourceUrl: b['source_url'] as String?,
          note: b['note'] as String?,
        );
      }).toList(),
      units: parseUnits(json['units'] as List<dynamic>?),
      variants: ((json['variants'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) {
        final Map<String, dynamic> v = e as Map<String, dynamic>;
        return CurriculumVariant(
          variantId: (v['variant_id'] as String?) ?? '',
          nameAr: (v['variant_name_ar'] as String?) ?? '',
          units: parseUnits(v['units'] as List<dynamic>?),
          sourceUrl: v['source_url'] as String?,
          note: v['note'] as String?,
        );
      }).toList(),
      defaultVariantId:
          (conflict?['default_variant'] as String?) ?? 'a_7_units',
      conflictNote: conflict?['issue'] as String?,
      semesterDistribution: json['semester_distribution'] as String?,
      experiments: ((json['experiments'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      activities: ((json['activities'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      activitiesNote: json['activities_note'] as String?,
      alternativeEdition:
          json['alternative_edition'] as Map<String, dynamic>?,
      adenComparison: json['aden_comparison'] as String?,
    );
  }

  static CurriculumUnit _unitFromJson(Map<String, dynamic> json) {
    return CurriculumUnit(
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      lessons: ((json['lessons'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      book: json['book'] as String?,
      semester: (json['semester'] as num?)?.toInt(),
      note: json['note'] as String?,
    );
  }

  CurriculumSubject? subjectById(String id) {
    for (final CurriculumSubject s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// عدد الدروس الكلي في العرض الافتراضي (الكيمياء 9 وحدات موثقة من PDF؛ الأحياء: الوحدة 6 تقانة حيوية 9 دروس موثقة من PDF).
  int get totalLessons =>
      subjects.fold<int>(0, (int s, CurriculumSubject sub) => s + sub.lessonCount);

  /// صفوف جاهزة لزرع جداول subjects/units/lessons في SQLite
  /// (هيكل فقط — بلا أسئلة). تطابق مخطط `lib/db/schema.dart` v2
  /// (الأعمدة الرسمية: name_ar/source/source_detail/is_demo).
  /// الكيمياء تُزرع بنسخة صنعاء (9 وحدات موثقة من ملف PDF). الأحياء تُزرع
  /// بنسخة صنعاء (الوحدة 6 تقانة حيوية، 9 دروس، موثقة من ملف PDF). مصدر كل صف هو كتابه
  /// (عنوان + طبعة صنعاء 2027 + رابط المصدر).
  List<Map<String, Object>> seedRows() {
    final List<Map<String, Object>> rows = <Map<String, Object>>[];
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final CurriculumSubject subject in subjects) {
      final String source = subject.books.isEmpty
          ? 'المنهج اليمني — نسخة صنعاء 2027'
          : subject.books.map((CurriculumBook b) => b.titleAr).join('؛ ');
      rows.add(<String, Object>{
        'table': 'subjects',
        'id': subject.id,
        'name_ar': subject.nameAr,
        'name_en': '',
        'icon_key': 'book',
        'color_hex': '#2E86AB',
        'sort_order': subjects.indexOf(subject) + 1,
        'source': source,
        'source_detail': 'نسخة صنعاء 2027 — هيكل فقط، بلا نصوص وبلا أسئلة',
        'is_demo': 0,
        'created_at': now,
        'updated_at': now,
      });
      for (final CurriculumUnit unit in subject.defaultUnits) {
        final String unitId = '${subject.id}-u${unit.number}';
        rows.add(<String, Object>{
          'table': 'units',
          'id': unitId,
          'subject_id': subject.id,
          'title_ar': 'الوحدة ${unit.number}: ${unit.title}',
          'sort_order': unit.number,
          'source': source,
          'source_detail': unit.note ?? '',
          'is_demo': 0,
          'created_at': now,
          'updated_at': now,
        });
        int i = 0;
        for (final String lesson in unit.lessons) {
          i++;
          rows.add(<String, Object>{
            'table': 'lessons',
            'id': '$unitId-l$i',
            'unit_id': unitId,
            'subject_id': subject.id,
            'title_ar': lesson,
            'sort_order': i,
            'source': source,
            'source_detail': unit.note ?? '',
            'is_demo': 0,
            'created_at': now,
            'updated_at': now,
          });
        }
      }
    }
    return rows;
  }
}
