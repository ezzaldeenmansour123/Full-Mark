import 'package:material_ui/material_ui.dart';

import '../core/routes.dart';
import '../db/database.dart';
import '../labs/biology_lab.dart';
import '../labs/chemistry_lab.dart';
import '../labs/math_lab.dart';
import '../labs/physics_lab.dart';

/// المختبرات: تجارب ومحاكاة تفاعلية حقيقية مبنية في `lib/labs/`
/// (رسم إجرائي فقط في v1 — بلا محرك 3D).
///
/// تُعرض هنا المختبرات الأربعة المبنية فعلًا فقط — فيزياء، كيمياء،
/// أحياء، رياضيات — ويفتح الضغط على أي بطاقة شاشة المختبر الحقيقية
/// عبر المسار المسمّى [AppRoutes.lab]. لا مختبرات مخطط لها ولا
/// بطاقات «قيد الإعداد» في هذه الشاشة.
class LabEntry {
  const LabEntry({
    required this.labId,
    required this.subject,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String labId;
  final String subject;
  final String title;
  final String description;
  final IconData icon;
}

const List<LabEntry> kLabs = <LabEntry>[
  LabEntry(
    labId: PhysicsLab.labId,
    subject: 'فيزياء',
    title: PhysicsLab.title,
    description: PhysicsLab.description,
    icon: Icons.bolt,
  ),
  LabEntry(
    labId: ChemistryLab.labId,
    subject: 'كيمياء',
    title: ChemistryLab.title,
    description: ChemistryLab.description,
    icon: Icons.science,
  ),
  LabEntry(
    labId: BiologyLab.labId,
    subject: 'أحياء',
    title: BiologyLab.title,
    description: BiologyLab.description,
    icon: Icons.eco,
  ),
  LabEntry(
    labId: MathLab.labId,
    subject: 'رياضيات',
    title: MathLab.title,
    description: MathLab.description,
    icon: Icons.calculate,
  ),
];

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  int _completedLabs = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // حقيقي من قاعدة البيانات: عدد مراحل المختبر المكتملة.
    final int completed =
        await DatabaseHelper.instance.getCompletedLabStagesCount();
    if (!mounted) return;
    setState(() {
      _completedLabs = completed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المختبرات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.science),
                    title: const Text('تجاربك المكتملة'),
                    trailing: Text(
                      '$_completedLabs',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'مختبرات تفاعلية تعمل دون اتصال. افتح أي مختبر وجرّب، '
                  'ثم أكمل أسئلة «اختبر نفسك» داخله لتُسجَّل نتيجتك — '
                  'ويمكنك إعادة أي تجربة متى شئت.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...kLabs.map(
                  (LabEntry lab) => Card(
                    child: ListTile(
                      leading: Icon(lab.icon),
                      title: Text(lab.title),
                      subtitle: Text('${lab.subject} — ${lab.description}'),
                      trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed(AppRoutes.lab, arguments: lab.labId)
                            .then((_) => _load());
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
