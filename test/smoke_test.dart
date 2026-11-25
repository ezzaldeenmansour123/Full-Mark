// اختبار دخان خفيف: منطق المستويات النقي في progress_store.
// لا يحتاج قاعدة بيانات ولا محاكي — يعمل بـ `flutter test` في CI.
import 'package:abqariya/core/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levelForXp: 0 XP is level 1', () {
    expect(levelForXp(0), 1);
  });

  test('levelForXp: 499 XP is still level 1, 500 XP is level 2', () {
    expect(levelForXp(499), 1);
    expect(levelForXp(500), 2);
    expect(levelForXp(1000), 3);
  });

  test('levelForXp: negative XP clamps to level 1', () {
    expect(levelForXp(-10), 1);
  });

  test('xpToNextLevel: 0 XP needs 500', () {
    expect(xpToNextLevel(0), 500);
    expect(xpToNextLevel(499), 1);
    expect(xpToNextLevel(500), 500);
  });

  test('PlayerProgress.empty has zeroed fields', () {
    final PlayerProgress p = PlayerProgress.empty();
    expect(p.xp, 0);
    expect(p.stars, 0);
    expect(p.level, 1);
    expect(p.completionPercent, 0);
    expect(p.totalAttempts, 0);
    expect(p.accuracy, 0);
  });
}
