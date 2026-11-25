import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../core/backup.dart';
import '../core/version.dart';
import '../core/progress_store.dart';
import '../core/routes.dart';
import '../db/database.dart';

/// الإعدادات: الوضع الداكن، النسخ الاحتياطي (تصدير/استيراد حقيقيان)،
/// إعادة تعيين التقدّم (بتأكيد)، والنسخة الدراسية، وحول التطبيق
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
  bool _busy = false;
  String? _backupMessage;

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

  String _todayStamp() {
    final DateTime now = DateTime.now();
    final String y = '${now.year}';
    final String m = '${now.month}'.padLeft(2, '0');
    final String d = '${now.day}'.padLeft(2, '0');
    return '$y$m$d';
  }

  /// تصدير النسخة الاحتياطية: يُبنى ملف JSON من تقدّمك الحالي
  /// (محاولات، إنجازات، مراجعة، امتحانات، تقدّم، إعدادات)، ثم يُحفظ
  /// عبر نافذة الحفظ النظامية، ثم تُعرض ورقة المشاركة النظامية
  /// لإرساله إلى جهاز آخر إن أردتِ. الملف محفوظ حتى لو أُلغيت
  /// المشاركة.
  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _backupMessage = null;
    });
    try {
      final Map<String, Object?> data = await buildBackupData(
        DatabaseHelper.instance,
        appVersion: kAppVersion,
      );
      final String json = encodeBackupJson(data);
      final Uint8List bytes =
          Uint8List.fromList(utf8.encode(json));
      final String fileName = 'full-mark-backup-${_todayStamp()}.json';
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: fileName,
        bytes: bytes,
      );
      if (path == null) {
        if (mounted) {
          setState(() =>
              _backupMessage = 'أُلغي الحفظ — لم يُحفظ أي ملف.');
        }
        return;
      }
      // المشاركة إضافة اختيارية: الملف محفوظ أصلاً في `path`، فأي
      // فشل هنا لا يعني فشل التصدير.
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: <XFile>[
              XFile.fromData(bytes, mimeType: 'application/json'),
            ],
            fileNameOverrides: <String>[fileName],
            text: 'نسخة احتياطية من تقدّمك في فُل مارك',
          ),
        );
      } catch (_) {
        // تجاهل: الملف محفوظ بالفعل.
      }
      if (mounted) {
        setState(() => _backupMessage = 'تم حفظ النسخة الاحتياطية.');
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _backupMessage = 'تعذّر حفظ النسخة الاحتياطية: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// استيراد نسخة احتياطية: يُختار ملف JSON عبر منتقي الملفات
  /// النظامي، يُتحقق منه كاملاً أولاً، ثم يُعرض ملخّص ما سيُستعاد
  /// للتأكيد، ثم يُستعاد في معاملة واحدة. ملف تالف لا يغيّر شيئاً،
  /// والاستيراد يدمج مع تقدّمك الحالي ولا يمسحه أبداً.
  Future<void> _importBackup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _backupMessage = null;
    });
    try {
      final FilePickerResult? picked =
          await FilePicker.platform.pickFiles(
        dialogTitle: 'اختيار ملف نسخة احتياطية',
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        if (mounted) {
          setState(() =>
              _backupMessage = 'أُلغي الاستيراد — لم يُختر أي ملف.');
        }
        return;
      }
      final Uint8List? bytes = picked.files.first.bytes;
      if (bytes == null) {
        if (mounted) {
          setState(() => _backupMessage = 'تعذّر قراءة الملف المختار.');
        }
        return;
      }
      final Map<String, dynamic> data =
          decodeBackupJson(utf8.decode(bytes));
      final BackupImportSummary preview = await previewBackupImport(
        DatabaseHelper.instance,
        data,
      );
      if (!mounted) return;
      if (preview.isEmpty) {
        setState(() =>
            _backupMessage = 'الملف لا يحتوي على أي بيانات تقدّم — لم يتغيّر شيء.');
        return;
      }
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('استيراد النسخة الاحتياطية؟'),
          content: SingleChildScrollView(
            child: Text(
              'سيُدمج تقدّم الملف مع تقدّمك الحالي — لن يُمسح شيء، '
              'ولن تتكرر المحاولات المستعادة.\n\n'
              '${preview.describeAr()}',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('استيراد'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        if (mounted) {
          setState(() =>
              _backupMessage = 'أُلغي الاستيراد — لم يتغيّر شيء.');
        }
        return;
      }
      final BackupImportSummary done = await restoreBackupData(
        DatabaseHelper.instance,
        data,
      );
      if (!mounted) return;
      if (done.darkModeValue != null) {
        await widget.onDarkModeChanged(done.darkModeValue!);
        setState(() => _darkMode = done.darkModeValue!);
      }
      setState(() => _backupMessage =
          'تم استيراد النسخة الاحتياطية بنجاح.\n${done.describeAr()}');
    } on FormatException catch (e) {
      if (mounted) setState(() => _backupMessage = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _backupMessage = 'تعذّر استيراد الملف: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حول فُل مارك'),
        content: const SingleChildScrollView(
          child: Text(
            'فُل مارك | FULL MARK\n'
            'منصة ألعاب تعليمية للصف الثالث الثانوي العلمي — المنهج اليمني.\n\n'
            '• تعمل دون اتصال بالإنترنت بالكامل.\n'
            '• بلا إعلانات وبلا حسابات وبلا اشتراكات.\n'
            '• كل بياناتك محفوظة على جهازك فقط.\n'
            '• المحتوى التعليمي من الكتب الوزارية المعتمدة فقط، '
            'وما لم يُعتمد بعد يظهر بصراحة على أنه غير متوفر بعد.\n\n'
            'الشعار: افهم، جرّب، اكتشف، وتفوّق.\n\n'
            'إهداء إلى منى منصور.',
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
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    'النسخ الاحتياطي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('تصدير نسخة احتياطية'),
                  subtitle: const Text(
                    'حفظ الخبرة والنجوم والمحاولات والإنجازات والمراجعة في ملف JSON',
                  ),
                  onTap: _exportBackup,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Text(
                    'ملاحظة: النسخة تحفظ التقدّم فقط (محاولات/إنجازات/مراجعة) — '
                    'أما الأسئلة والمنهج فهي داخل التطبيق ويجب أن تكون موجودة '
                    'على الجهاز المستقبِل قبل الاستيراد.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('استيراد نسخة احتياطية'),
                  subtitle: const Text(
                    'استعادة تقدّم من ملف سابق — يُدمج مع تقدّمك ولا يمسحه',
                  ),
                  onTap: _importBackup,
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: LinearProgressIndicator(),
                  ),
                if (_backupMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_backupMessage!),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('إعادة تعيين التقدّم'),
                  subtitle: const Text('مسح الخبرة والنجوم والمحاولات'),
                  onTap: _confirmReset,
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('النسخة الدراسية'),
                  subtitle: const Text('صنعاء 2027 — النسخة المعتمدة في التطبيق'),
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.edition),
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
                  subtitle: Text(kAppVersion),
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
