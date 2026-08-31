import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class InfoPageScreen extends StatelessWidget {
  final String title;
  final List<InfoSection> sections;

  const InfoPageScreen({super.key, required this.title, required this.sections});

  factory InfoPageScreen.faq() => const InfoPageScreen(
        title: 'الأسئلة الشائعة',
        sections: [
          InfoSection(
            title: 'كيف أضيف إعلانًا؟',
            body: 'سجّل الدخول، اختر إضافة هاتف، أدخل البيانات وأرفق الصور، ثم انشر الإعلان. يظهر الإعلان للعامة فوراً بعد النشر.',
          ),
          InfoSection(
            title: 'هل يمكن تعديل السعر؟',
            body: 'نعم، افتح إعلاناتي واختر الإعلان ثم حدّث السعر. يحتفظ التطبيق بالسعر السابق عند أول تحديث لإظهار الخصم بوضوح.',
          ),
          InfoSection(
            title: 'كيف أتواصل مع البائع؟',
            body: 'يمكنك استخدام الاتصال أو WhatsApp أو المحادثة الداخلية. لا ترسل أموالًا قبل معاينة الهاتف والتحقق من البائع.',
          ),
          InfoSection(
            title: 'ماذا أفعل عند وجود إعلان مخالف؟',
            body: 'لا تشارك بياناتك الحساسة. احتفظ برابط الإعلان وتواصل مع إدارة PhoneK عند توفر قناة البلاغات.',
          ),
        ],
      );

  factory InfoPageScreen.terms() => const InfoPageScreen(
        title: 'الشروط والخصوصية',
        sections: [
          InfoSection(
            title: 'ضوابط النشر',
            body: 'يجب أن تكون بيانات الهاتف وصوره حقيقية ومملوكة للبائع أو مصرحًا له بعرضها. يمنع نشر الأجهزة المسروقة أو المقلدة أو الإعلانات المضللة.',
          ),
          InfoSection(
            title: 'مسؤولية الصفقة',
            body: 'PhoneK منصة لعرض الإعلانات والتواصل، وليست طرفًا في البيع ما لم تُعلن خدمة معاملات موثقة بشكل مستقل. اتفق على مكان آمن وتحقق من الجهاز ورقمه التعريفي.',
          ),
          InfoSection(
            title: 'البيانات الشخصية',
            body: 'تُستخدم بيانات الحساب لتشغيل المصادقة وإدارة الإعلانات والتواصل. لا تشارك كلمة مرور أو مفتاحًا سريًا، ولا ترسل بيانات مالية داخل المحادثة.',
          ),
          InfoSection(
            title: 'الإبلاغ والتنفيذ',
            body: 'يحق للإدارة تعليق أو إزالة المحتوى المخالف وحظر الحسابات عند إساءة الاستخدام، مع الاحتفاظ بسجل إداري مناسب للمراجعة.',
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final section = sections[index];
          return Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              iconColor: AppColors.gold,
              collapsedIconColor: AppColors.textSecondary,
              title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(section.body, style: const TextStyle(color: AppColors.textSecondary, height: 1.6)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class InfoSection {
  final String title;
  final String body;

  const InfoSection({required this.title, required this.body});
}
