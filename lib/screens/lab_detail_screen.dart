// ABQARIYA — Lab Detail Screen (شاشة المختبر)
// Hosts a chosen lab by id. Route: '/lab', argument = lab id (String).
// Example: Navigator.pushNamed(context, '/lab', arguments: 'physics_lab');
// 100% offline. Labs are independent widgets. When a hosted lab reports
// completion via onComplete, this screen persists it in the database
// (markStageCompleted + setLastStage, stage id 'lab:<labId>') and then
// forwards the score to the optional [onComplete] callback. Labs are
// replayable: completing again upserts the same progress row.
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
  /// a callback was supplied (see [_persistingOnComplete]).
  final void Function(int score)? onComplete;

  /// Build from a route: `LabDetailScreen.fromRoute(settings.arguments)`.
  /// Returns null when the argument is not a String lab id.
  static LabDetailScreen? fromRoute(Object? arguments) {
    if (arguments is String) return LabDetailScreen(labId: arguments);
    return null;
  }

  /// Stable stage id used for progress persistence of this lab.
  String get _stageId => 'lab:$labId';

  /// Persist a completed lab run, then forward the score to the
  /// optional external callback. Idempotent: re-completing the same
  /// lab upserts the same progress row, so labs stay replayable.
  Future<void> _persistCompletion() async {
    await DatabaseHelper.instance.markStageCompleted(_stageId);
    await DatabaseHelper.instance.setLastStage(_stageId, _title());
  }

  /// Callback handed to the hosted lab: persist first, then forward.
  void Function(int score) get _persistingOnComplete =>
      (int score) async {
        await _persistCompletion();
        onComplete?.call(score);
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

  Widget _labWidget() {
    switch (labId) {
      case MathLab.labId:
        return MathLab(onComplete: _persistingOnComplete);
      case PhysicsLab.labId:
        return PhysicsLab(onComplete: _persistingOnComplete);
      case ChemistryLab.labId:
        return ChemistryLab(onComplete: _persistingOnComplete);
      case BiologyLab.labId:
        return BiologyLab(onComplete: _persistingOnComplete);
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
                child: _labWidget(),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'اختبر نفسك — أسئلة «اختبر نفسك» داخل كل مختبر تجريبية '
                  '(demo — ليست من المنهج اليمني).',
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
