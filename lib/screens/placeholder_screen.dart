import 'package:material_ui/material_ui.dart';

/// شاشة «قيد الإعداد» القابلة لإعادة الاستخدام.
///
/// مبدأ الصدق في هذا التطبيق: أي ميزة أو محتوى غير جاهز بعد يفتح شاشة
/// حقيقية كهذه — تشرح ما القادم ومتى — ولا يظهر أبدًا زر ميّت أو سؤال
/// مزيّف يقدَّم على أنه من المنهج.
class PlaceholderArgs {
  const PlaceholderArgs({
    required this.title,
    this.subtitle,
    this.comingSoon = const <String>[],
    this.icon = Icons.construction,
  });

  final String title;
  final String? subtitle;
  final List<String> comingSoon;
  final IconData icon;
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.args});

  final PlaceholderArgs args;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(args.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 24),
          Icon(
            args.icon,
            size: 72,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'قيد الإعداد',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            args.subtitle ??
                'نعمل على تجهيز هذا القسم بعناية من المنهج اليمني المعتمد، '
                    'ولن نعرض فيه أي محتوى قبل التأكد من صحته.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          if (args.comingSoon.isNotEmpty) ...<Widget>[
            const SizedBox(height: 28),
            Text(
              'ما القادم هنا؟',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...args.comingSoon.map(
              (String item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.hourglass_top),
                  title: Text(item),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('عودة'),
          ),
        ],
      ),
    );
  }
}
