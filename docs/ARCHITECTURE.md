# ABQARIYA — ARCHITECTURE | البنية المعمارية

> **Status:** Phase 0 design document, 2026-11-25.
> **What was NOT run:** no Flutter/Dart SDK exists in this environment.
> `flutter analyze`, `flutter test`, `flutter build apk` were **not** run.
> Nothing in this document claims a build or test succeeded. The first real
> verification is the GitHub Actions CI build (§8).
>
> **Hard rules (never violate):** 100% offline · no accounts · no ads ·
> no external servers · no cloud AI · **no `INTERNET` permission** ·
> APK ≤ 100 MB · Arabic RTL · content only from Yemeni textbooks once
> supplied — until then the question bank is **empty except the labelled
> demo set** (see `docs/CONTENT_IMPORT.md`).

---

## 1. Product in one paragraph

**عبقرية | ABQARIYA** — «افهم، جرّب، اكتشف، وتفوّق» — is a free, offline,
no-ads Flutter Android educational-games platform for one learner: the
user's sister, 3rd secondary scientific (Yemen). Seven worlds (maths,
physics, chemistry, biology, Arabic, English, Islamic), interactive
science labs, 12 mini-game modes, local smart analytics, and a
ministerial-exam simulation. There is no server. There is no account.
All state lives in one local SQLite database on the device.

---

## 2. Technology stack — verified versions (2026-11-25)

Verified by web search on pub.dev / release pages on 2026-11-25.
Re-check with `flutter pub outdated` at build time; pin in `pubspec.yaml`
and commit `pubspec.lock`.

| Component | Chosen version | Source / note |
|---|---|---|
| Flutter (stable) | **3.50.1** (20 Nov 2026) | Latest stable; 3.50.0 released 11 Nov 2026. Bundles Dart 3.14.0, DevTools 2.61.0. |
| Dart SDK | **3.14.0** (bundled) | `sdk: ^3.14.0` in `pubspec.yaml`. |
| sqflite | **^2.4.6** | Latest on pub.dev, published 10 Nov 2026; 160 pub points, analysed with Flutter 3.50.0 / Dart 3.14.0. Fallback if the resolver disagrees: `^2.4.5+1` (the version on pub.dev's score page on 2026-11-25). Requires `sqflite_android` 2.4.6 / `sqflite_common` 2.5.17 (resolved transitively). |
| path | **^1.9.1** | Required by sqflite for `join(getDatabasesPath(), ...)`. |
| path_provider | **NOT used in v1** | See §2.1 — sqflite exposes `getDatabasesPath()` itself; no other file path is needed in v1. Latest would be 2.1.6. |
| shared_preferences | **NOT used — deliberately** | See §2.1. Latest would be 2.5.6. All settings live in SQLite (`app_meta` table). |
| flame (2D game engine) | **^1.38.2** (optional, v1) | Latest stable Oct 2026, 160 pub points, needs Flutter ≥ 3.41. **Do NOT use 2.0.0-dev.1** (prerelease). See §6: Flame is the fallback, not the default. |
| flutter_3d / model_viewer_plus / flutter_3d_controller | **NOT used in v1** | See §6 comparison. |
| flutter_lints | `^6.0.0` (check at `flutter create` time) | Keep lints on; CI runs `flutter analyze` with zero-tolerance for errors. |
| sqflite_common_ffi (dev) | latest at build time | Dev-only, for `flutter test` on the Dart VM (sqflite needs the FFI factory in tests). |

### 2.1 Why no `shared_preferences` and no `path_provider`

* **One store, one truth.** Settings (dark mode, sound, demo visibility,
  onboarding) + content + progress all live in `abqariya.db`. Two stores
  can diverge (e.g. progress reset but a flag survives); one store makes
  "reset everything" a single transaction and makes backup/restore trivial.
* **sqflite already gives us the path.** `getDatabasesPath()` is part of
  sqflite; `path_provider` would add a plugin (and its platform code) to
  answer a question we never ask in v1. Content import in v1 reads a
  bundled asset or a file the user picks — the file-picker step, if added,
  is the moment to add `path_provider` + `file_picker`, not before.
* **Cost:** one extra plugin each is small, but every plugin is a CI
  risk, an Android-manifest surface, and a future breaking change. The
  rule for v1 is: **no dependency without a feature that needs it.**

### 2.2 Flutter 3.50 compatibility note (important)

Flutter 3.50 formally **deprecates the bundled `package:flutter/material.dart`
and `package:flutter/cupertino.dart`** in favour of the standalone
`material_ui` / `cupertino_ui` packages (1.x, released independently since
3.47), and `flutter create` now imports `material_ui` by default. This
affects the skeleton agent directly:

* Generate the project with Flutter 3.50.1 and follow what `flutter create`
  produces — do **not** fight the template back to `material.dart`.
* sqflite 2.4.6, Flame 1.38.2 and the other chosen packages were analysed
  against Flutter 3.50.0 / Dart 3.14.0, so they are compatible with the
  3.50 line — but re-verify with `flutter pub get` + `flutter analyze` in
  CI; if a package has not yet migrated off `material.dart`, pin the newest
  version that has, or drop it.
* `minSdk`: 21 (Android 5.0) is the Flutter default and keeps mid-range /
  older Yemeni-market devices in scope. Do **not** raise it for a 3D
  package (model_viewer_plus demands 24 — one more reason it is rejected,
  §6). `targetSdk`: whatever Flutter 3.50.1's template sets (35/36);
  do not lower it.

### 2.3 Android manifest — no-internet policy

`AndroidManifest.xml` MUST contain **no** `INTERNET` permission, no
`ACCESS_NETWORK_STATE`, no `FOREGROUND_SERVICE`, no deep links, no
`queries` entries. CI greps the merged manifest for `INTERNET` and fails
the build if it appears (see §8). Consequences, accepted deliberately:

* No `webview_flutter` anywhere (it is the usual way `INTERNET` sneaks
  in, and it is also how model_viewer_plus works — §6).
* No crash reporting, no analytics SDK, no update check. Updates arrive
  only as a new APK the user installs herself.
* System TTS (`flutter_tts`) is the only audio path in v1 and it is
  **optional / deferred** — it needs no permission, but it is not in the
  v1 dependency list until the games agent needs spoken questions.
  No audio files ship in v1 (see `docs/SIZE_BUDGET.md`).

---

## 3. Layered architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ UI layer (Flutter widgets, Material 3, RTL, dark mode)          │
│  screens: home / world map / unit / lesson / stage / exam /     │
│  review / analytics / achievements / settings / about           │
│  widgets: question cards, timers, stars, XP bar, charts         │
├─────────────────────────────────────────────────────────────────┤
│ Game engine layer (pure Dart, no Flutter import where possible) │
│  session runner · scoring · timers · gating · XP/stars ·        │
│  boss & exam orchestration · spaced-repetition scheduler (SM-2) │
├─────────────────────────────────────────────────────────────────┤
│ Labs layer (procedural graphics only — CustomPainter)           │
│  maths plotter · physics sims · chemistry balancer · biology    │
│  diagrams — all drawn in code, zero image/GLB/video assets      │
├─────────────────────────────────────────────────────────────────┤
│ Analytics layer (pure Dart, local only)                         │
│  mastery % · strength/weakness · time-per-question · review plan│
│  — estimates, NEVER a prediction of the ministerial result      │
├─────────────────────────────────────────────────────────────────┤
│ Data layer (sqflite, single DB file abqariya.db)                │
│  repositories: content / attempts / progress / review / exams   │
│  importer: JSON pack -> validated rows (one transaction)        │
└─────────────────────────────────────────────────────────────────┘
```

**Dependency rule:** UI depends on game engine, labs and analytics;
game engine / labs / analytics depend only on the data layer's
repositories (interfaces); the data layer depends on nothing above it.
Pure-Dart logic (scoring, SM-2, mastery, chemistry balancing) lives in
files with **no `flutter` import** so it can be unit-tested on the Dart VM
with `sqflite_common_ffi` and, in parallel, re-implemented/verified in
Python by the games agent. Widgets never run SQL directly.

### 3.1 Folder structure (target)

```
abqariya/
├── android/                  # generated by flutter create; manifest edited per §2.3
├── assets/
│   ├── data/demo_questions.json        # 14 demo Qs ONLY (labelled, not curriculum)
│   └── schema/content_schema.json      # JSON Schema for content packs
├── docs/
│   ├── ARCHITECTURE.md      # this file
│   ├── CONTENT_IMPORT.md
│   ├── GAME_DESIGN.md
│   └── SIZE_BUDGET.md
├── lib/
│   ├── main.dart
│   ├── app.dart              # MaterialApp, theme (dark/light), RTL, routes
│   ├── config/theme.dart     # colours, typography (modern scientific, not childish)
│   ├── db/
│   │   ├── schema.dart       # CREATE TABLE constants (Phase 0, done)
│   │   ├── database.dart     # AppDatabase: open, onCreate, onUpgrade
│   │   └── repositories.dart # Content/Attempt/Progress/Review/Exam repos
│   ├── content/
│   │   ├── importer.dart     # JSON pack validation + transactional import
│   │   ├── normalizer.dart   # Arabic search-text normalisation (no FTS5, §5.4)
│   │   └── demo_pack.dart    # loads assets/data/demo_questions.json via importer
│   ├── game/
│   │   ├── session.dart      # session runner, timers
│   │   ├── scoring.dart      # XP/stars (pure Dart)
│   │   ├── gating.dart       # unlock rules (pure Dart)
│   │   └── spaced_repetition.dart  # simplified SM-2 (pure Dart)
│   ├── labs/                 # procedural CustomPainter labs (owned by labs agent)
│   │   ├── maths_plotter.dart
│   │   ├── physics_lab.dart
│   │   ├── chemistry_lab.dart
│   │   └── biology_lab.dart
│   ├── analytics/
│   │   └── analytics.dart    # mastery, strengths/weaknesses (pure Dart)
│   ├── ui/
│   │   ├── screens/          # home, world_map, unit, lesson, stage, exam,
│   │   │                     # review, analytics, achievements, settings
│   │   └── widgets/          # question_card, timer_ring, stars_row, xp_bar
│   └── l10n/                 # Arabic strings (single source; English UI strings
│                             # for English-world content live in the DB, not here)
├── test/
│   ├── scoring_test.dart
│   ├── spaced_repetition_test.dart
│   ├── gating_test.dart
│   ├── importer_test.dart    # incl. "rejects a pack without source_page"
│   └── widget_test.dart      # smoke: app boots, empty states render
└── .github/workflows/android.yml   # CI: analyze + test + release APK
```

---

## 4. Progression model

```
World (subject, 1 of 7)
  └─ Unit (chapter of the book)
       └─ Lesson (one lesson of the book)
            └─ Stage (one game mode played on that lesson's questions)
                 └─ Boss (20 questions, whole unit, unlocks the next unit)
```

| Level | What it is | Source of truth |
|---|---|---|
| World | A subject: maths, physics, chemistry, biology, Arabic, English, Islamic. | `subjects` table |
| Unit | A chapter of the Yemeni textbook (once imported). | `units` table |
| Lesson | One lesson inside a unit. | `lessons` table |
| Stage | A lesson played in one of the 12 modes (§5, GAME_DESIGN.md). | `stages` table |
| Boss | 20 mixed questions from the whole unit, timed. | `stages` row with `mode='boss'`, `exam_results` row with `exam_type='boss'` |

### 4.1 Gating rules (enforced in `game/gating.dart`, never only in UI)

1. **Units are sequential within a world.** Unit *n+1* unlocks when unit *n*
   is complete (boss passed). Units of different worlds are independent —
   the learner can do physics unit 1 and maths unit 1 in any order.
2. **Lessons are sequential within a unit.** Lesson *n+1* unlocks when
   lesson *n* has ≥ 1 star in any stage.
3. **Stages within a lesson unlock in order** (the lesson's stage list is
   ordered by `sort_order`). The first stage is always `quiz` — the
   learner meets the content before the twitchy modes.
4. **Boss unlocks** when every lesson in the unit has ≥ 2 stars in at
   least one stage **and** the unit's mastery is ≥ 60% (see GAME_DESIGN
   §6 for the mastery definition). Boss pass = ≥ 70% correct in the
   20 questions.
5. **Ministerial exam** unlocks per subject when ≥ 50% of that subject's
   units are boss-passed. It is clearly labelled a **simulation** —
   it uses only imported questions, in ministerial style, and its score
   is never presented as a prediction.
6. **Nothing is ever locked behind a paywall, account or download.**
   Locked means "not yet earned", and the UI always says exactly what
   earns it ("أكمل دروس الوحدة بنجمتين لفتح الزعيم").
7. **Demo content never gates curriculum content.** Demo stars/XP are
   stored separately (`is_demo = 1` rows) and are not counted toward any
   unlock. When the first real pack is imported, demo progress is hidden
   from the home screen (kept in the DB only so the demo can still be
   replayed from Settings → "الأسئلة التجريبية").

### 4.2 XP, stars, levels

| Event | XP |
|---|---|
| Correct answer | 10 (× difficulty: ×1 / ×1.5 / ×2 → 10 / 15 / 20) |
| Correct answer in under 50% of the time limit | +5 speed bonus |
| Stage completed (any result) | +10 |
| Boss passed | +100 |
| Ministerial-exam simulation finished | +50 (participation, not score) |
| Review-queue item answered correctly | +5 |
| Daily streak (any play on a new day) | +20, once per day |

* Stars per stage (1–3): 1 star ≥ 50% correct · 2 stars ≥ 70% ·
  3 stars ≥ 90% **and** no question left unanswered. Stars never decrease.
* Levels are XP thresholds, cosmetic only, no gameplay effect:
  Level *n* needs `100 × n × (n + 1) / 2` cumulative XP
  (L1 100 · L2 300 · L3 600 · L5 1500 · L10 5500). The level name is a
  scientific title in Arabic (e.g. «مستكشفة»، «باحثة»، «عالِمة») — never
  a school grade, never a judgement of the learner.
* **Autosave:** every attempt is written to `attempts` the moment it is
  answered; stage results are committed before the result screen shows.
  If the app is killed mid-stage, answered questions are kept and the
  stage can be resumed or restarted — nothing is lost, nothing is
  double-counted (attempts are append-only; a replayed stage inserts new
  rows, it does not rewrite old ones).

---

## 5. Offline data flow

```
First run
  open abqariya.db (create v1)
    ├─ seed achievements catalogue + app_meta defaults
    └─ import demo pack via the SAME importer as real packs
         (assets/data/demo_questions.json, validated against the schema)
              └─ 7 subjects / 7 units / 7 lessons / 14 questions, all is_demo=1

Normal play (no network, ever)
  UI -> GameEngine -> Repository -> sqflite -> abqariya.db
  every answer -> attempts row -> progress upsert -> review_queue update
  (all in one transaction per answer batch; see §5.3)

Later: teacher/curator supplies a real textbook pack
  JSON file -> importer validates (schema + rules, CONTENT_IMPORT.md §4)
    -> single transaction -> content_packs row + content rows
    -> demo pack stays, but is hidden from the learning home
```

### 5.1 What is stored where

| Data | Where | Notes |
|---|---|---|
| Content (subjects/units/lessons/stages/questions) | `subjects…questions` | Imported, never typed into UI |
| Answers, XP, stars, mastery | `attempts`, `progress` | Append-only attempts; progress is a recomputable snapshot |
| Review schedule | `review_queue` | Simplified SM-2 (GAME_DESIGN §5) |
| Exam sittings | `exam_results` + linked `attempts` | Raw scores only |
| Achievements | `achievements` | Seeded catalogue; `unlocked_at` set by game engine |
| Settings | `app_meta` | dark mode, sound, demo visibility, onboarding |
| Import history | `content_packs` | One row per pack, with SHA-256 |

### 5.2 Concurrency & integrity

* Single `Database` instance (singleton in `AppDatabase`), one writer at
  a time — sqflite on Android serialises through the platform channel;
  do not open a second connection.
* `PRAGMA foreign_keys = ON` in `onConfigure` (the DDL's FKs are inert
  without it — a classic silent bug).
* Multi-table writes (import, exam finish, progress reset) always in
  `db.transaction()`. A failed import rolls back completely; the DB
  never holds half a pack.
* Autosave = write-through, not periodic: no in-memory progress that
  could be lost. The only in-memory state is the *current* session's
  transient UI state (timer display, selected option).

### 5.3 Performance budget (mid-range Android)

* Questions per query ≤ 20 (a stage/exam never loads more). Use
  `ORDER BY RANDOM()` only on the filtered set (unit/lesson), never on
  the whole table.
* Indexes on `questions(unit_id, difficulty)`, `questions(lesson_id,
  difficulty)`, `attempts(question_id)`, `review_queue(next_review_at)`
  — see `lib/db/schema.dart`.
* No images, no video, no GLB in v1 → the only heavy widget is
  CustomPainter labs, which must stay under ~16 ms/frame on a 2019
  mid-range device: cap lab animations at 60 fps, prefer static diagrams
  with small animated overlays, and never animate a full-screen repaint
  per frame.

### 5.4 Search — why there is NO FTS5 in v1

Lesson learned from the sibling PROTOCOL app (same team, same stack):
SQLite FTS5 with the default `unicode61` tokenizer treats Arabic
prefixed words as single tokens, so a search for a bare term returns
zero rows even when the content exists (verified on the shipped DB:
`MATCH 'بروتوكول'` → 37 rows, `MATCH 'الأسبقية'` → 0 rows). The fix is
not "add FTS5 and hope". v1 therefore:

* stores `questions.search_text` — question + options + explanation,
  normalised at import time (diacritics stripped, أ/إ/آ → ا, ة → ه,
  ى → ي, tatweel removed);
* searches with `WHERE search_text LIKE '%<normalised term>%'`;
* applies the **same** normalisation to the user's query;
* defers FTS5 until a proven Arabic tokenizer is tested on-device with
  the exact failure cases above. A search that silently misses is worse
  than a slower search that finds.

---

## 6. 3D / graphics decision — comparison and choice

Requirement: "interactive 3D labs/simulations" in the master prompt,
under the hard constraints APK ≤ 100 MB, 100% offline, no INTERNET
permission, mid-range Android. Three approaches were compared
(versions verified 2026-11-25):

### 6.1 Option A — Procedural Canvas / CustomPainter (+ Flame for 2D)

* **What:** every diagram, molecule, circuit, cell, graph and simulation
  is drawn in Dart code (`CustomPainter`, `Canvas`, `Path`); Flame
  1.38.2 (2D engine, 160 pub points) only where a real game loop is
  needed (aim / time-race / particle effects).
* **Size:** ~0 MB assets. Flame adds roughly 1–3 MB of Dart code to the
  APK. Total graphics cost: effectively zero.
* **Offline:** perfect — no assets, no WebView, no network, no permission.
* **Android:** pure Flutter rendering; works on minSdk 21, any GPU.
* **Limits:** no true 3D rotation; "3D" is isometric / pseudo-3D
  projection drawn by hand (which is how textbooks draw molecules and
  solids anyway). Rotation is a 2D transform of a projected model.

### 6.2 Option B — flutter_3d / model_viewer_plus with GLB

* **What:** `model_viewer_plus` **1.10.0** (last release ~Nov 2025, fork
  of the discontinued `model_viewer`) or `flutter_3d_controller` ^2.3.0
  render glTF/GLB models by embedding Google's `<model-viewer>` web
  component in a **WebView**.
* **Size:** the JS + WebView bridge is several MB; each GLB model is
  typically 0.5–5 MB, and a useful library (molecules, organs, solids)
  is tens of MB. A single detailed anatomy model can eat the whole
  graphics budget alone.
* **Offline / permission:** **fails the hard constraints.** It needs
  cleartext HTTP to `http://localhost` on Android 9+ (a
  `network_security_config.xml` exception), `minSdk 24` (cuts older
  devices), the Google app / a modern system WebView (blank screen on
  old Chrome — documented in its own FAQ), and its AR mode launches an
  external Google app. It is a web page pretending to be offline.
* **Maintenance:** `model_viewer_plus` has not had a release in ~12
  months; the upstream it forks is discontinued.
* **Verdict: rejected for v1.**

### 6.3 Option C — Pure CustomPainter vector diagrams (no engine at all)

* **What:** same drawing as A, but without Flame — timers, animations
  and hit-testing hand-rolled with `AnimationController` + `GestureDetector`.
* **Size / offline / Android:** identical to A, minus Flame's 1–3 MB.
* **Limits:** every game loop is hand-built; the aim/time-race modes get
  more boilerplate and more bug surface.
* **Verdict: the fallback if Flame fails CI** (see §6.5).

### 6.4 The new `flutter3d` engine (checked, not chosen)

`flutter3d` **1.0.0-rc.2** (Oct 2026) is a genuine from-scratch Dart 3D
engine (Impeller / `flutter_gpu`, software rasteriser fallback). Its own
docs measure a release arm64 example APK at **19.8 MiB** and a selected
shader bundle at **3.7 MB** — credible numbers, and it is the only 3D
option that is truly offline. But: it is a **release candidate**
(61 packages, breaking API changes between rc.1 and rc.2, viewer widget
only arriving in rc.3), it needs Flutter ≥ 3.44 and a build hook that
compiles shaders with the SDK's `impellerc`, and its Android story is
far less battle-tested than its desktop/web story. **Revisit after 1.0.0
stable + a successful CI build of its example on our workflow.** Not v1.

### 6.5 DECISION

> **v1 ships Option A: procedural CustomPainter first, Flame 1.38.2 only
> where a game loop is genuinely needed, no heavy 3D engine, no GLB in
> the APK.**
>
> "3D labs" in v1 means: isometric/pseudo-3D projections, exploded
> diagrams, rotatable-via-drag 2D projections, and step-through
> simulations — all code-drawn. This matches how Yemeni textbooks
> present the same objects (2D textbook figures), so nothing is lost
> pedagogically.
>
> **Fallback (if Flame fails CI):** drop Flame, fall back to Option C —
> pure CustomPainter + `AnimationController`. The labs do not depend on
> Flame, so the fallback costs a few days on the aim/time-race modes
> only, not a rewrite.
>
> **Later (post-v1, optional):** real GLB models as a **separate,
> optional downloadable pack** (side-loaded file, imported like a content
> pack, never inside the APK, never fetched by the app itself) rendered
> by `flutter3d` ≥ 1.0.0 stable — only if the model library is curated,
> its size is budgeted, and it passes the same offline/no-permission CI
> gate. The APK budget in `docs/SIZE_BUDGET.md` reserves 0 MB for this
> in v1.

---

## 7. Design & UX rules (binding on the UI agent)

* **Arabic RTL everywhere**, `Directionality rtl`, Arabic-first strings;
  English appears only inside English-world content (questions, options).
* **Modern scientific, not childish:** deep navy / teal / ivory palette,
  clean typography, restrained motion. The learner is 17–18, preparing
  for a ministerial exam — no cartoon mascots, no baby colours.
* **Dark mode is a first-class theme** (default: follow system; toggle in
  Settings; stored in `app_meta`). Every screen must be legible in both.
* **Honest empty states:** any world/unit/lesson with no imported
  questions shows «قيد الإعداد — سيُضاف مع كتاب المنهج» and **no**
  fake button. A disabled button with no action is a bug.
* **Demo labelling:** demo content always carries a visible badge
  «تجريبي — ليس من المنهج». Demo results never appear on the home
  analytics cards.
* **Accessibility:** minimum touch target 48 dp, text scale respected,
  colour never the only signal (correct/incorrect also differ by icon
  and text), timers pausable.

---

## 8. CI plan (GitHub Actions — `.github/workflows/android.yml`)

The skeleton agent owns the workflow file; this is the contract it must
satisfy. No Flutter SDK exists locally, so **CI is the only build/test
verification** until the user device-tests.

```yaml
# Triggers: push to main, pull requests. Runs on ubuntu-latest.
# 1. Checkout
# 2. Setup Java 17 (Temurin) + Flutter 3.50.1 (subosito/flutter-action)
# 3. flutter pub get
# 4. flutter analyze            # FAIL on any error (warnings: fail too in v1,
#                                #  so the codebase stays warning-clean)
# 5. flutter test --coverage    # unit + widget tests; FAIL below the bar
#                                #  the games agent sets (target: pure-Dart
#                                #  logic 100% covered; widgets smoke-covered)
# 6. Manifest gate (shell step, MUST exist):
#      - grep the merged manifest / AndroidManifest.xml for INTERNET
#        and fail the build if found
#      - check release APK size <= 100 MB and fail if over
# 7. flutter build apk --release --split-per-abi
#    (split APKs keep each download small; the universal APK is the
#     fallback artefact if a device needs it)
# 8. Upload APK artefact(s) + test report; on tags v* also create a
#    GitHub Release with the APK attached.
```

* **Signing:** release keystore lives in GitHub Secrets (never in the
  repo). Debug signing is for local runs only; a release APK signed with
  the debug key must never be delivered to the user.
* **Reproducibility:** `pubspec.lock` is committed. Dependabot / manual
  `flutter pub outdated` review monthly; a dependency bump is a PR with
  a green CI run, never a silent edit.
* **What CI cannot verify:** on-device feel (frame rate on a mid-range
  phone, TTS behaviour, real install size on the user's phone). That is
  the user's device test, with a checklist in the release notes.

---

## 9. Risks & open decisions

| # | Risk / decision | Status |
|---|---|---|
| 1 | **Yemeni textbooks not provided — content layer is structure-only.** The documented curriculum structure is now in `assets/data/curriculum.json` (see §11: 51 units / 391 lessons, Sanaa 2027 as default per user decision 2026-11-25). No lesson text and no questions can be written, imported or tested until the user supplies the books/PDFs **or** a written Ministry permission (copyright: «حقوق الطبع محفوظة لوزارة التربية والتعليم»). Questions stay «قيد الإعداد». | **BLOCKER — awaiting user / Ministry permission** |
| 2 | Flutter 3.50 `material.dart` deprecation — skeleton must follow the `flutter create` template (`material_ui`) or pin a compatible approach. | Open for skeleton agent; CI decides |
| 3 | Flame 1.38.2 vs pure CustomPainter — Flame is optional; fallback is Option C (§6.5). | Decided with fallback |
| 4 | True 3D (flutter3d) deferred to post-v1, pending 1.0.0 stable. | Decided |
| 5 | FTS5 Arabic search — deliberately not in v1 (§5.4). | Decided |
| 6 | No local build/test possible in this environment — all verification is CI + user device test. | Accepted, stated everywhere |
| 7 | APK size is a budget, not a measurement, until CI builds it (`docs/SIZE_BUDGET.md`). | Accepted |

---

## 10. File map (this workstream)

| File | Contents |
|---|---|
| `docs/ARCHITECTURE.md` | This file |
| `docs/GAME_DESIGN.md` | 12 game modes, scoring, SM-2, mastery, analytics |
| `docs/CONTENT_IMPORT.md` | Content-pack format, validation, import flow, migrations |
| `docs/SIZE_BUDGET.md` | ≤ 100 MB budget table |
| `assets/schema/content_schema.json` | JSON Schema (draft 2020-12) for content packs |
| `assets/data/demo_questions.json` | 14 demo questions, all `source = "demo — not Yemeni curriculum"` |
| `assets/data/curriculum.json` | **Documented Yemeni curriculum structure only** (51 units / 391 lessons, Sanaa 2027 default) — see §11 and `docs/CURRICULUM.md` |
| `lib/content/curriculum.dart` | `CurriculumData` loader (rootBundle) + `seedRows()` for units/lessons |
| `lib/screens/curriculum_screen.dart` | World detail screen rendering the documented structure |
| `docs/CURRICULUM.md` | Curriculum decision log (Sanaa 2027 default, chemistry settled to 7 units, copyright) |
| `lib/db/schema.dart` | SQLite DDL as Dart constants (12 tables + indexes) |

*Companion workstreams (other agents, not this file): Flutter skeleton +
CI, science labs (procedural only), games + analytics + exam + tests.*

---

## 11. المنهج اليمني الموثّق — `curriculum.json` (2026-11-25)

Source: documented research in
`workspace/research_notes/sanaa-edition-yemeni-curriculum-20261125-0222/report.md`
(Sanaa 2027, 2026-11-25; Aden report kept as the comparison source:
`workspace/research_notes/yemeni-third-secondary-curriculum-20261125-0216/report.md`).
Full decision log: `docs/CURRICULUM.md`.

### 11.1 What is in the file

`assets/data/curriculum.json` (~53 KB, validated with `python3 -m json.tool`)
holds the **structure only** — unit/lesson titles + book source + edition
for each of the 7 subjects. It holds **no lesson text and no questions**.

| Subject | Documented structure |
|---|---|
| Maths | 7 units / 41 lessons |
| Physics | 9 units / 81 lessons + 10 experiments |
| Chemistry | 7 units / 53 lessons + 17 activities (conflict settled — see §11.2) |
| Biology | 8 units / 53 lessons + 3 activities named (rest unverified by name) |
| Arabic | 3 books (Sanaa): Reading 9 lessons (semester 1 only), Grammar 4 units / 22 items, Literature 16 + Criticism 5 |
| English | Pupil's Course 6 units / 49 lessons + Science reader 11 + Arts reader 7 |
| Islamic + Quran | 5 books (Sanaa): Quran (13+2+2), Iman 10, Fiqh 13, Hadith & Tahdhib 10, Sira 12 |

Total in the default view (Sanaa 2027): **51 units / 391 lessons**.
Every subject carries `books[]` with `source_url` and edition; every
unit carries its semester where documented (marked "استنتاج" where
inferred); OCR-suspicious titles are kept verbatim with a `note`.

### 11.2 The two hard decisions (do not silently change)

1. **Default edition: Sanaa 2027.** User decision 2026-11-25
   («أريد نسخة صنعاء»). The Sanaa editions are the default reference
   (`meta.default_edition: "sanaa"`). Aden editions (mostly 2017-2018)
   appear only as documented comparison lines (`aden_comparison` on the
   differing subjects: Literature 227p vs 128p, Quran 195p vs 104p, Sira
   two different 12-lesson lists) — never as main content.
2. **Chemistry: settled to 7 units.** 7 units (yemenbooks) vs 9 units
   (sahl.io + alktab24 2026) — the Sanaa 2027 reference is 7 units, so
   the conflict is settled in its favour; the 9-unit index survives only
   as a comparison note (`conflict_resolved.comparison_note`). No
   chemistry question may be built until the textbooks/permission arrive
   (see risk #1).

### 11.3 Copyright — the binding constraint

The books carry «حقوق الطبع محفوظة لوزارة التربية والتعليم والبحث
العلمي»; no licence permitting redistribution or in-app inclusion was
found. Therefore: structure (titles) only, no copied text, no copied
questions. Questions remain «قيد الإعداد» until the books arrive **or**
a written Ministry permission is obtained. This is recorded in the
file itself (`meta.content_scope: "structure_only"`,
`meta.questions_status: "pending"`).

### 11.4 Wiring

- `lib/content/curriculum.dart` — `CurriculumData.load()` (rootBundle),
  models, `totalLessons`, and `seedRows()` producing rows for the
  `units`/`lessons` tables of `lib/db/database.dart` v1 (structure only).
  Seeding is **not yet called**: it lands with the DB v2 migration
  (see `docs/CURRICULUM.md` §4).
- `lib/screens/curriculum_screen.dart` — each open world now renders
  its documented units/lessons, books, edition, sources, the chemistry
  warning, Sanaa alternatives, and an honest «الأسئلة قيد الإعداد»
  footer. `worlds_screen.dart` routes open worlds there.
- `pubspec.yaml` now registers the three JSON assets
  (`assets/data/curriculum.json`, `assets/data/demo_questions.json`,
  `assets/schema/content_schema.json`) — previously the `assets:` block
  was commented out, so the demo pack was not actually bundled.
