# فونك | PhoneK

تطبيق Flutter Android لبيع وشراء الهواتف في السودان، بواجهة عربية RTL وثيم PhoneK، مع Supabase للمصادقة والبيانات والتخزين والمحادثات وFirebase للإشعارات.

## الحالة الحالية

- Flutter **3.47.2**.
- الإصدار الفعلي في `pubspec.yaml`: **1.0.86+86**.
- Supabase: قاعدة البيانات، RLS، Storage، Edge Functions، وRealtime مستخدمة في التطبيق.
- Firebase/FCM: منفذ للإشعارات المحلية والدفع، مع حفظ توكنات FCM في جدول `push_tokens`.
- الإعلانات تُقرأ من Supabase، وبيانات البائع العامة تأتي من `public_seller_cards` دون أرقام الهاتف.
- أرقام الهاتف/واتساب لا تُرجع إلا للمستخدم المسجّل عبر `get_seller_contact`.
- المحادثات محمية للمشاركين، واسم الطرف الآخر يأتي من `get_chat_participants`.
- المشاهدة تُسجّل مرة واحدة لكل إعلان في جلسة التطبيق، ولا تُحتسب لصاحب الإعلان.
- الصور في `listing-images`: JPEG/PNG/WebP، حد أقصى 3 MiB، والرفع/الحذف لصاحب المجلد فقط.
- تحديثات APK تستخدم SHA-256 وpatch مع fallback للتنزيل الكامل.
- بناء APK يدعم ARM32 + ARM64.

## الإشعارات

الدالة:
`supabase/functions/send-push-notification/index.ts`

تتحقق من JWT، وتتحقق أن المستخدم طرف في المحادثة وأنه مرسل الرسالة فعلاً، ثم تستخرج الطرف الآخر وتقرأ توكنات FCM المفعلة وترسل إشعار FCM HTTP v1.

الأسرار المطلوبة في Supabase Edge Functions:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

لا تضع أيّاً من هذه القيم داخل Flutter أو Git. مفتاح خدمة Firebase الخاص يستخدم في Edge Function فقط.

## تشغيل المشروع

```bash
flutter pub get
flutter analyze
flutter test
```

يتطلب Flutter **3.47.2** أو بيئة متوافقة معه.

## إصدار APK

ارفع رقم الإصدار في `pubspec.yaml` قبل أي إصدار جديد:

```yaml
version: 1.0.87+87
```

ثم ادفع إلى `main`. سير عمل GitHub Actions يقوم بالبناء والتحقق من `versionCode` وحساب SHA-256 وإنشاء patch عند صلاحيته ونشر `update.json` بعد التحقق.

لا تعِد استخدام وسم Release موجود ولا تعِد استخدام `versionCode`.

## التراجع عن إصدار سيئ

- أوقف توزيع الإصدار المعيب من Release.
- لا تعِد استخدام نفس `versionName` أو `versionCode`.
- ارفع إصداراً أعلى ثم انشر الإصدار المصحح.
- لا تعدّل SHA-256 في `update.json` يدوياً إلى قيمة غير مطابقة للملف المنشور.

## أسرار GitHub المطلوبة للإصدار

- `ANDROID_KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

## ترتيب migrations وسلامة قاعدة البيانات

المجلد الحالي يحتوي على تاريخ migrations فيه أرقام مكررة، منها 004 و008 و011 و012، كما توجد هجرتان تاريخيتان تؤديان نفس تغيير `listings.rejection_reason`.

**الخطة الآمنة لقاعدة تعمل بالفعل:**

1. لا تعِد تسمية أو إعادة ترقيم migration سبق تطبيقها على قاعدة الإنتاج؛ سجل Supabase يعتمد على اسم migration.
2. لا تحذف migration قديمة فقط لأنها مكررة؛ قد تكون مسجلة في قاعدة الإنتاج.
3. للبيئة الجديدة، نفّذ الملفات التاريخية كما هي في ترتيبها المسجل حالياً، ثم استخدم migrations جديدة بأسماء زمنية فريدة لأي تصحيح لاحق.
4. ابتداءً من هذه المرحلة، أي migration جديدة يجب أن تستخدم الصيغة `YYYYMMDD_NNNN_name.sql`، مع رقم لا يتكرر.
5. أي تغيير على قاعدة قائمة يجب أن يكون idempotent قدر الإمكان باستخدام `create if not exists` أو `drop ... if exists` قبل إعادة الإنشاء.
6. لا نستخدم migration جديدة في المرحلة 1؛ لذلك لا يوجد تغيير SQL مطلوب لهذه المرحلة.

> ملاحظة: لم يتم إجراء إعادة ترتيب بأثر رجعي لملفات migrations القديمة حتى لا تنكسر قاعدة Supabase القائمة.

## الأمان

- RLS هو خط الدفاع الأساسي لبيانات المستخدم.
- صلاحيات الأدمن تعتمد على RPC الخادم `is_admin()` ولا توجد هوية أدمن ثابتة داخل التطبيق.
- Edge Functions الحساسة تتحقق من JWT قبل تنفيذ العملية.
- لا توجد مفاتيح خدمة أو أسرار Firebase داخل تطبيق Flutter.

## البناء المحلي

```bash
flutter build apk --release --target-platform android-arm,android-arm64
```

الناتج:

```
build/app/outputs/flutter-apk/app-release.apk
```

## ما لم يُنفّذ بعد

- الإبلاغ والحظر.
- تحسين المحادثات والعروض والصور والموقع.
- Pagination والبحث والفلاتر من الخادم.
- المفضلة السحابية والبحث المحفوظ والتنبيهات السعرية.
- تحسينات البائع والإعلانات وIMEI ومؤشر السعر.
- تحسينات الكتالوج والواجهة وAndroid App Links.
- اختبارات الجودة الشاملة ومراجعة CI النهائية.
