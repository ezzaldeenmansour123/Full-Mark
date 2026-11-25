# ABQARIYA — GAME DESIGN | تصميم الألعاب

> **Status:** Phase 0 design document, 2026-11-25.
> **Scope:** the 12 mini-game modes, scoring, spaced repetition, mastery
> and local analytics. The engine that implements this lives in
> `lib/game/` (pure Dart where possible); the UI that renders it is the
> skeleton/UI workstream's.
>
> **Honesty rule (binding):** every analytic number in this app is an
> **estimate of past performance** — a description of what the learner
> has already done. It is **never a prediction of the ministerial exam
> result**, and the UI must say so wherever a number could be misread
> that way (§7).

---

## 1. Design principles

1. **Learn first, play second.** Every mode teaches through the
   explanation shown after each answer. A mode that only tests, without
   explaining, is unfinished.
2. **Short sessions.** A stage is 5–10 questions (boss: 20, exam:
   full simulation). A learner should be able to finish a stage on a bus.
3. **No punishment loops.** A wrong answer costs XP for that question
   only; it never locks the learner out, never subtracts earned stars,
   and always offers the explanation + a review slot (§5).
4. **Difficulty is in the content, not in the tricks.** Difficulty 1–3
   is set by the curator against the book (1 = تذكّر/فهم، 2 = تطبيق،
   3 = تحليل/تركيب). Games never invent difficulty by hiding the
   question or by unfair timers.
5. **One learner, no competition.** No leaderboards, no friends, no
   comparison with other people — the only comparison is with the
   learner's own past self.

---

## 2. The 12 mini-game modes

All modes draw questions from the same `questions` table, filtered by
lesson/unit and difficulty. A mode is a *renderer + rules* over a
question set — never a separate question bank. `stages.mode` stores the
mode key (see `lib/db/schema.dart`).

| # | Mode (key) | Arabic name | How it plays | Questions | Timer |
|---|---|---|---|---|---|
| 1 | `quiz` | اختبار سريع | Classic multiple-choice, one question at a time, explanation after each answer. The first stage of every lesson. | 10 | 60 s / Q (default; per-question `time_limit_seconds` wins) |
| 2 | `time_race` | سباق الزمن | MCQ against a shrinking total clock. Speed bonus XP doubled. A wrong answer costs 5 s. | 10 | 120 s total |
| 3 | `unlock` | افتح القفل | A chain of 3 locks; each lock opens with 2 consecutive correct answers. A wrong answer resets the current lock's streak (not the whole chain). | 6–9 (until 3 locks open or questions run out) | none |
| 4 | `complete_equation` | أكمل المعادلة | Fill-in / equation type: complete the formula, balance, or missing step. Options shown as tiles (v1); free-text input is post-v1. | 8 | 90 s / Q |
| 5 | `lab` | المختبر | An interactive procedural simulation (plotter, circuit, titration, cell diagram). The learner changes a variable, observes, then answers 3–5 questions about what happened. | 3–5 + simulation | none (exploration untimed) |
| 6 | `aim` | التصويب | Targets (answers) drift across the screen; tap the correct one before it leaves. Only for short answers (numbers, terms, symbols). | 8 | 15 s / Q |
| 7 | `memory_match` | طابق الأزواج | Classic memory: flip cards to match term ↔ definition / formula ↔ name / element ↔ symbol. A match needs both cards correct. | 6 pairs (12 cards) | 180 s total |
| 8 | `true_false` | صح أم خطأ | True/false questions, fast pace, streak multiplier. | 10 | 20 s / Q |
| 9 | `link_concepts` | اربط المفاهيم | Match two columns (concept → example / cause → effect / term → definition). All links must be placed before scoring. | 5 links | 120 s total |
| 10 | `boss` | الزعيم | 20 mixed questions from the whole unit (all difficulties, all lessons). Timed, no explanations until the end. Pass ≥ 70% unlocks the next unit. | **20** | 20 min total |
| 11 | `smart_memory` | الذاكرة الذكية | Spaced-repetition review session: questions due today from `review_queue`, easiest-first ordering, SM-2 scheduling (§5). Not gated — available from the home screen whenever items are due. | all due (cap 20 / session) | none |
| 12 | `ministerial_exam` | محاكاة الامتحان الوزاري | Full exam simulation in ministerial style: mixed subjects per exam, or one subject; fixed time; no explanations until submission; result screen shows score, per-topic breakdown and a review plan. | 30–50 (per exam definition in the pack) | 90–120 min (per exam) |

### 2.1 Mode availability rules

* A lesson's stages unlock in order; the first stage is always `quiz`.
* `lab` appears only for lessons that have a lab defined by the labs
  agent (maths plotter, physics, chemistry, biology). A lesson without
  a lab simply has no `lab` stage — never a placeholder lab.
* `boss` and `ministerial_exam` are not lesson stages; they are unit /
  subject level (see ARCHITECTURE.md §4.1 for unlock rules).
* `smart_memory` is never locked and never gated by stars; it is driven
  entirely by the review queue. If nothing is due, its home card says
  «لا توجد مراجعات مستحقة اليوم — أحسنتِ!» and shows the next due time.

### 2.2 What each mode needs from a question

| Question type | Used by |
|---|---|
| `mcq` | quiz, time_race, unlock, aim, boss, ministerial_exam, smart_memory |
| `true_false` | true_false, boss, ministerial_exam, smart_memory |
| `fill_blank`, `equation` | complete_equation, lab follow-up questions |
| `match` | memory_match, link_concepts |

The v1 importer accepts all six types; games enable renderers for
`mcq` and `true_false` first. A stage whose questions' types its
renderer cannot show is **not offered** (the stage row is not created
at import time for that mode) — a missing mode is honest, a crashing
mode is not.

---

## 3. Scoring — exact rules

All scoring lives in `lib/game/scoring.dart` (pure Dart, unit-tested).
These numbers are the contract; the UI displays them, it does not invent
its own.

### 3.1 XP per answer

| Component | XP |
|---|---|
| Correct answer, difficulty 1 | 10 |
| Correct answer, difficulty 2 | 15 |
| Correct answer, difficulty 3 | 20 |
| Speed bonus: answered in < 50% of the time limit | +5 |
| Wrong answer | 0 (never negative) |
| Unanswered (time ran out) | 0, and the question goes to the review queue |

### 3.2 Completion bonuses

| Event | XP |
|---|---|
| Stage completed (any score) | +10 |
| Boss passed (≥ 70% of 20) | +100 |
| Ministerial-exam simulation finished | +50 (for finishing, regardless of score) |
| Review-queue item answered correctly | +5 |
| Daily streak: first play on a new calendar day | +20 (once per day) |

### 3.3 Stars (per stage, 0–3, never decrease)

| Stars | Condition (on that stage's best sitting) |
|---|---|
| 1 ★ | ≥ 50% correct |
| 2 ★★ | ≥ 70% correct |
| 3 ★★★ | ≥ 90% correct **and** zero unanswered questions |

Stars are stored in `progress` (entity_type `stage`) and only ever move
up. A replay that scores lower does not take stars away — the learner is
competing with her past self, not being punished for a bad day.

### 3.4 Levels (cosmetic only)

Cumulative XP → level: level *n* requires `100 × n × (n + 1) / 2` XP
(L1 100 · L2 300 · L3 600 · L5 1500 · L10 5500). Level titles are
scientific Arabic titles («مستكشفة»، «باحثة»، «عالِمة» …). Levels change
nothing about gating or content — they are encouragement, not a mechanic.

### 3.5 Worked example

Stage `quiz`, 10 questions: 6× difficulty 1, 3× difficulty 2, 1× difficulty 3.
Learner answers 8 correctly (5× d1, 2× d2, 1× d3), 3 of them fast
(+5 each), 2 wrong.

* Answer XP: 5×10 + 2×15 + 1×20 = 100
* Speed bonus: 3×5 = 15
* Completion: +10
* **Total: 125 XP.** Score 8/10 = 80% → **2 stars** (needs 90% for 3).
* The 2 wrong questions enter the review queue (§5).

---

## 4. Timers and fairness

* Every timed mode shows the remaining time always; at 10 s remaining
  the timer pulses (colour + icon, never colour alone).
* **Pause:** the learner can pause any stage (timer freezes, question
  hides so a pause cannot be used to look things up — the question is
  hidden while paused, on purpose).
* **Interruption:** a phone call / app kill ends the timer; answered
  questions are saved (autosave), unanswered ones are marked unanswered
  and queued for review. The stage can be restarted; re-answering a
  previously answered question in the same stage inserts a new attempt
  row (append-only) — the *best* sitting counts for stars.
* No mode hides the question text, shrinks the font, or uses a timer
  shorter than the question's `time_limit_seconds` to manufacture
  difficulty.

---

## 5. Spaced repetition — simplified SM-2 (local only)

Implemented in `lib/game/spaced_repetition.dart` (pure Dart). No server,
no account, no cloud model — the schedule is computed on-device from the
learner's own answers.

### 5.1 State (table `review_queue`)

One row per question in the queue: `ease_factor` (starts 2.5, floor 1.3),
`interval_days` (starts 0), `repetitions` (starts 0), `lapses`,
`next_review_at` (UTC epoch-ms).

### 5.2 When a question enters the queue

* Every wrong or unanswered question, in any mode.
* Every question answered correctly but slowly (took > 80% of its time
  limit) — the learner knew it, but not fluently.
* The learner can also add a question manually from its explanation
  screen ("راجعيني بهذا لاحقاً").

### 5.3 Update rule (after each review answer)

The learner grades herself implicitly: the answer is either correct or
not, and the time taken is known. Map that to a quality score `q`:

| Outcome | q |
|---|---|
| Correct and fast (< 50% of limit) | 5 |
| Correct, normal speed | 4 |
| Correct but slow (> 80% of limit) | 3 |
| Wrong | 2 (lapse) |

Then the classic SM-2 update, simplified:

```
if q < 3:                       # lapse
    repetitions = 0
    interval_days = 1           # review again tomorrow
    lapses += 1
    ease_factor = max(1.3, ease_factor - 0.2)
else:
    if repetitions == 0: interval_days = 1
    elif repetitions == 1: interval_days = 6
    else: interval_days = round(interval_days * ease_factor)
    repetitions += 1
    ease_factor = ease_factor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    ease_factor = max(1.3, ease_factor)
next_review_at = now + interval_days days
```

**Caps (deliberate, for a school learner):** `interval_days` is capped
at 30 days — the exam is months away, not years, and a 6-month interval
would silently drop a topic before the ministerial exam. `ease_factor`
is floored at 1.3 (standard SM-2). A question answered correctly 3
times in a row with q ≥ 4 is marked "mastered" for that lesson's
mastery computation (§6) but stays in the queue at the capped interval
until the learner resets progress.

### 5.4 Daily review session (`smart_memory` mode)

* Home card shows the count due today and the next due time.
* A session draws due questions, easiest first (lowest `repetitions`,
  then lowest `ease_factor`), capped at 20 per session.
* Finishing a session updates every row via §5.3 in one transaction.
* Nothing is due → the card celebrates and shows the next due date.
  An empty queue is a success state, not an error.

---

## 6. Mastery % (per unit, per subject, per lesson)

Mastery is a **stored snapshot** in `progress.mastery_pct`, recomputed
from `attempts` after every stage (never typed, never guessed).

```
For a unit U:
  questions in U that the learner has attempted at least once = A
  of those, "known" = answered correctly on the most recent attempt
                 AND (not currently overdue in the review queue)
  mastery_pct(U) = round(100 * known / max(1, total questions in U))
```

* A question never attempted contributes 0 — mastery starts at 0% for
  every unit, honestly.
* A question answered correctly long ago but now overdue for review
  stops counting as "known" until it is reviewed — this is the point of
  spaced repetition, and the UI explains it ("3 أسئلة تحتاج مراجعة").
* Lesson mastery uses the same formula on the lesson's questions;
  subject mastery is the mean of its units' mastery, weighted by
  question count.
* **Mastery is not a grade and not a prediction.** It answers one
  question only: "of the questions in this unit, how many can you
  currently answer correctly?" The analytics screen (§7) states this in
  plain Arabic next to the number.

### 6.1 Boss gating, restated with mastery

Boss unlocks when: every lesson in the unit has ≥ 2 stars in at least
one stage **and** `mastery_pct(unit) ≥ 60%`. Both conditions are checked
in `game/gating.dart` from the DB, not from cached UI state.

---

## 7. Analytics — local, descriptive, never predictive

Implemented in `lib/analytics/analytics.dart` (pure Dart, computed from
`attempts` + `review_queue` + `exam_results`). Shown on the Analytics
screen and as small cards on Home. **Every number is an estimate of past
performance.**

### 7.1 What is shown

| Card | Definition | Wording rule |
|---|---|---|
| Mastery per subject / unit | §6 formula | «إتقان وحدة X: 64% — أي 16 سؤالاً من 25 تجيبين عليها صحيحاً حالياً» |
| Strengths | Top 3 lessons by mastery (≥ 5 attempts each) | «أقوى دروسك» |
| Weaknesses | Bottom 3 lessons by mastery (≥ 5 attempts each) | «دروس تحتاج مراجعة» — never «دروس ضعيفة» as a label for the learner |
| Time per question | Median seconds per answered question, per subject (median, not mean — one very slow question must not distort it) | «متوسط زمن الإجابة» with the median explained in a footnote |
| Accuracy trend | Correct % per week for the last 4 weeks (only weeks with ≥ 10 attempts; weeks with fewer show «بيانات غير كافية») | Never draw a trend line through fewer than 3 data points |
| Review plan | Due today / due this week, by subject, from `review_queue` | «راجعي اليوم: 8 أسئلة — فيزياء 5، كيمياء 3» |
| Exam simulations | List of past sittings: date, subject, score %, duration | Raw scores only |

### 7.2 What is NEVER shown

* **No predicted ministerial score.** No "you will get 87%", no grade
  forecast, no pass/fail prediction. The exam-simulation result screen
  carries the fixed text: «هذه نتيجة محاكاة تدريبية على أسئلة مستوردة،
  وليست توقعاً لنتيجة الامتحان الوزاري».
* **No comparison with other learners.** There are no other learners in
  the app; there is nothing to compare with.
* **No "IQ", "ذكاء", or ability label.** The app describes behaviour
  (answered, reviewed, mastered), never the person.
* **No fake precision.** Percentages are rounded to whole numbers; a
  mastery computed from fewer than 5 attempts is shown as «بيانات غير
  كافية» instead of a number.

### 7.3 Data rules

* Analytics read only the learner's own on-device rows. Nothing leaves
  the device. There is no export in v1 (an export would be a local file
  the learner chooses to share — post-v1, if requested).
* Demo rows (`is_demo = 1`) are excluded from every analytic card.
  Demo sittings are visible only inside Settings → "الأسئلة التجريبية".

---

## 8. Achievements (badges)

Seeded catalogue (in code, unlocked by the game engine writing
`achievements.unlocked_at`). Examples — the full catalogue is the games
agent's list, these are the rules it must follow:

| Badge | Condition (examples) |
|---|---|
| «أول خطوة» | Finish the first stage |
| «مثابرة» | 7-day streak |
| «زعيم الفيزياء» | Pass a physics boss |
| «مراجِعة» | Clear the review queue 5 days in a row |
| «محاكاة كاملة» | Finish a ministerial-exam simulation |

Rules: a badge once earned stays earned; conditions are checked from
the DB after every stage/exam, never from UI counters; badge art is
code-drawn (icon_key), never an image file; no badge is ever shown as
"missed" or "failed" — locked badges show their condition as an
invitation, not a rebuke.

---

## 9. What this document does NOT decide

* Visual design of the modes (UI agent, under ARCHITECTURE.md §7).
* Lab contents (labs agent — procedural CustomPainter only).
* Exact exam paper composition (depends on the real textbook packs;
  the exam draws from imported questions only, in the proportions the
  pack declares — see CONTENT_IMPORT.md §5).
* Sound / TTS design (deferred; system TTS only, no audio files, v1).
