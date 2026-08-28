import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/app_state.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

// ملاحظة مهمة قبل التشغيل الحقيقي:
// عند ربط Firebase أضف داخل main() قبل runApp():
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// راجع ملف README.md في جذر المشروع للتفاصيل الكاملة خطوة بخطوة.

void main() {
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
        // ملاحظة: لدعم ترجمة عناصر النظام (كأزرار منتقي التاريخ) بالعربية بالكامل مستقبلاً،
        // أضف حزمة flutter_localizations في pubspec.yaml ثم أضف:
        // locale: const Locale('ar'),
        // localizationsDelegates: const [
        //   GlobalMaterialLocalizations.delegate,
        //   GlobalWidgetsLocalizations.delegate,
        //   GlobalCupertinoLocalizations.delegate,
        // ],
        // supportedLocales: const [Locale('ar'), Locale('en')],
        builder: (context, child) {
          // يفرض اتجاه الواجهة من اليمين لليسار (RTL) في كل شاشات التطبيق
          return Directionality(textDirection: TextDirection.rtl, child: child!);
        },
        home: const HomeScreen(),
      ),
    );
  }
}
