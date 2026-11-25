// ABQARIYA — Physics Lab (مختبر الفيزياء)
// Three interactive labs: free fall, pendulum, simple DC circuit.
// 100% offline. Procedural CustomPainter only — no images, no assets.
// Formulas are standard physics; units are shown with every result.
// Content note: general scientific principles. Yemeni-curriculum questions
// are NOT invented here.
// «المحتوى مبني على المبادئ العلمية العامة — أسئلة المنهج اليمني قيد الإعداد»
//
// HAND-VERIFIED LOGIC (checked by hand, NOT run — no Flutter/Dart SDK here):
//  Free fall, g = 9.8 m/s²:
//   h=20 m → t = √(2h/g) = √(40/9.8) = √4.0816 ≈ 2.02 s; v = gt ≈ 19.8 m/s. ✓
//   Check: h = ½gt² = 4.9 × 4.0816 = 20.0 m. ✓
//   h=5 m → t = √(10/9.8) ≈ 1.01 s; v ≈ 9.9 m/s. ✓
//  Pendulum, g = 9.8 m/s²:
//   L=1.0 m → T = 2π√(1/9.8) = 2π×0.319 ≈ 2.01 s. ✓
//   L=0.25 m → T = 2π√(0.0255) = 2π×0.1597 ≈ 1.00 s. ✓ (quarter length → half period)
//  DC circuit:
//   V=12 V, R=6 Ω → I = V/R = 2 A; P = VI = 24 W. ✓
//   V=6 V, R=3 Ω → I = 2 A; P = 12 W. ✓
//   R→0 is clamped to ≥0.5 Ω in the slider so I never divides by zero.
//  Animation time-scale: free fall is played slowed (×0.5) so the fall is
//  visible; the displayed t/v are the REAL physical values, not the animation
//  clock — the label says so.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Physics Lab — free fall, pendulum, DC circuit.
///
/// Public constructor: `const PhysicsLab({super.key, this.onComplete})`.
class PhysicsLab extends StatefulWidget {
  const PhysicsLab({super.key, this.onComplete});

  final void Function(int score)? onComplete;

  static const String labId = 'physics_lab';
  static const String title = 'مختبر الفيزياء: السقوط الحر والبندول والدوائر';
  static const String description =
      'جرّب السقوط الحر (h = ½gt²)، والبندول البسيط (T = 2π√(L/g))، '
      'ودائرة كهربائية بسيطة (I = V/R) مع نتائج عددية ورسوم متحركة.';

  @override
  State<PhysicsLab> createState() => _PhysicsLabState();
}

class _PhysicsLabState extends State<PhysicsLab>
    with SingleTickerProviderStateMixin {
  static const double g = 9.8; // m/s² — standard gravity near Earth's surface

  // Free fall
  double _height = 20; // m, slider 1–50
  double _fallProgress = 0; // 0..1 animation progress
  bool _falling = false;

  // Pendulum
  double _length = 1.0; // m, slider 0.1–2.0
  double _pendulumTime = 0; // animation clock (s)
  bool _swinging = false;

  // DC circuit
  double _voltage = 12; // V, slider 1–24
  double _resistance = 6; // Ω, slider 0.5–50

  late final AnimationController _ctrl;

  // Demo mini-quiz (demo — not Yemeni curriculum).
  int _quizIndex = 0, _quizScore = 0;
  bool _quizDone = false;
  int? _selected;
  static const _quiz = [
    (
      q: 'جسم سقط من ارتفاع 20 m (g = 9.8 m/s²). ما زمن وصوله للأرض تقريبًا؟',
      options: ['2.0 s', '4.0 s', '1.0 s', '9.8 s'],
      correct: 0, // √(40/9.8) ≈ 2.02 s ✓
    ),
    (
      q: 'بندول طوله 1 m، ما دوره تقريبًا؟ (g = 9.8 m/s²)',
      options: ['2.0 s', '1.0 s', '3.1 s', '6.3 s'],
      correct: 0, // 2π√(1/9.8) ≈ 2.01 s ✓
    ),
    (
      q: 'دائرة V = 12 V و R = 6 Ω، ما شدة التيار؟',
      options: ['2 A', '72 A', '0.5 A', '18 A'],
      correct: 0, // 12/6 = 2 A ✓
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          if (_falling) {
            // Real fall time tFall; animation plays at half speed for visibility.
            final tFall = math.sqrt(2 * _height / g);
            _fallProgress += 0.05 / (tFall * 2);
            if (_fallProgress >= 1) {
              _fallProgress = 1;
              _falling = false;
            }
          }
          if (_swinging) _pendulumTime += 0.05;
        });
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // --- Pure physics helpers (hand-verified above) ---
  static double fallTime(double h) => math.sqrt(2 * h / g);
  static double fallVelocity(double h) => g * fallTime(h); // v = √(2gh) = gt
  static double pendulumPeriod(double l) => 2 * math.pi * math.sqrt(l / g);
  static double current(double v, double r) => v / r; // I = V/R
  static double power(double v, double r) => v * current(v, r); // P = VI

  void _answer(int i) {
    if (_quizDone) return;
    setState(() {
      _selected = i;
      if (i == _quiz[_quizIndex].correct) _quizScore++;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        if (_quizIndex < _quiz.length - 1) {
          _quizIndex++;
          _selected = null;
        } else {
          _quizDone = true;
          widget.onComplete?.call(_quizScore);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tFall = fallTime(_height);
    final vFall = fallVelocity(_height);
    final period = pendulumPeriod(_length);
    final currentI = current(_voltage, _resistance);
    final powerP = power(_voltage, _resistance);
    // Pendulum angle: small-angle swing, amplitude 0.5 rad.
    final angle = 0.5 * math.sin(2 * math.pi * _pendulumTime / period);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Note(),
            const SizedBox(height: 12),
            _sectionTitle(context, '1) السقوط الحر — h = ½gt² ، v = gt'),
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _FallPainter(progress: _fallProgress, height: _height),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            _SliderRow(
                label: 'الارتفاع h = ${_height.toStringAsFixed(0)} m',
                value: _height,
                min: 1,
                max: 50,
                onChanged: (v) => setState(() {
                      _height = v;
                      _fallProgress = 0;
                      _falling = false;
                    })),
            Row(children: [
              ElevatedButton(
                onPressed: _falling
                    ? null
                    : () => setState(() {
                          _fallProgress = 0;
                          _falling = true;
                        }),
                child: const Text('أسقط الجسم'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                      _fallProgress = 0;
                      _falling = false;
                    }),
                child: const Text('إعادة'),
              ),
            ]),
            _ResultCard(lines: [
              'القانون: h = ½gt² ، v = gt ، حيث g = 9.8 m/s²',
              'زمن السقوط: t = √(2h/g) = ${tFall.toStringAsFixed(2)} s',
              'السرعة عند الوصول: v = ${vFall.toStringAsFixed(1)} m/s',
              'ملاحظة: الحركة معروضة ببطء (نصف السرعة) لتراها بوضوح؛ الأرقام أعلاه حقيقية.',
            ]),
            const SizedBox(height: 16),
            _sectionTitle(context, '2) البندول البسيط — T = 2π√(L/g)'),
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _PendulumPainter(angle: angle, length: _length),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            _SliderRow(
                label: 'طول الخيط L = ${_length.toStringAsFixed(2)} m',
                value: _length,
                min: 0.1,
                max: 2.0,
                onChanged: (v) => setState(() => _length = v)),
            Row(children: [
              ElevatedButton(
                onPressed: () => setState(() => _swinging = !_swinging),
                child: Text(_swinging ? 'إيقاف التأرجح' : 'ابدأ التأرجح'),
              ),
            ]),
            _ResultCard(lines: [
              'القانون: T = 2π√(L/g) ، التردد f = 1/T',
              'الدور: T = ${period.toStringAsFixed(2)} s',
              'التردد: f = ${(1 / period).toStringAsFixed(2)} Hz',
              'ملاحظة: الدور لا يعتمد على كتلة الثقل ولا على السعة (للسعات الصغيرة).',
            ]),
            const SizedBox(height: 16),
            _sectionTitle(context, '3) دائرة كهربائية بسيطة — I = V/R ، P = VI'),
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _CircuitPainter(power: powerP),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            _SliderRow(
                label: 'الجهد V = ${_voltage.toStringAsFixed(0)} V',
                value: _voltage,
                min: 1,
                max: 24,
                onChanged: (v) => setState(() => _voltage = v)),
            _SliderRow(
                label: 'المقاومة R = ${_resistance.toStringAsFixed(1)} Ω',
                value: _resistance,
                min: 0.5,
                max: 50,
                onChanged: (v) => setState(() => _resistance = v)),
            _ResultCard(lines: [
              'قانون أوم: I = V/R ، القدرة: P = VI = V²/R',
              'شدة التيار: I = ${_voltage.toStringAsFixed(0)} / ${_resistance.toStringAsFixed(1)} = ${currentI.toStringAsFixed(2)} A',
              'القدرة: P = ${powerP.toStringAsFixed(1)} W (سطوع المصباح يتناسب معها)',
            ]),
            const SizedBox(height: 16),
            _QuizCard(
              question: _quiz[_quizIndex].q,
              options: _quiz[_quizIndex].options,
              correct: _quiz[_quizIndex].correct,
              selected: _selected,
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

Widget _sectionTitle(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );

class _Note extends StatelessWidget {
  const _Note();
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

/// Falling dot: y grows as ½gt², so progress p maps to y = p² of the height.
class _FallPainter extends CustomPainter {
  _FallPainter({required this.progress, required this.height});
  final double progress, height;
  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height - 24;
    final topY = 24.0;
    // True accelerated motion: distance ∝ t².
    final y = topY + (groundY - topY) * progress * progress;
    final ground = Paint()..color = Colors.brown;
    canvas.drawRect(
        Rect.fromLTWH(0, groundY, size.width, size.height - groundY), ground);
    canvas.drawCircle(Offset(size.width / 2, y), 12,
        Paint()..color = Colors.blue);
    final tp = TextPainter(
        text: const TextSpan(text: 'h', style: TextStyle(color: Colors.grey)),
        textDirection: TextDirection.rtl)
      ..layout();
    tp.paint(canvas, Offset(8, (topY + groundY) / 2));
  }

  @override
  bool shouldRepaint(covariant _FallPainter old) =>
      old.progress != progress || old.height != height;
}

class _PendulumPainter extends CustomPainter {
  _PendulumPainter({required this.angle, required this.length});
  final double angle, length; // length in metres, drawn scaled
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, 24);
    final rodLen = 60 + length * 60; // 0.1 m → 66 px, 2 m → 180 px
    final bob = Offset(
        pivot.dx + rodLen * math.sin(angle), pivot.dy + rodLen * math.cos(angle));
    canvas.drawLine(pivot, bob, Paint()..color = Colors.grey..strokeWidth = 2);
    canvas.drawCircle(pivot, 5, Paint()..color = Colors.black);
    canvas.drawCircle(bob, 16, Paint()..color = Colors.deepPurple);
    // Arc showing the swing amplitude.
    canvas.drawArc(
        Rect.fromCircle(center: pivot, radius: rodLen),
        math.pi / 2 - 0.5,
        1.0,
        false,
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _PendulumPainter old) =>
      old.angle != angle || old.length != length;
}

/// Rectangular loop: battery (left), resistor (top), bulb (right).
/// Bulb glow radius/alpha scale with power (clamped so it stays visible).
class _CircuitPainter extends CustomPainter {
  _CircuitPainter({required this.power});
  final double power; // watts
  @override
  void paint(Canvas canvas, Size size) {
    final wire = Paint()
      ..color = Colors.grey
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(30, 30, size.width - 60, size.height - 60);
    canvas.drawRect(rect, wire);
    // Battery: short + long plate on the left side.
    canvas.drawLine(Offset(30, size.height / 2 - 14),
        Offset(30, size.height / 2 + 14), Paint()..color = Colors.black..strokeWidth = 4);
    // Resistor: zigzag on the top wire.
    final topY = 30.0;
    final path = Path()..moveTo(size.width * 0.35, topY);
    for (var i = 0; i < 4; i++) {
      path.lineTo(size.width * (0.38 + i * 0.03), topY + (i.isEven ? -10 : 10));
    }
    path.lineTo(size.width * 0.5, topY);
    canvas.drawPath(path, Paint()..color = Colors.black..strokeWidth = 2..style = PaintingStyle.stroke);
    // Bulb on the right side; brightness ∝ power.
    final glow = (power / 100).clamp(0.05, 1.0);
    final cx = size.width - 30, cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), 14 + glow * 18,
        Paint()..color = Colors.amber.withValues(alpha: 0.25 * glow + 0.05));
    canvas.drawCircle(Offset(cx, cy), 14,
        Paint()..color = Colors.amber..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(Offset(cx - 6, cy + 4), Offset(cx + 6, cy - 4),
        Paint()..color = Colors.amber..strokeWidth = 2);
    final label = TextPainter(
        text: TextSpan(
            text: 'بطارية  •  مقاومة  •  مصباح',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        textDirection: TextDirection.rtl)
      ..layout();
    label.paint(canvas, Offset((size.width - label.width) / 2, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter old) => old.power != power;
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
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(
            child: Slider(
                value: value.clamp(min, max), min: min, max: max, onChanged: onChanged)),
      ]);
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.lines});
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Padding(
                    padding: const EdgeInsets.only(bottom: 4), child: Text(l)),
            ],
          ),
        ),
      );
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.question,
    required this.options,
    required this.correct,
    required this.selected,
    required this.done,
    required this.score,
    required this.total,
    required this.onAnswer,
  });
  final String question;
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
                  'أسئلة تجريبية (demo — ليست من المنهج اليمني).')));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اختبر نفسك (تجريبي)',
                style: Theme.of(context).textTheme.titleMedium),
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
