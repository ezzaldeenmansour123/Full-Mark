// FULL MARK — 3D Cell Viewer (الخلية ثلاثية الأبعاد)
// A REAL interactive 3D viewer built in pure Dart/Flutter Canvas —
// no plugins, no downloaded model files, no internet, fully offline.
//
// The engine (below) is a small software 3D renderer:
//  * 3D points are rotated by yaw (Y axis) + pitch (X axis) matrices,
//  * projected with perspective (focal length / depth),
//  * drawn back-to-front (painter's algorithm) so nearer organelles
//    correctly overlap farther ones.
// Drag rotates the cell; an auto-rotate toggle spins it slowly;
// tapping an organelle shows its name + function.
//
// CONTENT HONESTY: organelle functions are general scientific
// description, NOT quoted textbook text — the biology question bank
// has almost nothing on organelles (one question only: protein
// synthesis, ye-biology-u5-l5-002, book p.143, naming nucleus +
// ribosome). That question is cited where it applies; every other
// organelle is labelled «وصف علمي عام — ليس نصاً من الكتاب» on its
// card, exactly like the 2D biology lab's own labelling.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

// ------------------------------------------------------------------
// Tiny 3D engine (pure Dart)
// ------------------------------------------------------------------

/// A point in model space. The cell lives in a cube roughly
/// [-1.15, 1.15] on every axis.
class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x, y, z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 scale(double sx, double sy, double sz) =>
      Vec3(x * sx, y * sy, z * sz);
}

/// Rotate [p] by [yaw] around Y, then [pitch] around X.
Vec3 rotatePoint(Vec3 p, double yaw, double pitch) {
  final cy = math.cos(yaw), sy = math.sin(yaw);
  final x1 = p.x * cy + p.z * sy;
  final z1 = -p.x * sy + p.z * cy;
  final cp = math.cos(pitch), sp = math.sin(pitch);
  final y2 = p.y * cp - z1 * sp;
  final z2 = p.y * sp + z1 * cp;
  return Vec3(x1, y2, z2);
}

/// Perspective projection of a rotated point onto the canvas.
/// Returns null when the point is behind the camera.
Offset? projectPoint(
  Vec3 rotated,
  double focal,
  double radius,
  Offset center,
) {
  final double depth = focal - rotated.z;
  if (depth <= 0.2) return null;
  final double s = focal / depth;
  return Offset(
    center.dx + rotated.x * s * radius,
    center.dy - rotated.y * s * radius,
  );
}

/// One drawable piece of the scene, with a depth used for sorting.
class _DrawCmd {
  _DrawCmd(this.depth, this.draw);
  final double depth;
  final void Function(Canvas canvas) draw;
}

// ------------------------------------------------------------------
// Organelle data
// ------------------------------------------------------------------

enum CellKind { animal, plant }

/// One organelle in the 3D cell.
class Organelle {
  const Organelle({
    required this.id,
    required this.name,
    required this.function,
    required this.source,
    required this.color,
    required this.center,
    required this.radius,
    required this.shape,
    this.axis = const Vec3(1, 0, 0),
    this.flattenY = 1.0,
  });

  final String id;
  final String name;
  final String function;

  /// Source line shown on the card, e.g. 'بنك الأسئلة — كتاب الأحياء ص143'
  /// or 'وصف علمي عام — ليس نصاً من الكتاب'.
  final String source;

  final Color color;

  /// Centre in model space.
  final Vec3 center;

  /// Base radius (model units).
  final double radius;

  /// 'sphere' | 'capsule' | 'disc' | 'dots' | 'sheets' | 'tubes' | 'box'.
  final String shape;

  /// Long axis for capsules/discs (unit vector).
  final Vec3 axis;

  /// Vertical squash for discs (Golgi, chloroplasts).
  final double flattenY;
}

const String _kGeneralSource = 'وصف علمي عام — ليس نصاً من الكتاب';
const String _kBankSource =
    'بنك الأسئلة — كتاب الأحياء، طبعة صنعاء 2027، ص143';

/// Animal-cell organelles (model space: cell radius ≈ 1.0).
const List<Organelle> kAnimalOrganelles = <Organelle>[
  Organelle(
    id: 'membrane',
    name: 'الغشاء الخلوي',
    function: 'يحيط بالخلية وينظّم دخول المواد وخروجها.',
    source: _kGeneralSource,
    color: Colors.blue,
    center: Vec3(0, 0, 0),
    radius: 1.0,
    shape: 'sphere',
  ),
  Organelle(
    id: 'nucleus',
    name: 'النواة',
    function:
        'مركز التحكم في الخلية؛ تحتوي DNA وتدير أنشطة الخلية. يُنسخ جزء من DNA إلى mRNA داخلها.',
    source: _kBankSource,
    color: Colors.purple,
    center: Vec3(-0.22, 0.08, 0.12),
    radius: 0.36,
    shape: 'sphere',
  ),
  Organelle(
    id: 'nucleolus',
    name: 'النوية',
    function: 'جسم صغير داخل النواة تُصنع فيه مكونات الريبوسومات.',
    source: _kGeneralSource,
    color: Colors.deepPurple,
    center: Vec3(-0.22, 0.08, 0.38),
    radius: 0.13,
    shape: 'sphere',
  ),
  Organelle(
    id: 'mito1',
    name: 'الميتوكوندريا',
    function: 'التنفس الخلوي وإنتاج الطاقة (ATP).',
    source: _kGeneralSource,
    color: Colors.orange,
    center: Vec3(0.55, 0.42, 0.25),
    radius: 0.16,
    shape: 'capsule',
    axis: Vec3(1, 0.4, 0.2),
  ),
  Organelle(
    id: 'mito2',
    name: 'الميتوكوندريا',
    function: 'التنفس الخلوي وإنتاج الطاقة (ATP).',
    source: _kGeneralSource,
    color: Colors.orange,
    center: Vec3(0.5, -0.5, -0.2),
    radius: 0.15,
    shape: 'capsule',
    axis: Vec3(0.3, 1, 0.2),
  ),
  Organelle(
    id: 'mito3',
    name: 'الميتوكوندريا',
    function: 'التنفس الخلوي وإنتاج الطاقة (ATP).',
    source: _kGeneralSource,
    color: Colors.orange,
    center: Vec3(-0.55, -0.45, 0.35),
    radius: 0.14,
    shape: 'capsule',
    axis: Vec3(1, -0.3, 0.5),
  ),
  Organelle(
    id: 'rough_er',
    name: 'الشبكة الإندوبلازمية الخشنة',
    function:
        'أغشية مطوية عليها ريبوسومات؛ تنقل البروتينات الجديدة وتعدّلها.',
    source: _kGeneralSource,
    color: Colors.pink,
    center: Vec3(-0.3, 0.55, -0.35),
    radius: 0.22,
    shape: 'sheets',
  ),
  Organelle(
    id: 'smooth_er',
    name: 'الشبكة الإندوبلازمية الملساء',
    function: 'أنابيب تصنع الدهون وتشارك في إزالة السموم من الخلية.',
    source: _kGeneralSource,
    color: Colors.teal,
    center: Vec3(0.62, 0.05, -0.45),
    radius: 0.2,
    shape: 'tubes',
  ),
  Organelle(
    id: 'golgi',
    name: 'جهاز جولجي',
    function: 'يعدّل البروتينات والدهون ويغلّفها ويرسلها إلى وجهتها.',
    source: _kGeneralSource,
    color: Colors.amber,
    center: Vec3(0.15, -0.62, 0.15),
    radius: 0.2,
    shape: 'disc',
  ),
  Organelle(
    id: 'ribosomes',
    name: 'الريبوسومات',
    function:
        'مصانع البروتين؛ تُترجم شفرة mRNA إلى سلسلة أحماض أمينية تكون البروتين.',
    source: _kBankSource,
    color: Colors.red,
    center: Vec3(0.1, 0.3, -0.55),
    radius: 0.3,
    shape: 'dots',
  ),
  Organelle(
    id: 'lysosome1',
    name: 'الليسوسومات',
    function: 'تهضم الفضلات والمواد التالفة داخل الخلية.',
    source: _kGeneralSource,
    color: Colors.brown,
    center: Vec3(-0.62, 0.15, -0.15),
    radius: 0.09,
    shape: 'sphere',
  ),
  Organelle(
    id: 'lysosome2',
    name: 'الليسوسومات',
    function: 'تهضم الفضلات والمواد التالفة داخل الخلية.',
    source: _kGeneralSource,
    color: Colors.brown,
    center: Vec3(0.3, 0.68, -0.1),
    radius: 0.08,
    shape: 'sphere',
  ),
];

/// Plant-cell extras (shared parts are the same as the animal cell,
/// minus lysosomes which are rare in plant cells — omitted honestly).
const List<Organelle> kPlantExtras = <Organelle>[
  Organelle(
    id: 'cell_wall',
    name: 'الجدار الخلوي',
    function: 'طبقة صلبة تحيط بالخلية النباتية تحميها وتدعمها وتعطيها شكلاً ثابتاً.',
    source: _kGeneralSource,
    color: Colors.green,
    center: Vec3(0, 0, 0),
    radius: 1.12,
    shape: 'box',
  ),
  Organelle(
    id: 'chloro1',
    name: 'البلاستيدات الخضراء',
    function: 'البناء الضوئي؛ تحوّل ضوء الشمس إلى طاقة كيميائية.',
    source: _kGeneralSource,
    color: Colors.lightGreen,
    center: Vec3(0.6, 0.35, 0.45),
    radius: 0.17,
    shape: 'disc',
    flattenY: 0.45,
  ),
  Organelle(
    id: 'chloro2',
    name: 'البلاستيدات الخضراء',
    function: 'البناء الضوئي؛ تحوّل ضوء الشمس إلى طاقة كيميائية.',
    source: _kGeneralSource,
    color: Colors.lightGreen,
    center: Vec3(-0.6, -0.35, 0.5),
    radius: 0.16,
    shape: 'disc',
    flattenY: 0.45,
  ),
  Organelle(
    id: 'chloro3',
    name: 'البلاستيدات الخضراء',
    function: 'البناء الضوئي؛ تحوّل ضوء الشمس إلى طاقة كيميائية.',
    source: _kGeneralSource,
    color: Colors.lightGreen,
    center: Vec3(0.15, 0.7, -0.4),
    radius: 0.15,
    shape: 'disc',
    flattenY: 0.45,
  ),
  Organelle(
    id: 'vacuole',
    name: 'الفجوة العصارية الكبيرة',
    function: 'تخزّن الماء والمواد الذائبة وتدعم ضغط الامتلاء في الخلية النباتية.',
    source: _kGeneralSource,
    color: Colors.cyan,
    center: Vec3(0.05, -0.05, -0.1),
    radius: 0.42,
    shape: 'sphere',
  ),
];

/// Full organelle list for a cell kind. Plant cells share the animal
/// parts except the lysosomes (rare in plant cells — omitted, not faked).
List<Organelle> organellesFor(CellKind kind) {
  if (kind == CellKind.animal) return kAnimalOrganelles;
  final List<Organelle> shared = kAnimalOrganelles
      .where((o) => o.id != 'lysosome1' && o.id != 'lysosome2')
      .toList(growable: false);
  return <Organelle>[...shared, ...kPlantExtras];
}

/// Points of a circle of radius [r] in the plane spanned by [u] and [v],
/// centred at [c]. Used for great circles, rings and wavy sheets.
List<Vec3> _circlePoints(Vec3 c, Vec3 u, Vec3 v, double r, int n) {
  final List<Vec3> pts = <Vec3>[];
  for (var i = 0; i <= n; i++) {
    final double t = 2 * math.pi * i / n;
    pts.add(Vec3(
      c.x + (u.x * math.cos(t) + v.x * math.sin(t)) * r,
      c.y + (u.y * math.cos(t) + v.y * math.sin(t)) * r,
      c.z + (u.z * math.cos(t) + v.z * math.sin(t)) * r,
    ));
  }
  return pts;
}

// ------------------------------------------------------------------
// The 3D painter
// ------------------------------------------------------------------

class Cell3DPainter extends CustomPainter {
  Cell3DPainter({
    required this.organelles,
    required this.yaw,
    required this.pitch,
    required this.selectedId,
    required this.showLabels,
    required this.quizTargetId,
  });

  final List<Organelle> organelles;
  final double yaw;
  final double pitch;
  final String? selectedId;
  final bool showLabels;

  /// Organelle id the quiz is asking for (highlighted with a ring).
  final String? quizTargetId;

  static const double _focal = 3.2;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) * 0.42;

    final List<_DrawCmd> cmds = <_DrawCmd>[];
    final Map<String, _Hit> hits = <String, _Hit>{};

    for (final Organelle o in organelles) {
      final Vec3 rc = rotatePoint(o.center, yaw, pitch);
      final Offset? pc = projectPoint(rc, _focal, radius, center);
      if (pc == null) continue;
      final double scale = _focal / (_focal - rc.z);
      final double pr = o.radius * scale * radius;
      hits[o.id] = _Hit(pc, math.max(pr, 10), rc.z);

      final bool selected = o.id == selectedId;
      final bool quizTarget = o.id == quizTargetId;
      final double depth = rc.z;

      switch (o.shape) {
        case 'sphere':
          cmds.add(_DrawCmd(depth, (c) {
            _drawSphere(c, o, pc, pr, center, radius, selected, quizTarget);
          }));
          break;
        case 'capsule':
          cmds.add(_DrawCmd(depth, (c) {
            _drawCapsule(c, o, pc, pr, center, radius, selected, quizTarget);
          }));
          break;
        case 'disc':
          cmds.add(_DrawCmd(depth, (c) {
            _drawDisc(c, o, pc, pr, center, radius, selected, quizTarget);
          }));
          break;
        case 'dots':
          cmds.add(_DrawCmd(depth, (c) {
            _drawDots(c, o, pc, pr, center, radius, selected, quizTarget);
          }));
          break;
        case 'sheets':
          cmds.add(_DrawCmd(depth, (c) {
            _drawSheets(c, o, pc, pr, center, radius, selected, quizTarget);
          }));
          break;
        case 'tubes':
          cmds.add(_DrawCmd(depth, (c) {
            _drawTubes(c, o, pc, pr, center, radius, selected, quizTarget);
          }));
          break;
        case 'box':
          cmds.add(_DrawCmd(depth - 0.5, (c) {
            _drawBox(c, o, center, radius, selected, quizTarget);
          }));
          break;
      }
    }

    // Painter's algorithm: farthest first.
    cmds.sort((a, b) => a.depth.compareTo(b.depth));
    for (final _DrawCmd cmd in cmds) {
      cmd.draw(canvas);
    }

    // Labels on top (front organelles only, so the view stays readable).
    if (showLabels) {
      for (final Organelle o in organelles) {
        final _Hit? hit = hits[o.id];
        if (hit == null || hit.depth < -0.55) continue;
        final bool selected = o.id == selectedId;
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: o.name,
            style: TextStyle(
              color: selected ? Colors.black : Colors.black87,
              fontSize: selected ? 13 : 11,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              backgroundColor: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        tp.paint(
          canvas,
          Offset(hit.point.dx - tp.width / 2,
              hit.point.dy - hit.radius - tp.height - 2),
        );
      }
    }
  }

  /// Project a model-space polyline to screen space; null if any point
  /// is behind the camera.
  List<Offset>? _projectPolyline(
    List<Vec3> pts,
    Offset center,
    double radius,
  ) {
    final List<Offset> out = <Offset>[];
    for (final Vec3 p in pts) {
      final Vec3 r = rotatePoint(p, yaw, pitch);
      final Offset? s = projectPoint(r, _focal, radius, center);
      if (s == null) return null;
      out.add(s);
    }
    return out;
  }

  void _drawPolyline(
    Canvas canvas,
    List<Vec3> pts,
    Offset center,
    double radius,
    Paint paint, {
    bool close = false,
  }) {
    final List<Offset>? screen = _projectPolyline(pts, center, radius);
    if (screen == null || screen.length < 2) return;
    final Path path = Path()..moveTo(screen.first.dx, screen.first.dy);
    for (var i = 1; i < screen.length; i++) {
      path.lineTo(screen[i].dx, screen[i].dy);
    }
    if (close) path.close();
    canvas.drawPath(path, paint);
  }

  void _ring(
    Canvas canvas,
    Organelle o,
    Vec3 u,
    Vec3 v,
    Offset center,
    double radius,
    Paint paint,
  ) {
    _drawPolyline(
      canvas,
      _circlePoints(o.center, u, v, o.radius, 36),
      center,
      radius,
      paint,
      close: true,
    );
  }

  void _selectionRing(Canvas canvas, Offset pc, double pr, bool quizTarget) {
    canvas.drawCircle(
      pc,
      pr + 6,
      Paint()
        ..color = quizTarget ? Colors.amber : Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawSphere(
    Canvas canvas,
    Organelle o,
    Offset pc,
    double pr,
    Offset center,
    double radius,
    bool selected,
    bool quizTarget,
  ) {
    final bool isMembrane = o.id == 'membrane';
    final bool isVacuole = o.id == 'vacuole';
    // Translucent fill so inner organelles stay visible.
    canvas.drawCircle(
      pc,
      pr,
      Paint()
        ..color = o.color.withValues(
            alpha: isMembrane || isVacuole ? 0.10 : 0.55),
    );
    canvas.drawCircle(
      pc,
      pr,
      Paint()
        ..color = o.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMembrane ? 3 : 2,
    );
    // Great circles give the sphere its 3D read.
    final Paint ringPaint = Paint()
      ..color = o.color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _ring(canvas, o, const Vec3(1, 0, 0), const Vec3(0, 1, 0),
        center, radius, ringPaint);
    _ring(canvas, o, const Vec3(1, 0, 0), const Vec3(0, 0, 1),
        center, radius, ringPaint);
    // Small highlight: a short arc near the top-left of the disc.
    canvas.drawArc(
      Rect.fromCircle(center: pc, radius: pr * 0.7),
      math.pi * 1.05,
      math.pi * 0.35,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (selected || quizTarget) _selectionRing(canvas, pc, pr, quizTarget);
  }

  void _drawCapsule(
    Canvas canvas,
    Organelle o,
    Offset pc,
    double pr,
    Offset center,
    double radius,
    bool selected,
    bool quizTarget,
  ) {
    // Ellipsoid: a sphere squashed along its long axis, drawn as a
    // filled ellipse plus inner fold lines (cristae).
    final Vec3 axis = o.axis;
    final double len = math.sqrt(
        axis.x * axis.x + axis.y * axis.y + axis.z * axis.z);
    final Vec3 a = Vec3(axis.x / len, axis.y / len, axis.z / len);
    // A perpendicular in model space.
    final Vec3 perp = (a.x.abs() < 0.9)
        ? Vec3(0, -a.z, a.y)
        : Vec3(-a.z, 0, a.x);
    final double plen =
        math.sqrt(perp.x * perp.x + perp.y * perp.y + perp.z * perp.z);
    final Vec3 p = Vec3(perp.x / plen, perp.y / plen, perp.z / plen);
    // Outline: ellipse in the (axis, perp) plane.
    final List<Vec3> outline = <Vec3>[];
    for (var i = 0; i <= 36; i++) {
      final double t = 2 * math.pi * i / 36;
      outline.add(Vec3(
        o.center.x + (a.x * math.cos(t) * 1.7 + p.x * math.sin(t)) * o.radius,
        o.center.y + (a.y * math.cos(t) * 1.7 + p.y * math.sin(t)) * o.radius,
        o.center.z + (a.z * math.cos(t) * 1.7 + p.z * math.sin(t)) * o.radius,
      ));
    }
    final List<Offset>? screen = _projectPolyline(outline, center, radius);
    if (screen != null && screen.length > 2) {
      final Path path = Path()..moveTo(screen.first.dx, screen.first.dy);
      for (var i = 1; i < screen.length; i++) {
        path.lineTo(screen[i].dx, screen[i].dy);
      }
      path.close();
      canvas.drawPath(
          path, Paint()..color = o.color.withValues(alpha: 0.75));
      canvas.drawPath(
          path,
          Paint()
            ..color = o.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      // Cristae: two inner wavy lines along the long axis.
      for (var k = -1; k <= 1; k += 2) {
        final List<Vec3> fold = <Vec3>[];
        for (var i = 0; i <= 20; i++) {
          final double t = -1.0 + 2.0 * i / 20;
          fold.add(Vec3(
            o.center.x + a.x * t * o.radius * 1.4 + p.x * k * o.radius * 0.45 * math.sin(t * 6),
            o.center.y + a.y * t * o.radius * 1.4 + p.y * k * o.radius * 0.45 * math.sin(t * 6),
            o.center.z + a.z * t * o.radius * 1.4 + p.z * k * o.radius * 0.45 * math.sin(t * 6),
          ));
        }
        _drawPolyline(
          canvas,
          fold,
          center,
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    if (selected || quizTarget) _selectionRing(canvas, pc, pr * 1.4, quizTarget);
  }

  void _drawDisc(
    Canvas canvas,
    Organelle o,
    Offset pc,
    double pr,
    Offset center,
    double radius,
    bool selected,
    bool quizTarget,
  ) {
    // Golgi: a stack of 4 flattened discs; chloroplast: one flattened
    // disc with inner lines. Flattened along Y in model space.
    final int layers = o.id == 'golgi' ? 4 : 1;
    for (var l = 0; l < layers; l++) {
      final double dy = (l - (layers - 1) / 2) * 0.09;
      final double lr = o.radius * (1 - 0.12 * (l - (layers - 1) / 2).abs());
      final Vec3 c = Vec3(o.center.x, o.center.y + dy, o.center.z);
      final List<Vec3> ring = _circlePoints(
          c, const Vec3(1, 0, 0), const Vec3(0, 0, 1), lr, 32);
      // Squash the ring vertically to fake the flattened disc.
      final List<Vec3> flat = ring
          .map((p) => Vec3(
              p.x, o.center.y + (p.y - o.center.y) * o.flattenY, p.z))
          .toList(growable: false);
      final List<Offset>? screen = _projectPolyline(flat, center, radius);
      if (screen == null || screen.length < 3) continue;
      final Path path = Path()..moveTo(screen.first.dx, screen.first.dy);
      for (var i = 1; i < screen.length; i++) {
        path.lineTo(screen[i].dx, screen[i].dy);
      }
      path.close();
      canvas.drawPath(
          path, Paint()..color = o.color.withValues(alpha: 0.7));
      canvas.drawPath(
          path,
          Paint()
            ..color = o.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    if (selected || quizTarget) _selectionRing(canvas, pc, pr, quizTarget);
  }

  void _drawDots(
    Canvas canvas,
    Organelle o,
    Offset pc,
    double pr,
    Offset center,
    double radius,
    bool selected,
    bool quizTarget,
  ) {
    // Ribosomes: deterministic pseudo-random dots inside a small ball,
    // so the layout is stable between frames.
    final math.Random rng = math.Random(42);
    for (var i = 0; i < 14; i++) {
      final double dx = (rng.nextDouble() * 2 - 1) * o.radius;
      final double dy = (rng.nextDouble() * 2 - 1) * o.radius;
      final double dz = (rng.nextDouble() * 2 - 1) * o.radius;
      final Vec3 p = Vec3(o.center.x + dx, o.center.y + dy, o.center.z + dz);
      final Vec3 r = rotatePoint(p, yaw, pitch);
      final Offset? s = projectPoint(r, _focal, radius, center);
      if (s == null) continue;
      canvas.drawCircle(
          s, 3.5, Paint()..color = o.color.withValues(alpha: 0.9));
    }
    if (selected || quizTarget) _selectionRing(canvas, pc, pr, quizTarget);
  }

  void _drawSheets(
    Canvas canvas,
    Organelle o,
    Offset pc,
    double pr,
    Offset center,
    double radius,
    bool selected,
    bool quizTarget,
  ) {
    // Rough ER: three parallel wavy sheets, dotted with ribosomes.
    for (var s = 0; s < 3; s++) {
      final double zoff = (s - 1) * 0.14;
      final List<Vec3> wave = <Vec3>[];
      for (var i = 0; i <= 24; i++) {
        final double t = -1.0 + 2.0 * i / 24;
        wave.add(Vec3(
          o.center.x + t * o.radius * 1.3,
          o.center.y + (s - 1) * 0.1 + 0.06 * math.sin(t * 8 + s),
          o.center.z + zoff,
        ));
      }
      _drawPolyline(
        canvas,
        wave,
        center,
        radius,
        Paint()
          ..color = o.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      // Ribosome dots sitting on the sheet.
      for (var i = 0; i <= 4; i++) {
        final double t = -0.9 + 0.45 * i;
        final Vec3 p = Vec3(
          o.center.x + t * o.radius * 1.3,
          o.center.y + (s - 1) * 0.1 + 0.06 * math.sin(t * 8 + s) + 0.05,
          o.center.z + zoff,
        );
        final Vec3 r = rotatePoint(p, yaw, pitch);
        final Offset? sp = projectPoint(r, _focal, radius, center);
        if (sp != null) {
          canvas.drawCircle(
              sp, 2.5, Paint()..color = Colors.red.withValues(alpha: 0.9));
        }
      }
    }
    if (selected || quizTarget) _selectionRing(canvas, pc, pr, quizTarget);
  }

  void _drawTubes(
    Canvas canvas,
    Organelle o,
    Offset pc,
    double pr,
    Offset center,
    double radius,
    bool selected,
    bool quizTarget,
  ) {
    // Smooth ER: three winding tubes (helix-like curves).
    for (var s = 0; s < 3; s++) {
      final List<Vec3> tube = <Vec3>[];
      for (var i = 0; i <= 28; i++) {
        final double t = i / 28;
        final double ang = t * math.pi * 3 + s * 2.1;
        tube.add(Vec3(
          o.center.x + (t - 0.5) * o.radius * 2.2,
          o.center.y + 0.1 * math.sin(ang) + (s - 1) * 0.09,
          o.center.z + 0.1 * math.cos(ang),
        ));
      }
      _drawPolyline(
        canvas,
        tube,
        center,
        radius,
        Paint()
          ..color = o.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    if (selected || quizTarget) _selectionRing(canvas, pc, pr, quizTarget);
  }

  void _drawBox(
    Canvas canvas,
    Organelle o,
    Offset center,
    double radius,
    bool selected,
    bool quizTarget,
  ) {
    // Cell wall: a cube around the cell, edges + 3 translucent faces.
    final double s = o.radius;
    final List<Vec3> v = <Vec3>[
      Vec3(-s, -s, -s), Vec3(s, -s, -s), Vec3(s, s, -s), Vec3(-s, s, -s),
      Vec3(-s, -s, s), Vec3(s, -s, s), Vec3(s, s, s), Vec3(-s, s, s),
    ];
    const List<List<int>> edges = <List<int>>[
      [0, 1], [1, 2], [2, 3], [3, 0],
      [4, 5], [5, 6], [6, 7], [7, 4],
      [0, 4], [1, 5], [2, 6], [3, 7],
    ];
    // Faces (quads) sorted far-to-near so nearer faces paint over.
    const List<List<int>> faces = <List<int>>[
      [0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4],
      [2, 3, 7, 6], [1, 2, 6, 5], [0, 3, 7, 4],
    ];
    final List<({double depth, List<Offset> pts})> faceCmds = [];
    for (final List<int> f in faces) {
      double depth = 0;
      final List<Offset> pts = <Offset>[];
      var ok = true;
      for (final int idx in f) {
        final Vec3 r = rotatePoint(v[idx], yaw, pitch);
        depth += r.z;
        final Offset? s2 = projectPoint(r, _focal, radius, center);
        if (s2 == null) {
          ok = false;
          break;
        }
        pts.add(s2);
      }
      if (ok) faceCmds.add((depth: depth / 4, pts: pts));
    }
    faceCmds.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faceCmds) {
      final Path path = Path()..moveTo(face.pts.first.dx, face.pts.first.dy);
      for (var i = 1; i < face.pts.length; i++) {
        path.lineTo(face.pts[i].dx, face.pts[i].dy);
      }
      path.close();
      canvas.drawPath(
          path, Paint()..color = o.color.withValues(alpha: 0.06));
    }
    final Paint edgePaint = Paint()
      ..color = o.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final List<int> e in edges) {
      final List<Offset>? line =
          _projectPolyline([v[e[0]], v[e[1]]], center, radius);
      if (line == null || line.length < 2) continue;
      canvas.drawLine(line[0], line[1], edgePaint);
    }
    if (selected || quizTarget) {
      final Vec3 rc = rotatePoint(o.center, yaw, pitch);
      final Offset? pc = projectPoint(rc, _focal, radius, center);
      if (pc != null) {
        _selectionRing(canvas, pc, o.radius * radius * 0.9, quizTarget);
      }
    }
  }

  @override
  bool shouldRepaint(covariant Cell3DPainter old) =>
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.selectedId != selectedId ||
      old.showLabels != showLabels ||
      old.quizTargetId != quizTargetId ||
      old.organelles != organelles;
}

class _Hit {
  _Hit(this.point, this.radius, this.depth);
  final Offset point;
  final double radius;
  final double depth;
}

// ------------------------------------------------------------------
// The 3D viewer screen
// ------------------------------------------------------------------

/// Interactive 3D cell viewer: animal / plant toggle, drag to rotate,
/// auto-rotate, tap an organelle to learn its name + function, and a
/// 3-question "find the organelle" quiz mode.
class Cell3DScreen extends StatefulWidget {
  const Cell3DScreen({super.key});

  static const String title = 'الخلية ثلاثية الأبعاد';

  @override
  State<Cell3DScreen> createState() => _Cell3DScreenState();
}

class _Cell3DScreenState extends State<Cell3DScreen>
    with SingleTickerProviderStateMixin {
  CellKind _kind = CellKind.animal;
  double _yaw = 0.6;
  double _pitch = 0.35;
  bool _autoRotate = true;
  bool _showLabels = true;
  String? _selectedId;
  late final AnimationController _spin;

  // Quiz mode: find the named organelle in 3D.
  bool _quizMode = false;
  String? _quizTargetId;
  int _quizScore = 0;
  int _quizAsked = 0;
  bool _quizDone = false;
  String? _quizMessage;

  List<Organelle> get _organelles => organellesFor(_kind);

  /// Organelles the quiz can ask for (real 3D shapes, not the
  /// membrane/wall/cytoplasm background).
  List<Organelle> get _quizPool => _organelles
      .where((o) =>
          o.shape != 'box' &&
          o.id != 'membrane' &&
          o.id != 'ribosomes')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
    _spin.addListener(() {
      if (_autoRotate && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  double get _totalYaw =>
      _yaw + (_autoRotate ? _spin.value * 2 * math.pi : 0);

  Organelle? get _selected {
    if (_selectedId == null) return null;
    for (final Organelle o in _organelles) {
      if (o.id == _selectedId) return o;
    }
    return null;
  }

  Organelle? get _quizTarget {
    if (_quizTargetId == null) return null;
    for (final Organelle o in _organelles) {
      if (o.id == _quizTargetId) return o;
    }
    return null;
  }

  void _startQuiz() {
    setState(() {
      _quizMode = true;
      _quizDone = false;
      _quizScore = 0;
      _quizAsked = 0;
      _quizMessage = null;
      _selectedId = null;
      _nextQuizTarget();
    });
  }

  void _nextQuizTarget() {
    final pool = _quizPool.where((o) => o.id != _quizTargetId).toList();
    _quizTargetId = pool[math.Random().nextInt(pool.length)].id;
  }

  void _endQuiz() {
    setState(() {
      _quizDone = true;
      _quizMode = false;
      _quizTargetId = null;
    });
  }

  /// Hit-test a tap in canvas coordinates: project every organelle
  /// centre and take the nearest one within its projected radius.
  void _handleTap(TapUpDetails d, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) * 0.42;
    const double focal = 3.2;
    Organelle? best;
    double bestDepth = -1e9;
    for (final Organelle o in _organelles) {
      final Vec3 rc = rotatePoint(o.center, _totalYaw, _pitch);
      final Offset? pc = projectPoint(rc, focal, radius, center);
      if (pc == null) continue;
      final double scale = focal / (focal - rc.z);
      final double pr = math.max(o.radius * scale * radius, 14);
      if ((d.localPosition - pc).distance <= pr && rc.z > bestDepth) {
        best = o;
        bestDepth = rc.z;
      }
    }
    setState(() {
      if (best == null) {
        _selectedId = null;
        return;
      }
      _selectedId = best.id;
      if (_quizMode) {
        _quizAsked++;
        if (best.id == _quizTargetId) {
          _quizScore++;
          _quizMessage = 'صحيح ✓ — هذه هي «${best.name}».';
          if (_quizAsked >= 3) {
            _endQuiz();
            return;
          }
          _nextQuizTarget();
        } else {
          _quizMessage = 'ليست هذه — جرّبي مرة أخرى: أين «${_quizTarget?.name ?? ''}»؟';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Organelle? selected = _selected;
    final Organelle? quizTarget = _quizTarget;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الخلية ثلاثية الأبعاد')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'رسم تعليمي مبسّط ثلاثي الأبعاد — اسحبي لتدوير الخلية واضغطي على أي عضية لتعرفي اسمها ووظيفتها. المحتوى وصف علمي عام؛ وما له مصدر في بنك الأسئلة يظهر مصدره ورقم صفحته.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<CellKind>(
                segments: const [
                  ButtonSegment(
                      value: CellKind.animal, label: Text('خلية حيوانية')),
                  ButtonSegment(
                      value: CellKind.plant, label: Text('خلية نباتية')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _selectedId = null;
                  _quizMode = false;
                  _quizDone = false;
                  _quizTargetId = null;
                }),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double w = constraints.maxWidth;
                  final Size canvasSize = Size(w, 340);
                  return GestureDetector(
                    onPanUpdate: (d) => setState(() {
                      _yaw += d.delta.dx * 0.012;
                      _pitch = (_pitch + d.delta.dy * 0.008)
                          .clamp(-1.1, 1.1);
                    }),
                    onTapUp: (d) => _handleTap(d, canvasSize),
                    child: Container(
                      height: 340,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CustomPaint(
                        size: canvasSize,
                        painter: Cell3DPainter(
                          organelles: _organelles,
                          yaw: _totalYaw,
                          pitch: _pitch,
                          selectedId: _selectedId,
                          showLabels: _showLabels,
                          quizTargetId: _quizTargetId,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: <Widget>[
                  const Icon(Icons.autorenew, size: 18),
                  const SizedBox(width: 4),
                  const Text('تدوير تلقائي'),
                  Switch(
                    value: _autoRotate,
                    onChanged: (v) => setState(() => _autoRotate = v),
                  ),
                  const SizedBox(width: 8),
                  const Text('التسميات'),
                  Switch(
                    value: _showLabels,
                    onChanged: (v) => setState(() => _showLabels = v),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _yaw = 0.6;
                      _pitch = 0.35;
                      _selectedId = null;
                    }),
                    child: const Text('إعادة الضبط'),
                  ),
                ],
              ),
              const Text(
                'اسحبي بإصبعك لتدوير الخلية في كل الاتجاهات، واضغطي على أي جزء.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (_quizMode && quizTarget != null)
                Card(
                  color: Colors.amber.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'وضع الاختبار: اضغطي على «${quizTarget.name}» في الخلية ثلاثية الأبعاد (${_quizAsked + 1} من 3)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_quizMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(_quizMessage!),
                        ],
                      ],
                    ),
                  ),
                )
              else if (_quizDone)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'انتهى الاختبار — نتيجتك: $_quizScore / 3\n'
                      'أسئلة تجريبية (demo — ليست من المنهج اليمني).',
                    ),
                  ),
                )
              else if (selected != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(selected.function),
                        const SizedBox(height: 6),
                        Text(
                          'المصدر: ${selected.source}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                        'اضغطي على أي عضية في الخلية لتعرفي اسمها ووظيفتها.'),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _quizMode ? null : _startQuiz,
                child: const Text('اختبر نفسك: أين العضية؟ (تجريبي)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'ملاحظة: الأبعاد والأشكال مبسطة للتعليم ولا تمثل المقاييس الحقيقية؛ '
                'الخلية الحقيقية تحوي عضيات أكثر مما يظهر هنا.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
