#!/usr/bin/env python3
"""ABQARIYA — Python reference implementation of the pure logic.

Mirrors, exactly:
  lib/models/game_result.dart   (stars, XP)
  lib/games/game_engine.dart    (streak bonus rule)
  lib/analytics/analytics_engine.dart (mastery, SM-2, insufficient data)
  lib/core/progress_store.dart      (XP levels: flat 500 XP/level)
  lib/exam/ministerial_exam.dart      (auto-grading)

Run: python3 tools/verify_logic.py
Exit code 0 = all asserts passed. No Flutter/Dart SDK needed.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta

# ---------------------------------------------------------------- stars / XP
def stars_for_accuracy(pct: float) -> int:
    if pct >= 90:
        return 3
    if pct >= 70:
        return 2
    if pct >= 50:
        return 1
    return 0


def xp_for(correct: int, streak_bonus: int) -> int:
    """XP = 10*correct + 5*streakBonus (game_result.dart)."""
    return 10 * correct + 5 * streak_bonus


def streak_bonus_from_answers(answers: list[bool]) -> tuple[int, int, int]:
    """Return (correct, streak_bonus, best_streak).

    Streak bonus: each correct answer given while the running streak
    is >= 3 earns +1 bonus (game_engine.dart).
    """
    correct = 0
    streak = 0
    best = 0
    bonus = 0
    for a in answers:
        if a:
            correct += 1
            streak += 1
            best = max(best, streak)
            if streak >= 3:
                bonus += 1
        else:
            streak = 0
    return correct, bonus, best


def xp_from_answers(answers: list[bool]) -> int:
    correct, bonus, _ = streak_bonus_from_answers(answers)
    return xp_for(correct, bonus)


# ------------------------------------------------------------------- mastery
@dataclass
class Attempt:
    subject: str
    unit: str
    correct: bool
    seconds: int = 10
    at: datetime = field(default_factory=lambda: datetime(2026, 11, 25))


def summarize(attempts: list[Attempt]) -> dict:
    total = len(attempts)
    correct = sum(1 for a in attempts if a.correct)
    by_subject: dict[str, list[Attempt]] = {}
    by_unit: dict[str, list[Attempt]] = {}
    for a in attempts:
        by_subject.setdefault(a.subject, []).append(a)
        by_unit.setdefault(f"{a.subject} / {a.unit}", []).append(a)

    def mastery(groups):
        out = {}
        for k, g in groups.items():
            c = sum(1 for a in g if a.correct)
            out[k] = (c * 100.0 / len(g), len(g), c)
        return out

    weakest = []
    if total >= 5:
        units = [
            (k, v[0])
            for k, v in mastery(by_unit).items()
            if v[1] >= 3
        ]
        units.sort(key=lambda kv: kv[1])
        weakest = [k for k, _ in units[:3]]
    return {
        "total": total,
        "correct": correct,
        "overall": (correct * 100.0 / total) if total else None,
        "has_enough_data": total >= 5,
        "readiness": (correct * 100.0 / total) if total >= 5 else None,
        "by_subject": mastery(by_subject),
        "by_unit": mastery(by_unit),
        "weakest_units": weakest,
        "avg_seconds": (
            sum(a.seconds for a in attempts) / total if total else None
        ),
    }


# ---------------------------------------------------------------------- SM-2
SM2_INTERVALS = [1, 3, 7, 14, 30]


def sm2_interval(repetitions: int) -> int:
    if repetitions <= 0:
        return 1
    idx = min(repetitions - 1, len(SM2_INTERVALS) - 1)
    return SM2_INTERVALS[idx]


def sm2_ease(ease: float, quality: int) -> float:
    q = max(0, min(5, quality))
    nxt = ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    return max(1.3, nxt)


@dataclass
class ReviewState:
    question_id: str
    repetitions: int = 0
    ease: float = 2.5
    interval_days: int = 1
    next_review: date = field(default_factory=lambda: date(2026, 11, 26))


def sm2_review(state: ReviewState, quality: int, today: date) -> ReviewState:
    q = max(0, min(5, quality))
    ease = sm2_ease(state.ease, q)
    if q < 3:
        return ReviewState(state.question_id, 0, ease, 1,
                           today + timedelta(days=1))
    reps = state.repetitions + 1
    interval = sm2_interval(reps)
    return ReviewState(state.question_id, reps, ease, interval,
                       today + timedelta(days=interval))


# ---------------------------------------------------------------- XP levels
# Canonical curve (lib/core/progress_store.dart levelForXp):
# flat 500 XP per level — level N starts at (N-1)*500 XP.
def xp_for_level(level: int) -> int:
    if level <= 1:
        return 0
    return (level - 1) * 500


def level_for_xp(total_xp: int) -> int:
    level = 1
    while total_xp >= xp_for_level(level + 1):
        level += 1
    return level


# --------------------------------------------------------------- exam grade
def grade_exam(correct_answers: list[str],
               given: dict[int, str | None]) -> dict:
    correct = sum(
        1 for i, c in enumerate(correct_answers)
        if given.get(i) is not None and given[i].strip() == c.strip()
    )
    total = len(correct_answers)
    unanswered = sum(1 for i in range(total) if given.get(i) is None)
    return {
        "correct": correct,
        "wrong": total - correct,
        "unanswered": unanswered,
        "accuracy": correct * 100.0 / total if total else 0.0,
    }


# -------------------------------------------------------------------- checks
def main() -> None:
    # stars (boundaries)
    assert stars_for_accuracy(100) == 3
    assert stars_for_accuracy(90) == 3
    assert stars_for_accuracy(89.9) == 2
    assert stars_for_accuracy(70) == 2
    assert stars_for_accuracy(69.9) == 1
    assert stars_for_accuracy(50) == 1
    assert stars_for_accuracy(49.9) == 0
    assert stars_for_accuracy(0) == 0

    # XP formula
    assert xp_for(5, 0) == 50
    assert xp_for(5, 3) == 65
    assert xp_for(0, 0) == 0
    # streak bonus: 3rd+ consecutive correct answers
    assert streak_bonus_from_answers([True, True, True, True]) == (4, 2, 4)
    assert streak_bonus_from_answers([True, False, True]) == (2, 0, 1)
    assert streak_bonus_from_answers([True, True, False, True, True, True]) == (5, 1, 3)
    assert xp_from_answers([True, True, True, True]) == 50  # 40 + 10
    assert xp_from_answers([True, False, True]) == 20

    # mastery + insufficient data
    empty = summarize([])
    assert empty["total"] == 0 and empty["overall"] is None
    assert empty["has_enough_data"] is False
    assert empty["readiness"] is None
    few = summarize([Attempt("physics", "u1", True)] * 4)
    assert few["has_enough_data"] is False
    assert few["readiness"] is None
    assert few["weakest_units"] == []
    attempts = [
        Attempt("physics", "u1", True), Attempt("physics", "u1", True),
        Attempt("physics", "u1", False), Attempt("physics", "u1", False),
        Attempt("math", "u1", True), Attempt("math", "u1", True),
    ]
    s = summarize(attempts)
    assert s["total"] == 6 and s["correct"] == 4
    assert math.isclose(s["overall"], 66.666, abs_tol=0.01)
    assert s["has_enough_data"] is True
    assert math.isclose(s["readiness"], 66.666, abs_tol=0.01)
    assert math.isclose(s["by_subject"]["physics"][0], 50.0)
    assert math.isclose(s["by_subject"]["math"][0], 100.0)
    # weakest units: u1 physics 0/3, u2 physics 1/3, u3 3/3, u4 2/3
    w_attempts: list[Attempt] = []
    w_attempts += [Attempt("physics", "u1", False)] * 3
    w_attempts += [Attempt("physics", "u2", True)] + [Attempt("physics", "u2", False)] * 2
    w_attempts += [Attempt("physics", "u3", True)] * 3
    w_attempts += [Attempt("physics", "u4", True)] * 2 + [Attempt("physics", "u4", False)]
    ws = summarize(w_attempts)
    assert ws["weakest_units"][0] == "physics / u1"
    assert ws["weakest_units"][1] == "physics / u2"
    assert len(ws["weakest_units"]) == 3

    # SM-2 intervals
    assert [sm2_interval(r) for r in (1, 2, 3, 4, 5, 9)] == [1, 3, 7, 14, 30, 30]
    today = date(2026, 11, 25)
    st = ReviewState("q1", next_review=today + timedelta(days=1))
    st = sm2_review(st, 5, today)
    assert (st.repetitions, st.interval_days) == (1, 1)
    st = sm2_review(st, 5, today)
    assert (st.repetitions, st.interval_days) == (2, 3)
    st = sm2_review(st, 5, today)
    assert (st.repetitions, st.interval_days) == (3, 7)
    # failure resets, ease floors at 1.3
    st = sm2_review(st, 0, today)
    assert (st.repetitions, st.interval_days) == (0, 1)
    assert st.ease >= 1.3
    for _ in range(10):
        st = sm2_review(st, 0, today)
    assert st.ease == 1.3

    # XP levels (canonical: flat 500 XP/level, progress_store.dart)
    assert xp_for_level(1) == 0 and xp_for_level(2) == 500
    assert xp_for_level(3) == 1000 and xp_for_level(4) == 1500
    assert level_for_xp(0) == 1 and level_for_xp(499) == 1
    assert level_for_xp(500) == 2 and level_for_xp(1000) == 3

    # exam auto-grading
    g = grade_exam(["أ", "ب"], {0: "أ", 1: "ب"})
    assert g == {"correct": 2, "wrong": 0, "unanswered": 0, "accuracy": 100.0}
    g = grade_exam(["أ", "ب"], {0: "أ"})
    assert g["correct"] == 1 and g["unanswered"] == 1

    print("ABQARIYA verify_logic: ALL CHECKS PASSED")
    print(f"  stars: 90%->3, 70%->2, 50%->1, 49.9%->0  OK")
    print(f"  XP: 4 correct in a row -> {xp_from_answers([True]*4)} XP "
          f"(40 + 2x5 streak bonus)")
    print(f"  mastery: 4/6 = {s['overall']:.1f}% ; weakest unit = "
          f"{ws['weakest_units'][0]}")
    print(f"  SM-2 intervals: 1,3,7,14,30 ; ease floor 1.3  OK")
    print(f"  levels: L2=500 XP, L3=1000 XP, L4=1500 XP (flat 500/level)  OK")
    print(f"  exam grading: 2/2 -> 100.0%  OK")


if __name__ == "__main__":
    main()
