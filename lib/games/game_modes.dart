// FULL MARK — 12 game modes: enum + config.
// The registry keeps all 12 configs (tests pin the count), but the UI
// exposes ONLY the 8 truly playable modes (see [isPlayable]: quiz,
// true_false, time_race, memory_match, boss_20, complete_equation,
// concept_match, unlock). The other 4 never appear in any picker, and
// GameScreen never shows a placeholder screen for them;
// ministerial_exam links to ExamScreen instead.
//
// complete_equation plays the 4 verified equations in
// lib/games/equation_items.dart (lab + bank, none invented).
// concept_match pairs each lesson question stem with its correct
// answer (MCQ only, from the verified bank).

import '../models/question.dart';

enum GameModeId {
  quiz,
  timeRace,
  unlock,
  completeEquation,
  lab,
  aim,
  memoryMatch,
  trueFalse,
  conceptMatch,
  boss20,
  smartMemory,
  ministerialExam,
}

class GameModeConfig {
  final GameModeId id;

  /// Stable string id used in routes / saved results, e.g. "quiz".
  final String routeId;
  final String titleAr;
  final String descriptionAr;
  final int questionCount;
  final int secondsPerQuestion;

  /// 0 = no overall time limit.
  final int totalSeconds;

  final String scoringRuleAr;

  /// True only when GameScreen really implements this mode.
  final bool isPlayable;

  const GameModeConfig({
    required this.id,
    required this.routeId,
    required this.titleAr,
    required this.descriptionAr,
    required this.questionCount,
    required this.secondsPerQuestion,
    required this.totalSeconds,
    required this.scoringRuleAr,
    required this.isPlayable,
  });
}

const List<GameModeConfig> kGameModes = <GameModeConfig>[
  GameModeConfig(
    id: GameModeId.quiz,
    routeId: 'quiz',
    titleAr: 'اختبار سريع',
    descriptionAr: 'أسئلة اختيار من متعدد مع شرح فوري بعد كل إجابة.',
    questionCount: 10,
    secondsPerQuestion: 60,
    totalSeconds: 0,
    scoringRuleAr: '10 نقاط لكل إجابة صحيحة + 5 نقاط مكافأة للسلسلة.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.timeRace,
    routeId: 'time_race',
    titleAr: 'سباق الوقت',
    descriptionAr: 'أجب بأسرع ما يمكن — كل سؤال 20 ثانية فقط.',
    questionCount: 10,
    secondsPerQuestion: 20,
    totalSeconds: 0,
    scoringRuleAr: 'نفس نقاط الاختبار السريع، مع ضغط الوقت.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.unlock,
    routeId: 'unlock',
    titleAr: 'افتح القفل',
    descriptionAr: 'أجب إجابات صحيحة متتالية لفتح الأقفال واحداً تلو الآخر.',
    questionCount: 12,
    secondsPerQuestion: 60,
    totalSeconds: 0,
    scoringRuleAr: 'قفل يُفتح كل 3 إجابات صحيحة متتالية — 4 أقفال في الجولة.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.completeEquation,
    routeId: 'complete_equation',
    titleAr: 'أكمل المعادلة',
    descriptionAr:
        'وازن معادلات كيميائية حقيقية باختيار المعاملات الصحيحة — '
        '4 معادلات موثقة من المختبر وبنك الأسئلة (الكيمياء فقط).',
    questionCount: 4,
    // 0 = no per-question timer: the equation screen has no countdown,
    // and the old "90 s" was fiction. (v0.1.4 follow-up.)
    secondsPerQuestion: 0,
    totalSeconds: 0,
    scoringRuleAr: '10 نقاط لكل معادلة موزونة صحيحة بأصغر المعاملات.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.lab,
    routeId: 'lab',
    titleAr: 'المختبر',
    descriptionAr: 'تجارب ومحاكاة تفاعلية — ترتبط بوحدة المحاكاة العلمية.',
    questionCount: 6,
    secondsPerQuestion: 0,
    totalSeconds: 0,
    scoringRuleAr: 'نقاط حسب خطوات التجربة الصحيحة.',
    isPlayable: false,
  ),
  GameModeConfig(
    id: GameModeId.aim,
    routeId: 'aim',
    titleAr: 'صوّب الهدف',
    descriptionAr: 'صوّب على الإجابة الصحيحة قبل انتهاء الوقت.',
    questionCount: 10,
    secondsPerQuestion: 15,
    totalSeconds: 0,
    scoringRuleAr: 'نقاط حسب سرعة الإصابة ودقتها.',
    isPlayable: false,
  ),
  GameModeConfig(
    id: GameModeId.memoryMatch,
    routeId: 'memory_match',
    titleAr: 'طابق الذاكرة',
    descriptionAr: 'اقلب البطاقات وطابق كل سؤال مع إجابته الصحيحة.',
    questionCount: 8,
    secondsPerQuestion: 0,
    totalSeconds: 180,
    scoringRuleAr: '10 نقاط لكل تطابق صحيح، وخصم محاولة عند الخطأ.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.trueFalse,
    routeId: 'true_false',
    titleAr: 'صح أم خطأ',
    descriptionAr: 'احكم على كل عبارة: صحيحة أم خاطئة، مع الشرح.',
    questionCount: 10,
    secondsPerQuestion: 30,
    totalSeconds: 0,
    scoringRuleAr: '10 نقاط لكل حكم صحيح + 5 لمكافأة السلسلة.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.conceptMatch,
    routeId: 'concept_match',
    titleAr: 'مطابقة المفاهيم',
    descriptionAr:
        'طابق كل سؤال مع إجابته الصحيحة من أسئلة الدرس نفسه — '
        '5 أزواج في كل جولة.',
    questionCount: 5,
    secondsPerQuestion: 0,
    totalSeconds: 0,
    scoringRuleAr: '10 نقاط لكل تطابق صحيح من أول محاولة.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.boss20,
    routeId: 'boss_20',
    titleAr: 'تحدي العشرين',
    descriptionAr: '20 سؤالاً متتالياً — تحدٍّ كامل لاختبار إتقانك.',
    questionCount: 20,
    secondsPerQuestion: 45,
    totalSeconds: 0,
    scoringRuleAr: '10 نقاط لكل إجابة صحيحة + 5 لمكافأة السلسلة.',
    isPlayable: true,
  ),
  GameModeConfig(
    id: GameModeId.smartMemory,
    routeId: 'smart_memory',
    titleAr: 'الذاكرة الذكية',
    descriptionAr: 'مراجعة ذكية مبنية على جدول التكرار المتباعد.',
    questionCount: 10,
    secondsPerQuestion: 60,
    totalSeconds: 0,
    scoringRuleAr: 'نقاط المراجعة حسب دقة الإجابة.',
    isPlayable: false,
  ),
  GameModeConfig(
    id: GameModeId.ministerialExam,
    routeId: 'ministerial_exam',
    titleAr: 'محاكاة الامتحان الوزاري',
    descriptionAr: 'جلسة امتحان مؤقتة كاملة — انظر lib/exam/ministerial_exam.dart.',
    questionCount: 20,
    secondsPerQuestion: 0,
    totalSeconds: 3600,
    scoringRuleAr: 'تصحيح تلقائي ونتيجة مفصلة لكل سؤال.',
    isPlayable: false,
  ),
];

GameModeConfig modeConfigByRouteId(String routeId) =>
    kGameModes.firstWhere(
      (m) => m.routeId == routeId,
      orElse: () => kGameModes.first,
    );

/// True only for a route id that exists in the registry. GameScreen
/// shows an honest "unknown mode" screen for anything else instead
/// of silently playing a quiz (the old firstWhere fallback hid typos).
bool isKnownRouteId(String routeId) =>
    kGameModes.any((GameModeConfig m) => m.routeId == routeId);

/// Which question types a mode can use. Playable modes filter the bank
/// to these types; other types are excluded at load time and reported
/// honestly by GameScreen (never silently dropped). `match` is not
/// supported by any mode yet: no match rows exist in the bank and the
/// pair structure has no game UI, so it is always excluded with a
/// message instead of being offered as a broken game.
List<QuestionType> questionTypesForMode(GameModeId id) {
  switch (id) {
    case GameModeId.quiz:
    case GameModeId.timeRace:
    case GameModeId.boss20:
      return const [
        QuestionType.mcq,
        QuestionType.trueFalse,
        QuestionType.fill,
        QuestionType.ordering,
      ];
    case GameModeId.unlock:
      // MCQ + true/false only: the lock mechanic stays snappy and
      // every question has one tap answer.
      return const [QuestionType.mcq, QuestionType.trueFalse];
    case GameModeId.trueFalse:
      return const [QuestionType.trueFalse];
    case GameModeId.memoryMatch:
    case GameModeId.conceptMatch:
      return const [QuestionType.mcq];
    default:
      return const [QuestionType.mcq];
  }
}

/// Arabic label for a question type, used in honest "unsupported type"
/// messages shown to the player.
String questionTypeLabelAr(QuestionType type) {
  switch (type) {
    case QuestionType.mcq:
      return 'اختيار من متعدد';
    case QuestionType.trueFalse:
      return 'صح أم خطأ';
    case QuestionType.fill:
      return 'أكمل الفراغ';
    case QuestionType.ordering:
      return 'ترتيب';
    case QuestionType.match:
      return 'مطابقة';
  }
}
