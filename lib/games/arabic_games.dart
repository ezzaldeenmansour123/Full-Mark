// ABQARIYA — Arabic games: sentence building + i'rab.
// DEMO DATA ONLY. The Yemeni Arabic textbook was not provided, so no
// sentence here is presented as Yemeni curriculum. Every demo item is
// labelled «تجريبي». The widgets take their data as parameters; the only
// built-in example below is explicitly marked demo and is a generic
// language exercise, not a curriculum sentence.

import 'package:flutter/material.dart';

/// One sentence-building item: [words] in shuffled display order,
/// [correctOrder] the correct order (same words, correct sequence).
class SentenceItem {
  final String id;
  final List<String> words;
  final List<String> correctOrder;

  /// Must be "demo — not Yemeni curriculum" for all built-in items.
  final String source;

  const SentenceItem({
    required this.id,
    required this.words,
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

/// One i'rab item: tap a word, then choose its i'rab from [options].
class IrabItem {
  final String id;
  final String sentence;
  final List<String> words;

  /// word -> correct i'rab label, e.g. {"العلمُ": "مبتدأ مرفوع"}.
  /// Labels are grammatical terms, not quoted textbook text.
  final Map<String, String> correctIrab;
  final List<String> options;
  final String source;

  const IrabItem({
    required this.id,
    required this.sentence,
    required this.words,
    required this.correctIrab,
    required this.options,
    required this.source,
  });

  bool get isDemo => source.trim() == 'demo — not Yemeni curriculum';
}

/// Pure logic: score a sentence-building attempt.
bool checkSentenceOrder(SentenceItem item, List<String> attempt) =>
    item.isCorrectOrder(attempt);

/// Pure logic: score one i'rab choice.
bool checkIrab(IrabItem item, String word, String chosen) =>
    item.correctIrab[word] == chosen;

/// A single generic demo sentence, labelled demo. It is NOT curriculum.
/// Used only when the caller passes no data at all, so the widget never
/// renders an invented "curriculum" sentence.
const SentenceItem kDemoSentence = SentenceItem(
  id: 'demo-ar-sentence-001',
  words: <String>['العلمُ', 'نورٌ', 'يهدي', 'إلى', 'الحقِّ'],
  correctOrder: <String>['العلمُ', 'نورٌ', 'يهدي', 'إلى', 'الحقِّ'],
  source: 'demo — not Yemeni curriculum',
);

/// Sentence-building widget: tap words in order to build the sentence.
/// Shows a «تجريبي» badge on every demo item.
class ArabicSentenceGame extends StatefulWidget {
  final List<SentenceItem> items;
  final void Function(int correct, int total)? onFinished;

  const ArabicSentenceGame({
    super.key,
    this.items = const <SentenceItem>[kDemoSentence],
    this.onFinished,
  });

  @override
  State<ArabicSentenceGame> createState() => _ArabicSentenceGameState();
}

class _ArabicSentenceGameState extends State<ArabicSentenceGame> {
  int _index = 0;
  final List<String> _picked = [];
  String? _feedback;
  int _correct = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text('قيد الإعداد — جمل المنهج اليمني لم تُضف بعد.'),
      );
    }
    final item = widget.items[_index];
    final remaining =
        item.words.where((w) => !_picked.contains(w)).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Chip(label: Text('تجريبي')),
          Text('رتّب الكلمات لتكوين جملة صحيحة',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('الجملة ${_index + 1} من ${widget.items.length}'),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          if (_feedback != null) Text(_feedback!),
          Row(
            children: [
              FilledButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () {
                        final ok = checkSentenceOrder(item, _picked);
                        setState(() {
                          _feedback = ok ? 'صحيحة ✓' : 'غير صحيحة ✗ — حاول مجدداً';
                          if (ok) _correct++;
                        });
                      },
                child: const Text('تحقق'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  _picked.clear();
                  _feedback = null;
                }),
                child: const Text('إعادة'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_index + 1 >= widget.items.length) {
                    widget.onFinished?.call(_correct, widget.items.length);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('انتهت اللعبة: $_correct / ${widget.items.length}')),
                    );
                  } else {
                    setState(() {
                      _index++;
                      _picked.clear();
                      _feedback = null;
                    });
                  }
                },
                child: const Text('التالي'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// I'rab widget: tap a word, then choose its i'rab from the options.
class ArabicIrabGame extends StatefulWidget {
  final IrabItem item;
  const ArabicIrabGame({super.key, required this.item});

  @override
  State<ArabicIrabGame> createState() => _ArabicIrabGameState();
}

class _ArabicIrabGameState extends State<ArabicIrabGame> {
  String? _selectedWord;
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
          Text(item.sentence, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text('اضغط على كلمة ثم اختر إعرابها:'),
          Wrap(
            spacing: 8,
            children: item.words
                .map((w) => ChoiceChip(
                      label: Text(w),
                      selected: _selectedWord == w,
                      onSelected: (_) =>
                          setState(() => _selectedWord = w),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: item.options
                .map((opt) => FilledButton.tonal(
                      onPressed: _selectedWord == null
                          ? null
                          : () {
                              final ok =
                                  checkIrab(item, _selectedWord!, opt);
                              setState(() => _feedback = ok
                                  ? 'صحيح ✓ — «$_selectedWord» إعرابها: $opt'
                                  : 'غير صحيح ✗ — حاول مجدداً');
                            },
                      child: Text(opt),
                    ))
                .toList(),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(_feedback!),
          ],
        ],
      ),
    );
  }
}
