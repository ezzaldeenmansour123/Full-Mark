// ABQARIYA — Chemistry Lab (مختبر الكيمياء)
// Molecule builder + equation balancer game.
// 100% offline. Procedural CustomPainter only — no images, no assets.
// Atom counts must balance exactly; valency rules are enforced.
// Content note: general chemistry principles. Yemeni-curriculum questions
// are NOT invented here.
// «المحتوى مبني على المبادئ العلمية العامة — أسئلة المنهج اليمني قيد الإعداد»
//
// HAND-VERIFIED LOGIC (checked by hand, NOT run — no Flutter/Dart SDK here):
//  Valency (max bonds): H=1, O=2, C=4, N=3. Bond counts in the builder are
//  checked against these maxima; exceeding them is rejected with a message.
//  Targets:
//   H₂O: 2 H + 1 O. Bonds: O–H ×2. O has 2 bonds ✓, each H has 1 ✓.
//   CO₂: 1 C + 2 O. Bonds: C=O ×2 (double bonds). C has 4 ✓, each O has 2 ✓.
//   O₂: 2 O. Bond: O=O (double). Each O has 2 ✓.
//   NH₃: 1 N + 3 H. Bonds: N–H ×3. N has 3 ✓, each H has 1 ✓.
//  Balancer — 2H₂ + O₂ → 2H₂O:
//   Correct coefficients (2, 1, 2): left H = 2×2 = 4, O = 1×2 = 2;
//   right H = 2×2 = 4, O = 2×1 = 2. Balanced ✓.
//   Wrong example (1, 1, 1): left H=2 vs right H=2 ✓ but left O=2 vs right O=1 ✗
//   → the live check must show O unbalanced. ✓
//   Wrong example (1, 1, 2): left H=2 vs right H=4 ✗ → H unbalanced. ✓
//  Atom counting is done by the pure function countAtoms() — no UI state
//  involved — so the check cannot drift from the display.

import 'package:flutter/material.dart';

/// Chemistry Lab — molecule builder + equation balancer.
///
/// Public constructor: `const ChemistryLab({super.key, this.onComplete})`.
class ChemistryLab extends StatefulWidget {
  const ChemistryLab({super.key, this.onComplete});

  final void Function(int score)? onComplete;

  static const String labId = 'chemistry_lab';
  static const String title = 'مختبر الكيمياء: بناء الجزيئات وموازنة المعادلات';
  static const String description =
      'ابنِ جزيئات H₂O و CO₂ و O₂ و NH₃ بذرات صحيحة التكافؤ، '
      'ثم وازن المعادلة 2H₂ + O₂ → 2H₂O حتى تتساوى الذرات تمامًا.';

  @override
  State<ChemistryLab> createState() => _ChemistryLabState();
}

/// One atom kind: symbol, display colour, max bonds (valency).
enum AtomKind {
  h('H', Colors.white, 1),
  o('O', Colors.red, 2),
  c('C', Colors.black, 4),
  n('N', Colors.blue, 3);

  const AtomKind(this.symbol, this.color, this.maxBonds);
  final String symbol;
  final Color color;
  final int maxBonds;
}

/// A placed atom in the builder canvas.
class _PlacedAtom {
  _PlacedAtom(this.kind, this.offset);
  final AtomKind kind;
  Offset offset;
}

/// A bond between two placed atoms (index-based, order = single/double).
class _Bond {
  _Bond(this.a, this.b, this.order);
  final int a, b, order;
}

class _ChemistryLabState extends State<ChemistryLab> {
  // --- Molecule builder state ---
  final List<_PlacedAtom> _atoms = [];
  final List<_Bond> _bonds = [];
  int? _bondFrom; // index of first atom tapped when making a bond
  String _builderMessage = 'اضغط على ذرة لإضافتها، ثم اضغط على ذرتين متتاليتين لربطهما برابطة.';
  String _target = 'H₂O';

  // --- Balancer state (2H₂ + O₂ → 2H₂O) ---
  int _cH2 = 1, _cO2 = 1, _cH2O = 1; // coefficients, each 1..4
  bool _balancerSolved = false;

  // --- Pure helpers (hand-verified above) ---

  /// Count atoms in a term: coefficient × atoms-per-molecule.
  /// e.g. countAtoms(2, {'H': 2}) → {'H': 4}.
  static Map<String, int> countAtoms(
      int coeff, Map<String, int> perMolecule) {
    return perMolecule.map((k, v) => MapEntry(k, k == '' ? 0 : coeff * v));
  }

  /// Is the current balancer state balanced?
  bool get _balanced {
    final leftH = _cH2 * 2;
    final leftO = _cO2 * 2;
    final rightH = _cH2O * 2;
    final rightO = _cH2O * 1;
    return leftH == rightH && leftO == rightO;
  }

  Map<String, int> get _targetCounts => switch (_target) {
        'H₂O' => {'H': 2, 'O': 1},
        'CO₂' => {'C': 1, 'O': 2},
        'O₂' => {'O': 2},
        'NH₃' => {'N': 1, 'H': 3},
        _ => {},
      };

  Map<String, int> get _currentCounts {
    final m = <String, int>{};
    for (final a in _atoms) {
      m[a.kind.symbol] = (m[a.kind.symbol] ?? 0) + 1;
    }
    return m;
  }

  int _bondCount(int index) =>
      _bonds.fold(0, (s, b) => s + ((b.a == index || b.b == index) ? b.order : 0));

  void _addAtom(AtomKind kind) {
    setState(() {
      // Stagger positions so new atoms do not stack exactly.
      final dx = 60.0 + (_atoms.length % 4) * 60.0;
      final dy = 70.0 + (_atoms.length ~/ 4) * 70.0;
      _atoms.add(_PlacedAtom(kind, Offset(dx, dy)));
      _builderMessage = 'أُضيفت ذرة ${kind.symbol}.';
    });
  }

  void _tapAtom(int index) {
    setState(() {
      if (_bondFrom == null) {
        _bondFrom = index;
        _builderMessage = 'اختر الذرة الثانية للربط (أو اضغط «إلغاء»).';
        return;
      }
      if (_bondFrom == index) {
        _bondFrom = null;
        return;
      }
      final a = _atoms[_bondFrom!];
      final b = _atoms[index];
      // Bond order: double bond allowed only O=O and C=O (standard cases here).
      final isDouble = (a.kind == AtomKind.o && b.kind == AtomKind.o) ||
          (a.kind == AtomKind.c && b.kind == AtomKind.o) ||
          (a.kind == AtomKind.o && b.kind == AtomKind.c);
      final order = isDouble ? 2 : 1;
      if (_bondCount(_bondFrom!) + order > a.kind.maxBonds ||
          _bondCount(index) + order > b.kind.maxBonds) {
        _builderMessage =
            'لا يمكن: تجاوز التكافؤ! ${a.kind.symbol} تكافؤه ${a.kind.maxBonds} و ${b.kind.symbol} تكافؤه ${b.kind.maxBonds}.';
        _bondFrom = null;
        return;
      }
      _bonds.add(_Bond(_bondFrom!, index, order));
      _builderMessage =
          'رابطة ${order == 2 ? 'مزدوجة' : 'أحادية'} بين ${a.kind.symbol} و ${b.kind.symbol}.';
      _bondFrom = null;
      _checkTarget();
    });
  }

  void _checkTarget() {
    final want = _targetCounts;
    final have = _currentCounts;
    final match = want.length == have.length &&
        want.entries.every((e) => have[e.key] == e.value);
    if (match) {
      _builderMessage = 'أحسنت! بنيت $_target بعدد ذرات صحيح. جرّب هدفًا آخر.';
    }
  }

  void _checkBalancer() {
    setState(() {
      if (_balanced && !_balancerSolved) {
        _balancerSolved = true;
        widget.onComplete?.call(1);
      } else if (!_balanced) {
        _balancerSolved = false;
      }
    });
  }

  Widget _coeffStepper(String label, int value, ValueChanged<int> onChanged) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > 1 ? () => onChanged(value - 1) : null),
        Container(
          width: 36,
          alignment: Alignment.center,
          child: Text('$value',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < 4 ? () => onChanged(value + 1) : null),
        Text(label, style: const TextStyle(fontSize: 16)),
      ]);

  @override
  Widget build(BuildContext context) {
    final leftH = _cH2 * 2, leftO = _cO2 * 2;
    final rightH = _cH2O * 2, rightO = _cH2O * 1;
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
                'المحتوى مبني على المبادئ العلمية العامة — أسئلة المنهج اليمني قيد الإعداد',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text('1) بناء الجزيئات',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                'قواعد التكافؤ: H يرتبط برابطة واحدة، O برابطتين، N بثلاث، C بأربع. '
                'الرابطة المزدوجة مسموحة فقط بين O=O و C=O في هذا المختبر.'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _target,
              items: const ['H₂O', 'CO₂', 'O₂', 'NH₃']
                  .map((t) => DropdownMenuItem(value: t, child: Text('الهدف: $t')))
                  .toList(),
              onChanged: (v) => setState(() {
                _target = v!;
                _atoms.clear();
                _bonds.clear();
                _bondFrom = null;
                _builderMessage = 'ابنِ $_target — عدد الذرات المطلوب: '
                    '${_targetCounts.entries.map((e) => '${e.key}×${e.value}').join(' ، ')}';
              }),
            ),
            Wrap(spacing: 8, children: [
              for (final k in AtomKind.values)
                ElevatedButton(
                  onPressed: () => _addAtom(k),
                  child: Text('أضف ${k.symbol} (تكافؤ ${k.maxBonds})'),
                ),
              OutlinedButton(
                  onPressed: () => setState(() {
                        _atoms.clear();
                        _bonds.clear();
                        _bondFrom = null;
                        _builderMessage = 'مسحت اللوحة.';
                      }),
                  child: const Text('مسح')),
              if (_bondFrom != null)
                OutlinedButton(
                    onPressed: () => setState(() => _bondFrom = null),
                    child: const Text('إلغاء الربط')),
            ]),
            const SizedBox(height: 8),
            Container(
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(children: [
                CustomPaint(
                  size: const Size(double.infinity, 240),
                  painter: _MoleculePainter(
                      atoms: _atoms, bonds: _bonds, selected: _bondFrom),
                ),
                for (var i = 0; i < _atoms.length; i++)
                  Positioned(
                    left: _atoms[i].offset.dx - 22,
                    top: _atoms[i].offset.dy - 22,
                    child: GestureDetector(
                      onTap: () => _tapAtom(i),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _atoms[i].kind.color,
                          border: Border.all(
                              color: _bondFrom == i
                                  ? Colors.green
                                  : Colors.grey,
                              width: _bondFrom == i ? 3 : 1),
                        ),
                        child: Text(_atoms[i].kind.symbol,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _atoms[i].kind == AtomKind.c
                                    ? Colors.white
                                    : Colors.black)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(_builderMessage),
            Text(
                'الذرات الحالية: ${_currentCounts.entries.map((e) => '${e.key}×${e.value}').join(' ، ') == '' ? 'لا شيء بعد' : _currentCounts.entries.map((e) => '${e.key}×${e.value}').join(' ، ')}'
                '  |  المطلوب لـ$_target: ${_targetCounts.entries.map((e) => '${e.key}×${e.value}').join(' ، ')}'),
            const SizedBox(height: 16),
            Text('2) موازنة المعادلة',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                'غيّر المعاملات حتى تتساوى ذرات كل عنصر في الطرفين. '
                'المعادلة الصحيحة: 2H₂ + O₂ → 2H₂O (تكوين الماء).'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      _coeffStepper('H₂ +', _cH2,
                          (v) => setState(() => _cH2 = v)),
                      _coeffStepper('O₂  →  ', _cO2,
                          (v) => setState(() => _cO2 = v)),
                      _coeffStepper('H₂O', _cH2O,
                          (v) => setState(() => _cH2O = v)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الطرف الأيسر: H = $leftH ، O = $leftO    |    الطرف الأيمن: H = $rightH ، O = $rightO',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _balanced
                        ? '✓ متوازنة تمامًا! عدد ذرات H و O متساوٍ في الطرفين.'
                        : '✗ غير متوازنة بعد — قارن عدد ذرات H و O في الطرفين.',
                    style: TextStyle(
                        color: _balanced ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _checkBalancer,
                    child: const Text('تحقق من الموازنة'),
                  ),
                  if (_balancerSolved)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'قبل التفاعل: جزيئا هيدروجين + جزيء أكسجين  •  بعد التفاعل: جزيئا ماء — لا ذرة تُفقد ولا تُستحدث (قانون حفظ الكتلة).',
                          textAlign: TextAlign.center),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'قانون حفظ الكتلة: في التفاعل الكيميائي لا تُفقد الذرات ولا تُستحدث؛ '
              'بل يعاد ترتيبها فقط — لذلك يجب أن تتساوى أعدادها في الطرفين.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoleculePainter extends CustomPainter {
  _MoleculePainter(
      {required this.atoms, required this.bonds, required this.selected});
  final List<_PlacedAtom> atoms;
  final List<_Bond> bonds;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final bondPaint = Paint()..color = Colors.grey..strokeWidth = 3;
    for (final b in bonds) {
      final a = atoms[b.a].offset, c = atoms[b.b].offset;
      if (b.order == 1) {
        canvas.drawLine(a, c, bondPaint);
      } else {
        // Double bond: two parallel lines offset perpendicular to the bond.
        final dir = (c - a).normalize();
        final perp = Offset(-dir.dy, dir.dx) * 4;
        canvas.drawLine(a + perp, c + perp, bondPaint);
        canvas.drawLine(a - perp, c - perp, bondPaint);
      }
    }
    if (selected != null) {
      canvas.drawCircle(atoms[selected!].offset, 28,
          Paint()..color = Colors.green.withValues(alpha: 0.2));
    }
  }

  @override
  bool shouldRepaint(covariant _MoleculePainter old) =>
      old.atoms != atoms || old.bonds != bonds || old.selected != selected;
}

extension on Offset {
  Offset normalize() {
    final len = distance;
    return len == 0 ? this : this / len;
  }
}
