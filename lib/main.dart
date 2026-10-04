import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'services/update_service.dart';
import 'widgets/phonek_update_dialog.dart';
import 'features/merchant_badges/level_up_celebration.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

export 'widgets/phonek_update_dialog.dart' show PhoneKUpdateDialog;

final GlobalKey<NavigatorState> phoneKNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter's default release ErrorWidget is a silent gray rectangle. Keep
  // production build errors visible instead of making the page look frozen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('PhoneK FlutterError: ' + details.exception.toString());
  };
  ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.rtl,
        child: ColoredBox(
          color: const Color(0xFF121212),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'تعذر عرض الصفحة. أغلق التطبيق وافتحه من جديد.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ),
      );

  await Supabase.initialize(
    url: 'https://hnuzqjotgmdgqjpbrqlb.supabase.co',
    publishableKey: 'sb_publishable_3XRVtwMyK5nNOvNpNDT7Mg_4nyH7FC1',
  );

  await NotificationService.initialize();
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
        navigatorKey: phoneKNavigatorKey,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          NotificationService.setOnNotificationTap((data) async {
            final targetUserId = data['recipient_user_id']?.toString();
            final currentUserId =
                Supabase.instance.client.auth.currentUser?.id;
            final appState = context.read<AppState>();

            if (targetUserId != null &&
                targetUserId.isNotEmpty &&
                targetUserId != currentUserId) {
              final switched =
                  await NotificationService.switchToAccount(targetUserId);
              if (!switched) {
                debugPrint(
                  'PhoneK notification target account is not available on this device: $targetUserId',
                );
                return;
              }

              await appState.syncAuthState();
              if (Supabase.instance.client.auth.currentUser?.id !=
                  targetUserId) {
                debugPrint(
                  'PhoneK notification account switch did not activate target account: $targetUserId',
                );
                return;
              }
            } else {
              await appState.syncAuthState();
            }

            var navigator = phoneKNavigatorKey.currentState;
            if (navigator == null) {
              await Future<void>.delayed(const Duration(milliseconds: 500));
              navigator = phoneKNavigatorKey.currentState;
            }
            if (navigator == null || !context.mounted) return;

            final threadId = data['thread_id']?.toString();
            if (threadId == null || threadId.isEmpty) return;

            final thread = await appState.getChatThreadById(threadId);
            if (thread == null) return;

            final listing = await appState.getListingById(thread.phoneListingId);
            if (listing == null) return;

            navigator.push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  listing: listing,
                  thread: thread,
                ),
              ),
            );
          });

          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const PhoneKUpdateGate(
          child: MerchantLevelUpGate(child: HomeScreen()),
        ),
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
    PhoneKUpdateService.cleanupStaleFiles();
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
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || _dialogShown) return;

      final checkResult = await PhoneKUpdateService.check();
      if (!mounted ||
          checkResult.status != PhoneKUpdateCheckStatus.updateAvailable) {
        return;
      }
      final update = checkResult.update!;

      _dialogShown = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.mandatory,
        builder: (dialogContext) => PhoneKUpdateDialog(update: update),
      );
    } catch (error) {
      debugPrint('PhoneK update gate error: $error');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
