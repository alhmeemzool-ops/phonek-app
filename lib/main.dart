import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';
import 'screens/home_screen.dart';
import 'services/update_service.dart';
import 'features/merchant_badges/level_up_celebration.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hnuzqjotgmdgqjpbrqlb.supabase.co',
    publishableKey: 'sb_publishable_3XRVtwMyK5nNOvNpNDT7Mg_4nyH7FC1',
  );

  runApp(const PhoneKApp());
}

class PhoneKApp extends StatelessWidget {
  const PhoneKApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'PhoneK - فونك',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          return Directionality(textDirection: TextDirection.rtl, child: child!);
        },
        home: const PhoneKUpdateGate(child: MerchantLevelUpGate(child: HomeScreen())),
      ),
    );
  }
}

class PhoneKUpdateGate extends StatefulWidget {
  final Widget child;

  const PhoneKUpdateGate({super.key, required this.child});

  @override
  State<PhoneKUpdateGate> createState() => _PhoneKUpdateGateState();
}

class _PhoneKUpdateGateState extends State<PhoneKUpdateGate>
    with WidgetsBindingObserver {
  bool _dialogShown = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_dialogShown) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    _checking = true;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _dialogShown) {
      _checking = false;
      return;
    }

    final update = await PhoneKUpdateService.check();
    if (!mounted || update == null) {
      _checking = false;
      return;
    }

    _dialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (dialogContext) {
        return _UpdateDialog(update: update);
      },
    );
    _checking = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatefulWidget {
  final PhoneKUpdate update;

  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  bool _downloading = false;
  String? _error;

  Future<void> _install() async {
    final canInstall = await PhoneKUpdateService.canInstallPackages();
    if (!canInstall) {
      if (!mounted) return;
      setState(() {
        _error = 'يجب السماح لـ PhoneK بتثبيت التطبيقات من هذا المصدر قبل بدء التحديث.';
      });
      return;
    }

    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      await PhoneKUpdateService.downloadAndInstall(
        widget.update,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
    } on PhoneKUpdateException catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = error.reason == 'install_permission'
            ? 'تم تنزيل التحديث. اسمح للتطبيق بتثبيت التطبيقات من هذا المصدر ثم اضغط «تحديث الآن» مرة أخرى.'
            : 'تعذر بدء تثبيت التحديث. حاول مرة أخرى.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'تعذر تنزيل التحديث. تأكد من اتصال الإنترنت والرابط ثم حاول مرة أخرى.';
      });
    }
  }

  Future<void> _openInstallPermissionSettings() async {
    try {
      await PhoneKUpdateService.openInstallPermissionSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر فتح إعدادات الصلاحية. افتح إعدادات Android ثم فعّل السماح لـ PhoneK بتثبيت التطبيقات.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.update.mandatory && !_downloading,
      child: AlertDialog(
        title: const Text('تحديث جديد متاح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الإصدار ${widget.update.versionName} أصبح متاحاً لـ PhoneK.'),
            if (widget.update.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(widget.update.notes),
            ],
            if (_downloading) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text('جاري تنزيل النسخة الأحدث... ${(_progress * 100).round()}%'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              if (_error == 'يجب السماح لـ PhoneK بتثبيت التطبيقات من هذا المصدر قبل بدء التحديث.' ||
                  _error == 'تم تنزيل التحديث. اسمح للتطبيق بتثبيت التطبيقات من هذا المصدر ثم اضغط «تحديث الآن» مرة أخرى.') ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openInstallPermissionSettings,
                  icon: const Icon(Icons.security_outlined),
                  label: const Text('السماح بالتثبيت من هذا المصدر'),
                ),
              ],
            ],
          ],
        ),
        actions: [
          if (!widget.update.mandatory && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لاحقاً'),
            ),
          FilledButton(
            onPressed: _downloading ? null : _install,
            child: Text(_downloading ? 'جاري التحديث...' : 'تحديث الآن'),
          ),
        ],
      ),
    );
  }
}
