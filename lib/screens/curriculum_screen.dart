import 'package:material_ui/material_ui.dart';

import '../content/curriculum.dart';
import '../db/database.dart';
import '../games/arabic_games.dart';
import '../games/english_games.dart';
import '../games/equation_game.dart';
import '../games/equation_items.dart';
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

  /// عدد الأسئلة لكل درس (null = لم يُحمَّل بعد؛ لا يُعرض أي ادعاء
  /// عن درس قبل تحميل عدده، حتى لا تظهر شارة «لا توجد أسئلة» كاذبة).
  Map<String, int>? _questionCounts;

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
    DatabaseHelper.instance
        .getQuestionCountsForSubject(widget.subjectId)
        .then((Map<String, int> counts) {
      if (!mounted) return;
      setState(() => _questionCounts = counts);
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
              'أسئلة الدروس متوفرة من الحزم الموثقة — شارة العدد على '
              'كل درس توضح عدد أسئلته، والدرس بلا أسئلة يظهر «لا توجد '
              'أسئلة» ولا يُفتح. كل سؤال يعرض مصدره ورقم صفحته، ولا '
              'يُعرض أي سؤال مخترع أو بلا مصدر.',
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

  /// يفتح أسئلة درس واحد: أولاً منتقي الأنماط (الأنماط القابلة
  /// للعب فعلاً)، ثم `GameScreen` بالنمط المختار. درس بلا أسئلة:
  /// لا أيقونة لعب ولا ضغطة عليه أصلاً (شارة «لا توجد أسئلة»)،
  /// والحارس هنا احتياط أخير فقط: رسالة صادقة بلا أسئلة مخترعة.
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
    final String? picked = await _showModePicker(lessonTitle, questions);
    if (!mounted || picked == null) return;
    if (picked == 'complete_equation') {
      await _playEquationGame(lessonTitle, lessonId);
      return;
    }
    final GameModeConfig mode = modeConfigByRouteId(picked);
    // Only the questions this mode can actually play: the result's
    // per-question record is built from exactly these, so recording
    // the whole lesson here would invent «correct» attempts for
    // questions the player never saw (e.g. MCQ rows in a true/false
    // game). Defense in depth — the picker already hides modes with
    // no usable question in this lesson.
    final List<Question> usable = questions
        .where((Question q) =>
            questionTypesForMode(mode.id).contains(q.type))
        .toList(growable: false);
    if (usable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا توجد أسئلة مناسبة لنمط «${mode.titleAr}» في درس '
            '«$lessonTitle» بعد — جرّبي نمطاً آخر.',
          ),
        ),
      );
      return;
    }
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
              playedQuestions: usable,
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

  /// «أكمل المعادلة» — chemistry only: the 4 verified equations
  /// (lab + bank) are all chemistry. The bank questions the items
  /// are taken from are loaded for recordGameResult; the water item
  /// has no bank question, so its attempt is recorded anonymously.
  Future<void> _playEquationGame(String lessonTitle, String lessonId) async {
    final List<Question> bankQuestions = <Question>[];
    for (final EquationItem item in kEquationItems) {
      final String? qid = item.sourceQuestionId;
      if (qid == null) continue;
      final Question? q =
          await DatabaseHelper.instance.getQuestionById(qid);
      if (q != null) bankQuestions.add(q);
    }
    if (!mounted) return;
    await DatabaseHelper.instance.setLastStage(lessonId, lessonTitle);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EquationGameScreen(
          lessonId: lessonId,
          lessonTitle: lessonTitle,
          stageId: lessonId,
          sourceQuestions: bankQuestions,
          onFinished: (GameResult result, bool waterCorrect) async {
            await DatabaseHelper.instance.recordGameResult(
              result: result,
              playedQuestions: bankQuestions,
              mode: 'complete_equation',
              stageId: lessonId,
              lessonId: lessonId,
              lessonTitle: lessonTitle,
            );
            // The water item has no bank question: count its attempt
            // anonymously so the totals still match the 4 rounds.
            await DatabaseHelper.instance.recordAttempt(
              questionId: null,
              isCorrect: waterCorrect,
              mode: 'complete_equation',
            );
          },
        ),
      ),
    );
  }

  /// Mode picker: ONLY the 8 really playable modes. Every entry
  /// launches a real playable game — no placeholder entries.
  /// «أكمل المعادلة» is chemistry-only: its 4 equations are all
  /// chemistry, so it is hidden for other subjects. A mode is also
  /// hidden when this lesson has no question of a type it can play
  /// (e.g. «مطابقة المفاهيم» in a lesson with only true/false
  /// questions) — offering it would crash or play an empty board.
  Future<String?> _showModePicker(
    String lessonTitle,
    List<Question> questions,
  ) {
    final playable = kGameModes
        .where((m) => m.isPlayable)
        .where((m) =>
            m.routeId != 'complete_equation' ||
            widget.subjectId == 'chemistry')
        .where((m) =>
            m.routeId == 'complete_equation' ||
            questions.any((Question q) =>
                questionTypesForMode(m.id).contains(q.type)))
        .toList(growable: false);
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
            // لا مدخل «محاكاة الامتحان الوزاري» هنا: الامتحان عام
            // على المادة كلها ولا يخص هذا الدرس، وزرّه موجود في
            // الشاشة الرئيسية وشاشة الامتحان. (أُزيل في v0.1.4؛
            // كان يفتح الامتحان العام متجاهلاً الدرس المختار.)
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
              Builder(
                builder: (BuildContext context) {
                  final String lessonId =
                      '${widget.subjectId}-u${unit.number}-l${i + 1}';
                  // قبل تحميل الأعداد: السلوك القديم (أيقونة لعب)؛
                  // وبعد التحميل: شارة العدد، والدرس بلا أسئلة بلا
                  // أيقونة لعب وبلا ضغطة (الرسالة على الشارة نفسها).
                  final int? count = _questionCounts?[lessonId];
                  final bool noQuestions =
                      _questionCounts != null && (count ?? 0) == 0;
                  return ListTile(
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
                    trailing: _questionCounts == null
                        ? const Icon(Icons.play_circle_outline)
                        : noQuestions
                            ? const Chip(
                                label: Text(
                                  'لا توجد أسئلة',
                                  style: TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Chip(
                                    label: Text(
                                      '$count أسئلة',
                                      style:
                                          const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.play_circle_outline),
                                ],
                              ),
                    onTap: noQuestions
                        ? null
                        : () => _playLesson(unit.lessons[i], lessonId),
                  );
                },
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
