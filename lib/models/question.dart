// ABQARIYA — Question model.
// Content honesty: Yemeni textbooks were NOT provided. No question may be
// presented as Yemeni curriculum unless its `source` says so explicitly.
// Every Question MUST carry a non-empty `source`. Validation throws on a
// missing/empty source. Demo questions must use source
// "demo — not Yemeni curriculum" and the UI shows a visible "تجريبي" badge.

/// Types of question the engine / screens can render.
enum QuestionType { mcq, trueFalse, fill, ordering, match }

QuestionType questionTypeFromString(String value) {
  switch (value) {
    case 'mcq':
      return QuestionType.mcq;
    case 'true_false':
      return QuestionType.trueFalse;
    case 'fill':
      return QuestionType.fill;
    case 'ordering':
      return QuestionType.ordering;
    case 'match':
      return QuestionType.match;
    default:
      throw FormatException('Unknown QuestionType: $value');
  }
}

String questionTypeToString(QuestionType type) {
  switch (type) {
    case QuestionType.mcq:
      return 'mcq';
    case QuestionType.trueFalse:
      return 'true_false';
    case QuestionType.fill:
      return 'fill';
    case QuestionType.ordering:
      return 'ordering';
    case QuestionType.match:
      return 'match';
  }
}

/// The source string that marks a question as DEMO — never curriculum.
const String kDemoSource = 'demo — not Yemeni curriculum';

/// A single question loaded from JSON / DB. The engine never invents one.
class Question {
  /// Stable id, e.g. "demo-math-001" or "ye-phys-u1-l2-001".
  final String id;

  /// Subject key, e.g. "math", "physics", "chemistry", "biology",
  /// "arabic", "english", "islamic". Free-form string, not an enum, so a
  /// future content importer can add subjects without a code change.
  final String subject;

  /// Unit / lesson labels as they appear in the source book, if known.
  final String unit;
  final String lesson;

  final QuestionType type;

  /// The question text itself, exactly as in its source.
  final String text;

  /// Answer options. For mcq: 3-4 options. For true_false: ["صح", "خطأ"]
  /// (or ["True", "False"] for English). For fill/ordering/match the
  /// meaning is defined by [correctAnswer] / [matchPairs] below.
  final List<String> options;

  /// The correct answer.
  /// - mcq / true_false / fill: the exact correct option / text.
  /// - ordering: the correct order, joined with " | " (see [orderingAnswer]).
  /// - match: the correct pairs, joined with " | " as "a=ب" (see [matchPairs]).
  final String correctAnswer;

  /// Optional explanation, exactly as in the source (or empty).
  final String explanation;

  /// 1 = easy, 2 = medium, 3 = hard.
  final int difficulty;

  /// REQUIRED. Where this question came from, e.g.
  /// "demo — not Yemeni curriculum" or
  /// "كتاب الفيزياء — ثالث ثانوي علمي (اليمن)، ص 42".
  /// Empty / missing source is a data error and throws in [fromJson].
  final String source;

  /// Page number in the source book, if known; null for demo questions.
  final int? sourcePage;

  const Question({
    required this.id,
    required this.subject,
    required this.unit,
    required this.lesson,
    required this.type,
    required this.text,
    required this.options,
    required this.correctAnswer,
    this.explanation = '',
    this.difficulty = 2,
    required this.source,
    this.sourcePage,
  });

  /// True when this is demo data — never Yemeni curriculum.
  bool get isDemo => source.trim() == kDemoSource;

  /// True when the source claims to be the Yemeni curriculum.
  /// NOTE: this only checks the label; the content importer / coordinator
  /// is responsible for verifying that labelled content really came from
  /// the Yemeni textbooks.
  bool get isCurriculum => !isDemo && source.trim().isNotEmpty;

  /// For ordering questions: correctAnswer split on " | ".
  List<String> get orderingAnswer =>
      type == QuestionType.ordering ? correctAnswer.split(' | ') : const [];

  /// For match questions: correctAnswer split into "left=right" pairs.
  Map<String, String> get matchPairs {
    if (type != QuestionType.match) return const {};
    final out = <String, String>{};
    for (final part in correctAnswer.split(' | ')) {
      final i = part.indexOf('=');
      if (i > 0) out[part.substring(0, i).trim()] = part.substring(i + 1).trim();
    }
    return out;
  }

  /// Throws [FormatException] if the source is missing/empty, if the id or
  /// text is empty, if difficulty is outside 1-3, or if an mcq has
  /// fewer than 2 options / its correct answer is not among the options.
  factory Question.fromJson(Map<String, dynamic> json) {
    final source = (json['source'] as String?)?.trim() ?? '';
    if (source.isEmpty) {
      throw FormatException(
        'Question ${json['id'] ?? '(no id)'} has no source — '
        'a question without a source must never be loaded.',
      );
    }
    final id = (json['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) throw const FormatException('Question id is missing.');
    final text = (json['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      throw FormatException('Question $id has empty text.');
    }
    final difficulty = json['difficulty'] is int
        ? json['difficulty'] as int
        : int.tryParse('${json['difficulty'] ?? 2}') ?? 2;
    if (difficulty < 1 || difficulty > 3) {
      throw FormatException('Question $id: difficulty must be 1-3.');
    }
    final type = questionTypeFromString(
      (json['type'] as String?)?.trim() ?? 'mcq',
    );
    final options = (json['options'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final correctAnswer = (json['correctAnswer'] as String?)?.trim() ?? '';
    if (correctAnswer.isEmpty) {
      throw FormatException('Question $id: correctAnswer is missing.');
    }
    if (type == QuestionType.mcq) {
      if (options.length < 2) {
        throw FormatException('Question $id: mcq needs at least 2 options.');
      }
      if (!options.contains(correctAnswer)) {
        throw FormatException(
          'Question $id: correctAnswer is not among the options.',
        );
      }
    }
    if (type == QuestionType.trueFalse && options.length < 2) {
      throw FormatException('Question $id: true_false needs 2 options.');
    }
    return Question(
      id: id,
      subject: (json['subject'] as String?)?.trim() ?? '',
      unit: (json['unit'] as String?)?.trim() ?? '',
      lesson: (json['lesson'] as String?)?.trim() ?? '',
      type: type,
      text: text,
      options: options,
      correctAnswer: correctAnswer,
      explanation: (json['explanation'] as String?) ?? '',
      difficulty: difficulty,
      source: source,
      sourcePage: json['sourcePage'] is int
          ? json['sourcePage'] as int
          : int.tryParse('${json['sourcePage'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'subject': subject,
        'unit': unit,
        'lesson': lesson,
        'type': questionTypeToString(type),
        'text': text,
        'options': options,
        'correctAnswer': correctAnswer,
        'explanation': explanation,
        'difficulty': difficulty,
        'source': source,
        'sourcePage': sourcePage,
      };

  /// Parses a list; skips nothing silently — a bad entry throws, so bad
  /// content can never slip into a game silently. Callers that want to
  /// tolerate bad rows must catch per-row and log the id.
  static List<Question> listFromJson(List<dynamic> jsonList) =>
      jsonList
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
}
