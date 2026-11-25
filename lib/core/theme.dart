import 'package:flutter/material.dart';

/// لوحة ألوان عَبْقَرِيّة: علمية حديثة (كحلي / تركوازي / ذهبي)، وليست طفولية.
///
/// - الكحلي: العمق والثقة (الخلفيات الداكنة والعناوين).
/// - التركوازي (Teal): التفاعل والتقدّم.
/// - الذهبي: الإنجاز والنجوم والمستوى.
/// - العاجي: خلفية الوضع الفاتح الهادئة لراحة القراءة الطويلة.
class AbqariyaColors {
  AbqariyaColors._();

  static const Color navy = Color(0xFF0B2545);
  static const Color navyDeep = Color(0xFF081A33);
  static const Color navySoft = Color(0xFF13315C);
  static const Color teal = Color(0xFF0E7C7B);
  static const Color tealLight = Color(0xFF17A398);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldSoft = Color(0xFFE3C766);
  static const Color ivory = Color(0xFFF7F3EA);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1B2A41);
  static const Color muted = Color(0xFF5A6B84);
  static const Color danger = Color(0xFFB3261E);

  /// ألوان العوالم السبعة — مميزة لكل عالم، ومتباينة بما يكفي في الوضعين.
  static const Map<String, Color> worldColors = <String, Color>{
    'math': Color(0xFF2563EB), // رياضيات — أزرق
    'physics': Color(0xFF7C3AED), // فيزياء — بنفسجي
    'chemistry': Color(0xFF059669), // كيمياء — أخضر
    'biology': Color(0xFF65A30D), // أحياء — أخضر ليموني
    'arabic': Color(0xFFB45309), // عربية — كهرماني
    'english': Color(0xFFDB2777), // إنجليزية — وردي
    'islamic': Color(0xFF0E7C7B), // تربية إسلامية — تركوازي
  };
}

/// ثيمات التطبيق (فاتح / داكن) — خط واحد واضح، وزوايا مستديرة هادئة.
class AbqariyaTheme {
  AbqariyaTheme._();

  static const String? _fontFamily = null; // الخط الافتراضي للنظام (عربي سليم) في v1.

  static ThemeData get lightTheme {
    const ColorScheme scheme = ColorScheme.light(
      primary: AbqariyaColors.navy,
      secondary: AbqariyaColors.teal,
      tertiary: AbqariyaColors.gold,
      surface: AbqariyaColors.paper,
      onSurface: AbqariyaColors.ink,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AbqariyaColors.ivory,
      fontFamily: _fontFamily,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AbqariyaColors.navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AbqariyaColors.navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AbqariyaColors.navy,
          side: const BorderSide(color: AbqariyaColors.navy),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: AbqariyaColors.paper,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AbqariyaColors.paper,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AbqariyaColors.teal,
      ),
    );
  }

  static ThemeData get darkTheme {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AbqariyaColors.tealLight,
      secondary: AbqariyaColors.goldSoft,
      tertiary: AbqariyaColors.gold,
      surface: Color(0xFF12233D),
      onSurface: Color(0xFFEAF0F7),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AbqariyaColors.navyDeep,
      fontFamily: _fontFamily,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AbqariyaColors.navyDeep,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AbqariyaColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AbqariyaColors.goldSoft,
          side: const BorderSide(color: AbqariyaColors.goldSoft),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF12233D),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: const Color(0xFF12233D),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AbqariyaColors.tealLight,
      ),
    );
  }
}
