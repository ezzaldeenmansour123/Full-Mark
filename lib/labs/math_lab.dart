// ABQARIYA — Math Lab (مختبر الرياضيات)
// Function plotter + quadratic equation solver.
// 100% offline. Procedural CustomPainter only — no images, no assets.
// Content note: teaches general mathematical principles (quadratic / linear
// functions). Yemeni-curriculum questions are NOT invented here.
// «المحتوى مبني على المبادئ العلمية العامة — أسئلة المنهج اليمني قيد الإعداد»
//
// HAND-VERIFIED LOGIC (checked by hand, NOT run — no Flutter/Dart SDK here):
//  1. y = x² − 5x + 6, a=1,b=−5,c=6 → Δ = 25 − 24 = 1, √Δ = 1,
//     x = (5 ± 1)/2 → x₁ = 2, x₂ = 3. ✓ (2²−10+6=0, 3²−15+6=0)
//  2. Same function: vertex xᵥ = −b/2a = 2.5, yᵥ = 6.25 − 12.5 + 6 = −0.25. ✓
//  3. y = x² + 1 → Δ = −4 < 0 → no real roots. ✓
//  4. y = 2x + 1, x∈[0,2] → exact area ∫ = [x²+x]₀² = 6. Trapezoid rule with
//     n=100 on a linear function is exact (error 0), so the widget must show 6.00. ✓
//  5. y = x², x∈[0,1] → exact area 1/3 ≈ 0.333. Trapezoid n=100:
//     error ≈ (b−a)³·f″/(12n²) = 2/(12·10⁴) ≈ 0.0000167 → shows ≈ 0.33. ✓
//  6. Linear mode y = mx + b: root x = −b/m (m≠0); m=0 → horizontal line,
//     root only if b=0 (infinite) else none — handled explicitly.

import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

/// Math Lab — function plotter + quadratic solver.
///
/// Public constructor: `const MathLab({super.key, this.onComplete})`.
/// Static metadata used by the lab registry / detail screen.
class MathLab extends StatefulWidget {
  const MathLab({super.key, this.onComplete});

  /// Called once when the user finishes the built-in mini-quiz.
  final void Function(int score)? onComplete;

  static const String labId = 'math_lab';
  static const String title = 'مختبر الرياضيات: الدوال التربيعية والخطية';
  static const String description =
      'ارسم الدالة y = ax² + bx + c أو y = mx + b، وغيّر المعاملات، '
      'وشاهد الجذور والرأس والمساحة تحت المنحنى، ثم حلّ المعادلة خطوة بخطوة.';

  @override
  State<MathLab> createState() => _MathLabState();
}

enum _Mode { quadratic, linear }

class _MathLabState extends State<MathLab> {
  _Mode _mode = _Mode.quadratic;
  double _a = 1, _b = -5, _c = 6; // quadratic coefficients
  double _m = 2, _bb = 1; // linear: y = mx + b
  final double _xMin = -10, _xMax = 10;
  int _quizIndex = 0;
  int _quizScore = 0;
  bool _quizDone = false;
  int? _selectedAnswer;

  // --- Pure math (kept as separate static helpers so the logic is testable) ---

  static double f(double x, double a, double b, double c) =>
      a * x * x + b * x + c;

  /// Real roots of ax²+bx+c=0 (a≠0). Empty list = no real roots.
  static List<double> quadraticRoots(double a, double b, double c) {
    final d = b * b - 4 * a * c;
    if (d < 0) return const [];
    if (d == 0) return [-b / (2 * a)];
    final s = math.sqrt(d);
    return [(-b - s) / (2 * a), (-b + s) / (2 * a)];
  }

  /// Vertex (xᵥ, yᵥ) of ax²+bx+c.
  static (double, double) vertex(double a, double b, double c) {
    final xv = -b / (2 * a);
    return (xv, f(xv, a, b, c));
  }

  /// Area under the curve between [x0, x1] by the trapezoid rule (n slices).
  /// Hand-check #4/#5 above: exact for linear functions, error ~1.7e-5 for x² on [0,1].
  static double trapezoidArea(
      double Function(double) fn, double x0, double x1, int n) {
    if (n <= 0 || x1 <= x0) return 0;
    final h = (x1 - x0) / n;
    double sum = (fn(x0) + fn(x1)) / 2;
    for (var i = 1; i < n; i++) {
      sum += fn(x0 + i * h);
    }
    return sum * h;
  }

  double _current(double x) => _mode == _Mode.quadratic
      ? f(x, _a, _b, _c)
      : _m * x + _bb;

  List<double> get _roots => _mode == _Mode.quadratic
      ? quadraticRoots(_a, _b, _c)
      : (_m == 0 ? const [] : [-_bb / _m]);

  // Demo mini-quiz — labelled demo, NOT Yemeni curriculum.
  static const _quiz = [
    (
      q: 'ما جذرا المعادلة x² − 5x + 6 = 0؟',
      options: ['2 و 3', '1 و 6', '−2 و −3', 'لا جذور حقيقية'],
      correct: 0,
    ),
    (
      q: 'ما إحداثي x للرأس في y = x² − 4x + 3؟',
      options: ['x = 2', 'x = −2', 'x = 4', 'x = 0'],
      correct: 0, // xᵥ = 4/2 = 2 ✓
    ),
    (
      q: 'متى لا توجد جذور حقيقية لمعادلة تربيعية؟',
      options: [
        'عندما يكون المميز Δ سالبًا',
        'عندما يكون a = 0',
        'عندما يكون c = 0',
        'عندما يكون b = 0'
      ],
      correct: 0,
    ),
  ];

  void _answer(int i) {
    if (_quizDone) return;
    setState(() {
      _selectedAnswer = i;
      if (i == _quiz[_quizIndex].correct) _quizScore++;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        if (_quizIndex < _quiz.length - 1) {
          _quizIndex++;
          _selectedAnswer = null;
        } else {
          _quizDone = true;
          widget.onComplete?.call(_quizScore);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roots = _roots;
    final area = trapezoidArea(_current, 0, 2, 100);
    final (vx, vy) = _mode == _Mode.quadratic
        ? vertex(_a, _b, _c)
        : (0.0, 0.0); // linear: no vertex
    final delta = _mode == _Mode.quadratic ? _b * _b - 4 * _a * _c : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NoteBanner(),
            const SizedBox(height: 12),
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                    value: _Mode.quadratic, label: Text('تربيعية y = ax²+bx+c')),
                ButtonSegment(
                    value: _Mode.linear, label: Text('خطية y = mx+b')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: CustomPaint(
                painter: _GraphPainter(
                  fn: _current,
                  xMin: _xMin,
                  xMax: _xMax,
                  roots: roots,
                  vertex: _mode == _Mode.quadratic ? (vx, vy) : null,
                  lineColor: theme.colorScheme.primary,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.quadratic) ...[
              _SliderRow(
                  label: 'a = ${_a.toStringAsFixed(1)}',
                  value: _a,
                  min: -5,
                  max: 5,
                  onChanged: (v) => setState(() => _a = v == 0 ? 0.1 : v)),
              _SliderRow(
                  label: 'b = ${_b.toStringAsFixed(1)}',
                  value: _b,
                  min: -10,
                  max: 10,
                  onChanged: (v) => setState(() => _b = v)),
              _SliderRow(
                  label: 'c = ${_c.toStringAsFixed(1)}',
                  value: _c,
                  min: -10,
                  max: 10,
                  onChanged: (v) => setState(() => _c = v)),
            ] else ...[
              _SliderRow(
                  label: 'm = ${_m.toStringAsFixed(1)}',
                  value: _m,
                  min: -5,
                  max: 5,
                  onChanged: (v) => setState(() => _m = v)),
              _SliderRow(
                  label: 'b = ${_bb.toStringAsFixed(1)}',
                  value: _bb,
                  min: -10,
                  max: 10,
                  onChanged: (v) => setState(() => _bb = v)),
            ],
            const SizedBox(height: 8),
            _ResultCard(
              title: 'النتائج العددية',
              lines: [
                if (_mode == _Mode.quadratic) ...[
                  'المميز: Δ = b² − 4ac = ${delta!.toStringAsFixed(2)}',
                  'الرأس: (${vx.toStringAsFixed(2)} ، ${vy.toStringAsFixed(2)})',
                  'محور التماثل: x = ${vx.toStringAsFixed(2)}',
                ],
                roots.isEmpty
                    ? 'لا توجد جذور حقيقية (المنحنى لا يقطع محور x)'
                    : 'الجذور: ${roots.map((r) => r.toStringAsFixed(2)).join(' ، ')}',
                'المساحة تحت المنحنى من x=0 إلى x=2 (تقريب شبه المنحرف، n=100): '
                    '${area.toStringAsFixed(2)} وحدة مربعة',
              ],
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.quadratic)
              _QuadraticSolver(a: _a, b: _b, c: _c),
            const SizedBox(height: 16),
            _QuizCard(
              title: 'اختبر نفسك (تجريبي)',
              question: _quiz[_quizIndex].q,
              options: _quiz[_quizIndex].options,
              correct: _quiz[_quizIndex].correct,
              selected: _selectedAnswer,
              done: _quizDone,
              score: _quizScore,
              total: _quiz.length,
              onAnswer: _answer,
            ),
          ],
        ),
      ),
    );
  }
}

/// Step-by-step quadratic solver: Δ → √Δ → x = (−b ± √Δ) / 2a.
class _QuadraticSolver extends StatelessWidget {
  const _QuadraticSolver({required this.a, required this.b, required this.c});
  final double a, b, c;

  @override
  Widget build(BuildContext context) {
    final d = b * b - 4 * a * c;
    final steps = <String>[
      'المعادلة: ${a.toStringAsFixed(1)}x² + (${b.toStringAsFixed(1)})x + (${c.toStringAsFixed(1)}) = 0',
      'الخطوة 1 — المميز: Δ = b² − 4ac = ${b.toStringAsFixed(1)}² − 4×${a.toStringAsFixed(1)}×${c.toStringAsFixed(1)} = ${d.toStringAsFixed(2)}',
    ];
    String result;
    if (d < 0) {
      steps.add('الخطوة 2 — Δ < 0 إذن لا توجد جذور حقيقية.');
      result = 'لا حل حقيقي.';
    } else if (d == 0) {
      final x = -b / (2 * a);
      steps.add('الخطوة 2 — Δ = 0 إذن جذر مضاعف: x = −b / 2a = ${x.toStringAsFixed(2)}');
      result = 'x = ${x.toStringAsFixed(2)} (جذر مضاعف)';
    } else {
      final s = math.sqrt(d);
      final x1 = (-b - s) / (2 * a);
      final x2 = (-b + s) / (2 * a);
      steps.add('الخطوة 2 — √Δ = ${s.toStringAsFixed(2)}');
      steps.add(
          'الخطوة 3 — x = (−b ± √Δ) / 2a = (${(-b).toStringAsFixed(1)} ± ${s.toStringAsFixed(2)}) / ${(2 * a).toStringAsFixed(1)}');
      result =
          'x₁ = ${x1.toStringAsFixed(2)} ،  x₂ = ${x2.toStringAsFixed(2)}';
    }
    return _ResultCard(title: 'حلّ المعادلة خطوة بخطوة', lines: [...steps, 'النتيجة: $result']);
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.fn,
    required this.xMin,
    required this.xMax,
    required this.roots,
    required this.vertex,
    required this.lineColor,
  });
  final double Function(double) fn;
  final double xMin, xMax;
  final List<double> roots;
  final (double, double)? vertex;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 12.0;
    final w = size.width - pad * 2, h = size.height - pad * 2;
    // y-range: sample the function so the curve always fits.
    double yMin = 0, yMax = 0;
    for (var i = 0; i <= 200; i++) {
      final y = fn(xMin + (xMax - xMin) * i / 200);
      if (y.isFinite) {
        yMin = math.min(yMin, y);
        yMax = math.max(yMax, y);
      }
    }
    final span = math.max(yMax - yMin, 1);
    yMin -= span * 0.15;
    yMax += span * 0.15;
    double px(double x) => pad + (x - xMin) / (xMax - xMin) * w;
    double py(double y) => pad + (1 - (y - yMin) / (yMax - yMin)) * h;

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;
    // Axes (x-axis at y=0 if in range, else bottom; y-axis at x=0 if in range).
    if (yMin <= 0 && 0 <= yMax) {
      canvas.drawLine(Offset(pad, py(0)), Offset(pad + w, py(0)), axisPaint);
    }
    if (xMin <= 0 && 0 <= xMax) {
      canvas.drawLine(Offset(px(0), pad), Offset(px(0), pad + h), axisPaint);
    }
    // Gridlines every 2 units.
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    for (var x = xMin.ceilToDouble(); x <= xMax; x += 2) {
      canvas.drawLine(Offset(px(x), pad), Offset(px(x), pad + h), gridPaint);
    }

    final path = Path();
    var started = false;
    for (var i = 0; i <= 300; i++) {
      final x = xMin + (xMax - xMin) * i / 300;
      final y = fn(x);
      if (!y.isFinite) {
        started = false;
        continue;
      }
      final p = Offset(px(x), py(y.clamp(yMin, yMax)));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);

    // Roots (red dots on the x-axis) and vertex (green dot).
    final rootPaint = Paint()..color = Colors.red;
    for (final r in roots) {
      if (r >= xMin && r <= xMax) {
        canvas.drawCircle(Offset(px(r), py(0)), 5, rootPaint);
      }
    }
    if (vertex != null) {
      canvas.drawCircle(
          Offset(px(vertex!.$1), py(vertex!.$2)), 5, Paint()..color = Colors.green);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.fn != fn ||
      old.xMin != xMin ||
      old.xMax != xMax ||
      old.roots != roots ||
      old.vertex != vertex;
}

class _NoteBanner extends StatelessWidget {
  const _NoteBanner();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'المحتوى مبني على المبادئ العلمية العامة — أسئلة المنهج اليمني قيد الإعداد',
          style: TextStyle(fontSize: 12),
        ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.onChanged});
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: ((max - min) * 2).round(),
                onChanged: onChanged),
          ),
        ],
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l, textDirection: TextDirection.rtl),
                ),
            ],
          ),
        ),
      );
}

/// Shared demo-quiz card (also used by the other labs via copy — labs stay
/// independent of each other, so each file carries its own copy).
class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.title,
    required this.question,
    required this.options,
    required this.correct,
    required this.selected,
    required this.done,
    required this.score,
    required this.total,
    required this.onAnswer,
  });
  final String title, question;
  final List<String> options;
  final int correct;
  final int? selected;
  final bool done;
  final int score, total;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('انتهى الاختبار التجريبي — نتيجتك: $score / $total\n'
              'أسئلة تجريبية (demo — ليست من المنهج اليمني).'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(question),
            const SizedBox(height: 8),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: selected == null ? () => onAnswer(i) : null,
                    style: selected == i
                        ? OutlinedButton.styleFrom(
                            backgroundColor: i == correct
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2))
                        : null,
                    child: Text(options[i]),
                  ),
                ),
              ),
            const Text('أسئلة تجريبية (demo — ليست من المنهج اليمني).',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
