#!/usr/bin/env python3
"""ABQARIYA — validate question packs (runs without the Flutter SDK).

Checks every pack in assets/data/questions/*.json:
  1. JSON parses and validates against assets/schema/content_schema.json
     (jsonschema, draft 2020-12).
  2. Pack is NOT demo (is_demo == false) and every question has a real
     book source (never 'demo — not Yemeni curriculum') and source_page >= 1.
  3. Every subject_id / unit_id / lesson_id exists in
     assets/data/curriculum.json (seed IDs: {subject}-u{N}, {subject}-u{N}-l{M}).
  4. Question ids unique across all packs; ids match ye-{subject}-u{N}-l{M}-NNN.
  5. mcq: 2-6 options, correct_option_index in range, and
     correct_answer == options[correct_option_index].
     true_false: correct_answer in ('صح', 'خطأ', 'True', 'False').
  6. explanation present and non-empty; difficulty 1-3; no question text
     longer than the schema allows; no two questions with identical text
     in the same lesson (likely copy/paste error).
  7. Coverage report: lessons with 0 questions, per subject/unit counts,
     and grounding tags (page-read vs toc-verified).

Exit code 0 = all packs valid. Warnings (coverage gaps) are printed but
do not fail the run — gaps are tracked in QUESTIONS_REPORT.md, not hidden.

Run: python3 tools/validate_questions.py [--strict]  (--strict fails on
any lesson with 0 questions)
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
QDIR = ROOT / "assets/data/questions"
SCHEMA_PATH = ROOT / "assets/schema/content_schema.json"
CURRICULUM_PATH = ROOT / "assets/data/curriculum.json"

ID_RE = re.compile(r"^ye-[a-z]+-u\d+-l\d+-\d{3}$")
MCQ = "mcq"
TF = "true_false"


def main() -> int:
    import jsonschema

    failures: list[str] = []
    warnings: list[str] = []
    passed = 0

    def check(name: str, ok: bool, detail: str = "") -> None:
        nonlocal passed
        if ok:
            passed += 1
        else:
            failures.append(f"{name}: {detail}")

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(schema)
    cur = json.loads(CURRICULUM_PATH.read_text(encoding="utf-8"))
    valid_lessons: set[str] = set()
    valid_units: set[str] = set()
    valid_subjects: set[str] = set()
    lessons_by_subject: dict[str, list[str]] = {}
    for subj in cur["subjects"]:
        valid_subjects.add(subj["id"])
        lessons_by_subject[subj["id"]] = []
        for unit in subj["units"]:
            uid = f"{subj['id']}-u{unit['number']}"
            valid_units.add(uid)
            for j in range(1, len(unit["lessons"]) + 1):
                lid = f"{uid}-l{j}"
                valid_lessons.add(lid)
                lessons_by_subject[subj["id"]].append(lid)

    pack_files = sorted(
        p for p in QDIR.glob("*.json")
        if QDIR.exists() and not p.name.startswith("_")
    ) if QDIR.exists() else []
    check("question packs exist", len(pack_files) > 0,
          f"no .json files in {QDIR}")
    all_ids: set[str] = set()
    seen_text: dict[str, str] = {}
    per_subject: dict[str, int] = {}
    per_lesson: dict[str, int] = {}
    tags_seen: dict[str, int] = {}

    for path in pack_files:
        try:
            pack = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            failures.append(f"{path.name}: invalid JSON: {exc}")
            continue
        errors = sorted(validator.iter_errors(pack), key=lambda e: list(e.path))
        check(f"{path.name}: schema-valid", not errors,
              "; ".join(f"{'/'.join(str(p) for p in e.path)}: {e.message}" for e in errors[:5]))
        meta = pack.get("pack", {})
        check(f"{path.name}: is_demo is false", meta.get("is_demo") is False)
        check(f"{path.name}: pack id present",
              bool(meta.get("id")) and meta["id"].startswith("ye-"))
        check(f"{path.name}: curriculum_year present",
              bool(meta.get("curriculum_year")))
        questions = pack.get("questions", [])
        check(f"{path.name}: has questions", len(questions) > 0)
        for q in questions:
            qid = q.get("id", "")
            check(f"{qid}: id format", bool(ID_RE.match(qid)), f"id={qid!r}")
            check(f"{qid}: id unique", qid not in all_ids, "duplicate id")
            all_ids.add(qid)
            check(f"{qid}: subject exists", q.get("subject_id") in valid_subjects,
                  f"subject_id={q.get('subject_id')!r}")
            check(f"{qid}: unit exists", q.get("unit_id") in valid_units,
                  f"unit_id={q.get('unit_id')!r}")
            check(f"{qid}: lesson exists", q.get("lesson_id") in valid_lessons,
                  f"lesson_id={q.get('lesson_id')!r}")
            check(f"{qid}: source is a real book",
                  bool(q.get("source")) and q["source"] != "demo — not Yemeni curriculum")
            check(f"{qid}: source_page >= 1",
                  isinstance(q.get("source_page"), int) and q["source_page"] >= 1,
                  f"source_page={q.get('source_page')!r}")
            check(f"{qid}: explanation present",
                  bool((q.get("explanation") or "").strip()))
            check(f"{qid}: media_ref is null", q.get("media_ref") is None)
            if q.get("type") == MCQ:
                opts = q.get("options") or []
                idx = q.get("correct_option_index")
                check(f"{qid}: mcq options 2-6", 2 <= len(opts) <= 6,
                      f"got {len(opts)}")
                check(f"{qid}: correct_option_index in range",
                      isinstance(idx, int) and 0 <= idx < len(opts),
                      f"idx={idx!r} options={len(opts)}")
                if isinstance(idx, int) and 0 <= idx < len(opts):
                    check(f"{qid}: correct_answer == options[idx]",
                          q.get("correct_answer") == opts[idx],
                          f"answer={q.get('correct_answer')!r} options[{idx}]={opts[idx]!r}")
            elif q.get("type") == TF:
                check(f"{qid}: true_false answer",
                      q.get("correct_answer") in ("صح", "خطأ", "True", "False"),
                      f"answer={q.get('correct_answer')!r}")
            key = (q.get("lesson_id"), (q.get("question_text") or "").strip())
            if key in seen_text:
                check(f"{qid}: no duplicate text in lesson", False,
                      f"same text as {seen_text[key]}")
            else:
                seen_text[key] = qid
            per_subject[q.get("subject_id", "?")] = per_subject.get(q.get("subject_id", "?"), 0) + 1
            per_lesson[q.get("lesson_id", "?")] = per_lesson.get(q.get("lesson_id", "?"), 0) + 1
            for tag in q.get("tags") or []:
                tags_seen[tag] = tags_seen.get(tag, 0) + 1

    total = sum(per_subject.values())
    print(f"packs: {len(pack_files)}  questions: {total}")
    for subj in sorted(per_subject):
        covered = sum(1 for lid in lessons_by_subject.get(subj, []) if per_lesson.get(lid))
        total_lessons = len(lessons_by_subject.get(subj, []))
        print(f"  {subj}: {per_subject[subj]} questions, "
              f"{covered}/{total_lessons} lessons covered")
    print(f"  grounding tags: {tags_seen}")
    uncovered = [lid for lid in sorted(valid_lessons) if not per_lesson.get(lid)]
    print(f"  lessons with 0 questions: {len(uncovered)}")
    for lid in uncovered[:40]:
        warnings.append(f"lesson without questions: {lid}")
    if len(uncovered) > 40:
        warnings.append(f"... and {len(uncovered) - 40} more lessons without questions")

    print(f"\n{passed} passed, {len(failures)} failed, {len(warnings)} warnings")
    for w in warnings:
        print("  WARN:", w)
    if failures:
        for f in failures[:30]:
            print("  FAIL:", f)
        if len(failures) > 30:
            print(f"  ... and {len(failures) - 30} more failures")
        return 1
    if "--strict" in sys.argv and uncovered:
        print("STRICT: failing because lessons have 0 questions")
        return 1
    print("ALL QUESTION PACKS VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
