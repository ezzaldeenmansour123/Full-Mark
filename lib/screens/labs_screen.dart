import 'package:flutter/material.dart';

import '../db/database.dart';
import 'placeholder_screen.dart';

/// المختبرات: تجارب ومحاكاة تفاعلية (رسم إجرائي فقط في v1 — بلا محرك 3D).
///
/// في هذه النسخة تُعرض المختبرات المخطط لها كقائمة «قيد الإعداد» — أسماء
/// مواضيع عامة من المنهج فقط، لا تجربة وهمية ولا نتائج مزيّفة.
/// عندما يبني وكيل المختبرات تجربةً حقيقية، تُستبدل بطاقتها بتجربة عاملة.
class PlannedLab {
  const PlannedLab({
    required this.subject,
    required this.title,
    required this.description,
  });

  final String subject;
  final String title;
  final String description;
}

const List<PlannedLab> kPlannedLabs = <PlannedLab>[
  PlannedLab(
    subject: 'فيزياء',
    title: 'البندول البسيط',
    description: 'جرّبي أثر طول الخيط على زمن الذبذبة — محاكاة تفاعلية.',
  ),
  PlannedLab(
    subject: 'فيزياء',
    title: 'قانون أوم',
    description: 'غيّري الجهد والمقاومة وشاهدي التيار يتغير لحظيًا.',
  ),
  PlannedLab(
    subject: 'كيمياء',
    title: 'التفاعلات الكيميائية',
    description: 'امزجي المواد الافتراضية ولاحظي التغيرات بأمان كامل.',
  ),
  PlannedLab(
    subject: 'أحياء',
    title: 'الخلية تحت المجهر',
    description: 'استكشفي مكونات الخلية الحيوانية والنباتية طبقة طبقة.',
  ),
  PlannedLab(
    subject: 'رياضيات',
    title: 'رسم الدوال',
    description: 'ارسمي الدوال وغيّري معاملاتها وشاهدي المنحنى يتحرك.',
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
    // (الاستعلام السابق كان يشير إلى عمودين غير موجودين في المخطط
    // الرسمي، فأُصلح في دمج 2026-11-25 عبر دالة مساعدة.)
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
                  'المختبرات المخطط لها — قيد الإعداد، وستُبنى من المنهج '
                  'الوزاري المعتمد. الضغط على أي مختبر يعرض تفاصيل ما القادم فيه.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...kPlannedLabs.map(
                  (PlannedLab lab) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_top),
                      title: Text(lab.title),
                      subtitle: Text('${lab.subject} — ${lab.description}'),
                      trailing: const Chip(label: Text('قيد الإعداد')),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlaceholderScreen(
                            args: PlaceholderArgs(
                              title: lab.title,
                              subtitle:
                                  '${lab.subject} — ${lab.description}\n\n'
                                  'هذه التجربة قيد البناء، وستعمل دون اتصال '
                                  'وبالرسم الإجرائي فقط (بلا فيديو وبلا محرك 3D) '
                                  'لتبقى خفيفة على جهازك.',
                              comingSoon: const <String>[
                                'محاكاة تفاعلية تعمل دون اتصال',
                                'أسئلة فهم مرتبطة بالتجربة',
                                'تسجيل نتيجتك في تقدّمك تلقائيًا',
                              ],
                              icon: Icons.science,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
