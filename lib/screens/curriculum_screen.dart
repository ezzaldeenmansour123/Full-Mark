import 'package:material_ui/material_ui.dart';

import '../content/curriculum.dart';
import '../core/routes.dart';
import '../db/database.dart';
import '../games/arabic_games.dart';
import '../games/english_games.dart';
import '../games/game_modes.dart';
import '../games/game_screen.dart';
import '../games/islamic_games.dart';
import '../models/game_result.dart';
import '../models/question.dart';

/// شاشة تفاصيل عالم (مادة): تعرض هيكل المنهج اليمني الموثّق
/// (الوحدات والدروس) من `assets/data/curriculum.json`.
///
/// هيكل فقط — لا نصوص دروس. الضغط على درس يفتح أسئلته الحقيقية
/// من قاعدة البيانات (`GameScreen` بوضع quiz)؛ والدرس الذي لا
/// أسئلة له بعد يُظهر رسالة صادقة بذلك، لا أسئلة مخترعة.
/// دروس النسخ البديلة الموثقة (غير المزروعة في قاعدة البيانات)
/// غير قابلة للعب، حتى لا تُعرض أسئلة درس آخر على أنها أسئلتها.
class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({
    super.key,
    required this.subjectId,
    required this.title,
    required this.color,
    required this.icon,
  });

  final String subjectId;
  final String title;
  final Color color;
  final IconData icon;

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  CurriculumData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    CurriculumData.load().then((CurriculumData data) {
      if (!mounted) return;
      setState(() => _data = data);
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('عالم ${widget.title}'),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(child: Text('تعذّر تحميل هيكل المنهج:\n$_error'))
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(_data!.subjectById(widget.subjectId)),
    );
  }

  Widget _buildBody(CurriculumSubject? subject) {
    if (subject == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'هيكل هذه المادة لم يُوثَّق بعد في ملف المنهج.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final List<Widget> children = <Widget>[
      _infoCard(subject),
      if (subject.conflictNote != null) _warningCard(subject),
      if (subject.adenComparison != null) _adenCard(subject.adenComparison!),
      if (widget.subjectId == 'arabic' ||
          widget.subjectId == 'english' ||
          widget.subjectId == 'islamic')
        _subjectGameCard(),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          'وحدات المنهج (نسخة صنعاء 2027)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      ...subject.defaultUnits.map(_unitTile),
      if (subject.variants.length > 1) ..._variantSection(subject),
      if (subject.alternativeEdition != null)
        _alternativeCard(subject.alternativeEdition!),
      if (subject.experiments.isNotEmpty)
        _listCard('التجارب العملية (${subject.experiments.length})',
            subject.experiments),
      if (subject.activities.isNotEmpty)
        _listCard(
            'الأنشطة (${subject.activities.length}) — القائمة الكاملة في المصدر',
            subject.activities,
            note: subject.activitiesNote),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'أسئلة الدروس متوفرة من الحزم الموثقة — اضغطي على أي درس '
              'لبدء لعب أسئلته. كل سؤال يعرض مصدره ورقم صفحته، ولا يُعرض '
              'أي سؤال مخترع أو بلا مصدر.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ];
    return ListView(children: children);
  }

  Widget _infoCard(CurriculumSubject subject) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: widget.color,
                  foregroundColor: Colors.white,
                  child: Icon(widget.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subject.nameAr,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${subject.defaultUnits.length} وحدات • ${subject.lessonCount} دروساً موثقة',
            ),
            const SizedBox(height: 8),
            for (final CurriculumBook book in subject.books)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📖 ${book.titleAr}'
                  '${book.edition != null ? ' — ${book.edition}' : ''}'
                  '${book.pages != null ? ' (${book.pages} ص)' : ''}',
                ),
              ),
            if (subject.semesterDistribution != null) ...<Widget>[
              const SizedBox(height: 8),
              Text('التوزيع الفصلي: ${subject.semesterDistribution}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _warningCard(CurriculumSubject subject) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'تصحيح موثق — الكيمياء 9 وحدات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(subject.conflictNote ?? ''),
            const SizedBox(height: 6),
            const Text(
              'المعروض هو نسخة صنعاء 2027 (9 وحدات) كما في ملف PDF نفسه؛ '
              'وفهرس الـ7 وحدات كان فهرس صفحة الموقع فقط ومحفوظ كملاحظة مقارنة.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _adenCard(String comparison) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: const Text(
          'مقارنة موثقة مع نسخة عدن (ليست محتوى رئيسياً)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(comparison),
          ),
        ],
      ),
    );
  }

  /// Special game of this subject, fed by real database questions
  /// (Arabic / English sentence building from real correct answers,
  /// Islamic lesson-ordering from the real curriculum structure).
  /// Each screen records its own real result.
  Widget _subjectGameCard() {
    late final String title;
    late final String subtitle;
    late final Widget screen;
    switch (widget.subjectId) {
      case 'arabic':
        title = 'لعبة بناء الجمل';
        subtitle = 'رتّب كلمات الإجابات الصحيحة من أسئلة اللغة العربية';
        screen = const ArabicSentenceGameScreen();
      case 'english':
        title = 'Sentence building game';
        subtitle = 'رتّب كلمات الإجابات الصحيحة من أسئلة اللغة الإنجليزية';
        screen = const EnglishSentenceGameScreen();
      case 'islamic':
      default:
        title = 'لعبة ترتيب الدروس';
        subtitle = 'رتّب دروس كل وحدة بالترتيب الصحيح من المنهج';
        screen = const IslamicOrderingGameScreen();
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.extension),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.play_circle_fill),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => screen),
        ),
      ),
    );
  }

  /// يفتح أسئلة درس واحد: أولاً منتقي الأنماط (الأنماط الخمسة القابلة
  /// للعب فعلاً + محاكاة الامتحان الوزاري)، ثم `GameScreen` بالنمط
  /// المختار. درس بلا أسئلة: رسالة صادقة، بلا لعبة وبلا أسئلة مخترعة.
  /// تُحفظ المرحلة الأخيرة عند بدء اللعبة، وتُسجَّل النتيجة كاملة
  /// (مع معرّف الدرس وعنوانه) قبل ظهور شاشة النتيجة.
  Future<void> _playLesson(String lessonTitle, String lessonId) async {
    final List<Question> questions = await DatabaseHelper.instance
        .getQuestionsForLesson(widget.subjectId, lessonId);
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا توجد أسئلة بعد في درس «$lessonTitle» — ستُضاف فور '
            'توفرها من الكتاب المعتمد.',
          ),
        ),
      );
      return;
    }
    final String? picked = await _showModePicker(lessonTitle);
    if (!mounted || picked == null) return;
    if (picked == 'ministerial_exam') {
      await Navigator.of(context).pushNamed(AppRoutes.exam);
      return;
    }
    final GameModeConfig mode = modeConfigByRouteId(picked);
    // Game start: remember this lesson as the last stage.
    await DatabaseHelper.instance.setLastStage(lessonId, lessonTitle);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          modeRouteId: mode.routeId,
          subject: widget.subjectId,
          subjectTitleAr: lessonTitle,
          questions: questions,
          lessonId: lessonId,
          stageId: lessonId,
          onFinished: (GameResult result) async {
            await DatabaseHelper.instance.recordGameResult(
              result: result,
              playedQuestions: questions,
              mode: mode.routeId,
              stageId: lessonId,
              lessonId: lessonId,
              lessonTitle: lessonTitle,
            );
          },
        ),
      ),
    );
  }

  /// Mode picker: ONLY the 5 really playable modes, plus the
  /// ministerial-exam entry (which opens ExamScreen). Every entry
  /// launches a real playable game — no placeholder entries.
  Future<String?> _showModePicker(String lessonTitle) {
    final playable =
        kGameModes.where((m) => m.isPlayable).toList(growable: false);
    return showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'اختاري نمط اللعب — $lessonTitle',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final GameModeConfig mode in playable)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(mode.titleAr),
                subtitle: Text(
                  '${mode.descriptionAr}\n${mode.scoringRuleAr}',
                ),
                isThreeLine: true,
                onTap: () => Navigator.of(context).pop(mode.routeId),
              ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('محاكاة الامتحان الوزاري'),
              subtitle: const Text('جلسة امتحان مؤقتة كاملة — شاشة مستقلة.'),
              onTap: () =>
                  Navigator.of(context).pop('ministerial_exam'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitTile(CurriculumUnit unit, {bool allowPlay = true}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        title: Text(
          'الوحدة ${unit.number}: ${unit.title}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${unit.lessons.length} دروس'
          '${unit.semester != null ? ' • الفصل ${unit.semester == 1 ? 'الأول' : 'الثاني'}' : ''}'
          '${unit.book != null ? ' • ${unit.book}' : ''}',
        ),
        children: <Widget>[
          if (unit.note != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'ملاحظة: ${unit.note}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          for (int i = 0; i < unit.lessons.length; i++)
            if (allowPlay)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 13,
                  backgroundColor: widget.color.withValues(alpha: 0.15),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(fontSize: 12, color: widget.color),
                  ),
                ),
                title: Text(unit.lessons[i]),
                trailing: const Icon(Icons.play_circle_outline),
                onTap: () => _playLesson(
                  unit.lessons[i],
                  '${widget.subjectId}-u${unit.number}-l${i + 1}',
                ),
              )
            else
              // Variant lesson rows are NOT tappable: plain text, never
              // a silent ListTile that looks tappable but does nothing.
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: widget.color.withValues(alpha: 0.15),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 12, color: widget.color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(unit.lessons[i])),
                  ],
                ),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              allowPlay
                  ? 'اضغطي على أي درس لبدء أسئلته.'
                  : 'لا تتوفر أسئلة لهذه النسخة البديلة — المعروضة للاطلاع فقط.',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _variantSection(CurriculumSubject subject) {
    final List<Widget> out = <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          'النسخة البديلة الموثقة (لا تُستخدم افتراضياً)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    ];
    for (final CurriculumVariant variant in subject.variants) {
      if (variant.variantId == subject.defaultVariantId) continue;
      out.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            variant.nameAr,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      if (variant.note != null) {
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(variant.note!),
          ),
        );
      }
      out.addAll(variant.units.map(
        (CurriculumUnit u) => _unitTile(u, allowPlay: false),
      ));
    }
    return out;
  }

  Widget _alternativeCard(Map<String, Object?> alt) {
    final List<dynamic> lessons =
        (alt['lessons'] as List<dynamic>?) ?? <dynamic>[];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text('بديل موثق: ${alt['book'] ?? ''}'),
        subtitle: Text(
          '${lessons.length} درساً — ${alt['note'] ?? ''}',
        ),
        children: <Widget>[
          // Non-tappable reference rows: plain text, never a ListTile.
          for (final dynamic lesson in lessons)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('• ${lesson.toString()}'),
            ),
        ],
      ),
    );
  }

  Widget _listCard(String title, List<String> items, {String? note}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: <Widget>[
          if (note != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(note,
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
          for (final String item in items)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }
}
