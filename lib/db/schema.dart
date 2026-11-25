// ABQARIYA — SQLite schema (single source of truth).
//
// Phase 0 / Database v1. Written 2026-11-25. NOT compiled or tested locally:
// no Flutter/Dart SDK exists in this environment, so `flutter analyze`,
// `flutter test` and any APK build were NOT run. The SQL below was checked
// by eye and against the JSON Schema in assets/schema/content_schema.json
// and the demo pack in assets/data/demo_questions.json; the first CI build
// (see docs/ARCHITECTURE.md §8) is the first real verification.
//
// Design rules enforced by this file:
//  * One database file, `abqariya.db`, opened with sqflite. No
//    shared_preferences, no second store: settings, progress and content
//    all live here so they can never diverge (see ARCHITECTURE.md §2).
//  * Every content row carries provenance: `source` (NOT NULL) and
//    `source_page` (page in the source book; NULL only for the demo pack).
//    Every question row additionally carries `difficulty` (1-3),
//    `subject_id` / `unit_id` / `lesson_id` foreign keys and `explanation`
//    (NOT NULL). A question without an explanation cannot be inserted.
//  * Content ids are stable TEXT keys (e.g. `physics`, `physics-u03`,
//    `physics-u03-l02`), NOT autoincrement integers, so a re-import of the
//    same pack upserts instead of duplicating rows.
//  * Foreign keys are enforced at runtime: openDatabase MUST run
//    `PRAGMA foreign_keys = ON` in onConfigure (see AppDatabase notes at
//    the bottom). The DDL alone does not enforce them on Android.
//  * NO FTS5 virtual table in v1 — deliberate. SQLite FTS5 `unicode61`
//    tokenises Arabic prefixed words as single tokens, so bare terms fail
//    (this exact failure shipped in the sibling PROTOCOL app: MATCH
//    'الأسبقية' -> 0 rows). v1 search is `LIKE` on a normalised column
//    (`questions.search_text`, diacritics/alef variants stripped at import
//    time). FTS5 may return only after a proven Arabic tokenizer is tested
//    on-device; see ARCHITECTURE.md §5.4.
//  * `is_demo` (0/1) marks the clearly-labelled demo set. Demo rows are
//    excluded from every curriculum statistic and shown behind a
//    "تجريبي — ليس من المنهج" badge. Real curriculum rows have
//    is_demo = 0, a real book in `source`, and source_page >= 1.
//  * Unit-level / boss / exam questions still carry a lesson_id: they use
//    the unit's synthetic review lesson `<unit_id>-review`, which every
//    real pack must define in its `lessons` array. lesson_id is therefore
//    NOT NULL on questions — a question that belongs nowhere is a data bug.
//  * All timestamps are INTEGER milliseconds since epoch (UTC), stored via
//    DateTime.now().millisecondsSinceEpoch. Never store formatted dates.

/// Database file name (inside getDatabasesPath()).
const String kDatabaseName = 'abqariya.db';

/// Current schema version. Bump ONLY together with an onUpgrade migration
/// in AppDatabase (see docs/CONTENT_IMPORT.md §6). Never bump without one.
///
/// v2 (2026-11-25, merge pass): version bumped for the Sanaa-curriculum
/// seed. The DDL itself is unchanged from v1; v2 adds the onUpgrade
/// migration in `lib/db/database.dart` (legacy v1 tables -> canonical
/// schema, user progress preserved) and the curriculum seed path.
/// `lib/db/database.dart` is the ONLY implementation of this schema:
/// it runs `kCreateAllStatements` in onCreate and the v1->v2 migration
/// in onUpgrade. Do not duplicate this DDL anywhere else.
const int kDatabaseVersion = 2;

/// Exact demo-source marker. Must match assets/data/demo_questions.json
/// and assets/schema/content_schema.json character for character.
const String kDemoSource = 'demo — not Yemeni curriculum';

// ---------------------------------------------------------------------------
// 1. Content tables (imported from a content pack; see CONTENT_IMPORT.md)
// ---------------------------------------------------------------------------

/// Subjects = the 7 worlds. Seeded from the content pack, never hard-coded
/// in UI code: if a pack has no rows for a subject, that world shows
/// «قيد الإعداد» instead of fake content.
const String kCreateSubjects = '''
CREATE TABLE IF NOT EXISTS subjects (
  id          TEXT PRIMARY KEY,
  name_ar     TEXT NOT NULL,
  name_en     TEXT NOT NULL,
  icon_key    TEXT NOT NULL DEFAULT 'book',
  color_hex   TEXT NOT NULL DEFAULT '#2E86AB',
  sort_order  INTEGER NOT NULL DEFAULT 0,
  source      TEXT NOT NULL,
  source_detail TEXT,
  is_demo     INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);
''';

const String kCreateUnits = '''
CREATE TABLE IF NOT EXISTS units (
  id            TEXT PRIMARY KEY,
  subject_id    TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  title_ar      TEXT NOT NULL,
  title_en      TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  source        TEXT NOT NULL,
  source_page   INTEGER CHECK (source_page IS NULL OR source_page >= 1),
  source_detail TEXT,
  is_demo       INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);
''';

const String kCreateLessons = '''
CREATE TABLE IF NOT EXISTS lessons (
  id            TEXT PRIMARY KEY,
  unit_id       TEXT NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  subject_id    TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  title_ar      TEXT NOT NULL,
  title_en      TEXT,
  summary_ar    TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  source        TEXT NOT NULL,
  source_page   INTEGER CHECK (source_page IS NULL OR source_page >= 1),
  source_detail TEXT,
  is_demo       INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);
''';

/// Stages are gameplay wrappers around a lesson: one lesson can be played
/// in several modes (quiz, time race, memory, ...). `mode` must be one of
/// the 12 modes in docs/GAME_DESIGN.md; the importer rejects anything else.
/// `question_count` is the number of questions a stage session draws.
const String kCreateStages = '''
CREATE TABLE IF NOT EXISTS stages (
  id              TEXT PRIMARY KEY,
  lesson_id       TEXT NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  unit_id         TEXT NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  subject_id      TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  mode            TEXT NOT NULL CHECK (mode IN (
                      'quiz', 'time_race', 'unlock', 'complete_equation',
                      'lab', 'aim', 'memory_match', 'true_false',
                      'link_concepts', 'boss', 'smart_memory',
                      'ministerial_exam')),
  title_ar        TEXT NOT NULL,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  question_count  INTEGER NOT NULL DEFAULT 10 CHECK (question_count >= 1),
  time_limit_sec  INTEGER CHECK (time_limit_sec IS NULL OR time_limit_sec >= 10),
  source          TEXT NOT NULL,
  source_detail   TEXT,
  is_demo         INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);
''';

/// Questions. The heart of the content-honesty rule: source, source_page,
/// difficulty, all three FKs and explanation are all NOT NULL (except
/// source_page, which is NULL only for demo rows — enforced by the
/// importer, not by this CHECK, because SQLite cannot know "demo").
/// `options_json` is a JSON array of strings (mcq only, else NULL);
/// `correct_option_index` is the 0-based index into it (mcq only, else
/// NULL); `correct_answer` holds the answer text for true_false /
/// fill_blank / equation. `search_text` is the normalised
/// (diacritics-stripped, alef-normalised) concatenation of question +
/// options + explanation, built at import time for LIKE search.
const String kCreateQuestions = '''
CREATE TABLE IF NOT EXISTS questions (
  id                   TEXT PRIMARY KEY,
  type                 TEXT NOT NULL CHECK (type IN (
                         'mcq', 'true_false', 'fill_blank', 'match',
                         'ordering', 'equation')),
  subject_id           TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  unit_id              TEXT NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  lesson_id            TEXT NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  difficulty           INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 3),
  question_text        TEXT NOT NULL,
  options_json         TEXT,
  correct_option_index INTEGER CHECK (correct_option_index IS NULL OR correct_option_index BETWEEN 0 AND 5),
  correct_answer       TEXT,
  explanation          TEXT NOT NULL,
  time_limit_seconds   INTEGER CHECK (time_limit_seconds IS NULL OR time_limit_seconds BETWEEN 5 AND 300),
  tags_json            TEXT,
  media_ref            TEXT CHECK (media_ref IS NULL),
  search_text          TEXT NOT NULL DEFAULT '',
  source               TEXT NOT NULL,
  source_page          INTEGER CHECK (source_page IS NULL OR source_page >= 1),
  source_detail        TEXT,
  is_demo              INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
  created_at           INTEGER NOT NULL,
  updated_at           INTEGER NOT NULL,
  CHECK (
    (type = 'mcq' AND options_json IS NOT NULL AND correct_option_index IS NOT NULL)
    OR (type != 'mcq')
  )
);
''';

// ---------------------------------------------------------------------------
// 2. Learner tables (created empty on first run; never shipped with data)
// ---------------------------------------------------------------------------

/// One row per answered question. Append-only: never UPDATE, never DELETE
/// except on an explicit "reset all progress" action confirmed by the user.
/// `session_id` groups the attempts of one play session / exam sitting.
const String kCreateAttempts = '''
CREATE TABLE IF NOT EXISTS attempts (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id  TEXT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  stage_id     TEXT REFERENCES stages(id) ON DELETE SET NULL,
  exam_id      INTEGER REFERENCES exam_results(id) ON DELETE SET NULL,
  mode         TEXT NOT NULL,
  session_id   TEXT NOT NULL,
  is_correct   INTEGER NOT NULL CHECK (is_correct IN (0, 1)),
  time_ms      INTEGER NOT NULL CHECK (time_ms >= 0),
  xp_earned    INTEGER NOT NULL DEFAULT 0 CHECK (xp_earned >= 0),
  answered_at  INTEGER NOT NULL
);
''';

/// Progress, one row per entity (subject / unit / lesson / stage).
/// `entity_type` + `entity_id` form the logical key; `id` is their join
/// (`'unit:physics-u03'`) so upserts are a single INSERT OR REPLACE.
/// `stars` 0-3; `mastery_pct` 0-100, recomputed from attempts (see
/// GAME_DESIGN.md §6) — it is a stored snapshot, not a second truth:
/// it is always recomputable from `attempts`.
const String kCreateProgress = '''
CREATE TABLE IF NOT EXISTS progress (
  id            TEXT PRIMARY KEY,
  entity_type   TEXT NOT NULL CHECK (entity_type IN ('subject', 'unit', 'lesson', 'stage')),
  entity_id     TEXT NOT NULL,
  xp            INTEGER NOT NULL DEFAULT 0 CHECK (xp >= 0),
  stars         INTEGER NOT NULL DEFAULT 0 CHECK (stars BETWEEN 0 AND 3),
  best_score    INTEGER NOT NULL DEFAULT 0 CHECK (best_score BETWEEN 0 AND 100),
  attempts_count INTEGER NOT NULL DEFAULT 0 CHECK (attempts_count >= 0),
  correct_count INTEGER NOT NULL DEFAULT 0 CHECK (correct_count >= 0),
  mastery_pct   INTEGER NOT NULL DEFAULT 0 CHECK (mastery_pct BETWEEN 0 AND 100),
  last_played_at INTEGER,
  updated_at    INTEGER NOT NULL
);
''';

/// Achievements (badges). Rows are seeded by the app at first run from a
/// fixed catalogue in code; `unlocked_at` NULL means still locked.
/// Never delete a row when its condition changes — a badge once earned
/// stays earned.
const String kCreateAchievements = '''
CREATE TABLE IF NOT EXISTS achievements (
  id              TEXT PRIMARY KEY,
  title_ar        TEXT NOT NULL,
  description_ar  TEXT NOT NULL,
  icon_key        TEXT NOT NULL DEFAULT 'badge',
  condition_type  TEXT NOT NULL,
  condition_value INTEGER NOT NULL DEFAULT 0,
  is_unlocked     INTEGER NOT NULL DEFAULT 0 CHECK (is_unlocked IN (0, 1)),
  unlocked_at     INTEGER
);
''';

/// Spaced-repetition queue (simplified SM-2; see GAME_DESIGN.md §5).
/// One row per question currently scheduled. `ease_factor` starts at 2.5;
/// `interval_days` starts at 0; `next_review_at` is a UTC epoch-ms.
/// A question leaves the queue only when the learner deletes progress.
const String kCreateReviewQueue = '''
CREATE TABLE IF NOT EXISTS review_queue (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id     TEXT NOT NULL UNIQUE REFERENCES questions(id) ON DELETE CASCADE,
  ease_factor     REAL NOT NULL DEFAULT 2.5 CHECK (ease_factor >= 1.3),
  interval_days   INTEGER NOT NULL DEFAULT 0 CHECK (interval_days >= 0),
  repetitions     INTEGER NOT NULL DEFAULT 0 CHECK (repetitions >= 0),
  lapses          INTEGER NOT NULL DEFAULT 0 CHECK (lapses >= 0),
  next_review_at  INTEGER NOT NULL,
  last_reviewed_at INTEGER
);
''';

/// One row per finished ministerial-exam simulation (or per finished
/// boss run, with exam_type = 'boss'). `score_pct` is a raw score on
/// that sitting only — the app NEVER presents it as a prediction of the
/// real ministerial result (see GAME_DESIGN.md §7).
const String kCreateExamResults = '''
CREATE TABLE IF NOT EXISTS exam_results (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  exam_type       TEXT NOT NULL CHECK (exam_type IN ('ministerial_exam', 'boss', 'unit_test')),
  subject_id      TEXT REFERENCES subjects(id) ON DELETE SET NULL,
  unit_id         TEXT REFERENCES units(id) ON DELETE SET NULL,
  total_questions INTEGER NOT NULL CHECK (total_questions >= 1),
  correct_count   INTEGER NOT NULL CHECK (correct_count >= 0),
  score_pct       INTEGER NOT NULL CHECK (score_pct BETWEEN 0 AND 100),
  duration_ms     INTEGER NOT NULL CHECK (duration_ms >= 0),
  is_demo         INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
  note            TEXT,
  started_at      INTEGER NOT NULL,
  finished_at     INTEGER NOT NULL
);
''';

// ---------------------------------------------------------------------------
// 3. Housekeeping tables
// ---------------------------------------------------------------------------

/// One row per imported pack (including the demo pack). `file_sha256` lets
/// a re-import of the same file be detected and skipped; `status` is
/// 'imported' | 'failed' | 'rolled_back'. A failed import must roll back
/// its whole transaction — never leave a half-imported pack behind.
const String kCreateContentPacks = '''
CREATE TABLE IF NOT EXISTS content_packs (
  id             TEXT PRIMARY KEY,
  title_ar       TEXT NOT NULL,
  source         TEXT NOT NULL,
  is_demo        INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
  schema_version INTEGER NOT NULL DEFAULT 1,
  question_count INTEGER NOT NULL DEFAULT 0 CHECK (question_count >= 0),
  file_sha256    TEXT,
  status         TEXT NOT NULL DEFAULT 'imported'
                 CHECK (status IN ('imported', 'failed', 'rolled_back')),
  imported_at    INTEGER NOT NULL
);
''';

/// Tiny key/value store: replaces shared_preferences entirely.
/// Keys in v1: 'db_version' (mirrors kDatabaseVersion), 'demo_visible'
/// ('1'/'0'), 'dark_mode' ('1'/'0'), 'sound_enabled' ('1'/'0'),
/// 'last_pack_id', 'onboarding_done' ('1'/'0').
const String kCreateAppMeta = '''
CREATE TABLE IF NOT EXISTS app_meta (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
''';

// ---------------------------------------------------------------------------
// 4. Indexes (query paths the UI actually uses)
// ---------------------------------------------------------------------------

const String kCreateIndexes = '''
CREATE INDEX IF NOT EXISTS idx_units_subject ON units(subject_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_lessons_unit ON lessons(unit_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_stages_lesson ON stages(lesson_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_questions_unit ON questions(unit_id, difficulty);
CREATE INDEX IF NOT EXISTS idx_questions_lesson ON questions(lesson_id, difficulty);
CREATE INDEX IF NOT EXISTS idx_questions_subject ON questions(subject_id, difficulty);
CREATE INDEX IF NOT EXISTS idx_questions_search ON questions(search_text);
CREATE INDEX IF NOT EXISTS idx_questions_demo ON questions(is_demo);
CREATE INDEX IF NOT EXISTS idx_attempts_question ON attempts(question_id, answered_at);
CREATE INDEX IF NOT EXISTS idx_attempts_session ON attempts(session_id, answered_at);
CREATE INDEX IF NOT EXISTS idx_attempts_exam ON attempts(exam_id);
CREATE INDEX IF NOT EXISTS idx_progress_entity ON progress(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_review_due ON review_queue(next_review_at);
CREATE INDEX IF NOT EXISTS idx_exams_finished ON exam_results(finished_at);
''';

/// Creation order matters: parents before children (FK targets first).
/// Run inside a single transaction in onCreate.
/// NOTE (v2, 2026-11-25): `exam_results` is listed BEFORE `attempts`
/// because `attempts.exam_id` references it.
const List<String> kCreateAllStatements = <String>[
  kCreateSubjects,
  kCreateUnits,
  kCreateLessons,
  kCreateStages,
  kCreateQuestions,
  kCreateExamResults,
  kCreateAttempts,
  kCreateProgress,
  kCreateAchievements,
  kCreateReviewQueue,
  kCreateContentPacks,
  kCreateAppMeta,
  kCreateIndexes,
];

/// Drop order for tests / full reset only (children first). NEVER run on a
/// user's device except behind the explicit "reset everything" confirmation.
const List<String> kDropAllStatements = <String>[
  'DROP TABLE IF EXISTS attempts;',
  'DROP TABLE IF EXISTS review_queue;',
  'DROP TABLE IF EXISTS exam_results;',
  'DROP TABLE IF EXISTS progress;',
  'DROP TABLE IF EXISTS achievements;',
  'DROP TABLE IF EXISTS questions;',
  'DROP TABLE IF EXISTS stages;',
  'DROP TABLE IF EXISTS lessons;',
  'DROP TABLE IF EXISTS units;',
  'DROP TABLE IF EXISTS subjects;',
  'DROP TABLE IF EXISTS content_packs;',
  'DROP TABLE IF EXISTS app_meta;',
];

// ---------------------------------------------------------------------------
// 5. AppDatabase contract (to be implemented by the engine-skeleton agent
//    in lib/db/database.dart — NOT in this file, so this file stays pure
//    SQL constants with no sqflite import and no logic to test).
//
//    openDatabase(
//      join(await getDatabasesPath(), kDatabaseName),
//      version: kDatabaseVersion,
//      onConfigure: (db) async {
//        await db.execute('PRAGMA foreign_keys = ON;');
//      },
//      onCreate: (db, version) async {
//        final batch = db.batch();
//        for (final s in kCreateAllStatements) batch.execute(s);
//        await batch.commit(noResult: true);
//        // Seed: achievements catalogue + app_meta defaults + demo pack
//        // (demo pack import runs through the SAME importer as real packs,
//        //  so demo rows are validated exactly like curriculum rows).
//      },
//      onUpgrade: (db, oldVersion, newVersion) async {
//        // v1 -> v2 (when it exists): ALTER TABLE migrations ONLY, in
//        // ascending order, one `if (oldVersion < N)` block per version.
//        // Never DROP a user-data table in a migration. See
//        // docs/CONTENT_IMPORT.md §6 for the migration policy.
//      },
//    );
//
//    All writes that touch more than one table (import, exam finish,
//    reset) MUST run inside db.transaction(). All reads that feed one
//    screen SHOULD use a single query with JOINs rather than N+1 queries.
// ---------------------------------------------------------------------------
