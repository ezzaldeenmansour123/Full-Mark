# ABQARIYA — MERGE LOG | سجل الدمج (2026-11-25)

دمج عمل 4 مسارات متوازية في شجرة واحدة متماسكة، مع التحويل إلى
نسخة صنعاء 2027 وتجهيز الشجرة للرفع إلى `ezzaldeenmansour123/Full-Mark`.
لم يُنشأ أي مستودع ولم يُدفع أي شيء — الإنشاء والرفع من جهة المستخدم.

## 1. قاعدة البيانات — حسم التكرار (الأهم)

**المشكلة:** كان يوجد تنفيذان متعارضان لنفس قاعدة البيانات:
- `lib/db/schema.dart` — المخطط الرسمي الكامل (12 جدولاً، أعمدة
  `name_ar/source/source_page/is_demo`، جداول `exam_results` و
  `content_packs` و`app_meta`، فهارس).
- `lib/db/database.dart` — تنفيذ مبسّط متعارض كُتب في مسار الهيكل
  (جداول بأعمدة مختلفة: `subjects` بلا `name_ar`، وأسئلة
  `stage_id/stem/options`، وجدول `settings` بدل `app_meta`، وتقدّم
  من صف واحد `id='player'`).

**القرار:** `schema.dart` هو المرجع الوحيد. أُعيدت كتابة
`database.dart` بالكامل لينفّذ `schema.dart` حرفياً:
- `onCreate` ينفّذ `kCreateAllStatements`، و`onConfigure` يفعّل
  `PRAGMA foreign_keys = ON`.
- ترتيب الإنشاء في `kCreateAllStatements` صُحّح: `exam_results` قبل
  `attempts` (لأن `attempts.exam_id` يشير إليه).
- كل واجهات الاستخدام المحفوظة (التي تعتمد عليها الشاشات و
  `progress_store.dart`) أُعيد تنفيذها على المخطط الرسمي:
  `getSetting/setSetting` (عبر `app_meta`)، `getProgressRow/addXp/
  setLastStage` (إجماليات اللاعب في `app_meta`)، `getCompletionPercent/
  getSubjectCompletion` (إكمال المرحلة = نجمة ≥ 1 في صف `progress`)،
  `markStageCompleted`، `recordAttempt`، `getAttemptStats/
  getAttemptsPerSubject/getAttemptsTodayCount/getTotalQuestions`،
  `getUnlockedAchievementIds/unlockAchievement` (تحديث صف الكتالوج
  بدل إدخال صف ناقص)، `getReviewQueueCount/getDueReviewItems`
  (عمود `next_review_at`)، `clearAllProgress`.
- إضافات جديدة: `seedCurriculumRows()` و`seedCurriculumIfEmpty()`،
  `getCompletedLabStagesCount()`، `getQuestionsForSubject()` (تحويل
  صفوف الأسئلة إلى نماذج `Question` مع تخطّي الصفوف التالفة).
- **إصلاح خطأ استيراد:** `lib/core/progress_store.dart` كان يستورد
  `'db/database.dart'` (مسار غير موجود من `lib/core/`) — صُحّح إلى
  `'../db/database.dart'`.
- **إصلاح استعلام مكسور:** `lib/screens/labs_screen.dart` كان يستعلم
  عن عمودين غير موجودين في المخطط الرسمي — استُبدل بدالة مساعدة.

## 2. الشاشات المكررة — حسم التكرار

| الملفان | القرار |
|---|---|
| `lib/screens/analytics_screen.dart` مقابل `lib/analytics/analytics_screen.dart` | **الرسمية: `lib/screens/`** — Stateful، بلا وسائط، تقرأ من قاعدة البيانات عبر `SqliteProgressStore` + `getAttemptsPerSubject()`، وتطابق مسارات `main.dart`. **حُذف** `lib/analytics/analytics_screen.dart` (كانت تتطلب `attempts` كوسائط فلا يمكن توجيهها). منطق التحليل الغني باقٍ في `lib/analytics/analytics_engine.dart` (وتختبره الاختبارات). |
| `lib/screens/achievements_screen.dart` مقابل `lib/achievements/achievements_screen.dart` | **الرسمية: `lib/screens/`** — بلا وسائط، تقرأ/تسجّل من قاعدة البيانات، وتطابق المسارات. **حُذف** `lib/achievements/achievements_screen.dart` (كانت تتطلب وسائط). منطق الشارات والمكافأة اليومية باقٍ في `lib/achievements/achievements.dart`. |
| `lib/screens/exam_screen.dart` مقابل `lib/exam/exam_screen.dart` | **الاثنتان محفوظتان بعد الدمج:** شاشة `lib/exam/` هي واجهة الامتحان الحقيقية (توقيت، تنقّل، تمييز للمراجعة، تصحيح، مراجعة كل سؤال) لكنها تتطلب وسائط، فـ**أُعيدت تسميتها** إلى `lib/exam/ministerial_exam_screen.dart` (الصنف `MinisterialExamScreen`)، و**أُعيدت كتابة** `lib/screens/exam_screen.dart` كمُطلِق قابل للتوجيه: يعرض عدد الأسئلة الموثّقة، وحالة «قيد الإعداد» الصادقة عند الصفر، وأزرار المواد عند توفر أسئلة تفتح شاشة الامتحان الحقيقية بأسئلة المادة من قاعدة البيانات. |

**فحوصات إضافية (سليمة، لا تغيير):** أسماء خاصة مكررة (`_SeededRandom`،
`_SliderRow`، `_ResultCard`، `_QuizCard`) في ملفات مختلفة — هي أسماء
خاصة بنطاق المكتبة في Dart ولا تتعارض. و`main.dart` يشير الآن إلى
الشاشات الرسمية فقط (تحقّق به `tools/verify_merge.py`).

## 3. التحويل إلى نسخة صنعاء 2027 (قرار المستخدم 2026-11-25)

المصدر: `workspace/research_notes/sanaa-edition-yemeni-curriculum-20261125-0222/report.md`.

- `assets/data/curriculum.json` أُعيد بناؤه بالكامل (من 51KB عدن إلى
  53,320 بايت صنعاء): **51 وحدة / 391 درساً** — رياضيات 7/41، فيزياء
  9/81 + 10 تجارب، كيمياء 7/53 + 17 نشاطاً، أحياء 8/53، عربية 7/52،
  إنجليزية 6/49 + القارئان، إسلامية 7/62. `default_edition: "sanaa"`.
- وحدات العلوم/الرياضيات/الإنجليزية أُخذت من ملف عدن بعد التحقق
  الآلي من تطابق عناوينها وأعداد دروسها مع تقرير صنعاء (طبعة 2027
  موحّدة «صنعاء – عدن»)؛ والعربية/الإسلامية أُعيدت كتابتها من تقرير
  صنعاء (القراءة 9 دروس فصل أول فقط، النحو 4 وحدات، الأدب 16 + نقد 5،
  القرآن 13+2+2، الإيمان 10، الفقه 13، الحديث والتهذيب 10، السيرة 12).
- **الكيمياء: حُسم الخلاف لصالح 7 وحدات** (نسخة صنعاء 2027)؛ النسخة
  ذات 9 وحدات محفوظة كملاحظة مقارنة فقط (`conflict_resolved`)، وأُزيل
  مفتاح `variants` من البيانات.
- عدن مذكورة فقط كسطور مقارنة (`aden_comparison` في العربية
  والإسلامية + بطاقة في شاشة المنهج) — ليست محتوى رئيسياً.
- الفجوات الـ13 من تقرير صنعاء مسجّلة حرفياً في `unverified_gaps`
  (فصل القراءة الثاني، صفحات السيرة، التوزيع الفصلي الرسمي، وثيقة
  المحذوف 1447هـ، عنوان الدرس الرابع في الحديث والتهذيب، وغيرها).
- `lib/content/curriculum.dart`: تعليق المرجع + حقل `adenComparison` +
  `seedRows()` أُعيدت كتابتها بأعمدة المخطط الرسمي v2
  (مواد + وحدات + دروس مع `source`/`source_detail`/`is_demo`) —
  تُنتج 449 صف زرع (7 مواد + 51 وحدة + 391 درساً) بمعرّفات فريدة.
- `lib/screens/curriculum_screen.dart`: العنوان «نسخة صنعاء 2027»،
  بطاقة مقارنة عدن الجديدة، وبطاقة تحذير الكيمياء تظهر فقط إن وُجد
  `conflictNote` (لم يعد موجوداً).
- `docs/CURRICULUM.md` أُعيدت كتابته لصنعاء؛ و`docs/ARCHITECTURE.md`
  §11 والجدول §9 صُحّحا (459 -> 391، عدن -> صنعاء)؛ و`docs/SIZE_BUDGET.md`
  سُجّل فيه حجم `curriculum.json` المقاس.

## 4. DB v2 — الترقية

- `kDatabaseVersion`: 1 -> 2 في `lib/db/schema.dart`.
- `_migrateV1ToV2` في `database.dart`: تقرأ بيانات v1 أولاً، ثم تعيد
  بناء الجداول بالمخطط الرسمي، وتستعيد الإعدادات وإجماليات اللاعب
  والإنجازات المفتوحة، وتجمّع المحاولات القديمة في عدّادات
  (`legacy_attempts_total/correct/xp`) وقائمة المراجعة المسقَطة في
  `migration_review_dropped` — لا إسقاط صامت. **v1 لم تُشحن على أي
  جهاز**، فالترقية دفاعية؛ ووثّق الاستثناء في `docs/CONTENT_IMPORT.md`
  §6 (ابتداءً من v2: إضافي فقط، بلا استثناء).
- الزرع: `main()` يستدعي `seedCurriculumIfEmpty()` بعد فتح قاعدة
  البيانات (عند أول تشغيل فقط)؛ أي فشل لا يمنع التشغيل.
- لا أسئلة أُضيفت: بنك الأسئلة يبقى فارغاً («قيد الإعداد») — الكتب
  لم تصل ولا يوجد إذن وزارة.

## 5. CI — جاهزية الرفع إلى `ezzaldeenmansour123/Full-Mark`

- **لم يُنشأ المستودع ولم يُدفع أي شيء.** الشجرة جاهزة للرفع كما هي.
- `.github/workflows/build-apk.yml`: Java 17 + Flutter stable 3.50.1،
  **جديد:** فحص يفشل البناء إن طلب الـ manifest إذن INTERNET،
  و**جديد:** بوابة حجم تفشل البناء إن تجاوز أي APK ‏100 MB
  (104,857,600 بايت). باقي الخطوات كما هي: `analyze` و`test` و
  `build apk --release --split-per-abi` ورفع الـ APK.
- `README.md`: أُضيف قسم المستودع (الاسم `Full-Mark`، خطوات الإنشاء
  والرفع من جهة المستخدم، وتنبيه عدم وجود أي keystore/سرّ)، وحُدّثت
  الحالة إلى v0.2.0 وقسم قاعدة البيانات إلى v2. **اسم التطبيق المعروض
  ما زال عبقرية | ABQARIYA** — تغييره إلى FULL MARK غير مؤكد بعد.
- **اكتشاف مهم أثناء تجهيز الرفع:** وُجد في الشجرة مجلد `books/`
  (17MB) لم يكن ضمن نطاق الدمج الأصلي: ملف
  `books/sanaa/math-student.pdf` (‏12.6MB، ‏255 صفحة، أُنشئ
  2025-08-09 — يطابق كتاب رياضيات الطالب لنسخة صنعاء، نزّله بحث
  المناهج أثناء العمل ولم يُتحقق من محتواه صفحةً صفحة بعد) + مجلد
  `books/tmp/` فيه صفحات HTML وصور من البحث وملف `cookies.txt`
  يحوي جلسة تسجيل دخول حيّة (PHPSESSID) لموقع الكتب. **الخطر:**
  `books/` لم يكن مستثنىً في `.gitignore`، فلو رُفعت الشجرة كما هي
  لانتقل كتاب وزاري محفوظ الحقوق وملف جلسة إلى مستودع عام.
  **الإصلاح:** أُضيف `books/` إلى `.gitignore` مع تعليق يشرح السبب.
  الكتاب **ليس** محتوىً مستورداً في التطبيق بعد — لم يُستخرج منه
  أي سؤال، وبنك الأسئلة ما زال فارغاً («قيد الإعداد») حتى التحقق
  من الكتاب واعتماد الاستيراد عبر `docs/CONTENT_IMPORT.md`.
- **قائمة التحقق قبل الرفع (للمستخدم):**
  1. أنشئ مستودعاً عاماً باسم `Full-Mark` تحت `ezzaldeenmansour123`.
  2. ارفع محتويات `~/workspace/abqariya/` كاملة إلى فرع `main`
     (بما فيها `.github/` و`android/` و`assets/` و`docs/`)، وتأكّد
     قبل الدفع أن `git status` لا يظهر `books/` أبداً (مستثنى الآن
     في `.gitignore`، وتحقق منه قبل أول دفع).
  3. انتظر أول تشغيل CI: سيولّد `flutter create .` أيقونات التشغيل
     الغائبة (`mipmap/ic_launcher.png`) تلقائياً في أول تشغيل — راجع
     نتيجته، ثم يُفضَّل تثبيت الأيقونات المولّدة في المستودع.
  4. بعد نجاح أول بناء: أرسل رابط الـ APK هنا للاختبار على الهاتف.
  5. قبل أي توزيع حقيقي: أضف keystore خاصاً كـ GitHub secret
     (لا تضع أي مفتاح في المستودع أبداً).
- **تحذير CI معروف:** خطوة `flutter create .` الاحتياطية ستعمل في
  أول تشغيل لأن أيقونات التشغيل غير مضمّنة؛ هي تولّد السقالات
  الناقصة دون المساس بـ `lib/`، لكن راجع ما غيّرته في أول تشغيل.

## 6. ملفات أُضيفت / حُذفت / أُعيدت تسميتها

| الإجراء | الملف |
|---|---|
| حُذف | `lib/analytics/analytics_screen.dart` (مكرر، غير قابل للتوجيه) |
| حُذف | `lib/achievements/achievements_screen.dart` (مكرر، غير قابل للتوجيه) |
| أُعيدت تسميته | `lib/exam/exam_screen.dart` -> `lib/exam/ministerial_exam_screen.dart` (الصنف `MinisterialExamScreen`) |
| أُعيدت كتابته | `lib/db/database.dart` (تنفيذ رسمي v2)، `lib/screens/exam_screen.dart` (مُطلِق)، `docs/CURRICULUM.md` |
| أُعيد بناؤه | `assets/data/curriculum.json` (صنعاء 2027) |
| أُضيف | `MERGE_LOG.md` (هذا الملف)، `TEST_REPORT.md`، `tools/verify_merge.py` |
| حُدّث | `lib/db/schema.dart` (v2 + ترتيب الإنشاء)، `lib/content/curriculum.dart` (صنعاء + زرع رسمي)، `lib/core/progress_store.dart` (إصلاح استيراد)، `lib/screens/labs_screen.dart` (إصلاح استعلام)، `lib/screens/curriculum_screen.dart` (صنعاء + بطاقة عدن)، `lib/main.dart` (زرع المنهج عند أول تشغيل)، `.github/workflows/build-apk.yml` (فحص INTERNET + بوابة 100MB)، `README.md` (مستودع Full-Mark + v0.2.0 + DB v2)، `docs/ARCHITECTURE.md` (§11)، `docs/SIZE_BUDGET.md` (حجم curriculum.json المقاس)، `docs/CONTENT_IMPORT.md` (§6 استثناء v1->v2 + سجل التغييرات) |

## 7. ما لم يتغير (بقي كما هو عمداً)

- اسم التطبيق المعروض وحزمة أندرويد: `عبقرية` / `com.abqariya.app`
  (تغيير الاسم إلى FULL MARK يحتاج تأكيد المستخدم).
- الاعتماديات في `pubspec.yaml` (sqflite ^2.4.6، path ^1.9.1) — لم
  تتغير؛ لا اعتماديات جديدة أُضيفت في الدمج.
- محرك الألعاب والمختبرات والتحليلات: لم تُمسّ منطقاً — فقط حُسمت
  التكرارات حولها.

## تصحيح لاحق — الكيمياء 9 وحدات (2026-11-25)
تصحيح لأرقام هذا السجل: فهرس الكيمياء في ملف PDF المنزَّل نفسه
(`books/sanaa/chemistry-student.pdf`، 192 صفحة) هو **9 وحدات / 61 درساً**
(فهرس مصوَّر ص 7–10، قُرئ بصرياً)، لا 7/53 كما ورد أعلاه. فهرس الـ7 وحدات
كان فهرس صفحة الموقع. الأرقام الصحيحة بعد التصحيح: **53 وحدة / 399 درساً**،
وصفوف الزرع **459** (7 مواد + 53 وحدة + 399 درساً). حُدّثت
`assets/data/curriculum.json` و`tools/verify_merge.py` (60/60) و`docs/CURRICULUM.md`
و`docs/ARCHITECTURE.md` و`README.md` و`docs/SIZE_BUDGET.md` وشاشة المنهج.

## تصحيح لاحق — الأحياء: الوحدة 6 تقانة حيوية (2026-11-25)
تصحيح لأرقام هذا السجل: فهرس الأحياء في صفحة الموقع كان يقول إن
الوحدة السادسة «التغذية البشرية» (8 دروس)، لكن ملف PDF المنزَّل نفسه
(`books/sanaa/biology-student.pdf`، 224 صفحة فعلية) فهرسُه المصوَّر
(ص 7) ومقدمتُه (ص 5) يقولان إن الوحدة السادسة هي **«التقانة الحيوية»
(9 دروس)** — ولا توجد وحدة تغذية بشرية في هذا الكتاب أصلاً. الأرقام
الصحيحة بعد التصحيح: **53 وحدة / 400 درساً** (الأحياء 8/54)، وصفوف
الزرع **460** (7 مواد + 53 وحدة + 400 درس). مع التصحيح صُحّحت عناوين
أحياء أخرى من الفهرس المصوَّر (الألياف العصبية، أعضاء الحس، التنظيم
الهرموني، الشكل الجيني، دورة حمض DNA، ملوثات الغذاء، التاريخ المطلق
للصخور، نبذة من تاريخ الأرض)، وأُضيفت أرقام صفحات الدروس لكل وحدات
الأحياء والفيزياء (`lesson_pages`)، وصُحّح عدد صفحات كتابي الطالب:
الأحياء 224 (لا 227)، الفيزياء 216 (لا 219). حُدّثت
`assets/data/curriculum.json` و`tools/verify_merge.py` و`docs/CURRICULUM.md`
(القرار 3) و`docs/ARCHITECTURE.md` و`README.md` و`docs/SIZE_BUDGET.md`.

## بنك الأسئلة — المرحلة 1 (2026-11-25)
بُني بنك أسئلة موثق من الكتب الـ18 المنزَّلة: **7 حزم، 798 سؤالاً
(711 اختيار من متعدد + 87 صح/خطأ)، 400/400 درس مغطى**، في
`assets/data/questions/` (1.1 ميغابايت)؛ التقرير الكامل
`QUESTIONS_REPORT.md`. التحقق: `tools/validate_questions.py`
**9438 فحصاً، 0 فشل**؛ `tools/verify_merge.py` **72/72 PASS**؛
`tools/verify_logic.py` **ALL CHECKS PASSED**. الحزم السبع مسجلة في
`pubspec.yaml` ومربوطة بزرع قاعدة البيانات (`seedQuestionPacks`).
تصحيحان إضافيان مع البنك: عنوانا «خطورة النفاق» (إيمان) و«تداعى عليكم
الأمم» (حديث) من الفهرس المصوَّر؛ وعنوان «الإسلام دين وعي وزكاة» ثبت
أنه سليم أصلاً (صفر أحرف بديلة في الملف).
