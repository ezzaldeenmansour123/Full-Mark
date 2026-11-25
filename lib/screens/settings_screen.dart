import 'package:material_ui/material_ui.dart';

import '../core/progress_store.dart';

/// الإعدادات: الوضع الداكن، إعادة تعيين التقدّم (بتأكيد)، وحول التطبيق
/// (دون اتصال / بلا إعلانات / بلا حسابات) ورقم الإصدار.
/// لا يوجد مبدّل صوت هنا: لا توجد أي أصوات في التطبيق بعد، فلا معنى
/// لمبدّل يتحكم بشيء غير موجود.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.onDarkModeChanged,
  });

  final ProgressStore store;
  final Future<void> Function(bool enabled) onDarkModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bool dark = await widget.store.isDarkMode();
    if (!mounted) return;
    setState(() {
      _darkMode = dark;
      _loading = false;
    });
  }

  Future<void> _confirmReset() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('إعادة تعيين التقدّم؟'),
        content: const Text(
          'سيُمسح كل تقدّمك: نقاط الخبرة والنجوم والمحاولات والإنجازات.\n'
          'لا يمكن التراجع عن هذا الإجراء.\n'
          'لن يُمسح المحتوى التعليمي ولا الإعدادات.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('نعم، امسح تقدّمي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.resetAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إعادة تعيين تقدّمك')),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حول عَبْقَرِيّة'),
        content: const SingleChildScrollView(
          child: Text(
            'عَبْقَرِيّة | ABQARIYA\n'
            'منصة ألعاب تعليمية للصف الثالث الثانوي العلمي — المنهج اليمني.\n\n'
            '• تعمل دون اتصال بالإنترنت بالكامل.\n'
            '• بلا إعلانات وبلا حسابات وبلا اشتراكات.\n'
            '• كل بياناتك محفوظة على جهازك فقط.\n'
            '• المحتوى التعليمي من الكتب الوزارية المعتمدة فقط، '
            'وما لم يُعتمد بعد يظهر بصراحة على أنه غير متوفر بعد.\n\n'
            'الشعار: افهم، جرّب، اكتشف، وتفوّق.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                SwitchListTile(
                  title: const Text('الوضع الداكن'),
                  subtitle: const Text('مريح للعين في الإضاءة الخافتة'),
                  value: _darkMode,
                  onChanged: (bool value) async {
                    await widget.onDarkModeChanged(value);
                    setState(() => _darkMode = value);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('إعادة تعيين التقدّم'),
                  subtitle: const Text('مسح الخبرة والنجوم والمحاولات'),
                  onTap: _confirmReset,
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('حول التطبيق'),
                  subtitle: const Text('دون اتصال • بلا إعلانات • بلا حسابات'),
                  onTap: _showAbout,
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.verified),
                  title: Text('الإصدار'),
                  subtitle: Text('0.1.2+3'),
                ),
                const ListTile(
                  leading: Icon(Icons.wifi_off),
                  title: Text('الاتصال'),
                  subtitle: Text(
                    'التطبيق لا يطلب إذن الإنترنت أصلًا — كل شيء يعمل دون اتصال.',
                  ),
                ),
              ],
            ),
    );
  }
}
