// ABQARIYA — Islamic games: ordering / linking concepts.
// CONTENT RULE (critical): concepts here are ONLY general, well-established
// Islamic education TOPIC TITLES (e.g. "أركان الإسلام"). No Quranic verse
// and no hadith text is quoted — nothing is reproduced from memory.
// Verified textbook wording is «قيد الإعداد» until the Yemeni textbook is
// provided and imported by the content owner. Every item is labelled
// «تجريبي» when it is demo data.

import 'package:material_ui/material_ui.dart';

/// A concept-ordering item: put the [items] in the correct order
/// ([correctOrder]). Items are topic titles only.
class ConceptOrderingItem {
  final String id;
  final String titleAr;
  final List<String> items;
  final List<String> correctOrder;
  final String source;

  const ConceptOrderingItem({
    required this.id,
    required this.titleAr,
    required this.items,
    required this.correctOrder,
    required this.source,
  });

  bool get isDemo => source.trim() == 'demo — not Yemeni curriculum';

  bool isCorrectOrder(List<String> attempt) {
    if (attempt.length != correctOrder.length) return false;
    for (var i = 0; i < attempt.length; i++) {
      if (attempt[i] != correctOrder[i]) return false;
    }
    return true;
  }
}

/// A concept-linking item: link each concept to its matching category.
/// Keys and values are topic titles only — no quoted texts.
class ConceptLinkItem {
  final String id;
  final String titleAr;
  final Map<String, String> correctLinks;
  final String source;

  const ConceptLinkItem({
    required this.id,
    required this.titleAr,
    required this.correctLinks,
    required this.source,
  });

  bool get isDemo => source.trim() == 'demo — not Yemeni curriculum';
  List<String> get concepts => correctLinks.keys.toList();
  List<String> get categories => correctLinks.values.toSet().toList();
}

/// Pure logic: check an ordering attempt.
bool checkConceptOrder(ConceptOrderingItem item, List<String> attempt) =>
    item.isCorrectOrder(attempt);

/// Pure logic: check one link.
bool checkConceptLink(ConceptLinkItem item, String concept, String category) =>
    item.correctLinks[concept] == category;

/// Demo only: the five Pillars of Islam as topic titles, in their
/// well-established order. Topic titles only — no quoted text.
/// Labelled demo; verified textbook wording is «قيد الإعداد».
const ConceptOrderingItem kDemoPillarsOrdering = ConceptOrderingItem(
  id: 'demo-islamic-pillars-001',
  titleAr: 'رتّب أركان الإسلام',
  items: <String>['الصلاة', 'الشهادتان', 'الحج', 'الزكاة', 'الصوم'],
  correctOrder: <String>['الشهادتان', 'الصلاة', 'الزكاة', 'الصوم', 'الحج'],
  source: 'demo — not Yemeni curriculum',
);

/// Demo only: link each worship topic to its general category (topic
/// titles only). Labelled demo; verified textbook wording «قيد الإعداد».
const ConceptLinkItem kDemoWorshipLinks = ConceptLinkItem(
  id: 'demo-islamic-links-001',
  titleAr: 'اربط كل عبادة بنوعها',
  correctLinks: <String, String>{
    'الصلاة': 'عبادة بدنية',
    'الزكاة': 'عبادة مالية',
    'الصوم': 'عبادة بدنية',
    'الحج': 'عبادة بدنية ومالية',
  },
  source: 'demo — not Yemeni curriculum',
);

/// Ordering widget: tap items in the correct order.
class IslamicOrderingGame extends StatefulWidget {
  final ConceptOrderingItem item;
  const IslamicOrderingGame({super.key, this.item = kDemoPillarsOrdering});

  @override
  State<IslamicOrderingGame> createState() => _IslamicOrderingGameState();
}

class _IslamicOrderingGameState extends State<IslamicOrderingGame> {
  final List<String> _picked = [];
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final remaining =
        item.items.where((w) => !_picked.contains(w)).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Chip(label: Text('تجريبي')),
          Text(item.titleAr,
              style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'ملاحظة: الصياغة المعتمدة من الكتاب المدرسي «قيد الإعداد» — '
            'العناوين هنا عامة وتجريبية فقط، ولا يُقتبس أي نص قرآني أو حديث.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _picked
                .map((w) => Chip(label: Text(w)))
                .toList(),
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: remaining
                .map((w) => FilledButton.tonal(
                      onPressed: () => setState(() => _picked.add(w)),
                      child: Text(w),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _picked.isEmpty
                ? null
                : () {
                    final ok = checkConceptOrder(item, _picked);
                    setState(() => _feedback =
                        ok ? 'صحيح ✓' : 'غير صحيح ✗ — حاول مجدداً');
                  },
            child: const Text('تحقق'),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(_feedback!),
          ],
        ],
      ),
    );
  }
}

/// Linking widget: tap a concept, then tap its matching category.
class IslamicLinkGame extends StatefulWidget {
  final ConceptLinkItem item;
  const IslamicLinkGame({super.key, this.item = kDemoWorshipLinks});

  @override
  State<IslamicLinkGame> createState() => _IslamicLinkGameState();
}

class _IslamicLinkGameState extends State<IslamicLinkGame> {
  String? _selectedConcept;
  final Set<String> _linked = {};
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Chip(label: Text('تجريبي')),
          Text(item.titleAr,
              style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'ملاحظة: الصياغة المعتمدة من الكتاب المدرسي «قيد الإعداد».',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: item.concepts.map((c) {
              final done = _linked.contains(c);
              return FilledButton.tonal(
                onPressed: done
                    ? null
                    : () => setState(() => _selectedConcept = c),
                child: Text(c),
              );
            }).toList(),
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: item.categories.map((cat) => FilledButton(
                  onPressed: _selectedConcept == null
                      ? null
                      : () {
                          final ok = checkConceptLink(
                              item, _selectedConcept!, cat);
                          setState(() {
                            _feedback =
                                ok ? 'صحيح ✓' : 'غير صحيح ✗ — حاول مجدداً';
                            if (ok) _linked.add(_selectedConcept!);
                            _selectedConcept = null;
                          });
                        },
                  child: Text(cat),
                )).toList(),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(_feedback!),
          ],
          if (_linked.length == item.concepts.length)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('أحسنت! أكملت كل الروابط ✓',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
