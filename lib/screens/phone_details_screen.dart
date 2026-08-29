import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/phone_card.dart';
import 'chat_screen.dart';

class PhoneDetailsScreen extends StatelessWidget {
  final PhoneListing listing;
  const PhoneDetailsScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final similar = appState.listings
        .where((p) => p.id != listing.id && p.brand == listing.brand)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              appState.isFavorite(listing.id) ? Icons.favorite : Icons.favorite_border,
              color: appState.isFavorite(listing.id) ? AppColors.danger : null,
            ),
            onPressed: () => appState.toggleFavorite(listing.id),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showShareOptions(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // معرض الصور
          Stack(
            children: [
              SizedBox(
                height: 280,
                width: double.infinity,
                child: listing.imageUrls.isNotEmpty
                    ? PageView.builder(
                        itemCount: listing.imageUrls.length,
                        itemBuilder: (context, index) => CachedNetworkImage(
                          imageUrl: listing.imageUrls[index],
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const _DetailImagePlaceholder(),
                          placeholder: (context, url) => const _DetailImagePlaceholder(),
                        ),
                      )
                    : const _DetailImagePlaceholder(),
              ),
              if (listing.imageUrls.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${listing.imageUrls.length} صور • اسحب للتصفح',
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ),
              if (listing.status == ListingStatus.sold)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(6)),
                    child: const Text('تم البيع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (listing.priceOnCall)
                      const Text('اتصل للسعر', style: TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold))
                    else
                      Text(AppFormatters.priceSDG(listing.price),
                          style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (listing.oldPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(AppFormatters.priceSDG(listing.oldPrice!),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14, decoration: TextDecoration.lineThrough)),
                    ],
                    if (listing.priceIsNegotiable && !listing.priceOnCall) ...[
                      const SizedBox(width: 8),
                      const _Pill(text: 'قابل للتفاوض'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(listing.city, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    const Icon(Icons.remove_red_eye, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${listing.viewCount} مشاهدة', style: const TextStyle(color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(AppFormatters.timeAgo(listing.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('المواصفات'),
                _specsTable(),
                if (listing.damageNotes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('ملاحظات الأعطال: ${listing.damageNotes}',
                              style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _sectionTitle('الملحقات المرفقة'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _accessoryChip('الكرتونة', listing.hasBox),
                    _accessoryChip('الشاحن الأصلي', listing.hasCharger),
                    _accessoryChip('الفاتورة', listing.hasInvoice),
                    _accessoryChip('السماعة', listing.hasEarphones),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('الوصف'),
                Text(listing.description.isEmpty ? 'لا يوجد وصف إضافي.' : listing.description,
                    style: const TextStyle(color: AppColors.textPrimary, height: 1.5)),
                const SizedBox(height: 20),
                _sectionTitle('البائع'),
                _sellerCard(context),
                if (similar.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionTitle('هواتف مشابهة'),
                  SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: similar.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final p = similar[index];
                        return SizedBox(
                          width: 140,
                          child: PhoneCard(
                            listing: p,
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: p)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, size: 16, color: AppColors.gold),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'التقِ بالبائع في مكان عام ونهاري، ولا تدفع أي مبلغ قبل معاينة الجهاز.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: listing.status == ListingStatus.sold ? null : _contactBar(context),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _specsTable() {
    final rows = <MapEntry<String, String>>[
      MapEntry('الحالة', listing.condition.labelAr),
      MapEntry('التخزين', listing.storage),
      MapEntry('الرام', listing.ram),
      if (listing.isIphone && listing.batteryHealthPercent != null)
        MapEntry('صحة البطارية', '${listing.batteryHealthPercent}%'),
      MapEntry('الضمان', _warrantyLabel(listing.warranty)),
    ];
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: rows.map((r) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.key, style: const TextStyle(color: AppColors.textSecondary)),
                Text(r.value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _warrantyLabel(WarrantyType w) {
    switch (w) {
      case WarrantyType.none:
        return 'بدون ضمان';
      case WarrantyType.storeWarranty:
        return 'ضمان محل';
      case WarrantyType.agentWarranty:
        return 'ضمان وكيل رسمي';
    }
  }

  Widget _accessoryChip(String label, bool included) {
    return Chip(
      avatar: Icon(included ? Icons.check_circle : Icons.cancel,
          size: 16, color: included ? AppColors.success : AppColors.textSecondary),
      label: Text(label),
      backgroundColor: AppColors.surfaceLight,
    );
  }

  Widget _sellerCard(BuildContext context) {
    final seller = listing.seller;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surfaceLight,
            child: Text(AppFormatters.firstChar(seller.name), style: const TextStyle(color: AppColors.gold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(seller.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    if (seller.isVerifiedStore) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: Colors.lightBlueAccent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(seller.replySpeedLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                if (seller.isVerifiedStore)
                  Text('${seller.completedSales} عملية بيع ناجحة', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (seller.isVerifiedStore && seller.rating > 0)
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.gold, size: 16),
                const SizedBox(width: 2),
                Text(seller.rating.toStringAsFixed(1)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _contactBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: Colors.white12))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _iconAction(Icons.call, 'اتصال', () => _launchTel(listing.seller.phone)),
            _iconAction(Icons.chat, 'واتساب', () => _launchWhatsapp(listing)),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.forum, size: 18),
                label: const Text('محادثة'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(listing: listing)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showOfferDialog(context),
                child: const Text('تقديم عرض'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.gold),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfferDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تقديم عرض سعر'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'أدخل السعر المقترح (ج.س)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال عرضك للبائع داخل المحادثة')),
              );
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.gold),
              title: const Text('نسخ رابط الإعلان'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: AppColors.gold),
              title: const Text('مشاركة كبطاقة مصورة'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchTel(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsapp(PhoneListing listing) async {
    final msg = Uri.encodeComponent('مرحباً، أنا مهتم بهاتف ${listing.title} المعروض في تطبيق فونك');
    final uri = Uri.parse('https://wa.me/${listing.seller.whatsapp?.replaceAll('+', '')}?text=$msg');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _DetailImagePlaceholder extends StatelessWidget {
  const _DetailImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF303030), Color(0xFF171717)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android_rounded, size: 82, color: Colors.white38),
            SizedBox(height: 10),
            Text('لا توجد صورة مضافة', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.gold)),
    );
  }
}
