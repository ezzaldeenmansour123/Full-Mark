# ABQARIYA — Science Labs (مختبرات العلوم)

Offline Flutter labs for 3rd secondary scientific (Yemeni curriculum).
100% offline, no internet, no accounts, no ads. All drawing is procedural
`CustomPainter`/vector only — no GLB files, no videos, no large images,
no 3D-engine dependency in v1. Arabic RTL, dark-mode friendly
(theme colours are taken from `Theme.of(context)` / `colorScheme`).

> **Content honesty:** Yemeni textbooks were NOT provided. No curriculum
> questions are invented and no invented fact is presented as Yemeni
> curriculum. Labs teach general scientific principles that are in the
> curriculum (laws, concepts), with the note:
> «المحتوى مبني على المبادئ العلمية العامة من المنهج اليمني».
> The question bank itself stays empty except for demo quizzes inside the
> labs, each labelled `demo — not Yemeni curriculum`.

## Files

| File | Lab | What it does |
|---|---|---|
| `lib/labs/math_lab.dart` | `MathLab` (`math_lab`) | Function plotter: `y = ax²+bx+c` and `y = mx+b`, sliders for a/b/c (m/b), live redraw, roots, vertex, axis of symmetry, area under the curve (trapezoid rule, n=100, x∈[0,2]), step-by-step quadratic solver. 3-question demo quiz. |
| `lib/labs/physics_lab.dart` | `PhysicsLab` (`physics_lab`) | (1) Free fall: height slider, animated falling dot, `t = √(2h/g)`, `v = gt`. (2) Pendulum: length slider, animated swing, `T = 2π√(L/g)`, `f = 1/T`. (3) DC circuit: V/R sliders, `I = V/R`, `P = VI`, bulb brightness ∝ power. 3-question demo quiz. |
| `lib/labs/chemistry_lab.dart` | `ChemistryLab` (`chemistry_lab`) | Molecule builder (tap to add H/O/C/N, tap two atoms to bond) for H₂O, CO₂, O₂, NH₃ with valency enforcement; equation balancer game for `2H₂ + O₂ → 2H₂O` with coefficient steppers and live atom-count check on both sides (must balance exactly). |
| `lib/labs/biology_lab.dart` | `BiologyLab` (`biology_lab`) | Vector diagrams (CustomPainter): human heart, human cell, digestive system. Tap a part → name + function. Pinch-zoom / drag-pan / rotate slider. Hide-labels quiz mode (tap the part asked for, 3 rounds). |
| `lib/screens/lab_detail_screen.dart` | — | Host screen, route `'/lab'` with the lab id as argument; shows title, law/principle card, the lab widget, explanation card, and the "اختبر نفسك" note. |

Each lab widget is a self-contained `StatefulWidget` with a documented
public constructor (`const XxxLab({super.key, this.onComplete})`) and static
`labId`, `title`, `description`. On quiz completion it calls optional
`onComplete(int score)`. Labs do **not** depend on any database code.

## Formulas / laws used (with sources)

All are standard textbook laws — no source beyond standard physics /
chemistry / biology textbooks is needed, and no page numbers are claimed.

- **Math:** quadratic formula `x = (−b ± √(b²−4ac)) / 2a`; discriminant
  `Δ = b² − 4ac`; vertex `xᵥ = −b/2a`; trapezoid rule for area.
- **Physics:** free fall `h = ½gt²`, `v = gt`, `g = 9.8 m/s²` (standard
  gravity near Earth's surface); simple pendulum `T = 2π√(L/g)`
  (small-angle approximation); Ohm's law `I = V/R`; power `P = VI = V²/R`.
- **Chemistry:** law of conservation of mass (atoms are rearranged, never
  created/destroyed — hence balancing); valency: H=1, O=2, N=3, C=4;
  double bonds O=O and C=O. Balanced equation: `2H₂ + O₂ → 2H₂O`.
- **Biology:** heart — 4 chambers (RA, RV, LA, LV), tricuspid/mitral and
  semilunar valves, flow order body → RA → RV → lungs → LA → LV → body;
  cell — nucleus (control/DNA), mitochondria (respiration/ATP), cytoplasm,
  cell membrane; digestive system — mouth → oesophagus → stomach →
  small intestine → large intestine, with liver (bile) and pancreas
  (enzymes/insulin) as accessory glands.

## What was verified vs NOT run

- **NOT run:** no Flutter/Dart SDK exists in this environment, so no
  `flutter analyze`, no `dart test`, no build, and no on-device test was
  performed. All Dart is written carefully but **uncompiled**.
- **Verified by hand-calculation** (worked examples are in the comments at
  the top of each lab file):
  - Math: `x²−5x+6=0` → roots 2, 3; vertex (2.5, −0.25); `x²+1` → no real
    roots; area of `2x+1` on [0,2] = 6 (trapezoid exact for linear);
    area of `x²` on [0,1] ≈ 0.333 (error ≈ 1.7×10⁻⁵ at n=100).
  - Physics: h=20 m → t≈2.02 s, v≈19.8 m/s; L=1 m → T≈2.01 s;
    L=0.25 m → T≈1.00 s; V=12 V, R=6 Ω → I=2 A, P=24 W.
  - Chemistry: H₂O/CO₂/O₂/NH₃ bond counts satisfy valency; balancer
    (2,1,2) gives H 4=4, O 2=2; wrong coefficients (1,1,1) and (1,1,2)
    are correctly shown unbalanced.
  - Biology: anatomy order and functions checked against standard
    textbook anatomy (see the header comment in `biology_lab.dart`).

## Simplifications made

- **Math:** graph y-range is auto-fitted from samples; area is shown only
  for x∈[0,2] with the trapezoid rule (an approximation — labelled as such);
  a=0 is clamped to 0.1 so the quadratic mode never degenerates silently.
- **Physics:** free-fall animation plays at half speed so the fall is
  visible — the displayed t/v are the real physical values (labelled on
  screen). Pendulum uses the small-angle formula with a 0.5 rad swing.
  The circuit is a single loop (battery + resistor + bulb); internal
  resistance, wire resistance, and AC are out of scope.
- **Chemistry:** only H, O, C, N and only the four target molecules; double
  bonds only O=O and C=O; atoms are placed on a fixed staggered grid
  (not freely draggable — tap-to-add, tap-two-to-bond); 3D geometry
  (e.g. the bent shape of H₂O) is not modelled.
- **Biology:** diagrams are explicitly labelled "رسوم تعليمية مبسطة".
  The heart is four rounded chambers (no coronary vessels, no chordae);
  the cell omits ER, Golgi, and ribosomes deliberately; the digestive
  system is an overview, not a to-scale anatomical drawing. Labels are
  drawn in black on the diagram — on dark backgrounds they rely on the
  coloured shapes behind them; a future pass should use theme-aware
  label colours.
- **Lab detail screen:** the lab is hosted in a fixed-height box inside an
  outer scroll view; long labs scroll inside their own area.

## What is NOT yet built

- Full anatomy systems: respiratory, circulatory (beyond the heart),
  nervous, skeletal, excretory, endocrine, reproductive systems; a fuller
  cell (ER, Golgi, ribosomes, lysosomes, vacuole); detailed heart valves
  and vessels.
- More physics labs (Ohm's-law graph, projectile motion, lenses/mirrors,
  waves, pressure); more chemistry (acids/bases pH, periodic table,
  more balanced equations, ionic bonding); more math (trigonometric
  functions, derivatives/integrals visualisation, statistics).
- Yemeni-curriculum question bank (blocked on the textbooks — must not be
  invented); wiring `onComplete` scores into the app's progress/XP store
  (labs deliberately do not depend on it yet).
- Compile/test pass once a Flutter SDK is available: `flutter analyze`,
  widget tests for the pure helpers (`quadraticRoots`, `trapezoidArea`,
  `fallTime`, `pendulumPeriod`, `countAtoms`, balancer logic), and a
  real-device check of tap hit-testing after zoom/rotate in BiologyLab.
