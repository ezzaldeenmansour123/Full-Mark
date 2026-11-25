// ABQARIYA — Biology Lab (مختبر الأحياء)
// Interactive vector diagrams: human heart, human cell, digestive system.
// 100% offline. Procedural CustomPainter only — no images, no assets.
// Diagrams are SIMPLIFIED teaching diagrams — labelled as such on screen.
// Only anatomically correct, clearly-labelled structures are shown;
// anything uncertain is omitted rather than drawn wrong.
// Content note: general biology principles. Yemeni-curriculum questions
// are NOT invented here.
// «المحتوى مبني على المبادئ العلمية العامة من المنهج اليمني»
//
// ANATOMY CHECKS (standard textbook anatomy, verified against general
// knowledge — NOT run, no SDK here):
//  Heart: 4 chambers — right atrium (receives deoxygenated blood from the
//  body via vena cava), right ventricle (pumps to lungs via pulmonary artery),
//  left atrium (receives oxygenated blood from lungs via pulmonary veins),
//  left ventricle (pumps to body via aorta, thickest wall). Valves:
//  tricuspid (right), mitral/bicuspid (left), pulmonary + aortic semilunar.
//  Blood flow order: body → RA → RV → lungs → LA → LV → body. ✓
//  Cell: nucleus (controls cell, contains DNA), mitochondria (respiration /
//  ATP energy), cytoplasm (jelly-like substance where reactions happen),
//  cell membrane (controls entry/exit). Ribosomes / ER / Golgi are NOT
//  drawn in this 2D diagram — omitted deliberately to keep it honest at
//  this level; the fuller cell (ER, Golgi, ribosomes, lysosomes,
//  chloroplasts, vacuole) lives in the 3D viewer lib/labs/cell_3d.dart. ✓
//  Digestive system (simplified overview, in order): mouth → oesophagus →
//  stomach → small intestine → large intestine → rectum/anus; liver and
//  pancreas shown as accessory glands (liver makes bile, pancreas makes
//  enzymes + insulin). Order verified: food cannot reach the large
//  intestine before the small intestine. ✓
//  Tap hit-testing uses circles/rects in the painter's own coordinate
//  space, with the inverse of the user's pan/zoom transform applied first,
//  so taps stay correct after rotate/zoom.

import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

import '../core/routes.dart';

/// Biology Lab — heart, cell, digestive system diagrams.
///
/// Public constructor: `const BiologyLab({super.key, this.onComplete})`.
class BiologyLab extends StatefulWidget {
  const BiologyLab({super.key, this.onComplete});

  /// (score, total) — total is 3 for the diagram quiz.
  final void Function(int score, int total)? onComplete;

  static const String labId = 'biology_lab';
  static const String title = 'مختبر الأحياء: القلب والخلية والجهاز الهضمي';
  static const String description =
      'رسوم تعليمية مبسطة: اضغط على أجزاء القلب والخلية والجهاز الهضمي '
      'لتتعرف على اسم كل جزء ووظيفته، ثم اختبر نفسك بوضع إخفاء التسميات.';

  @override
  State<BiologyLab> createState() => _BiologyLabState();
}

enum _System { heart, cell, digestive }

/// One labelled part: hit region in diagram coordinates (0..300 × 0..240),
/// name, and function.
class _Part {
  const _Part(this.id, this.name, this.function, this.center, this.radius);
  final String id, name, function;
  final Offset center;
  final double radius;
}

const Map<_System, List<_Part>> _parts = {
  _System.heart: [
    _Part('ra', 'الأذين الأيمن',
        'يستقبل الدم غير المؤكسج من الجسم عبر الوريدين الأجوفين.',
        Offset(105, 70), 34),
    _Part('rv', 'البطين الأيمن',
        'يضخ الدم غير المؤكسج إلى الرئتين عبر الشريان الرئوي.',
        Offset(105, 160), 38),
    _Part('la', 'الأذين الأيسر',
        'يستقبل الدم المؤكسج من الرئتين عبر الأوردة الرئوية.',
        Offset(195, 70), 34),
    _Part('lv', 'البطين الأيسر',
        'يضخ الدم المؤكسج إلى الجسم عبر الشريان الأبهر؛ جداره الأسمك.',
        Offset(195, 160), 38),
    _Part('aorta', 'الشريان الأبهر',
        'أكبر شريان؛ ينقل الدم المؤكسج من البطين الأيسر إلى الجسم.',
        Offset(195, 22), 26),
    _Part('valve', 'الصمامات',
        'تمنع رجوع الدم؛ ثلاثي الشرفات يمينًا، والتاجي (ذو الشرفتين) يسارًا.',
        Offset(150, 115), 26),
  ],
  _System.cell: [
    _Part('nucleus', 'النواة',
        'مركز التحكم في الخلية؛ تحتوي DNA وتدير أنشطة الخلية.',
        Offset(150, 120), 42),
    _Part('mito', 'الميتوكوندريا',
        'التنفس الخلوي وإنتاج الطاقة (ATP).', Offset(225, 70), 26),
    _Part('cyto', 'السيتوبلازم',
        'مادة هلامية تحدث فيها معظم التفاعلات الكيميائية.',
        Offset(80, 170), 34),
    _Part('membrane', 'الغشاء الخلوي',
        'يحيط بالخلية وينظّم دخول المواد وخروجها.',
        Offset(150, 225), 26),
  ],
  _System.digestive: [
    _Part('mouth', 'الفم',
        'بداية الهضم: المضغ واللعاب يبدآن تكسير الطعام.',
        Offset(150, 25), 24),
    _Part('oesophagus', 'المريء',
        'أنبوب ينقل الطعام من الفم إلى المعدة.', Offset(150, 65), 22),
    _Part('stomach', 'المعدة',
        'تخلط الطعام مع حمض المعدة والإنزيمات.', Offset(130, 115), 32),
    _Part('liver', 'الكبد',
        'يصنع العصارة الصفراء التي تساعد على هضم الدهون.',
        Offset(205, 105), 26),
    _Part('small', 'الأمعاء الدقيقة',
        'الهضم الكيميائي وامتصاص المغذيات إلى الدم.',
        Offset(150, 165), 36),
    _Part('large', 'الأمعاء الغليظة',
        'تمتص الماء والأملاح؛ وتتكون فيها الفضلات.', Offset(215, 165), 26),
  ],
};

class _BiologyLabState extends State<BiologyLab> {
  _System _system = _System.heart;
  double _scale = 1.0;

  /// Scale at the start of the current pinch — the pinch factor is
  /// RELATIVE to it (see onScaleStart below).
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  double _rotation = 0; // radians, small range via slider (pinch zoom + drag pan)
  String? _selectedPartId;
  bool _quizMode = false;
  String? _quizTargetId;
  int _quizScore = 0, _quizAsked = 0;
  bool _quizDone = false;

  /// Parts already asked in this quiz — the next target is always a
  /// part not asked yet (before, the same part could repeat within
  /// the 3 questions).
  final Set<String> _askedTargetIds = <String>{};

  List<_Part> get _currentParts => _parts[_system]!;

  void _handleTap(TapUpDetails d, Size size) {
    // Convert screen tap → diagram coordinates (inverse transform).
    // Diagram is drawn in a 300×240 box, scaled to fit the widget.
    final boxScale = math.min(size.width / 300, size.height / 240) * _scale;
    final origin = Offset(
      (size.width - 300 * boxScale) / 2 + _offset.dx,
      (size.height - 240 * boxScale) / 2 + _offset.dy,
    );
    var p = (d.localPosition - origin) / boxScale;
    // Inverse rotation about the diagram centre (150, 120).
    final c = const Offset(150, 120);
    final cosR = math.cos(-_rotation), sinR = math.sin(-_rotation);
    final rel = p - c;
    p = Offset(rel.dx * cosR - rel.dy * sinR,
            rel.dx * sinR + rel.dy * cosR) +
        c;
    for (final part in _currentParts) {
      if ((p - part.center).distance <= part.radius) {
        setState(() {
          if (_quizMode) {
            _quizAsked++;
            if (part.id == _quizTargetId) {
              _quizScore++;
              _selectedPartId = part.id;
            } else {
              _selectedPartId = part.id; // shows what was tapped (wrong)
            }
            if (_quizAsked >= 3) {
              _quizDone = true;
              _quizMode = false;
              widget.onComplete?.call(_quizScore, 3);
            } else {
              // Advance only while questions remain: calling this
              // after the 3rd question generated a throwaway target.
              _nextQuizTarget();
            }
          } else {
            _selectedPartId = part.id;
          }
        });
        return;
      }
    }
    setState(() => _selectedPartId = null);
  }

  void _startQuiz() {
    setState(() {
      _quizMode = true;
      _quizDone = false;
      _quizScore = 0;
      _quizAsked = 0;
      _selectedPartId = null;
      _askedTargetIds.clear();
      _nextQuizTarget();
    });
  }

  void _nextQuizTarget() {
    final remaining = _currentParts
        .where((p) => !_askedTargetIds.contains(p.id))
        .toList();
    // Fallback (cannot happen with 3 questions and 4+ parts per
    // system): reuse any part except the current target.
    final pool = remaining.isEmpty
        ? _currentParts.where((p) => p.id != _quizTargetId).toList()
        : remaining;
    _quizTargetId = pool[math.Random().nextInt(pool.length)].id;
    _askedTargetIds.add(_quizTargetId!);
  }

  String get _quizTargetName =>
      _currentParts.firstWhere((p) => p.id == _quizTargetId,
          orElse: () => _currentParts.first).name;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPartId == null
        ? null
        : _currentParts.firstWhere((p) => p.id == _selectedPartId);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'رسوم تعليمية مبسطة — المحتوى مبني على المبادئ العلمية العامة من المنهج اليمني',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.cell3d),
              icon: const Icon(Icons.view_in_ar),
              label: const Text('عرض الخلية ثلاثية الأبعاد — دوّرها واضغط على عضياتها'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_System>(
              segments: const [
                ButtonSegment(value: _System.heart, label: Text('القلب')),
                ButtonSegment(value: _System.cell, label: Text('الخلية')),
                ButtonSegment(
                    value: _System.digestive, label: Text('الجهاز الهضمي')),
              ],
              selected: {_system},
              onSelectionChanged: (s) => setState(() {
                _system = s.first;
                _selectedPartId = null;
                _quizMode = false;
                _quizDone = false;
              }),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                // d.scale is relative to the PINCH START, not to the
                // current scale: without remembering the start scale,
                // every new pinch snapped the zoom back to ~1x.
                onScaleStart: (d) => _baseScale = _scale,
                onScaleUpdate: (d) => setState(() {
                  _scale = (_baseScale * d.scale).clamp(0.6, 2.5);
                  _offset += d.focalPointDelta;
                }),
                onTapUp: (d) => _handleTap(d, Size(w, 280)),
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    size: Size(w, 280),
                    painter: _DiagramPainter(
                      system: _system,
                      parts: _currentParts,
                      scale: _scale,
                      offset: _offset,
                      rotation: _rotation,
                      showLabels: !_quizMode,
                      selectedId: _selectedPartId,
                    ),
                  ),
                ),
              );
            }),
            Row(children: [
              Expanded(
                child: Slider(
                  value: _rotation,
                  min: -0.5,
                  max: 0.5,
                  label: 'تدوير',
                  onChanged: (v) => setState(() => _rotation = v),
                ),
              ),
              TextButton(
                  onPressed: () => setState(() {
                        _scale = 1.0;
                        _offset = Offset.zero;
                        _rotation = 0;
                      }),
                  child: const Text('إعادة الضبط')),
            ]),
            const Text('قرّب بإصبعين واسحب للتحريك، وغيّر التدوير بالمنزلق.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            if (_quizMode)
              Card(
                color: Colors.amber.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      'وضع الاختبار: اضغط على «$_quizTargetName» في الرسم '
                      '(${_quizAsked + 1} من 3) — التسميات مخفية.',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            else if (_quizDone)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      'انتهى اختبار الرسم — نتيجتك: $_quizScore / 3\n'
                      'أسئلة من أجزاء الرسم التعليمي نفسه (ليست أسئلة '
                      'من الكتاب).'),
                ),
              )
            else if (selected != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(selected.function),
                    ],
                  ),
                ),
              )
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('اضغط على أي جزء في الرسم لتعرف اسمه ووظيفته.'),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _quizMode ? null : _startQuiz,
              child: Text(_quizDone
                  ? 'أعد الاختبار'
                  : 'اختبر نفسك: إخفاء التسميات'),
            ),
            const SizedBox(height: 8),
            const Text(
              'ملاحظة: الرسوم مبسطة للتعليم؛ القلب الحقيقي له صمامات وأوعية '
              'أكثر تفصيلًا. والخلية الكاملة بعضياتها (الشبكة الإندوبلازمية '
              'وجهاز جولجي والريبوسومات وغيرها) تجدينها في العرض ثلاثي '
              'الأبعاد أعلاه.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  _DiagramPainter({
    required this.system,
    required this.parts,
    required this.scale,
    required this.offset,
    required this.rotation,
    required this.showLabels,
    required this.selectedId,
  });
  final _System system;
  final List<_Part> parts;
  final double scale, rotation;
  final Offset offset;
  final bool showLabels;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final boxScale = math.min(size.width / 300, size.height / 240) * scale;
    canvas.translate(
        (size.width - 300 * boxScale) / 2 + offset.dx,
        (size.height - 240 * boxScale) / 2 + offset.dy);
    canvas.translate(150 * boxScale, 120 * boxScale);
    canvas.rotate(rotation);
    canvas.translate(-150 * boxScale, -120 * boxScale);
    canvas.scale(boxScale);

    switch (system) {
      case _System.heart:
        _drawHeart(canvas);
        break;
      case _System.cell:
        _drawCell(canvas);
        break;
      case _System.digestive:
        _drawDigestive(canvas);
        break;
    }
    // Labels + selection ring.
    for (final p in parts) {
      if (selectedId == p.id) {
        canvas.drawCircle(p.center, p.radius + 4,
            Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 2);
      }
      if (showLabels) {
        final tp = TextPainter(
            text: TextSpan(
                text: p.name,
                style: const TextStyle(color: Colors.black, fontSize: 10)),
            textDirection: TextDirection.rtl)
          ..layout();
        tp.paint(canvas,
            Offset(p.center.dx - tp.width / 2, p.center.dy - tp.height / 2));
      }
    }
    canvas.restore();
  }

  void _drawHeart(Canvas canvas) {
    final fill = Paint()..color = Colors.red.withValues(alpha: 0.75);
    final outline = Paint()
      ..color = Colors.red.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Four chambers as rounded rectangles (simplified but correctly placed:
    // right side = viewer's left in anatomical position; here labelled so
    // the diagram is read as the student's own heart, right on the left).
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(70, 40, 70, 60), const Radius.circular(16)), fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(160, 40, 70, 60), const Radius.circular(16)), fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(65, 120, 80, 80), const Radius.circular(18)), fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(155, 120, 80, 80), const Radius.circular(18)), fill);
    for (final r in [
      const Rect.fromLTWH(70, 40, 70, 60),
      const Rect.fromLTWH(160, 40, 70, 60),
      const Rect.fromLTWH(65, 120, 80, 80),
      const Rect.fromLTWH(155, 120, 80, 80),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(16)), outline);
    }
    // Aorta arch (top) and pulmonary artery.
    canvas.drawArc(const Rect.fromLTWH(160, 0, 70, 50), math.pi, math.pi,
        false, Paint()..color = Colors.red.shade900..strokeWidth = 5..style = PaintingStyle.stroke);
    canvas.drawLine(const Offset(120, 40), const Offset(120, 8),
        Paint()..color = Colors.blue.shade700..strokeWidth = 5);
    // Valve line between atria and ventricles.
    canvas.drawLine(const Offset(65, 108), const Offset(235, 108),
        Paint()..color = Colors.white..strokeWidth = 3);
  }

  void _drawCell(Canvas canvas) {
    // Membrane: large rounded outline.
    canvas.drawOval(
        const Rect.fromLTWH(20, 20, 260, 200),
        Paint()
          ..color = Colors.lightBlue.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill);
    canvas.drawOval(
        const Rect.fromLTWH(20, 20, 260, 200),
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    // Nucleus.
    canvas.drawCircle(const Offset(150, 120), 42,
        Paint()..color = Colors.purple.withValues(alpha: 0.6));
    canvas.drawCircle(const Offset(150, 120), 42,
        Paint()..color = Colors.purple..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(const Offset(150, 120), 14,
        Paint()..color = Colors.purple.shade900);
    // Mitochondria: two bean shapes.
    for (final c in [const Offset(225, 70), const Offset(70, 80)]) {
      canvas.drawOval(Rect.fromCenter(center: c, width: 44, height: 20),
          Paint()..color = Colors.orange.withValues(alpha: 0.8));
    }
  }

  void _drawDigestive(Canvas canvas) {
    final tube = Paint()
      ..color = Colors.pink.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    // Mouth → oesophagus → stomach → small → large (correct order).
    canvas.drawCircle(const Offset(150, 25), 14,
        Paint()..color = Colors.red.withValues(alpha: 0.6));
    canvas.drawLine(const Offset(150, 35), const Offset(150, 85), tube);
    canvas.drawOval(const Rect.fromLTWH(95, 90, 70, 50),
        Paint()..color = Colors.pink.withValues(alpha: 0.6));
    // Small intestine: coiled path.
    final coil = Path()..moveTo(150, 140);
    for (var i = 0; i < 5; i++) {
      coil.lineTo(i.isEven ? 185.0 : 115.0, 145 + i * 8);
    }
    canvas.drawPath(coil, tube);
    // Large intestine: frame around the small intestine.
    canvas.drawPath(
        Path()
          ..moveTo(110, 140)
          ..lineTo(110, 195)
          ..lineTo(200, 195)
          ..lineTo(200, 140),
        Paint()
          ..color = Colors.brown.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10);
    // Liver (right upper) and pancreas (behind stomach, small).
    canvas.drawOval(const Rect.fromLTWH(175, 85, 60, 35),
        Paint()..color = Colors.brown.withValues(alpha: 0.7));
    canvas.drawOval(const Rect.fromLTWH(140, 130, 40, 14),
        Paint()..color = Colors.yellow.withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter old) =>
      old.system != system ||
      old.scale != scale ||
      old.offset != offset ||
      old.rotation != rotation ||
      old.showLabels != showLabels ||
      old.selectedId != selectedId;
}
