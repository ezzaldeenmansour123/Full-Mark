import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalCupertinoLocalizations, GlobalMaterialLocalizations;

import 'content/curriculum.dart';
import 'content/question_packs.dart';
import 'core/progress_store.dart';
import 'labs/cell_3d.dart';
import 'db/database.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'screens/achievements_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/daily_challenge_screen.dart';
import 'screens/edition_screen.dart';
import 'screens/exam_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lab_detail_screen.dart';
import 'screens/labs_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/worlds_screen.dart';

/// نقطة دخول التطبيق.
///
/// يفتح قاعدة البيانات المحلية قبل بناء الواجهة (حفظ تلقائي واستئناف
/// آخر مرحلة يعتمدان عليها)، ويقرأ تفضيل الوضع الداكن المخزّن محليًا.
/// فشل فتح قاعدة البيانات كان ينهار قبل أول إطار دون أي رسالة — الآن
/// تظهر شاشة خطأ صريحة. وفشل الزرع كان يُبتلع بصمت — الآن يُسجَّل
/// في debugPrint ويظهر تنبيه في الشاشة الرئيسية.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ProgressStore store = SqliteProgressStore();
  String? initError;
  try {
    await store.init();
  } catch (e) {
    initError = 'تعذّر فتح قاعدة البيانات المحلية: $e';
    debugPrint('ABQARIYA init error: $e');
  }
  String? seedError;
  if (initError == null) {
    // زرع هيكل منهج صنعاء 2027 (وحدات/دروس فقط) عند أول تشغيل.
    try {
      await DatabaseHelper.instance.seedCurriculumIfEmpty(
        () async => (await CurriculumData.load()).seedRows(),
      );
    } catch (e) {
      seedError = 'تعذّر تحميل هيكل المنهج: $e';
      debugPrint('ABQARIYA curriculum seed error: $e');
    }
    // زرع حزم الأسئلة الموثقة (بعد المنهج، لمفاتيحها الأجنبية).
    try {
      await DatabaseHelper.instance
          .seedQuestionPacks(await QuestionPacks.loadAll());
    } catch (e) {
      final String msg = 'تعذّر تحميل حزم الأسئلة: $e';
      seedError = seedError == null ? msg : '$seedError\n$msg';
      debugPrint('ABQARIYA questions seed error: $e');
    }
    // حزمة مفقودة أو تالفة تُتخطَّى — لكن لا تُخفى: تُذكر في التنبيه.
    final List<String> skipped = QuestionPacks.lastSkippedAssets;
    if (skipped.isNotEmpty) {
      final String note =
          'حزم أسئلة تُخطّيت (ملف مفقود أو تالف): ${skipped.join('، ')}';
      seedError = seedError == null ? note : '$seedError\n$note';
    }
  }
  bool darkMode = false;
  try {
    darkMode = await store.isDarkMode();
  } catch (e) {
    debugPrint('ABQARIYA dark_mode read error: $e');
  }
  runApp(AbqariyaApp(
    store: store,
    startDarkMode: darkMode,
    initError: initError,
    seedError: seedError,
  ));
}

/// أسماء المسارات — مرجع واحد يتشاركه كل التنقل في التطبيق.
/// يوثَّق هنا ليتكامل معه المنسّق ووكلاء الشاشات الآخرون.
/// (التعريف الفعلي في `lib/core/routes.dart` لتجنّب الاستيراد الدائري.)
class AbqariyaApp extends StatefulWidget {
  const AbqariyaApp({
    super.key,
    required this.store,
    required this.startDarkMode,
    this.initError,
    this.seedError,
  });

  final ProgressStore store;
  final bool startDarkMode;

  /// Set when the local database could not be opened at all — the app
  /// then shows an error-only screen instead of crashing before the
  /// first frame.
  final String? initError;

  /// Set when seeding (curriculum / question packs) failed or a pack
  /// was skipped — shown as a banner on the home screen.
  final String? seedError;

  @override
  State<AbqariyaApp> createState() => _AbqariyaAppState();
}

class _AbqariyaAppState extends State<AbqariyaApp> {
  late final ValueNotifier<ThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = ValueNotifier<ThemeMode>(
      widget.startDarkMode ? ThemeMode.dark : ThemeMode.light,
    );
  }

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  Future<void> _setDarkMode(bool enabled) async {
    try {
      await widget.store.setDarkMode(enabled);
    } catch (e) {
      // فشل الحفظ لا يمنع تبديل المظهر في الجلسة الحالية.
      debugPrint('ABQARIYA setDarkMode error: $e');
    }
    _themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    // Database open failure: an honest error-only screen, never a
    // crash before the first frame and never a fake empty home.
    final String? initError = widget.initError;
    if (initError != null) {
      return MaterialApp(
        title: 'فُل مارك',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        home: Scaffold(
          appBar: AppBar(title: const Text('فُل مارك')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'تعذّر تشغيل التطبيق.\n$initError\n\n'
                'جرّب إعادة تشغيل التطبيق؛ إن تكررت المشكلة فأعد تثبيته '
                '(سيُفقد التقدّم المحفوظ على الجهاز).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (BuildContext context, ThemeMode mode, Widget? child) {
        return MaterialApp(
          title: 'فُل مارك',
          debugShowCheckedModeBanner: false,
          // عربي RTL بالكامل.
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AbqariyaTheme.lightTheme,
          darkTheme: AbqariyaTheme.darkTheme,
          themeMode: mode,
          initialRoute: AppRoutes.home,
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final ProgressStore store = widget.store;
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => HomeScreen(
            store: store,
            seedError: widget.seedError,
          ),
        );
      case AppRoutes.worlds:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const WorldsScreen(),
        );
      case AppRoutes.labs:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LabsScreen(),
        );
      case AppRoutes.lab:
        final LabDetailScreen? labScreen =
            LabDetailScreen.fromRoute(settings.arguments);
        if (labScreen == null) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const PlaceholderScreen(
              args: PlaceholderArgs(
                title: 'المختبر غير موجود',
                subtitle: 'تحقق من معرّف المختبر وحاول مجددًا.',
              ),
            ),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => labScreen,
        );
      case AppRoutes.dailyChallenge:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const DailyChallengeScreen(),
        );
      case AppRoutes.exam:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ExamScreen(),
        );
      case AppRoutes.edition:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const EditionScreen(),
        );
      case AppRoutes.cell3d:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Cell3DScreen(),
        );
      case AppRoutes.analytics:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AnalyticsScreen(),
        );
      case AppRoutes.achievements:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AchievementsScreen(),
        );
      case AppRoutes.review:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReviewScreen(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SettingsScreen(
            store: store,
            onDarkModeChanged: _setDarkMode,
          ),
        );
      case AppRoutes.placeholder:
        final Object? args = settings.arguments;
        final PlaceholderArgs placeholderArgs = args is PlaceholderArgs
            ? args
            : const PlaceholderArgs(title: 'الصفحة غير موجودة');
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PlaceholderScreen(args: placeholderArgs),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PlaceholderScreen(
            args: PlaceholderArgs(
              title: 'الصفحة غير موجودة',
              subtitle: 'يبدو أن الرابط الذي فتحتِه غير متوفر في هذه النسخة.',
            ),
          ),
        );
    }
  }
}
