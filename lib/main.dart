import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalCupertinoLocalizations, GlobalMaterialLocalizations;

import 'content/curriculum.dart';
import 'content/question_packs.dart';
import 'core/progress_store.dart';
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
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ProgressStore store = SqliteProgressStore();
  await store.init();
  // زرع هيكل منهج صنعاء 2027 (وحدات/دروس فقط) عند أول تشغيل — إن كان
  // جدول الوحدات فارغاً. أي فشل هنا لا يمنع التشغيل.
  try {
    await DatabaseHelper.instance.seedCurriculumIfEmpty(
      () async => (await CurriculumData.load()).seedRows(),
    );
  } catch (_) {
    // يبقى التطبيق يعمل بهيكل فارغ صادق («قيد الإعداد»).
  }
  // زرع حزم الأسئلة الموثقة (بعد المنهج، لمفاتيحها الأجنبية) — حزمة
  // مفقودة أو تالفة تُتخطَّى وتبقى مادتها «قيد الإعداد».
  try {
    await DatabaseHelper.instance
        .seedQuestionPacks(await QuestionPacks.loadAll());
  } catch (_) {
    // يبقى التطبيق يعمل بلا أسئلة صادق («قيد الإعداد»).
  }
  final bool darkMode = await store.isDarkMode();
  runApp(AbqariyaApp(store: store, startDarkMode: darkMode));
}

/// أسماء المسارات — مرجع واحد يتشاركه كل التنقل في التطبيق.
/// يوثَّق هنا ليتكامل معه المنسّق ووكلاء الشاشات الآخرون.
/// (التعريف الفعلي في `lib/core/routes.dart` لتجنّب الاستيراد الدائري.)
class AbqariyaApp extends StatefulWidget {
  const AbqariyaApp({
    super.key,
    required this.store,
    required this.startDarkMode,
  });

  final ProgressStore store;
  final bool startDarkMode;

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
    await widget.store.setDarkMode(enabled);
    _themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (BuildContext context, ThemeMode mode, Widget? child) {
        return MaterialApp(
          title: 'عبقرية',
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
          builder: (_) => HomeScreen(store: store),
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
