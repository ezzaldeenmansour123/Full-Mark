/// أسماء المسارات — مرجع واحد يتشاركه كل التنقل في التطبيق.
///
/// ملف مستقل عمدًا حتى لا تستورد الشاشات `main.dart`
/// (استيراد دائري) — كل شاشة تستورد هذا الملف فقط.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String worlds = '/worlds';
  static const String labs = '/labs';
  static const String lab = '/lab';
  static const String dailyChallenge = '/daily';
  static const String exam = '/exam';
  static const String analytics = '/analytics';
  static const String achievements = '/achievements';
  static const String review = '/review';
  static const String settings = '/settings';
  static const String placeholder = '/placeholder';
}
