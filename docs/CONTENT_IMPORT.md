# ABQARIYA — CONTENT IMPORT | استيراد المحتوى

> **Status:** Phase 0 design document, 2026-11-25.
> **The blocker this document works around:** the Yemeni textbooks have
> **not** been provided. No real curriculum content exists in this
> project yet, and none may be invented. This document defines the
> complete system so that, the day the books arrive, a teacher/curator
> can turn them into importable packs — and so the demo set can be
> validated by the exact same code path.
>
> **The rule, in one sentence:** a question without a source and a page
> number does not enter the database — the importer rejects it, and the
> app would rather show «قيد الإعداد» than a made-up question.

---

## 1. Roles

| Role | Who | What they do |
|---|---|---|
| **Curator** (teacher / family member) | A human with the textbook in hand | Reads the book, writes the JSON pack (or fills the template), checks every question against the book page, signs the pack with the book citation. |
| **Importer** (`lib/content/importer.dart`) | Code | Validates the JSON against the schema + the rules in §4, then inserts it in one transaction — or rejects it entirely. It never edits content, never guesses a page, never "fixes" a wrong answer. |
| **Learner** | The user's sister | Never sees the import flow. She sees worlds, lessons and questions — or «قيد الإعداد» where content does not exist yet. |

There is **no in-app question editor in v1** and no AI generation of
questions. A curator edits a JSON file on a computer; the file is
imported as a whole. This is deliberate: an editor inside the app would
let a typo become "curriculum" with one tap, and an AI generator would
violate the content-honesty rule by construction.

---

## 2. The pack format

* **One pack = one JSON file**, format `abqariya-content-pack`,
  `version: 1` (see `assets/schema/content_schema.json`).
* **Schema:** JSON Schema draft 2020-12, file
  `assets/schema/content_schema.json`. It is the machine-readable
  contract; this document is the human-readable one. Where they disagree,
  the **stricter** reading wins and the importer must be fixed to match.
* **Contents of a pack:** `pack` (metadata) + `subjects` + `units` +
  `lessons` + `questions`. All four arrays may be present; `subjects`
  and `questions` are required (a pack with zero questions is valid —
  it is how a "structure only" pack is shipped — but it changes nothing
  for the learner until questions arrive).
* **IDs:** stable kebab-case TEXT (`physics`, `physics-u03`,
  `physics-u03-l02`, `physics-u03-l02-q07`). Re-importing the same pack
  upserts on `id` (INSERT OR REPLACE on content tables) — it never
  duplicates. **Never reuse an id for different content.**
* **Language:** `question_text`, `options`, `explanation` are Arabic,
  except inside the English world, where they are English (with Arabic
  explanations allowed — the explanation may be bilingual; the question
  itself follows the subject's language).
* **Text only.** `media_ref` MUST be `null` in v1. Diagrams are drawn
  procedurally in code; a pack never carries image/audio/video files.
  A pack that references media is rejected.

### 2.1 Provenance fields (required on EVERY row)

| Field | Rule |
|---|---|
| `source` | Non-empty string. Real pack: full book citation, e.g. «كتاب الفيزياء — الصف الثالث الثانوي العلمي، الجمهورية اليمنية، طبعة 2024». Demo pack: exactly `demo — not Yemeni curriculum`. |
| `source_page` | Page in the source book (integer ≥ 1). **Required for every question, unit and lesson in a non-demo pack.** `null` is allowed **only** in demo packs. |
| `source_detail` | Optional, e.g. «التمرين 3، السؤال 2» / «مثال محلول ص 41». |
| `pack.is_demo` | `true` only for the demo set. A pack with `is_demo: false` and a demo source string is rejected; a pack with `is_demo: true` and a real-book source is rejected. |

### 2.2 Question fields

| Field | Rule |
|---|---|
| `id`, `type`, `subject_id`, `unit_id`, `lesson_id` | Required. `type` ∈ `mcq`, `true_false`, `fill_blank`, `match`, `ordering`, `equation`. |
| `difficulty` | Required, 1–3 (1 = تذكّر/فهم، 2 = تطبيق، 3 = تحليل/تركيب), set by the curator against the book. |
| `question_text` | Required, 1–2000 chars. |
| `options` + `correct_option_index` | Required for `mcq` (2–6 options, exactly one correct, index in range). Forbidden to leave `correct_option_index` out "for later". |
| `correct_answer` | Required for `true_false` (`صح` / `خطأ`), `fill_blank`, `equation`. For `mcq` it must be absent or equal to `options[correct_option_index]`. |
| `explanation` | **Required, always.** Why the answer is correct, grounded in the source. Shown after every answer. A question without an explanation is rejected. |
| `time_limit_seconds` | Optional, 5–300. If absent, the mode default applies (GAME_DESIGN.md §2). |
| `tags` | Optional, ≤ 10 short tags, used for analytics grouping only. |

### 2.3 The `<unit>-review` lesson convention

Unit-level, boss and exam questions still need a `lesson_id` (the DB
column is NOT NULL by design — a question that belongs nowhere is a
data bug). Every pack must therefore define, for each unit, a synthetic
review lesson with id `<unit_id>-review` (e.g. `physics-u03-review`,
title «مراجعة الوحدة»). Boss/exam questions point at it. The lesson
carries the unit's source and first page.

---

## 3. How a curator adds a Yemeni textbook (step by step)

1. **Get the book.** Physical book or a PDF the user lawfully holds.
   Note its exact title, edition/year, and the ministry/curriculum year.
2. **Copy the template.** Start from `assets/data/demo_questions.json`
   (structure) — or from an empty pack the importer agent provides —
   and replace every demo row. Do not edit the demo file itself.
3. **Map the structure first:** subjects (the 7 worlds already exist as
   ids: `maths`, `physics`, `chemistry`, `biology`, `arabic`,
   `english`, `islamic`) → units (one per chapter, in book order,
   `sort_order` 1, 2, 3…) → lessons (one per lesson, in order) →
   a `<unit>-review` lesson per unit.
4. **Write questions lesson by lesson**, with the book open: each
   question's `source_page` is the page where its topic is taught, and
   `source_detail` names the exercise/example when there is one.
   Write the explanation in your own words from the book — or quote
   the book briefly and mark it as a quotation in `source_detail`.
5. **Validate locally** (§4.3) before handing the file over. Fix every
   error the validator reports; the importer will reject the same file
   for the same reasons.
6. **Hand over the JSON file** (USB / file share / bundled into the
   next APK release as an asset — the delivery channel is the user's
   choice; the app never downloads it).
7. **Import** (§5). The app reports: pack id, counts imported, and any
   rejection reason. A failed import changes nothing.
8. **Spot-check in the app:** open the new unit, play one `quiz` stage,
   read two explanations, check the source line shown under a question
   («المصدر: كتاب الفيزياء … ص 41»). If the source line is wrong, the
   pack is wrong — fix the JSON and re-import (upsert by id).

### 3.1 Quality bar for a question (curator's checklist)

* [ ] The question is answerable from the named page(s) of the book.
* [ ] The correct answer is unambiguous; the distractors are plausible
  but clearly wrong to someone who studied the page.
* [ ] The explanation teaches — it does not just repeat the answer.
* [ ] No invented numbers, dates, names or "facts" that are not in the
  book. If the book does not say it, the question does not say it.
* [ ] Language matches the subject (Arabic, except the English world).
* [ ] `difficulty` reflects the book's own demand, not the curator's
  guess about the learner.

---

## 4. Validation rules (what the importer enforces)

Validation happens in two layers; **both** must pass.

### 4.1 Layer 1 — JSON Schema (`assets/schema/content_schema.json`)

Types, required fields, string lengths, enum values, id pattern
(`^[a-z0-9][a-z0-9-]{0,63}$`), `format`/`version` constants. Run with
any draft-2020-12 validator. The demo pack passes it (verified
2026-11-25 with Python `jsonschema` — see §7).

### 4.2 Layer 2 — Importer rules (cannot be expressed in JSON Schema)

The importer (`lib/content/importer.dart`) rejects the pack if ANY of
these fail — the whole pack, not just the bad row:

1. `pack.is_demo` is consistent with every row's `source`
   (demo ⇔ source is exactly `demo — not Yemeni curriculum`).
2. Non-demo pack: every question, unit and lesson has
   `source_page >= 1`. (Demo pack: `source_page` must be `null`.)
3. Non-demo pack: `pack.curriculum_year` is present and non-empty.
4. Every `subject_id` / `unit_id` / `lesson_id` referenced by a
   question, unit or lesson exists in the same pack (or already in the
   DB — cross-pack references are allowed only to subjects/units/
   lessons already imported).
5. No duplicate `id` inside one array; no duplicate question text
   within the same lesson (exact match after normalisation).
6. `mcq`: `options` has 2–6 items, no duplicate options (after
   normalisation), `correct_option_index` in range.
7. `true_false`: `correct_answer` is exactly `صح` or `خطأ`.
8. Every question has a non-empty `explanation`.
9. `media_ref` is `null` everywhere.
10. Pack size: ≤ 20,000 questions per file (a larger book is split
    into two packs by unit). File size ≤ 10 MB.
11. No `id` collides with a row of a different pack that has a
    different `source` (same id + different source = a data conflict;
    the curator must rename or correct the source).
12. `sort_order` values within a unit's lessons (and a subject's units)
    are unique — ordering must be explicit, never accidental.

### 4.3 How to validate locally (before import)

```bash
# 1. JSON is well-formed
python3 -m json.tool my-pack.json > /dev/null && echo JSON_OK

# 2. Schema validation (needs: pip install jsonschema)
python3 -m jsonschema -i my-pack.json assets/schema/content_schema.json

# 3. Importer rules 1–12 need the Dart importer; until it exists, check
#    rules 2, 5, 6, 7, 8 by eye + a small script. The CI test suite
#    (test/importer_test.dart) covers all 12 rules against good and bad
#    fixture packs, including "rejects a pack without source_page" and
#    "rejects a pack that mixes demo source with is_demo=false".
```

---

## 5. Import flow (in the app)

```
JSON file ──> read text ──> jsonDecode ──> Layer 1 schema check
   (bundled asset, or a file the user picks — v1: asset only;
    file-picker import is post-v1 and adds path_provider + file_picker)
        │  fail → show the error, import nothing
        ▼
   Layer 2 importer rules (§4.2)
        │  fail → show the FIRST failing rule in Arabic, import nothing
        ▼
   db.transaction():
       INSERT OR REPLACE subjects / units / lessons / stages
       INSERT OR REPLACE questions   (search_text normalised here)
       INSERT content_packs row (status='imported', file_sha256)
       -- stages: the importer creates the lesson's stage rows from a
       -- fixed stage template (quiz first, then the modes whose
       -- renderers exist and whose question types the lesson has).
       -- If a question type has no renderer yet, that mode's stage is
       -- simply not created for the lesson (honest absence, §GAME_DESIGN).
   commit
        ▼
   Report: "تم استيراد حزمة «…»: 7 وحدات، 42 درساً، 318 سؤالاً"
   + demo pack is hidden from the learning home (app_meta.demo_visible=0)
```

* **Atomicity:** one transaction; any failure rolls everything back.
  The DB never holds half a pack.
* **Idempotency:** re-importing the same file (same SHA-256) is detected
  via `content_packs.file_sha256` and skipped with «هذه الحزمة مستوردة
  بالفعل». Re-importing a *corrected* file upserts by id.
* **Deletion:** there is no per-question delete in v1. Removing a pack
  means deleting its rows (curator's corrected re-import with the rows
  removed, or a full "reset content" in Settings that keeps attempts
  only for questions that still exist — attempts referencing deleted
  questions are kept for history but excluded from analytics).
* **Demo pack:** imported on first run through this same pipeline, from
  the bundled asset. It is the importer's first live test on every
  install. Its `content_packs` row has `is_demo = 1`.

### 5.1 Exam-paper composition

A ministerial-exam simulation draws from imported questions only.
The pack may declare an exam definition (post-v1 schema extension):
subject mix, question counts per unit, time limit. Until that extension
lands, the exam draws proportionally to each unit's question count
(≥ 5 questions per included unit, units with < 5 questions excluded
and named on the exam screen). **An exam never includes a question
whose source is not a real book, and never includes demo questions.**

---

## 6. DB versioning / migration plan

* `lib/db/schema.dart`: `kDatabaseVersion = 2` (2026-11-25, merge pass).

> **استثناء v1 -> v2 الوحيد (2026-11-25):** جداول v1 لم تكن المخطط
> الرسمي أصلاً — كانت تنفيذاً مبسّطاً متعارضاً (أعمدة مختلفة كلياً:
> subjects بلا name_ar، وأسئلة stage_id/stem/options، وجدول settings
> بدل app_meta) كُتب بالتوازي قبل توحيد المخطط، ولم تُشحن على أي
> جهاز. لذلك ترقية v1 -> v2 في `lib/db/database.dart` (`_migrateV1ToV2`)
> **تعيد بناء الجداول** (DROP للجداول القديمة بعد نسخ بياناتها، ثم
> إنشاء المخطط الرسمي)، مع حفظ الإعدادات وإجماليات اللاعب والإنجازات،
> وتجميع المحاولات القديمة في عدّادات بدل إسقاطها بصمت. هذا استثناء
> موثّق لمرة واحدة بسبب عدم شحن v1؛ **ابتداءً من v2 تسري القاعدة 1
> (إضافي فقط) بلا استثناء**، وأي ترقية مستقبلية تتبع القواعد أدناه.
* **Rule 1 — additive only.** A migration may `ALTER TABLE … ADD COLUMN`
  (with a default), create a table, or create an index. It may never
  `DROP` a user-data table, never rename a column by dropping it, and
  never delete rows to "make room".
* **Rule 2 — one block per version, ascending.**
  ```dart
  onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) { /* v2 changes */ }
    if (oldVersion < 3) { /* v3 changes */ }
  }
  ```
  A user jumping from v1 to v3 runs both blocks, in order.
* **Rule 3 — content is not migrated, it is re-imported.** Schema
  changes never rewrite question text. If a new schema version needs a
  new column on `questions` (e.g. `exam_weight`), the migration adds the
  column with a safe default and the next pack import fills it.
* **Rule 4 — version bump checklist:** bump `kDatabaseVersion`, add the
  `onUpgrade` block, add a test that opens a v1 database (fixture),
  runs the upgrade, and asserts old rows survive with correct defaults,
  and note the change in this document's changelog (§8).
* **Rule 5 — the demo pack is version-proof:** it is re-validated
  against the current schema on every first run after an upgrade; if
  it fails, the app keeps the old DB untouched and reports the error
  instead of silently dropping content.

### Changelog

| DB version | Date | Change |
|---|---|---|
| 1 | 2026-11-25 | Initial schema: 12 tables (see `lib/db/schema.dart`). |
| 2 | 2026-11-25 | Merge pass: canonical `DatabaseHelper` now implements `schema.dart` (the divergent simplified v1 implementation was removed); v1 -> v2 rebuild migration preserving settings, player totals and unlocked achievements, attempts aggregated into counters; Sanaa 2027 curriculum structure seed (`seedCurriculumRows`). |

---

## 7. Worked example — one demo question, end to end

From `assets/data/demo_questions.json` (the only content that exists
today). This is the exact shape a real question must follow — only the
source changes.

```json
{
  "id": "demo-physics-q01",
  "type": "mcq",
  "subject_id": "physics",
  "unit_id": "physics-demo-u01",
  "lesson_id": "physics-demo-l01",
  "difficulty": 1,
  "question_text": "جسم كتلته 2 كغ يتحرك بتسارع 3 م/ث². ما مقدار القوة المؤثرة فيه؟",
  "options": ["3 نيوتن", "6 نيوتن", "5 نيوتن", "12 نيوتن"],
  "correct_option_index": 1,
  "explanation": "قانون نيوتن الثاني: القوة = الكتلة × التسارع = 2 × 3 = 6 نيوتن.",
  "time_limit_seconds": 60,
  "tags": ["نيوتن"],
  "source": "demo — not Yemeni curriculum",
  "source_page": null
}
```

* **Layer 1 (schema):** `type` is a valid enum, `difficulty` 1–3,
  `options` has 4 items, `correct_option_index` 1 is in range,
  `explanation` non-empty, `source` non-empty → passes.
* **Layer 2 (importer):** pack `is_demo` is `true` and the source is
  exactly the demo string → consistent; `source_page` is `null`, allowed
  only because the pack is a demo pack; `subject_id`/`unit_id`/
  `lesson_id` all exist in the same file → passes.
* **DB row:** inserted into `questions` with `is_demo = 1`,
  `search_text` = normalised question + options + explanation
  (diacritics stripped, أ→ا, ة→ه), `options_json` =
  `["3 نيوتن","6 نيوتن","5 نيوتن","12 نيوتن"]`.
* **In the app:** the question appears only inside the demo area, under
  the badge «تجريبي — ليس من المنهج», with the source line shown under
  the explanation. Its attempts never enter curriculum analytics.
* **The same question as real curriculum** would differ in exactly
  three fields: `id` (e.g. `physics-u02-l03-q04`), `source`
  («كتاب الفيزياء — الصف الثالث الثانوي العلمي، الجمهورية اليمنية،
  طبعة 2024»), and `source_page` (e.g. `41`) — plus
  `pack.is_demo: false` and a `curriculum_year`. Everything else is
  identical. That is the whole point of the demo: it proves the
  pipeline with content that cannot be mistaken for curriculum.

---

## 8. What the curator needs from the user (blockers)

1. **The textbooks** (or lawful PDFs): 3rd secondary scientific,
   Yemen — maths, physics, chemistry, biology, Arabic, English,
   Islamic. Without them, no real pack can be written. This is the
   project's top blocker, not a detail.
2. **Edition/year confirmation** for the citation string (which
   printing the learner actually studies from).
3. **A decision on delivery:** will packs be bundled into APK releases
   (simplest, fully offline) or side-loaded as files (faster updates,
   needs the file-picker import in post-v1)? Recommendation: **bundle
   into APK releases in v1** — one artefact, one version, nothing to
   lose or misplace.
