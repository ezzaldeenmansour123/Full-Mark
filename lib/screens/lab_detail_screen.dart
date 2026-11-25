// ABQARIYA — Lab Detail Screen (شاشة المختبر)
// Hosts a chosen lab by id. Route: '/lab', argument = lab id (String).
// Example: Navigator.pushNamed(context, '/lab', arguments: 'physics_lab');
// 100% offline. Labs are independent widgets. When a hosted lab reports
// a result via onComplete(score, total), this screen persists it ONLY
// when the run passed (>= 2/3 correct) — a 0/3 run used to mark the lab
// "completed" with 1 star and no XP was ever awarded. On the first
// passing completion it awards score*10 XP; replays never double-award.
// Labs are replayable: completing again upserts the same progress row.
// NOT run — no Flutter/Dart SDK here.

import 'package:material_ui/material_ui.dart';
import '../db/database.dart';
import '../labs/math_lab.dart';
import '../labs/physics_lab.dart';
import '../labs/chemistry_lab.dart';
import '../labs/biology_lab.dart';

/// Detail screen for one lab.
///
/// Route '/lab' with a [String] lab-id argument.
/// Known ids: [MathLab.labId], [PhysicsLab.labId], [ChemistryLab.labId],
/// [BiologyLab.labId]. Unknown ids show an honest "not found" message.
class LabDetailScreen extends StatelessWidget {
  const LabDetailScreen({super.key, required this.labId, this.onComplete});

  /// Lab id, e.g. 'physics_lab'. Also read from the route argument
  /// when the screen is built via onGenerateRoute (see [LabDetailScreen.fromRoute]).
  final String labId;

  /// Optional score callback forwarded to the hosted lab.
  /// Persistence happens inside this screen regardless of whether
  /// a callback was supplied (see [_onLabComplete]).
  final void Function(int score, int total)? onComplete;

  /// Build from a route: `LabDetailScreen.fromRoute(settings.arguments)`.
  /// Returns null when the argument is not a String lab id.
  static LabDetailScreen? fromRoute(Object? arguments) {
    if (arguments is String) return LabDetailScreen(labId: arguments);
    return null;
  }

  /// Stable stage id used for progress persistence of this lab.
  String get _stageId => 'lab:$labId';

  /// Callback handed to the hosted lab: a run counts as completed
  /// only when it passed (>= 2/3 correct). A failed run shows an
  /// honest "not completed — try again" message and saves nothing.
  /// On the FIRST passing completion, score*10 XP is awarded once;
  /// replays upsert the same progress row without double XP.
  void Function(int score, int total) _onLabComplete(
          BuildContext context) =>
      (int score, int total) async {
        if (total <= 0 || score * 3 < total * 2) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لم تكتمل — أعيدي المحاولة '
                    '(تحتاجين ثلثي الإجابات الصحيحة على الأقل).'),
              ),
            );
          }
          return;
        }
        final db = DatabaseHelper.instance;
        final bool alreadyDone = await db.isStageCompleted(_stageId);
        await db.markStageCompleted(_stageId);
        await db.setLastStage(_stageId, _title());
        if (!alreadyDone) await db.addXp(score * 10);
        onComplete?.call(score, total);
      };

  static const Map<String, ({String law, String explanation})> _lawCards = {
    MathLab.labId: (
      law: 'الدالة التربيعية: y = ax² + bx + c — الجذور من Δ = b² − 4ac، '
          'والرأس عند x = −b/2a.',
      explanation: 'غيّر المعاملات وشاهد كيف يتحرك المنحنى. الجذور هي نقاط '
          'تقاطع المنحنى مع محور x، والمساحة تحت المنحنى تُقدَّر بطريقة '
          'شبه المنحرف.',
    ),
    PhysicsLab.labId: (
      law: 'السقوط الحر: h = ½gt² ، v = gt — البندول: T = 2π√(L/g) — '
          'أوم: I = V/R ، P = VI. ‏g = 9.8 m/s².',
      explanation: 'كل تجربة تعرض القانون والوحدات والحساب العددي. جرّب '
          'المنزلقات ولاحظ كيف تتغير النتائج، ثم أجب عن أسئلة «اختبر نفسك».',
    ),
    ChemistryLab.labId: (
      law: 'قانون حفظ الكتلة: عدد ذرات كل عنصر متساوٍ في طرفي المعادلة. '
          'التكافؤ: H=1 ، O=2 ، N=3 ، C=4.',
      explanation: 'ابنِ الجزيء بذراته الصحيحة أولًا، ثم وازن المعادلة '
          'بالمعاملات حتى تتساوى الذرات تمامًا في الطرفين.',
    ),
    BiologyLab.labId: (
      law: 'القلب: 4 حجرات — أذينان وبطينان — والدم يسير: الجسم ← الأذين '
          'الأيمن ← البطين الأيمن ← الرئتان ← الأذين الأيسر ← البطين الأيسر ← الجسم.',
      explanation: 'رسوم تعليمية مبسطة. اضغط على أي جزء لتعرف اسمه ووظيفته، '
          'وكبّر/دوّر الرسم، ثم اختبر نفسك بإخفاء التسميات.',
    ),
  };

  Widget _labWidget(BuildContext context) {
    final complete = _onLabComplete(context);
    switch (labId) {
      case MathLab.labId:
        return MathLab(onComplete: complete);
      case PhysicsLab.labId:
        return PhysicsLab(onComplete: complete);
      case ChemistryLab.labId:
        return ChemistryLab(onComplete: complete);
      case BiologyLab.labId:
        return BiologyLab(onComplete: complete);
      default:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('المختبر غير موجود — تحقق من معرّف المختبر.'),
        );
    }
  }

  String _title() => switch (labId) {
        MathLab.labId => MathLab.title,
        PhysicsLab.labId => PhysicsLab.title,
        ChemistryLab.labId => ChemistryLab.title,
        BiologyLab.labId => BiologyLab.title,
        _ => 'مختبر غير معروف',
      };

  @override
  Widget build(BuildContext context) {
    final law = _lawCards[labId];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_title())),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (law != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('القانون / المبدأ',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(law.law),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('كيف تستخدم المختبر؟',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(law.explanation),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              // The lab widget itself is scrollable; give it a bounded
              // height inside this outer scroll view.
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: _labWidget(context),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'أسئلة «اختبر نفسك» في مختبري الفيزياء والرياضيات من بنك '
                  'المنهج الموثق مع المصدر والصفحة؛ واختبار مختبر الأحياء '
                  'يختبر أجزاء الرسم التعليمي نفسه.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
