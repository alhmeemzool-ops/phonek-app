import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';

enum _Stage { ready, working, waitingInstaller, needsPermission, failed }

/// نافذة التحديث الكاملة: عرض الإصدار، مراحل التنزيل، انتظار شاشة التثبيت،
/// طلب الصلاحية، وعرض سبب أي فشل حقيقي مع زر إعادة المحاولة.
class PhoneKUpdateDialog extends StatefulWidget {
  final PhoneKUpdate update;

  const PhoneKUpdateDialog({super.key, required this.update});

  @override
  State<PhoneKUpdateDialog> createState() => _PhoneKUpdateDialogState();
}

class _PhoneKUpdateDialogState extends State<PhoneKUpdateDialog>
    with WidgetsBindingObserver {
  _Stage _stage = _Stage.ready;
  PhoneKUpdatePhase _phase = PhoneKUpdatePhase.preparing;
  double _progress = 0;
  int _lastPercent = -1;
  String? _error;
  String? _detail;
  bool _softError = false;
  bool _copied = false;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PhoneKUpdateService.installStatus.addListener(_onInstallStatus);
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PhoneKUpdateService.installStatus.removeListener(_onInstallStatus);
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _currentVersion = info.version);
    } catch (_) {
      // عرض الإصدار الحالي اختياري.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_stage == _Stage.needsPermission) {
      _checkPermissionAndContinue();
    } else if (_stage == _Stage.waitingInstaller) {
      _pollInstallResult();
    }
  }

  void _onInstallStatus() {
    final status = PhoneKUpdateService.installStatus.value;
    if (status == null) return;
    _applyInstallStatus(status);
  }

  Future<void> _pollInstallResult() async {
    final status = await PhoneKUpdateService.lastInstallResult();
    if (!mounted || status == null || _stage != _Stage.waitingInstaller) return;
    _applyInstallStatus(status);
  }

  void _applyInstallStatus(PhoneKInstallStatus status) {
    if (!mounted || status.isSuccess) return;
    if (status.isPending) {
      setState(() {
        _stage = _Stage.waitingInstaller;
        _error = null;
        _detail = null;
      });
      return;
    }
    if (status.code == PhoneKInstallStatus.invalid) {
      PhoneKUpdateService.discardCachedApk(widget.update);
    }
    final extra = status.message.isEmpty ? '' : ' | ${status.message}';
    setState(() {
      _stage = _Stage.failed;
      _softError = status.isCancelled;
      _error = status.userMessage;
      _detail = 'status=${status.code}$extra';
      _copied = false;
    });
  }

  Future<void> _checkPermissionAndContinue() async {
    if (!mounted || _stage != _Stage.needsPermission) return;
    final canInstall = await PhoneKUpdateService.canInstallPackages();
    if (!mounted || !canInstall || _stage != _Stage.needsPermission) return;
    await _install();
  }

  Future<void> _install() async {
    if (_stage == _Stage.working) return;
    setState(() {
      _stage = _Stage.working;
      _phase = PhoneKUpdatePhase.preparing;
      _progress = 0;
      _lastPercent = -1;
      _error = null;
      _detail = null;
      _softError = false;
      _copied = false;
    });

    try {
      final canInstall = await PhoneKUpdateService.canInstallPackages();
      if (!canInstall) {
        if (!mounted) return;
        setState(() {
          _stage = _Stage.needsPermission;
          _error =
              'يجب السماح لـ PhoneK بتثبيت التطبيقات من هذا المصدر قبل بدء التحديث.';
        });
        return;
      }

      await PhoneKUpdateService.downloadAndInstall(
        widget.update,
        onProgress: (value) {
          if (!mounted) return;
          final percent = (value * 100).round();
          if (percent == _lastPercent) return;
          _lastPercent = percent;
          setState(() => _progress = value);
        },
        onPhase: (phase) {
          if (mounted) setState(() => _phase = phase);
        },
      );
      if (!mounted) return;
      // قد يكون النظام أبلغ بنتيجة (فشل/إلغاء) قبل وصولنا هنا؛ لا نكتبها فوقها.
      if (_stage == _Stage.working) {
        setState(() {
          _stage = _Stage.waitingInstaller;
          _progress = 1.0;
        });
      }
    } on PhoneKUpdateException catch (error) {
      debugPrint('PhoneK update failed: ${error.reason} ${error.detail ?? ''}');
      if (!mounted) return;
      final needsPermission = error.reason == 'install_permission';
      setState(() {
        _stage = needsPermission ? _Stage.needsPermission : _Stage.failed;
        _softError = false;
        _error = needsPermission
            ? 'تم تنزيل التحديث. اسمح للتطبيق بتثبيت التطبيقات من هذا المصدر ثم اضغط «متابعة التحديث».'
            : error.userMessage;
        _detail = needsPermission ? null : error.detail;
        _copied = false;
      });
    } catch (error) {
      debugPrint('PhoneK update unexpected error: $error');
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _softError = false;
        _error = 'حدث خطأ غير متوقع أثناء التحديث. أعد المحاولة.';
        _detail = error.toString();
        _copied = false;
      });
    }
  }

  Future<void> _openInstallPermissionSettings() async {
    try {
      await PhoneKUpdateService.openInstallPermissionSettings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.needsPermission;
        _error =
            'تعذر فتح إعدادات الصلاحية. افتح إعدادات أندرويد ثم فعّل السماح لـ PhoneK بتثبيت التطبيقات.';
        _detail = error.toString();
      });
    }
  }

  Future<void> _copyDetails() async {
    final current = _currentVersion ?? '?';
    final text = 'PhoneK $current -> ${widget.update.versionName} '
        '(${widget.update.versionCode})\n${_error ?? ''}\n${_detail ?? ''}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = true);
  }

  String _phaseLabel(PhoneKUpdatePhase phase) {
    switch (phase) {
      case PhoneKUpdatePhase.preparing:
        return 'جاري التحضير...';
      case PhoneKUpdatePhase.downloadingPatch:
        return 'تنزيل تحديث صغير...';
      case PhoneKUpdatePhase.applyingPatch:
        return 'جاري دمج التحديث...';
      case PhoneKUpdatePhase.downloadingApk:
        return 'جاري تنزيل النسخة الأحدث...';
      case PhoneKUpdatePhase.verifying:
        return 'جاري التحقق من سلامة الملف...';
      case PhoneKUpdatePhase.installing:
        return 'جاري فتح شاشة التثبيت...';
    }
  }

  String _primaryLabel() {
    switch (_stage) {
      case _Stage.ready:
        return 'تحديث الآن';
      case _Stage.working:
        return 'جاري التحديث...';
      case _Stage.waitingInstaller:
        return 'إعادة فتح شاشة التثبيت';
      case _Stage.needsPermission:
        return 'متابعة التحديث';
      case _Stage.failed:
        return 'إعادة المحاولة';
    }
  }

  Widget _versionColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _versionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _versionColumn(
            'الحالي',
            _currentVersion ?? '—',
            AppColors.textSecondary,
          ),
          const Icon(Icons.arrow_back_rounded, color: AppColors.gold),
          _versionColumn('الجديد', widget.update.versionName, AppColors.gold),
        ],
      ),
    );
  }

  Widget _progressBlock() {
    final determinate = (_phase == PhoneKUpdatePhase.downloadingPatch ||
            _phase == PhoneKUpdatePhase.downloadingApk) &&
        _progress > 0;
    final label = determinate
        ? '${_phaseLabel(_phase)} ${(_progress * 100).round()}%'
        : _phaseLabel(_phase);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: determinate ? _progress : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text(
          'لا تغلق التطبيق أثناء التحديث',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _waitingBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withAlpha(31),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withAlpha(120)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.touch_app_rounded, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'اضغط «تثبيت» في نافذة النظام. سيُغلق التطبيق ثم يُفتح تلقائياً بالنسخة الجديدة.',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'لم تظهر النافذة؟ اضغط «إعادة فتح شاشة التثبيت».',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _errorBlock() {
    final color = _softError ? AppColors.warning : AppColors.danger;
    final detail = _detail;
    final showCopy = !_softError &&
        _stage == _Stage.failed &&
        detail != null &&
        detail.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _softError ? Icons.info_outline : Icons.error_outline,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error ?? '',
                  style: const TextStyle(height: 1.5, fontSize: 13),
                ),
              ),
            ],
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              detail,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          if (_stage == _Stage.needsPermission) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openInstallPermissionSettings,
              icon: const Icon(Icons.security_outlined),
              label: const Text('السماح بالتثبيت من هذا المصدر'),
            ),
            const SizedBox(height: 6),
            const Text(
              'فعّل الخيار في الإعدادات ثم ارجع للتطبيق، وسيكمل التحديث تلقائياً.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          if (showCopy) ...[
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _copyDetails,
                icon: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16,
                ),
                label: Text(_copied ? 'تم النسخ' : 'نسخ تفاصيل الخطأ'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final busy = _stage == _Stage.working;

    return PopScope(
      canPop: !update.mandatory && !busy,
      child: AlertDialog(
        icon: const Icon(
          Icons.system_update_alt_rounded,
          color: AppColors.gold,
          size: 40,
        ),
        title: Text(
          update.mandatory ? 'تحديث مطلوب' : 'تحديث جديد متاح',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _versionRow(),
              if (update.mandatory) ...[
                const SizedBox(height: 10),
                const Text(
                  'هذا التحديث مطلوب لمتابعة استخدام التطبيق.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13),
                ),
              ],
              if (update.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(update.notes),
              ],
              if (busy) ...[
                const SizedBox(height: 16),
                _progressBlock(),
              ],
              if (_stage == _Stage.waitingInstaller) ...[
                const SizedBox(height: 16),
                _waitingBlock(),
              ],
              if ((_stage == _Stage.failed ||
                      _stage == _Stage.needsPermission) &&
                  _error != null) ...[
                const SizedBox(height: 16),
                _errorBlock(),
              ],
            ],
          ),
        ),
        actions: [
          if (!update.mandatory && !busy)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لاحقاً'),
            ),
          FilledButton(
            onPressed: busy ? null : _install,
            child: Text(_primaryLabel()),
          ),
        ],
      ),
    );
  }
}
