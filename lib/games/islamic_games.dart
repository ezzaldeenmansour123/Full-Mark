// ABQARIYA — Islamic games: ordering / linking concepts.
// CONTENT RULE (critical): concepts here are ONLY general, well-established
// Islamic education TOPIC TITLES (e.g. "أركان الإسلام"). No Quranic verse
// and no hadith text is quoted — nothing is reproduced from memory.
// The ordering game below is fed by the REAL documented curriculum
// structure (lesson titles of each unit, in their real order — see
// [IslamicOrderingGameScreen]); the linking game has NO entry point in
// the app because the database holds no concept↔category pairs to feed
// it honestly. Every demo item is labelled «تجريبي» only when it is
// actually demo data.

import 'package:material_ui/material_ui.dart';

import '../content/curriculum.dart';
import '../db/database.dart';
import '../models/game_result.dart';

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
/// Labelled demo; never shown as curriculum content.
const ConceptOrderingItem kDemoPillarsOrdering = ConceptOrderingItem(
  id: 'demo-islamic-pillars-001',
  titleAr: 'رتّب أركان الإسلام',
  items: <String>['الصلاة', 'الشهادتان', 'الحج', 'الزكاة', 'الصوم'],
  correctOrder: <String>['الشهادتان', 'الصلاة', 'الزكاة', 'الصوم', 'الحج'],
  source: 'demo — not Yemeni curriculum',
);

/// Demo only: link each worship topic to its general category (topic
/// titles only). Labelled demo; never shown as curriculum content.
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
/// Shows a «تجريبي» badge ONLY on demo items. «تحقق» counts only the
/// first check; after answering, «التالي» reports the result once via
/// [onFinished].
class IslamicOrderingGame extends StatefulWidget {
  final ConceptOrderingItem item;

  /// Called exactly once per item, when the player taps «التالي»
  /// after checking: true when the order was correct.
  final void Function(bool correct)? onFinished;

  const IslamicOrderingGame({
    super.key,
    this.item = kDemoPillarsOrdering,
    this.onFinished,
  });

  @override
  State<IslamicOrderingGame> createState() => _IslamicOrderingGameState();
}

class _IslamicOrderingGameState extends State<IslamicOrderingGame> {
  final List<String> _picked = [];
  String? _feedback;
  bool _answered = false;
  bool _lastCorrect = false;

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
          if (item.isDemo) const Chip(label: Text('تجريبي')),
          Text(item.titleAr,
              style: Theme.of(context).textTheme.titleMedium),
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
                      onPressed: _answered
                          ? null
                          : () => setState(() => _picked.add(w)),
                      child: Text(w),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          if (!_answered)
            FilledButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () {
                      final ok = checkConceptOrder(item, _picked);
                      setState(() {
                        _feedback =
                            ok ? 'صحيح ✓' : 'غير صحيح ✗ — حاول مجدداً';
                        _answered = true;
                        _lastCorrect = ok;
                      });
                    },
              child: const Text('تحقق'),
            ),
          if (_answered)
            FilledButton(
              onPressed: () => widget.onFinished?.call(_lastCorrect),
              child: const Text('التالي'),
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
/// NOTE: no entry point in the app — the database holds no
/// concept↔category pairs, so this widget is never shown with real data
/// (and never with demo data presented as content).
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
          if (item.isDemo) const Chip(label: Text('تجريبي')),
          Text(item.titleAr,
              style: Theme.of(context).textTheme.titleMedium),
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

/// لعبة ترتيب الدروس — التربية الإسلامية — fed by the REAL documented
/// curriculum structure (assets/data/curriculum.json, Sanaa 2027).
///
/// One ordering item per unit: the player orders that unit's lesson
/// titles into their real order. Lesson titles are topic titles from
/// the documented structure — no verse or hadith text is quoted.
/// Finishing records a real [GameResult] via
/// [DatabaseHelper.recordGameResult] (mode 'islamic_ordering'). The
/// game plays no [Question] rows, so [playedQuestions] is empty on
/// purpose: no per-question attempt is ever fabricated for questions
/// the player did not answer.
class IslamicOrderingGameScreen extends StatefulWidget {
  const IslamicOrderingGameScreen({super.key});

  @override
  State<IslamicOrderingGameScreen> createState() =>
      _IslamicOrderingGameScreenState();
}

class _IslamicOrderingGameScreenState
    extends State<IslamicOrderingGameScreen> {
  List<ConceptOrderingItem> _items = <ConceptOrderingItem>[];
  int _index = 0;
  final List<bool> _results = <bool>[];
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await CurriculumData.load();
    final subject = data.subjectById('islamic');
    final items = <ConceptOrderingItem>[];
    if (subject != null) {
      for (final unit in subject.defaultUnits) {
        if (unit.lessons.length < 2) continue;
        final display = List<String>.from(unit.lessons)..shuffle();
        items.add(ConceptOrderingItem(
          id: 'islamic-u${unit.number}-order',
          titleAr: 'رتّب دروس الوحدة ${unit.number}: ${unit.title}',
          items: display,
          correctOrder: List<String>.from(unit.lessons),
          source: 'المنهج اليمني — نسخة صنعاء 2027',
        ));
      }
    }
    await DatabaseHelper.instance.setLastStage(
      'islamic',
      'لعبة ترتيب الدروس — التربية الإسلامية',
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _onItemFinished(bool correct) async {
    _results.add(correct);
    if (_index + 1 >= _items.length) {
      await _finish();
    } else {
      setState(() => _index++);
    }
  }

  Future<void> _finish() async {
    if (_saved || _results.isEmpty) return;
    _saved = true;
    final total = _results.length;
    final correct = _results.where((r) => r).length;
    var bestStreak = 0;
    var run = 0;
    for (final ok in _results) {
      run = ok ? run + 1 : 0;
      if (run > bestStreak) bestStreak = run;
    }
    final result = GameResult(
      modeId: 'islamic_ordering',
      subject: 'islamic',
      totalQuestions: total,
      correct: correct,
      wrong: total - correct,
      skipped: 0,
      bestStreak: bestStreak,
      streakBonus: 0,
      elapsedSeconds: 0,
      perQuestionCorrect: List<bool>.unmodifiable(_results),
      wrongQuestionIds: const [],
    );
    await DatabaseHelper.instance.recordGameResult(
      result: result,
      playedQuestions: const [],
      mode: 'islamic_ordering',
      stageId: 'islamic',
      lessonTitle: 'لعبة ترتيب الدروس — التربية الإسلامية',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('نتيجة لعبة ترتيب الدروس'),
        content: Text(
          'رتّبت $correct من $total وحدات ترتيباً صحيحاً '
          '(${(correct * 100 / total).round()}٪)\n'
          'النقاط (XP): ${result.xpEarned}',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('لعبة ترتيب الدروس — التربية الإسلامية')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('لعبة ترتيب الدروس — التربية الإسلامية')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لا توجد وحدات متاحة بعد لترتيب دروسها — '
              'ستُضاف فور توفر هيكل المنهج المعتمد.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final item = _items[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لعبة ترتيب الدروس — التربية الإسلامية (${_index + 1}/${_items.length})',
        ),
      ),
      body: IslamicOrderingGame(
        key: ValueKey<String>(item.id),
        item: item,
        onFinished: _onItemFinished,
      ),
    );
  }
}
