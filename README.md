# فونك | PhoneK

تطبيق Flutter Android لبيع وشراء الهواتف، مع Supabase للمصادقة والبيانات والتخزين والمحادثات.

## الحالة الحالية

- Arabic RTL وواجهة PhoneK.
- الإعلانات تُقرأ من Supabase، وبيانات البائع العامة تأتي من `public_seller_cards` دون أرقام الهاتف.
- أرقام الهاتف/واتساب لا تُرجع إلا للمستخدم المسجّل عبر `get_seller_contact`.
- المحادثات محمية للمشاركين، واسم الطرف الآخر يأتي من `get_chat_participants`.
- المشاهدة تُسجّل مرة واحدة لكل إعلان في جلسة التطبيق، ولا تُحتسب لصاحب الإعلان.
- الصور في `listing-images`: JPEG/PNG/WebP، حد أقصى 3 MiB، والرفع/الحذف لصاحب المجلد فقط.
- تحديثات APK تستخدم SHA-256 وpatch مع fallback للتنزيل الكامل.
- الإصدار الحالي في `pubspec.yaml`: **1.0.57+57**.
- بناء الإصدار يدعم ARM32 + ARM64 في APK واحد.

## تشغيل المشروع

يتطلب Flutter **3.47.2** أو بيئة متوافقة معه.

```bash
flutter pub get
flutter analyze
flutter test
```

## إصدار APK

ارفع رقم الإصدار في `pubspec.yaml`، مثال:

```yaml
version: 1.0.58+58
```

ثم ادفع إلى `main`. سير عمل GitHub Actions يقوم بـ:

1. تثبيت Flutter بإصدار ثابت.
2. فحص وجود Release بنفس الوسم ومنع إعادة استخدامه.
3. بناء APK واحد لـ `android-arm,android-arm64`.
4. التحقق من `versionCode` داخل APK.
5. حساب SHA-256.
6. إنشاء patch فقط إذا كان صالحاً وأصغر من APK الكامل.
7. نشر Release.
8. تنزيل الـAPK من رابط Release نفسه والتحقق من SHA-256.
9. كتابة `update.json` فقط بعد نجاح التحقق.

لا تعِد استخدام وسم Release موجود؛ ارفع `versionName/versionCode` أولاً.

## التراجع عن إصدار سيئ

- أوقف توزيع الإصدار المعيب من Release.
- لا تعِد استخدام نفس `versionName`.
- ارفع إصداراً أعلى في `pubspec.yaml` ثم انشر الإصدار المصحح.
- لا تعدّل SHA-256 في `update.json` يدوياً إلى قيمة غير مطابقة للملف المنشور.

## أسرار GitHub المطلوبة للإصدار

- `ANDROID_KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

## Supabase

طبّق ملفات `supabase/migrations/` بالترتيب في بيئة جديدة. من أهم تغييرات الأمان:

- RLS على `profiles` مع منع القراءة العامة للملف الكامل.
- `public_seller_cards` كإسقاط آمن للبيانات العامة.
- `get_seller_contact` للمستخدمين المسجلين فقط.
- تقييد وظائف SECURITY DEFINER بحسب الحاجة.
- حماية Storage حسب هوية المستخدم.

## البناء المحلي

```bash
flutter build apk --release --target-platform android-arm,android-arm64
```

الناتج:

```
build/app/outputs/flutter-apk/app-release.apk
```

## ما لم يُنفّذ بعد

- أيقونة التطبيق النهائية المبنية من الشعار الأصلي.
- Firebase Crashlytics وFCM بعد توفير إعداد مشروع Firebase والـsecret المطلوب.
- Pagination/بحث وفلاتر كاملة من الخادم.
- تحسينات إضافية للصور والأداء والاختبارات الشاملة.
