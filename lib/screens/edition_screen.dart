// ABQARIYA — «النسخة الدراسية»: the active study edition, from the
// verified curriculum data itself (assets/data/curriculum.json) and
// the live question database. Honest by construction: every number
// is computed from what the app actually contains, and the screen
// states plainly that this is the only edition included in this
// version — there is no Aden option and no button that does nothing.

import 'package:material_ui/material_ui.dart';

import '../content/curriculum.dart';
import '../db/database.dart';

class EditionScreen extends StatefulWidget {
  const EditionScreen({super.key});

  @override
  State<EditionScreen> createState() => _EditionScreenState();
}

class _EditionScreenState extends State<EditionScreen> {
  CurriculumData? _curriculum;
  int? _totalQuestions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final CurriculumData curriculum = await CurriculumData.load();
    final int total =
        await DatabaseHelper.instance.getTotalQuestions();
    if (!mounted) return;
    setState(() {
      _curriculum = curriculum;
      _totalQuestions = total;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخة الدراسية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final CurriculumData curriculum = _curriculum!;
    final int totalQuestions = _totalQuestions ?? 0;
    final int totalUnits = curriculum.subjects.fold<int>(
      0,
      (int sum, CurriculumSubject s) => sum + s.defaultUnits.length,
    );
    final int totalBooks = curriculum.subjects.fold<int>(
      0,
      (int sum, CurriculumSubject s) => sum + s.books.length,
    );
    // The reference edition is Sanaa 2027 (user decision — the
    // unified edition for the third secondary scientific track).
    // defaultEdition is 'sanaa'; Aden is comparison-only, never app
    // content.
    final String editionName = curriculum.defaultEdition == 'sanaa'
        ? 'صنعاء 2027'
        : curriculum.defaultEdition;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book),
                    SizedBox(width: 8),
                    Text(
                      'النسخة المعتمدة في التطبيق',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'طبعة $editionName — النسخة الموحّدة للصف الثالث '
                  'الثانوي (علمي)، وهي المرجع الوحيد لمحتوى هذا '
                  'التطبيق.',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هذه هي النسخة الوحيدة المضمّنة في هذه النسخة من '
                  'التطبيق. لا توجد نسخة عدن داخل التطبيق، ولا توجد '
                  'نسخ أخرى للاختيار منها.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _statsRow(
          context,
          stats: <_Stat>[
            _Stat('المواد', '${curriculum.subjects.length}'),
            _Stat('الوحدات', '$totalUnits'),
            _Stat('الدروس', '${curriculum.totalLessons}'),
            _Stat('الكتب', '$totalBooks'),
            _Stat('الأسئلة الموثّقة', '$totalQuestions'),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'الكتب المعتمدة لكل مادة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final CurriculumSubject subject in curriculum.subjects)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${subject.nameAr} — ${subject.defaultUnits.length} '
                    'وحدة، ${subject.lessonCount} درساً',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  for (final CurriculumBook book in subject.books)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${book.titleAr}'
                        '${book.edition != null && book.edition!.isNotEmpty ? ' — ${book.edition}' : ''}'
                        '${book.pages != null && book.pages! > 0 ? ' — ${book.pages} صفحة' : ''}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${curriculum.copyright.isNotEmpty ? 'ملاحظة: ${curriculum.copyright}\n' : ''}'
              'الكتب المدرسية مصدر مرجعي فقط — نصوصها غير مضمّنة '
              'في التطبيق، وأسئلة اللعبة صياغة أصلية موثّقة بالكتاب '
              'ورقم الصفحة.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statsRow(BuildContext context, {required List<_Stat> stats}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final _Stat s in stats)
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  Text(
                    s.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(s.label),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value);

  final String label;
  final String value;
}
