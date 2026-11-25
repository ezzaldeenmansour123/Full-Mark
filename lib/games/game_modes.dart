// ABQARIYA — 12 game modes: enum + config.
// Only 5 modes are TRULY PLAYABLE in this delivery (see [isPlayable]:
// quiz, true_false, time_race, memory_match, boss_20). The other 7 are
// defined here so their config exists, but the game screen shows an honest
// «قيد الإعداد» state for them — never a dead button, never a fake game.

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
  linkConcepts,
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
    questionCount: 8,
    secondsPerQuestion: 60,
    totalSeconds: 0,
    scoringRuleAr: 'قفل يُفتح كل 3 إجابات صحيحة متتالية.',
    isPlayable: false,
  ),
  GameModeConfig(
    id: GameModeId.completeEquation,
    routeId: 'complete_equation',
    titleAr: 'أكمل المعادلة',
    descriptionAr: 'أكمل المعادلات والعلاقات العلمية الناقصة.',
    questionCount: 8,
    secondsPerQuestion: 90,
    totalSeconds: 0,
    scoringRuleAr: '10 نقاط لكل معادلة مكتملة صحيحة.',
    isPlayable: false,
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
    id: GameModeId.linkConcepts,
    routeId: 'link_concepts',
    titleAr: 'اربط المفاهيم',
    descriptionAr: 'اربط كل مفهوم بتعريفه أو مثاله الصحيح.',
    questionCount: 8,
    secondsPerQuestion: 60,
    totalSeconds: 0,
    scoringRuleAr: '10 نقاط لكل ربط صحيح.',
    isPlayable: false,
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

/// Which question types a mode can use. Playable modes filter the bank
/// to these types; other types are simply not offered in that mode.
List<QuestionType> questionTypesForMode(GameModeId id) {
  switch (id) {
    case GameModeId.quiz:
    case GameModeId.timeRace:
    case GameModeId.boss20:
      return const [QuestionType.mcq, QuestionType.trueFalse];
    case GameModeId.trueFalse:
      return const [QuestionType.trueFalse];
    case GameModeId.memoryMatch:
      return const [QuestionType.mcq, QuestionType.match];
    default:
      return const [QuestionType.mcq];
  }
}
