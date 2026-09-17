import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/phone_card.dart';
import '../features/merchant_badges/badge_model.dart';
import '../features/merchant_badges/badge_widgets.dart';
import 'chat_screen.dart';
import 'listing_settings_screen.dart';
import 'shop_profile_screen.dart';

class PhoneDetailsScreen extends StatelessWidget {
  const PhoneDetailsScreen({super.key, required this.listing});
  final PhoneListing listing;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isOwner = state.currentUser?.id == listing.seller.id;
    final similar = state.listings.where((p) => p.id != listing.id && p.brand == listing.brand).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'إعدادات الإعلان',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListingSettingsScreen(listing: listing))),
            ),
          if (!isOwner)
            IconButton(
              icon: Icon(state.isFavorite(listing.id) ? Icons.favorite : Icons.favorite_border, color: state.isFavorite(listing.id) ? AppColors.danger : null),
              onPressed: () => state.toggleFavorite(listing.id),
            ),
          IconButton(icon: const Icon(Icons.share), onPressed: () => _share(context)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          _heroImage(context),
          if (listing.imageUrls.length > 1) _thumbnails(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(listing.priceOnCall ? 'اتصل للسعر' : AppFormatters.priceSDG(listing.price), style: const TextStyle(color: AppColors.gold, fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${listing.city}  •  ${listing.viewCount} مشاهدة  •  ${AppFormatters.timeAgo(listing.createdAt)}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 18),
                _section('المواصفات'),
                _specs(),
                const SizedBox(height: 18),
                _section('الملحقات'),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  _chip('الكرتونة', listing.hasBox), _chip('الشاحن', listing.hasCharger), _chip('الفاتورة', listing.hasInvoice), _chip('السماعة', listing.hasEarphones),
                ]),
                if (listing.damageNotes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 18), _section('ملاحظات الأعطال'), Text(listing.damageNotes!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
                ],
                const SizedBox(height: 18), _section('الوصف'),
                Text(listing.description.isEmpty ? 'لا يوجد وصف إضافي.' : listing.description, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 18), _section(listing.seller.isShop ? 'المتجر' : 'البائع'), _seller(context),
                if (similar.isNotEmpty) ...[
                  const SizedBox(height: 22), _section('هواتف مشابهة'),
                  SizedBox(height: 220, child: ListView.separated(
                    scrollDirection: Axis.horizontal, itemCount: similar.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) { final phone = similar[i]; return SizedBox(width: 150, child: PhoneCard(listing: phone, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: phone))))); },
                  )),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.security, size: 16, color: AppColors.gold), SizedBox(width: 8),
                    Expanded(child: Text('التقِ بالبائع في مكان عام ونهاري، ولا تدفع أي مبلغ قبل معاينة الجهاز.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isOwner || listing.status == ListingStatus.sold ? null : _contactBar(context),
    );
  }

  Widget _heroImage(BuildContext context) => GestureDetector(
    onTap: listing.imageUrls.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoGalleryScreen(images: listing.imageUrls, initialIndex: 0, title: listing.title))),
    child: SizedBox(height: 300, child: Stack(fit: StackFit.expand, children: [
      listing.imageUrls.isEmpty ? const ColoredBox(color: AppColors.surfaceLight, child: Icon(Icons.phone_android, size: 80, color: AppColors.gold)) : CachedNetworkImage(imageUrl: listing.imageUrls.first, fit: BoxFit.cover, errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surfaceLight, child: Icon(Icons.broken_image))),
      if (listing.imageUrls.length > 1) Positioned(left: 12, bottom: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text('${listing.imageUrls.length} صور • اضغط للتكبير', style: const TextStyle(color: Colors.white)))),
    ])),
  );

  Widget _thumbnails(BuildContext context) => SizedBox(height: 74, child: ListView.separated(
    scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(10), itemCount: listing.imageUrls.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
    itemBuilder: (_, i) => GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoGalleryScreen(images: listing.imageUrls, initialIndex: i, title: listing.title))), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: listing.imageUrls[i], width: 82, height: 58, fit: BoxFit.cover))),
  ));

  Widget _section(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)));

  Widget _specs() {
    final rows = <MapEntry<String, String>>[
      MapEntry('الحالة', listing.condition.labelAr), MapEntry('التخزين', listing.storage), MapEntry('الرام', listing.ram),
      if (listing.isIphone && listing.batteryHealthPercent != null) MapEntry('صحة البطارية', '${listing.batteryHealthPercent}%'), MapEntry('الضمان', _warranty(listing.warranty)),
    ];
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: rows.map((row) => _row(row.key, row.value)).toList())));
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: AppColors.textSecondary)), Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))) ]));

  String _warranty(WarrantyType w) => switch (w) { WarrantyType.none => 'بدون ضمان', WarrantyType.storeWarranty => 'ضمان متجر', WarrantyType.agentWarranty => 'ضمان وكيل رسمي' };
  Widget _chip(String text, bool yes) => Chip(avatar: Icon(yes ? Icons.check_circle : Icons.cancel, size: 16, color: yes ? AppColors.success : AppColors.textSecondary), label: Text(text));

  Widget _seller(BuildContext context) {
    final seller = listing.seller;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: seller.isShop && seller.id.isNotEmpty ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopProfileScreen(shopId: seller.id, initialSeller: seller))) : null,
      child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        CircleAvatar(radius: 25, backgroundColor: AppColors.surfaceLight, child: seller.avatarUrl?.isNotEmpty == true ? ClipOval(child: Image.network(seller.avatarUrl!, width: 50, height: 50, fit: BoxFit.cover)) : Text(AppFormatters.firstChar(seller.name), style: const TextStyle(color: AppColors.gold))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Flexible(child: Text(seller.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if (seller.isVerifiedStore) ...[const SizedBox(width: 5), const Icon(Icons.verified, size: 16, color: Colors.lightBlueAccent), const SizedBox(width: 5), MerchantBadgeChip(level: levelForSales(seller.completedSales), compact: true)]]),
          const SizedBox(height: 3), Text(seller.isShop ? 'فتح صفحة المتجر' : seller.replySpeedLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        if (seller.isShop) const Icon(Icons.chevron_left, color: AppColors.gold),
      ]))),
    );
  }

  Widget _contactBar(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: Colors.white12))),
    child: SafeArea(top: false, child: Row(children: [
      _action(Icons.call, 'اتصال', () => _tel(listing.seller.phone)), _action(Icons.chat, 'واتساب', () => _whatsapp(context)),
      Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(listing: listing))), icon: const Icon(Icons.forum, size: 18), label: const Text('محادثة'))),
      if (!listing.priceOnCall) ...[const SizedBox(width: 7), Expanded(child: OutlinedButton(onPressed: () => _offer(context), child: const Text('تقديم عرض')))],
    ])),
  );

  Widget _action(IconData icon, String label, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(left: 4), child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(5), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: AppColors.gold), Text(label, style: const TextStyle(fontSize: 10))]))));

  Future<void> _tel(String phone) async { if (phone.trim().isEmpty) return; final uri = Uri(scheme: 'tel', path: phone.trim()); if (await canLaunchUrl(uri)) await launchUrl(uri); }

  Future<void> _whatsapp(BuildContext context) async {
    var number = (listing.seller.whatsapp ?? listing.seller.phone).replaceAll(RegExp(r'[^0-9]'), '');
    if (number.startsWith('0')) number = '249${number.substring(1)}';
    if (number.startsWith('9') && number.length == 9) number = '249$number';
    if (number.isEmpty) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم واتساب غير متوفر'))); return; }
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent('مرحباً، أنا مهتم بهاتف ${listing.title}')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _offer(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('تقديم عرض سعر'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'السعر المقترح')),
      actions: [
        TextButton(onPressed: () { controller.dispose(); Navigator.pop(dialogContext); }, child: const Text('إلغاء')),
        ElevatedButton(onPressed: () async {
          final amount = int.tryParse(controller.text.trim()); if (amount == null || amount <= 0) return;
          Navigator.pop(dialogContext);
          try { await context.read<AppState>().sendOffer(listing: listing, amount: amount); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العرض'))); }
          catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال العرض: $e'))); }
          finally { controller.dispose(); }
        }, child: const Text('إرسال')),
      ],
    ));
  }

  void _share(BuildContext context) {
    final deepLink = 'https://phonek.app/listing/${Uri.encodeComponent(listing.id)}';
    showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.copy, color: AppColors.gold), title: const Text('نسخ رقم الإعلان'), onTap: () async { await Clipboard.setData(ClipboardData(text: listing.id)); if (sheetContext.mounted) Navigator.pop(sheetContext); }),
      ListTile(leading: const Icon(Icons.share, color: AppColors.gold), title: const Text('مشاركة الإعلان'), onTap: () async { Navigator.pop(sheetContext); await Share.share('${listing.title}\n${listing.city}\n$deepLink'); }),
    ])));
  }
}

class _PhotoGalleryScreen extends StatefulWidget {
  const _PhotoGalleryScreen({required this.images, required this.initialIndex, required this.title});
  final List<String> images; final int initialIndex; final String title;
  @override State<_PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<_PhotoGalleryScreen> {
  late final PageController _controller;
  late int _index;
  @override void initState() { super.initState(); _index = widget.initialIndex.clamp(0, widget.images.length - 1); _controller = PageController(initialPage: _index); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${widget.title}  •  ${_index + 1}/${widget.images.length}')), body: PageView.builder(
    controller: _controller, itemCount: widget.images.length, onPageChanged: (i) => setState(() => _index = i), itemBuilder: (_, i) => InteractiveViewer(minScale: 1, maxScale: 4, child: Center(child: CachedNetworkImage(imageUrl: widget.images[i], fit: BoxFit.contain, errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 60)))),
  ));
}
