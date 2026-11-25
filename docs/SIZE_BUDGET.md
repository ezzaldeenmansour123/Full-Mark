# ABQARIYA — SIZE BUDGET | ميزانية الحجم (APK ≤ 100 MB)

> **Status:** Phase 0 budget document, 2026-11-25; updated in the 2026-11-25 merge pass (Sanaa curriculum file measured; CI now enforces the limit with a size-gate step and a no-INTERNET manifest check — see `.github/workflows/build-apk.yml`).
> **Honest note first:** the numbers below are a **budget, not a
> measurement**. No APK has been built — no Flutter/Dart SDK exists in
> this environment, and `flutter build apk` was **not** run. The first
> real measurement comes from the GitHub Actions CI build
> (ARCHITECTURE.md §8), which fails the build if the release APK exceeds
> 100 MB. Until then, every figure marked "estimate" is an estimate,
> derived from the known size of the components involved, not a claim.
> This document will be updated with the measured CI numbers in the
> first build report.

---

## 1. The rule

**Release APK ≤ 100 MB, hard limit, enforced in CI.** The budget is
spent in the order below; if a category threatens to exceed its line,
the feature is cut or deferred — the limit is never "re-negotiated"
upward to fit a feature.

The user asked for ≤ 100 MB because the app must install and update
easily on a mid-range phone, possibly over a slow/expensive connection.
Every MB in the APK is a MB the learner (or her family) downloads.

---

## 2. Budget table (release APK, arm64-v8a split APK)

| # | Category | Budget | Basis / notes |
|---|---|---|---|
| 1 | Flutter engine + Dart runtime + framework | **~25 MB** | Estimate. A minimal Flutter release APK is ~8–15 MB for the engine + framework on one ABI; ABQARIYA uses Material 3 + animations, so budget the upper end. `--split-per-abi` keeps this to one ABI per APK (the universal APK will be larger — see §4). |
| 2 | Dart application code (all screens, game engine, labs, analytics) | **~5 MB** | Estimate. Hand-written Dart compiles small; the risk is not code size but dependency bloat — every added package is charged here. |
| 3 | Dependencies (sqflite + path, Flame if used) | **~3 MB** | Estimate. sqflite/path are thin wrappers over the platform SQLite (already on the device). Flame 1.38.2 adds ~1–3 MB of Dart code. **No** webview, **no** model-viewer JS, **no** 3D engine in v1 — those are the line items that would break this budget (see §3). |
| 4 | Graphics — procedural / code-drawn (CustomPainter, icons) | **~0 MB** | By design. All diagrams, lab visuals, icons and badges are drawn in code. There are no PNG/JPG/SVG asset files for graphics in v1. |
| 5 | 3D models (GLB / glTF) | **0 MB** | By decision (ARCHITECTURE.md §6). No GLB in the APK in v1. Optional post-v1 as a separate side-loaded pack, never inside the APK. |
| 6 | Audio files (music, SFX, voice) | **0 MB** | By decision. v1 has **no audio files**. Sound, if any, is system TTS (no permission, no files) — deferred, and TTS voices live in the OS, not the APK. |
| 7 | Fonts | **~2 MB** | Estimate. One Arabic font (e.g. a single-weight modern Arabic font for UI + content). Rule: **one font family, ≤ 2 weights, subset if the tooling allows**. System fonts are the fallback if even this proves too big — but Arabic rendering quality on older devices justifies budgeting for one bundled font. |
| 8 | Database — shipped content (demo pack + curriculum structure + empty tables) | **< 0.1 MB** | Measured, not estimated: `assets/data/demo_questions.json` is **14 KB** (14 questions) and `assets/data/curriculum.json` (Sanaa 2027 structure, 53 units / 400 lessons) is **71,978 bytes** — measured 2026-11-25. The empty SQLite file is tens of KB. |
| 9 | Database — growth after real packs imported | **~2 MB** | Estimate for the full curriculum at scale: ~3,000–5,000 questions of plain text ≈ 1–2 MB of SQLite (text is cheap; the DB grows on-device as packs are imported, it does not all ship in the APK — packs bundled into a release add their JSON size to the APK, roughly 1 KB per question). |
| 10 | Android resources, manifest, native libs (SQLite is system-provided) | **~2 MB** | Estimate. |
| 11 | Contingency (unforeseen: a needed plugin, a second font weight, exam assets) | **~10 MB** | Reserve, not a target. Spent only by explicit decision, recorded here when spent. |
| | **TOTAL (budgeted, split-per-ABI release APK)** | **~50 MB** | **≈ half the 100 MB limit.** Deliberately leaves ~50 MB of headroom for the real curriculum packs, a second font weight, and measurement error. |

### What the table says in one line

> A code-drawn, text-only, offline app should land around **40–60 MB**;
> the 100 MB limit is comfortable **if and only if** no 3D models, no
> audio files, no WebView and no image library enter the APK.

---

## 3. What would break the budget (rejected / deferred costs)

| Item | Cost if added | Decision |
|---|---|---|
| `model_viewer_plus` + its WebView JS bridge | several MB + per-model GLB (0.5–5 MB each) | **Rejected** (also fails the no-internet / minSdk rules) |
| `flutter3d` 1.0.0-rc.2 engine | ~3.7 MB selected shader bundle + engine code; the engine's own example APK measures **19.8 MiB** (arm64 split, Oct 2026, per its docs) — affordable alone, but it is a pre-release with a build hook, and models would be extra | **Deferred to post-v1**, pending 1.0.0 stable |
| A library of GLB models (molecules, organs, solids) | tens of MB | **Deferred**; optional side-loaded pack only, never in the APK |
| Audio: music / SFX / recorded voice | 0.5–2 MB per minute of audio; a voiced question bank would be hundreds of MB | **Rejected**; system TTS only, deferred |
| Image library (textbook figures as PNG/JPG) | ~100–300 KB per figure; 200 figures = 20–60 MB | **Rejected**; figures are re-drawn procedurally in code |
| Video lessons | MB per minute | **Rejected**; out of scope for v1 and for the 100 MB limit |
| Extra fonts (multiple families/weights) | ~1 MB per weight | Capped at one family, ≤ 2 weights |

---

## 4. APK variants — which number counts

* **The 100 MB limit applies to the APK the user installs.**
  CI builds with `flutter build apk --release --split-per-abi` and
  measures each per-ABI APK (arm64-v8a is the user's device class).
* The **universal APK** (`--target-platform android-arm64,android-arm`
  without split, or a fat APK) will be larger — roughly the sum of the
  per-ABI native code — and is a fallback artefact only. If the
  universal APK exceeds 100 MB while the split APKs do not, that is
  acceptable but must be recorded; the split APK is what is delivered.
* **AAB / Play Store is out of scope** (sideload APK delivery, per the
  master prompt). If that changes, this budget is re-done for AAB
  download size, which is a different number.

---

## 5. Measurement plan (when CI first builds)

1. CI prints the APK size for every ABI and fails the build over 100 MB.
2. First build report records, per ABI: total APK size, plus a
   breakdown from `flutter build apk --analyze-size` (or
   `devtools` size analysis) — engine vs Dart code vs assets.
3. This document is then updated: "estimate" → "measured (CI run #N,
   date, commit)", and any line that missed its budget by > 20% gets a
   note explaining why and what changed.
4. On every release thereafter, the size is reported in the release
   notes next to the previous release's size, so growth is visible.
   A release that grows the APK by > 10 MB without a corresponding
   budget entry here is a review flag, not a silent change.

## 6. If the budget is exceeded

In order, before ever raising the limit:

1. Check the size analysis — usually one dependency or asset is the
   cause; remove or replace it.
2. Drop Flame (fallback to pure CustomPainter, ARCHITECTURE.md §6.5)
   — saves ~1–3 MB.
3. Drop the bundled font, use system fonts — saves ~2 MB.
4. Split content packs out of the APK (side-loaded JSON import) —
   saves the content's JSON size from the APK.
5. Only if all of the above still leave the APK over 100 MB does the
   limit itself get re-discussed with the user — with measured numbers,
   not estimates.
