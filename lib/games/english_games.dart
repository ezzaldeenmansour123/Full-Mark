// ABQARIYA — English games: vocabulary matching + sentence building.
// DEMO DATA ONLY (labelled «تجريبي»); no Yemeni English textbook content
// is included, because it was not provided.
// PRONUNCIATION: system TTS ONLY if available on the device. No audio
// files are bundled, and no audio is claimed to exist when TTS is
// unavailable. The UI label is always:
//   "نطق عبر نظام الهاتف (إن توفر)"
// TTS is attempted through flutter_tts ONLY if that package is added by
// the integrator; this file deliberately does NOT import flutter_tts, so
// the app compiles without it. The [EnglishTts] interface below is the
// seam: the app shell provides a real implementation when available,
// otherwise [NoTtsAvailable] is used and the button is disabled with an
// honest message.

import 'package:flutter/material.dart';

/// Seam for system TTS. Implement with flutter_tts in the app shell if
/// desired; this file ships without any TTS dependency.
abstract class EnglishTts {
  Future<bool> get isAvailable;
  Future<void> speak(String text, {String language = 'en-US'});
}

/// Used when no TTS engine is available: speak() does nothing, and the
/// UI reports honestly that pronunciation is unavailable.
class NoTtsAvailable implements EnglishTts {
  const NoTtsAvailable();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<void> speak(String text, {String language = 'en-US'}) async {
    // Intentionally a no-op: never pretend audio played.
  }
}

/// One vocabulary pair for the matching game.
class VocabPair {
  final String english;
  final String arabic;
  final String source;

  const VocabPair({
    required this.english,
    required this.arabic,
    required this.source,
  });

  bool get isDemo => source.trim() == 'demo — not Yemeni curriculum';
}

/// Pure logic: does [english] match [arabic] in [pairs]?
bool checkVocabMatch(List<VocabPair> pairs, String english, String arabic) =>
    pairs.any((p) => p.english == english && p.arabic == arabic);

/// Pure logic: is [attempt] the correct order for [correctOrder]?
bool checkEnglishSentenceOrder(List<String> correctOrder, List<String> attempt) {
  if (attempt.length != correctOrder.length) return false;
  for (var i = 0; i < attempt.length; i++) {
    if (attempt[i] != correctOrder[i]) return false;
  }
  return true;
}

/// Demo vocab pairs, labelled demo — generic words, NOT curriculum.
const List<VocabPair> kDemoVocab = <VocabPair>[
  VocabPair(english: 'book', arabic: 'كتاب', source: 'demo — not Yemeni curriculum'),
  VocabPair(english: 'water', arabic: 'ماء', source: 'demo — not Yemeni curriculum'),
  VocabPair(english: 'school', arabic: 'مدرسة', source: 'demo — not Yemeni curriculum'),
  VocabPair(english: 'science', arabic: 'علم', source: 'demo — not Yemeni curriculum'),
];

/// Vocabulary matching widget: tap an English word, then its Arabic match.
class EnglishVocabMatchGame extends StatefulWidget {
  final List<VocabPair> pairs;
  final EnglishTts tts;

  const EnglishVocabMatchGame({
    super.key,
    this.pairs = kDemoVocab,
    this.tts = const _NoTtsConst(),
  });

  @override
  State<EnglishVocabMatchGame> createState() => _EnglishVocabMatchGameState();
}

// const-compatible wrapper around NoTtsAvailable.
class _NoTtsConst extends NoTtsAvailable {
  const _NoTtsConst();
}

class _EnglishVocabMatchGameState extends State<EnglishVocabMatchGame> {
  String? _selectedEnglish;
  final Set<String> _matched = {};
  String? _feedback;
  bool _ttsAvailable = false;

  // Shuffled once in initState — never in build(), or the words would
  // jump around on every rebuild.
  late final List<String> _englishWords;
  late final List<String> _arabicWords;

  @override
  void initState() {
    super.initState();
    _englishWords = widget.pairs.map((p) => p.english).toList()..shuffle();
    _arabicWords = widget.pairs.map((p) => p.arabic).toList()..shuffle();
    widget.tts.isAvailable.then((v) {
      if (mounted) setState(() => _ttsAvailable = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pairs.isEmpty) {
      return const Center(
        child: Text('قيد الإعداد — مفردات المنهج اليمني لم تُضف بعد.'),
      );
    }
    final englishWords = _englishWords;
    final arabicWords = _arabicWords;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Chip(label: Text('تجريبي')),
          const Text('طابق كل كلمة إنجليزية بمعناها العربي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_ttsAvailable
              ? 'نطق عبر نظام الهاتف (إن توفر) — اضغط 🔊 بجانب الكلمة.'
              : 'النطق عبر نظام الهاتف غير متوفر على هذا الجهاز حالياً.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: englishWords.map((w) {
              final done = _matched.contains(w);
              return FilledButton.tonal(
                onPressed: done
                    ? null
                    : () => setState(() => _selectedEnglish = w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(w),
                    if (_ttsAvailable)
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 18),
                        tooltip: 'نطق عبر نظام الهاتف (إن توفر)',
                        onPressed: () => widget.tts.speak(w),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: arabicWords.map((a) {
              final done = _matched.any((e) =>
                  checkVocabMatch(widget.pairs, e, a));
              return FilledButton(
                onPressed: done || _selectedEnglish == null
                    ? null
                    : () {
                        final ok = checkVocabMatch(
                            widget.pairs, _selectedEnglish!, a);
                        setState(() {
                          _feedback = ok ? 'صحيح ✓' : 'غير صحيح ✗ — حاول مجدداً';
                          if (ok) _matched.add(_selectedEnglish!);
                          _selectedEnglish = null;
                        });
                      },
                child: Text(a),
              );
            }).toList(),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(_feedback!),
          ],
          if (_matched.length == widget.pairs.length)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('أحسنت! طابقت كل المفردات ✓',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// English sentence-building widget: tap words in the correct order.
class EnglishSentenceGame extends StatefulWidget {
  final List<String> words;
  final List<String> correctOrder;
  final EnglishTts tts;

  const EnglishSentenceGame({
    super.key,
    required this.words,
    required this.correctOrder,
    this.tts = const _NoTtsConst(),
  });

  @override
  State<EnglishSentenceGame> createState() => _EnglishSentenceGameState();
}

class _EnglishSentenceGameState extends State<EnglishSentenceGame> {
  final List<String> _picked = [];
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.words.where((w) => !_picked.contains(w)).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Chip(label: Text('تجريبي')),
          const Text('Arrange the words to make a correct sentence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _picked.map((w) => Chip(label: Text(w))).toList(),
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
                    final ok = checkEnglishSentenceOrder(
                        widget.correctOrder, _picked);
                    setState(() => _feedback =
                        ok ? 'Correct ✓' : 'Not correct ✗ — try again');
                  },
            child: const Text('Check / تحقق'),
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
