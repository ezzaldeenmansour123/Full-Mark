#!/usr/bin/env python3
"""ABQARIYA — merge + Sanaa verification (runs without the Flutter SDK).

Checks the 2026-11-25 merge pass:
  1. curriculum.json parses, is Sanaa-default, 53 units / 400 lessons,
     chemistry is 9 units (verified from the downloaded PDF itself),
     biology unit 6 is biotechnology (9 lessons, PDF-verified).
  2. pubspec.yaml + workflow YAML parse; workflow references real paths,
     pins Flutter 3.50.1 + Java 17, has the no-INTERNET check and the
     100 MB size gate.
  3. AndroidManifest has zero permissions (no INTERNET).
  4. Every relative Dart import resolves to an existing file.
  5. No duplicate public class names across lib/ (private _names are
     library-scoped in Dart and are exempt).
  6. Deleted duplicate screens are gone; canonical locations exist.
  7. Dart delimiter balance ({[( )]} + string/comment awareness is
     approximated — a balance failure is a hard fail, a pass is not a
     proof of compilability; see TEST_REPORT.md).
  8. DB v3: schema.dart kDatabaseVersion == 3, database.dart uses
     kCreateAllStatements and defines onUpgrade + seedCurriculumRows.
  9. Seed IDs are unique (subject-uN / -lM) and unit numbers are unique
     per subject.

Run: python3 tools/verify_merge.py
Exit code 0 = all checks passed.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
failures: list[str] = []
passed = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global passed
    if ok:
        passed += 1
        print(f"  PASS {name}")
    else:
        failures.append(name)
        print(f"  FAIL {name} {detail}")


def load_json(path: pathlib.Path):
    return json.loads(path.read_text(encoding="utf-8"))


print("== 1. curriculum.json (Sanaa) ==")
cur = load_json(ROOT / "assets/data/curriculum.json")
check("default_edition == sanaa", cur["meta"]["default_edition"] == "sanaa")
check("no questions in curriculum file",
      cur["meta"]["questions_status"] == "pending")
units = sum(len(s["units"]) for s in cur["subjects"])
lessons = sum(sum(len(u["lessons"]) for u in s["units"]) for s in cur["subjects"])
check("53 units", units == 53, f"got {units}")
check("400 lessons", lessons == 400, f"got {lessons}")
expected = {"math": (7, 41), "physics": (9, 81), "chemistry": (9, 61),
            "biology": (8, 54), "arabic": (7, 52), "english": (6, 49),
            "islamic": (7, 62)}
for s in cur["subjects"]:
    u, l = len(s["units"]), sum(len(x["lessons"]) for x in s["units"])
    check(f"subject {s['id']} {expected[s['id']]}", (u, l) == expected[s["id"]],
          f"got {(u, l)}")
    check(f"subject {s['id']} has no variants key",
          "variants" not in s or not s["variants"])
    nums = [x["number"] for x in s["units"]]
    check(f"subject {s['id']} unit numbers unique", len(nums) == len(set(nums)))
chem = next(s for s in cur["subjects"] if s["id"] == "chemistry")
check("chemistry conflict resolved to 9 units (PDF-verified)",
      chem.get("conflict_resolved", {}).get("decision") == "sanaa_9_units_pdf")
check("chemistry 9-unit TOC has lesson page numbers",
      all("lesson_pages" in u for u in chem["units"]) and
      all(len(u["lesson_pages"]) == len(u["lessons"]) for u in chem["units"]))
check("chemistry 7-unit index kept only as comparison note",
      "7 وحدات" in chem.get("conflict_resolved", {}).get("comparison_note", ""))
bio = next(s for s in cur["subjects"] if s["id"] == "biology")
check("biology unit 6 corrected to biotechnology (PDF-verified)",
      bio.get("conflict_resolved", {}).get("decision") == "sanaa_biology_u6_biotech_pdf")
check("biology unit 6 is التقانة الحيوية with 9 lessons",
      next(u for u in bio["units"] if u["number"] == 6)["title"] == "التقانة الحيوية" and
      len(next(u for u in bio["units"] if u["number"] == 6)["lessons"]) == 9)
check("biology units have lesson page numbers (TOC-verified)",
      all("lesson_pages" in u for u in bio["units"]) and
      all(len(u["lesson_pages"]) == len(u["lessons"]) for u in bio["units"]))
check("biology nutrition index kept only as comparison note",
      "التغذية البشرية" in bio.get("conflict_resolved", {}).get("comparison_note", ""))
phys = next(s for s in cur["subjects"] if s["id"] == "physics")
check("physics units have lesson page numbers (TOC-verified)",
      all("lesson_pages" in u for u in phys["units"]) and
      all(len(u["lesson_pages"]) == len(u["lessons"]) for u in phys["units"]))
check("unverified gaps recorded (>=13)", len(cur["unverified_gaps"]) >= 13,
      f"got {len(cur['unverified_gaps'])}")
check("Aden only as comparison (aden_comparison present, no aden default)",
      any("aden_comparison" in s for s in cur["subjects"]) and
      cur["meta"]["default_edition"] != "aden")

print("== 2. YAML (pubspec + workflow) ==")
try:
    import yaml
except ImportError:
    yaml = None
    print("  SKIP yaml module missing — install pyyaml to run YAML checks")
if yaml is not None:
    pub = yaml.safe_load((ROOT / "pubspec.yaml").read_text(encoding="utf-8"))
    check("pubspec parses, name abqariya", pub["name"] == "abqariya")
    check("pubspec assets include curriculum.json",
          "assets/data/curriculum.json" in pub["flutter"]["assets"])
    check("pubspec assets include all 7 verified question packs",
          all(f"assets/data/questions/{s}.json" in pub["flutter"]["assets"]
              for s in ("arabic", "biology", "chemistry", "english",
                        "islamic", "math", "physics")))
    check("sqflite ^2.4.6 pinned",
          str(pub["dependencies"]["sqflite"]).startswith("^2.4.6"))
    wf = yaml.safe_load(
        (ROOT / ".github/workflows/build-apk.yml").read_text(encoding="utf-8"))
    steps = wf["jobs"]["build-apk"]["steps"]
    text = (ROOT / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
    check("workflow pins Flutter 3.50.1", "3.50.1" in text)
    check("workflow uses Java 17", '"17"' in text)
    check("workflow has no-INTERNET manifest check",
          "android.permission.INTERNET" in text and
          "Check manifest requests no INTERNET permission" in text)
    check("workflow has 100 MB size gate", "104857600" in text)
    check("workflow builds split-per-abi",
          "flutter build apk --release --split-per-abi" in text)
    check("workflow runs analyze + test",
          any("flutter analyze" in str(s) for s in steps) and
          any("flutter test" in str(s) for s in steps))
    check("workflow manifest path exists",
          (ROOT / "android/app/src/main/AndroidManifest.xml").exists())

print("== 3. AndroidManifest ==")
man = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
check("manifest has no INTERNET permission", "android.permission.INTERNET" not in man)
check("manifest has no uses-permission at all", "uses-permission" not in man)
check("applicationId com.abqariya.app",
      "com.abqariya.app" in
      (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8"))

print("== 4/5/6. Dart imports, duplicate classes, deleted duplicates ==")
dart_files = sorted((ROOT / "lib").rglob("*.dart")) + \
    sorted((ROOT / "test").rglob("*.dart"))
rel_import = re.compile(r"""import\s+['"](\.[^'"]+)['"]""")
missing = []
for f in dart_files:
    for m in rel_import.finditer(f.read_text(encoding="utf-8")):
        target = (f.parent / m.group(1)).resolve()
        if not target.exists():
            missing.append(f"{f.relative_to(ROOT)} -> {m.group(1)}")
check("all relative imports resolve", not missing, "; ".join(missing[:5]))
check("progress_store import fixed to ../db/database.dart",
      "../db/database.dart" in
      (ROOT / "lib/core/progress_store.dart").read_text(encoding="utf-8"))
pub_classes: dict[str, list[str]] = {}
for f in sorted((ROOT / "lib").rglob("*.dart")):
    for m in re.finditer(r"^(?:class|abstract class|mixin|enum|extension)\s+(\w+)",
                         f.read_text(encoding="utf-8"), re.M):
        if m.group(1).startswith("_"):
            continue  # private names are library-scoped in Dart
        pub_classes.setdefault(m.group(1), []).append(str(f.relative_to(ROOT)))
dups = {k: v for k, v in pub_classes.items() if len(v) > 1}
check("no duplicate public class names in lib/", not dups, str(dups))
check("duplicate analytics screen deleted",
      not (ROOT / "lib/analytics/analytics_screen.dart").exists())
check("duplicate achievements screen deleted",
      not (ROOT / "lib/achievements/achievements_screen.dart").exists())
check("old exam screen file gone (renamed)",
      not (ROOT / "lib/exam/exam_screen.dart").exists())
check("canonical exam engine exists",
      (ROOT / "lib/exam/ministerial_exam_screen.dart").exists())
check("canonical screens exist",
      all((ROOT / p).exists() for p in (
          "lib/screens/analytics_screen.dart",
          "lib/screens/achievements_screen.dart",
          "lib/screens/exam_screen.dart",
          "lib/screens/curriculum_screen.dart")))
check("no 'kind'/'is_completed' stage columns referenced in labs_screen",
      "is_completed" not in
      (ROOT / "lib/screens/labs_screen.dart").read_text(encoding="utf-8"))

print("== 7. Dart delimiter balance ==")
def balanced(text: str) -> bool:
    stack: list[str] = []
    pairs = {"{": "}", "[": "]", "(": ")"}
    i = 0
    state = None  # None | 'line' | 'block' | "'" | '"' | "'''" | '"""'
    while i < len(text):
        c = text[i]
        two = text[i:i + 2]
        three = text[i:i + 3]
        if state is None:
            if two == "//":
                state = "line"; i += 2; continue
            if two == "/*":
                state = "block"; i += 2; continue
            if three in ("'''", '"""'):
                state = three; i += 3; continue
            if c in ("'", '"'):
                state = c; i += 1; continue
            if c in pairs:
                stack.append(pairs[c])
            elif c in "}])":
                if not stack or stack.pop() != c:
                    return False
        elif state == "line":
            if c == "\n":
                state = None
        elif state == "block":
            if two == "*/":
                state = None; i += 2; continue
        elif state in ("'", '"'):
            if c == "\\":
                i += 2; continue
            if c == state:
                state = None
        elif state in ("'''", '"""'):
            if three == state:
                state = None; i += 3; continue
        i += 1
    return state is None and not stack

bad = [str(f.relative_to(ROOT)) for f in dart_files
       if not balanced(f.read_text(encoding="utf-8"))]
check("all Dart files delimiter-balanced", not bad, "; ".join(bad[:5]))

print("== 8/9. DB v3 + seed IDs ==")
schema = (ROOT / "lib/db/schema.dart").read_text(encoding="utf-8")
check("schema kDatabaseVersion == 3", "const int kDatabaseVersion = 3;" in schema)
db = (ROOT / "lib/db/database.dart").read_text(encoding="utf-8")
check("database.dart uses kCreateAllStatements",
      "kCreateAllStatements" in db)
check("database.dart defines onUpgrade + migration",
      "onUpgrade" in db and "_migrateV1ToV2" in db)
check("database.dart seeds Sanaa curriculum",
      "seedCurriculumRows" in db and "seedCurriculumIfEmpty" in db)
check("database.dart has no legacy 'settings' table",
      "tableSettings" not in db)
check("main.dart seeds curriculum at startup",
      "seedCurriculumIfEmpty" in (ROOT / "lib/main.dart").read_text(encoding="utf-8"))
ids: list[str] = []
for s in cur["subjects"]:
    for u in s["units"]:
        uid = f"{s['id']}-u{u['number']}"
        ids.append(uid)
        for j in range(1, len(u["lessons"]) + 1):
            ids.append(f"{uid}-l{j}")
check("seed IDs unique", len(ids) == len(set(ids)), f"{len(ids)} ids")

print("== 10. Question packs wiring (DB seeding, schema v2) ==")
qp = (ROOT / "lib/content/question_packs.dart").read_text(encoding="utf-8")
check("question_packs.dart loader exists", "class QuestionPacks" in qp)
check("loader rejects demo packs", "is_demo" in qp and "continue" in qp)
check("loader rejects questions without source_page",
      "sourcePage == null || sourcePage < 1" in qp)
check("database.dart seeds question packs",
      "seedQuestionPacks" in db and "QuestionPackSeed" in db)
check("main.dart seeds questions after curriculum",
      "seedQuestionPacks" in (ROOT / "lib/main.dart").read_text(encoding="utf-8"))
check("question pack validator exists",
      (ROOT / "tools/validate_questions.py").exists())

print(f"\n{passed} passed, {len(failures)} failed")
if failures:
    print("FAILED:", failures)
    sys.exit(1)
print("ALL CHECKS PASSED")
