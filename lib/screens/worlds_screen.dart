import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../db/database.dart';
import 'curriculum_screen.dart';

/// تعريف عالم واحد (مادة دراسية).
class WorldDef {
  const WorldDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;

  Color get color =>
      AbqariyaColors.worldColors[id] ?? AbqariyaColors.navy;
}

/// العوالم السبعة — مواد الصف الثالث الثانوي العلمي اليمني.
/// الأوصاف نطاقٌ عام للمادة فقط؛ لا وحدات ولا دروس ولا أسئلة مخترعة هنا.
const List<WorldDef> kWorlds = <WorldDef>[
  WorldDef(
    id: 'math',
    name: 'رياضيات',
    description: 'الجبر والهندسة وحساب التفاضل والتكامل وفق المنهج الوزاري.',
    icon: Icons.calculate,
  ),
  WorldDef(
    id: 'physics',
    name: 'فيزياء',
    description: 'الميكانيكا والكهرباء والمغناطيسية والضوء والفيزياء الحديثة.',
    icon: Icons.bolt,
  ),
  WorldDef(
    id: 'chemistry',
    name: 'كيمياء',
    description: 'الكيمياء العضوية وغير العضوية والتفاعلات والحسابات الكيميائية.',
    icon: Icons.science,
  ),
  WorldDef(
    id: 'biology',
    name: 'أحياء',
    description: 'الخلية والوراثة والتصنيف وعلم البيئة وجسم الإنسان.',
    icon: Icons.eco,
  ),
  WorldDef(
    id: 'arabic',
    name: 'عربية',
    description: 'النحو والصرف والبلاغة والأدب والنصوص والتعبير.',
    icon: Icons.menu_book,
  ),
  WorldDef(
    id: 'english',
    name: 'إنجليزية',
    description: 'القواعد والمفردات والقراءة والكتابة وفق المنهج الوزاري.',
    icon: Icons.language,
  ),
  WorldDef(
    id: 'islamic',
    name: 'تربية إسلامية',
    description: 'القرآن الكريم والحديث والفقه والسيرة والأخلاق.',
    icon: Icons.mosque,
  ),
];

/// خريطة العوالم: بطاقة لكل مادة بلونها وأيقونتها وشريط تقدّمها.
///
/// كل العوالم السبعة مفتوحة من أول تثبيت — لا قفل تسلسلي: الضغط على أي
/// عالم يعرض هيكل منهجه اليمني الموثّق من curriculum.json (وحدات ودروس
/// بمصادرها وطبعاتها)، مع حالة «بلا أسئلة بعد» حيث لا أسئلة بعد.
/// شريط التقدّم والنجوم حقيقيان من قاعدة البيانات ويتحركان بعد اللعب.
class WorldsScreen extends StatefulWidget {
  const WorldsScreen({super.key});

  @override
  State<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends State<WorldsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  Map<String, double> _completion = <String, double>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Map<String, double> result = <String, double>{};
    for (final WorldDef world in kWorlds) {
      result[world.id] = await _db.getSubjectCompletion(world.id);
    }
    if (!mounted) return;
    setState(() {
      _completion = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خريطة العوالم')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: kWorlds.length,
              itemBuilder: (BuildContext context, int index) {
                final WorldDef world = kWorlds[index];
                final double progress = _completion[world.id] ?? 0;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: world.color,
                      foregroundColor: Colors.white,
                      child: Icon(world.icon),
                    ),
                    title: Text(
                      world.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(world.description),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor:
                              world.color.withValues(alpha: 0.2),
                          color: world.color,
                        ),
                        const SizedBox(height: 4),
                        Text('${(progress * 100).round()}% مكتمل'),
                      ],
                    ),
                    isThreeLine: true,
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _openWorld(context, world),
                  ),
                );
              },
            ),
    );
  }

  void _openWorld(BuildContext context, WorldDef world) {
    // كل عالم مفتوح: يعرض هيكل المنهج اليمني الموثّق من curriculum.json
    // (وحدات ودروس بمصادرها وطبعاتها)، مع حالة «بلا أسئلة بعد».
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CurriculumScreen(
          subjectId: world.id,
          title: world.name,
          color: world.color,
          icon: world.icon,
        ),
      ),
    );
  }
}
