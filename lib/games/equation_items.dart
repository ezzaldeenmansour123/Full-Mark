// ABQARIYA — Equation items for the «أكمل المعادلة» (complete the
// equation) game mode.
//
// HONESTY — the complete inventory of usable equations, counted
// 2026-11-25 from the verified sources only:
//   * The chemistry lab's balancer (lib/labs/chemistry_lab.dart) has
//     exactly ONE equation: 2H₂ + O₂ → 2H₂O.
//   * The verified chemistry question bank (assets/data/questions/
//     chemistry.json, 122 questions) contains exactly THREE more
//     equation strings usable as coefficient items, each taken
//     verbatim from a real question (stem or options) with its own
//     source + page: the iron-reduction equation (ye-chemistry-u1-l4-002,
//     p18), the carbon-combustion equation (ye-chemistry-u2-l7-002
//     stem, p36), and the magnesium redox equation
//     (ye-chemistry-u3-l1-002 stem, p43).
//   * Total: 4 items. No equation was invented: every equation string
//     below is verbatim from one of those sources, and the correct
//     coefficients are COMPUTED by atom counting (law of conservation
//     of mass), never written from memory. Correctness also requires
//     the SMALLEST whole-number coefficients: e.g. 4H₂ + 2O₂ → 4H₂O is
//     balanced but NOT the accepted answer (2, 1, 2).
//
// Each item keeps its source bank question id when one exists, so the
// game can record a real attempt against that question. The water
// item has no bank question (it comes from the lab), so its attempt
// is recorded anonymously — see EquationGameScreen.

/// One term of a chemical equation: display formula + atoms per unit.
class EquationTerm {
  const EquationTerm({required this.formula, required this.atoms});

  /// Display formula, e.g. 'H₂', 'FeO', 'Mg²⁺'.
  final String formula;

  /// Atoms per molecule/ion, e.g. {'H': 2, 'O': 1}.
  /// Charge is NOT counted here: coefficients are decided by atom
  /// balance only (every item below is atom-balanced at its canonical
  /// coefficients, and charge balance follows from the book's equation).
  final Map<String, int> atoms;
}

/// One balanceable equation.
class EquationItem {
  const EquationItem({
    required this.id,
    required this.title,
    required this.leftTerms,
    required this.rightTerms,
    required this.correctCoefficients,
    required this.source,
    this.sourcePage,
    this.sourceQuestionId,
    required this.explanation,
  });

  /// Stable id, e.g. 'eq-water'. Not a question id.
  final String id;

  /// Short Arabic title shown above the equation.
  final String title;

  /// Terms left of the arrow, in order.
  final List<EquationTerm> leftTerms;

  /// Terms right of the arrow, in order.
  final List<EquationTerm> rightTerms;

  /// Canonical (smallest whole-number) coefficients: left terms first,
  /// then right terms. Each is 1..4.
  final List<int> correctCoefficients;

  /// Where the equation string came from (book / lab), verbatim.
  final String source;

  /// Page in the source book, when known. Null for the lab item.
  final int? sourcePage;

  /// Id of the verified bank question this equation is taken from,
  /// when one exists. Null for the water item (lab-only).
  final String? sourceQuestionId;

  /// Why the canonical coefficients are correct (from the source).
  final String explanation;

  /// All terms in coefficient order (left, then right).
  List<EquationTerm> get allTerms => <EquationTerm>[...leftTerms, ...rightTerms];
}

/// Count atoms for one side: coefficient × atoms-per-term, summed.
Map<String, int> countSideAtoms(
  List<EquationTerm> terms,
  List<int> coefficients,
) {
  final Map<String, int> out = <String, int>{};
  for (var i = 0; i < terms.length; i++) {
    for (final MapEntry<String, int> e in terms[i].atoms.entries) {
      out[e.key] = (out[e.key] ?? 0) + coefficients[i] * e.value;
    }
  }
  return out;
}

/// True when [coefficients] balance the equation (same atom count for
/// every element on both sides). Balance alone is NOT correctness:
/// use [isCanonical] for the accepted answer.
bool coefficientsBalance(EquationItem item, List<int> coefficients) {
  if (coefficients.length != item.allTerms.length) return false;
  final Map<String, int> left = countSideAtoms(
    item.leftTerms,
    coefficients.sublist(0, item.leftTerms.length),
  );
  final Map<String, int> right = countSideAtoms(
    item.rightTerms,
    coefficients.sublist(item.leftTerms.length),
  );
  if (left.length != right.length) return false;
  for (final MapEntry<String, int> e in left.entries) {
    if (right[e.key] != e.value) return false;
  }
  return true;
}

/// True only for the canonical smallest whole-number coefficients.
bool isCanonical(EquationItem item, List<int> coefficients) {
  if (coefficients.length != item.correctCoefficients.length) return false;
  for (var i = 0; i < coefficients.length; i++) {
    if (coefficients[i] != item.correctCoefficients[i]) return false;
  }
  return true;
}

/// The four verified equations. Order is pedagogical (water first);
/// the game shuffles them per sitting.
const List<EquationItem> kEquationItems = <EquationItem>[
  EquationItem(
    id: 'eq-water',
    title: 'تكوين الماء',
    leftTerms: <EquationTerm>[
      EquationTerm(formula: 'H₂', atoms: <String, int>{'H': 2}),
      EquationTerm(formula: 'O₂', atoms: <String, int>{'O': 2}),
    ],
    rightTerms: <EquationTerm>[
      EquationTerm(formula: 'H₂O', atoms: <String, int>{'H': 2, 'O': 1}),
    ],
    correctCoefficients: <int>[2, 1, 2],
    source: 'مختبر الكيمياء — معادلة تكوين الماء (مبادئ عامة من المنهج اليمني)',
    sourceQuestionId: null,
    explanation:
        'جزيئا هيدروجين + جزيء أكسجين ← جزيئا ماء. عدد ذرات H و O '
        'متساوٍ في الطرفين؛ لا ذرة تُفقد ولا تُستحدث (قانون حفظ الكتلة).',
  ),
  EquationItem(
    id: 'eq-iron',
    title: 'اختزال خام الحديد في الفرن العالي',
    leftTerms: <EquationTerm>[
      EquationTerm(formula: 'FeO', atoms: <String, int>{'Fe': 1, 'O': 1}),
      EquationTerm(formula: 'CO', atoms: <String, int>{'C': 1, 'O': 1}),
    ],
    rightTerms: <EquationTerm>[
      EquationTerm(formula: 'Fe', atoms: <String, int>{'Fe': 1}),
      EquationTerm(formula: 'CO₂', atoms: <String, int>{'C': 1, 'O': 2}),
    ],
    correctCoefficients: <int>[1, 1, 1, 1],
    source:
        'كتاب الكيمياء — الصف الثالث الثانوي العلمي، الجمهورية اليمنية، طبعة صنعاء 2027',
    sourcePage: 18,
    sourceQuestionId: 'ye-chemistry-u1-l4-002',
    explanation:
        'في أسفل الفرن العالي يختزل أول أكسيد الكربون أكسيد الحديد '
        'الثنائي FeO إلى الحديد المنصهر وفق المعادلة FeO + CO → Fe + CO₂.',
  ),
  EquationItem(
    id: 'eq-carbon',
    title: 'احتراق الكربون',
    leftTerms: <EquationTerm>[
      EquationTerm(formula: 'C', atoms: <String, int>{'C': 1}),
      EquationTerm(formula: 'O₂', atoms: <String, int>{'O': 2}),
    ],
    rightTerms: <EquationTerm>[
      EquationTerm(formula: 'CO₂', atoms: <String, int>{'C': 1, 'O': 2}),
    ],
    correctCoefficients: <int>[1, 1, 1],
    source:
        'كتاب الكيمياء — الصف الثالث الثانوي العلمي، الجمهورية اليمنية، طبعة صنعاء 2027',
    sourcePage: 36,
    sourceQuestionId: 'ye-chemistry-u2-l7-002',
    explanation:
        'احتراق الكربون: C + O₂ → CO₂، وحرارة التفاعل تساوي حرارة '
        'تكوين CO₂ القياسية (−393.5 كيلوجول/مول).',
  ),
  EquationItem(
    id: 'eq-redox',
    title: 'تأكسد المغنيسيوم واختزال الأكسجين',
    leftTerms: <EquationTerm>[
      EquationTerm(formula: 'Mg', atoms: <String, int>{'Mg': 1}),
      EquationTerm(formula: 'O', atoms: <String, int>{'O': 1}),
    ],
    rightTerms: <EquationTerm>[
      EquationTerm(formula: 'Mg²⁺', atoms: <String, int>{'Mg': 1}),
      EquationTerm(formula: 'O²⁻', atoms: <String, int>{'O': 1}),
    ],
    correctCoefficients: <int>[1, 1, 1, 1],
    source:
        'كتاب الكيمياء — الصف الثالث الثانوي العلمي، الجمهورية اليمنية، طبعة صنعاء 2027',
    sourcePage: 43,
    sourceQuestionId: 'ye-chemistry-u3-l1-002',
    explanation:
        'تأكسد المغنيسيوم (Mg → Mg²⁺ + 2e⁻) واختزل الأكسجين '
        '(O + 2e⁻ → O²⁻).',
  ),
];
