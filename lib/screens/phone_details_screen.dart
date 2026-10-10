import 'dart:ui' as ui;
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
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
import 'compare_screen.dart';

class PhoneDetailsScreen extends StatefulWidget {
  const PhoneDetailsScreen({super.key, required this.listing});
  final PhoneListing listing;

  @override
  State<PhoneDetailsScreen> createState() => _PhoneDetailsScreenState();
}

class _PhoneDetailsScreenState extends State<PhoneDetailsScreen> {
  PhoneListing get listing => widget.listing;

  @override
  void initState() {
    super.initState();
    if (listing.status == ListingStatus.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final state = context.read<AppState>();
        if (state.currentUser?.id != listing.seller.id) {
          state.recordListingView(listing.id);
        }
      });
    }
  }

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
          if (!isOwner) IconButton(icon: const Icon(Icons.flag_outlined), tooltip: 'الإبلاغ عن الإعلان', onPressed: () => _report(context)),
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
                Row(children:[Expanded(child:Text(listing.priceOnCall ? 'اتصل للسعر' : AppFormatters.priceSDG(listing.displayedPrice), style: const TextStyle(color: AppColors.gold, fontSize: 23, fontWeight: FontWeight.bold))),if(listing.hasActiveOffer)Chip(label:Text('عرض -'+listing.offerDiscountPercent.toString()+'%')),if(listing.acceptsSwap)const Chip(label:Text('يقبل التبديل')),if(listing.subscriptionActive)const Chip(label:Text('معرض مميز'))]),
                const SizedBox(height: 8),
                if(!isOwner) Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CompareScreen(first:listing,candidates:context.read<AppState>().listings.where((x)=>x.id!=listing.id&&x.status==ListingStatus.active).toList()))),icon:const Icon(Icons.compare_arrows),label:const Text('قارن'))),
                if(listing.acceptsSwap && !isOwner) Align(alignment:Alignment.centerRight,child:OutlinedButton.icon(onPressed:()=>_swap(context),icon:const Icon(Icons.swap_horiz),label:const Text('اعرض تبديل'))),
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
    final merchantLevel = seller.isShop
        ? (seller.merchantBadgeLevel > 0
            ? seller.merchantBadgeLevel.clamp(1, merchantBadges.length).toInt()
            : levelForSales(seller.completedSales))
        : 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: seller.isShop && seller.id.isNotEmpty ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopProfileScreen(shopId: seller.id, initialSeller: seller))) : null,
      child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        CircleAvatar(radius: 25, backgroundColor: AppColors.surfaceLight, child: seller.avatarUrl?.isNotEmpty == true ? ClipOval(child: Image.network(seller.avatarUrl!, width: 50, height: 50, fit: BoxFit.cover)) : Text(AppFormatters.firstChar(seller.name), style: const TextStyle(color: AppColors.gold))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Flexible(child: Text(seller.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if (seller.isVerifiedStore) ...[const SizedBox(width: 5), const Icon(Icons.verified, size: 16, color: Colors.lightBlueAccent)], if (merchantLevel > 0) ...[const SizedBox(width: 5), MerchantBadgeChip(level: merchantLevel, compact: true)]]),
          const SizedBox(height: 3), Text(seller.isShop ? 'فتح صفحة المتجر' : seller.replySpeedLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        if (seller.isShop) const Icon(Icons.chevron_left, color: AppColors.gold),
      ]))),
    );
  }

  Widget _contactBar(BuildContext context) { final offline=context.watch<AppState>().isOffline; return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: Colors.white12))),
    child: SafeArea(top: false, child: Row(children: [
      _action(Icons.call, 'اتصال', offline?()=>_offlineMessage(context):() => _tel(context)), _action(Icons.chat, 'واتساب', offline?()=>_offlineMessage(context):() => _whatsapp(context)),
      Expanded(child: ElevatedButton.icon(onPressed: offline?()=>_offlineMessage(context):() { _recordContact(); Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(listing: listing))); }, icon: const Icon(Icons.forum, size: 18), label: const Text('محادثة'))),
      if (!listing.priceOnCall) ...[const SizedBox(width: 7), Expanded(child: OutlinedButton(onPressed: offline?()=>_offlineMessage(context):() => _offer(context), child: const Text('تقديم عرض')))],
    ])),
  );
  }

  void _offlineMessage(BuildContext context)=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تحتاج إلى اتصال بالإنترنت')));

  Widget _action(IconData icon, String label, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(left: 4), child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(5), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: AppColors.gold), Text(label, style: const TextStyle(fontSize: 10))]))));

  Future<void> _recordContact() async { try { await context.read<AppState>().recordListingEvent(listing.id,'contact'); } catch (_) {} }

  Future<void> _report(BuildContext context) async {
    final user = context.read<AppState>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول لإرسال بلاغ')));
      return;
    }
    final details = TextEditingController();
    var reason = 'scam';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('الإبلاغ عن الإعلان'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: reason,
            decoration: const InputDecoration(labelText: 'سبب البلاغ'),
            items: const [
              DropdownMenuItem(value: 'scam', child: Text('احتيال أو طلب دفع مشبوه')),
              DropdownMenuItem(value: 'wrong_info', child: Text('معلومات أو سعر غير صحيح')),
              DropdownMenuItem(value: 'prohibited', child: Text('محتوى أو منتج مخالف')),
              DropdownMenuItem(value: 'harassment', child: Text('إساءة أو مضايقة')),
              DropdownMenuItem(value: 'other', child: Text('سبب آخر')),
            ],
            onChanged: (value) => setDialogState(() => reason = value ?? reason),
          ),
          const SizedBox(height: 10),
          TextField(controller: details, maxLines: 3, decoration: const InputDecoration(labelText: 'تفاصيل إضافية (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إرسال البلاغ')),
        ],
      )),
    );
    if (submitted != true || !mounted) {
      details.dispose();
      return;
    }
    try {
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': user.id,
        'listing_id': listing.id,
        'reason': reason,
        'details': details.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال البلاغ للمراجعة')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال البلاغ: $error')));
    } finally {
      details.dispose();
    }
  }

  Future<void> _tel(BuildContext context) async {
    await _recordContact();
    try {
      final contact = await context.read<AppState>().getSellerContact(listing.seller.id);
      final phone = contact['phone'] ?? '';
      if (phone.trim().isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الهاتف غير متوفر')));
        return;
      }
      final uri = Uri(scheme: 'tel', path: phone.trim());
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحصول على رقم البائع: $e')));
    }
  }

  Future<void> _whatsapp(BuildContext context) async {
    try {
      final contact = await context.read<AppState>().getSellerContact(listing.seller.id);
      var number = (contact['whatsapp']?.trim().isNotEmpty == true ? contact['whatsapp']! : contact['phone'] ?? '')
          .replaceAll(RegExp(r'[^0-9]'), '');
      if (number.startsWith('0')) number = '249' + number.substring(1);
      if (number.startsWith('9') && number.length == 9) number = '249' + number;
      if (number.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم واتساب غير متوفر')));
        }
        return;
      }
      final uri = Uri.parse('https://wa.me/' + number + '?text=' + Uri.encodeComponent('مرحباً، أنا مهتم بهاتف ' + listing.title));
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحصول على رقم البائع: ' + e.toString())));
      }
    }
  }

  Future<void> _swap(BuildContext context) async {
    final model = TextEditingController();
    final diff = TextEditingController(text: '0');
    DeviceCondition condition = DeviceCondition.excellent;
    String direction = 'pay'; XFile? image;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialogState) => AlertDialog(
          title: const Text('اعرض تبديل'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(children: [
            TextField(controller: model, maxLength: 60, decoration: const InputDecoration(labelText: 'موديل هاتفك *')),
            DropdownButtonFormField<DeviceCondition>(value: condition, decoration: const InputDecoration(labelText: 'الحالة'), items: DeviceCondition.values.map((v) => DropdownMenuItem(value: v, child: Text(v.labelAr))).toList(), onChanged: (v) { if (v != null) setDialogState(() => condition = v); }),
            TextField(controller: diff, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'فرق السعر (ج.س)')),
            DropdownButtonFormField<String>(value: direction, decoration: const InputDecoration(labelText: 'فرق السعر'), items: const [DropdownMenuItem(value: 'pay', child: Text('أدفع الفرق')), DropdownMenuItem(value: 'request', child: Text('أطلب الفرق'))], onChanged: (v) { if (v != null) setDialogState(() => direction = v); }),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () async { image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600); setDialogState(() {}); }, icon: const Icon(Icons.image_outlined), label: Text(image == null ? 'إضافة صورة اختيارية' : 'تم اختيار الصورة')),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () async {
              final amount = int.tryParse(diff.text.trim()) ?? 0;
              if (model.text.trim().isEmpty || amount < 0) return;
              try {
                String? url;
                if (image != null) {
                  final uid = context.read<AppState>().currentUser!.id;
                  final path = uid + '/swap_' + DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
                  await Supabase.instance.client.storage.from('listing-images').uploadBinary(path, await image!.readAsBytes(), fileOptions: const FileOptions(upsert: false, contentType: 'image/jpeg'));
                  url = Supabase.instance.client.storage.from('listing-images').getPublicUrl(path);
                }
                await context.read<AppState>().sendSwap(listing: listing, model: model.text.trim(), condition: condition, diffAmount: amount, diffDirection: direction, imageUrl: url);
                if (context.mounted) { Navigator.pop(dialog); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال عرض التبديل'))); }
              } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال عرض التبديل: $e'))); }
            }, child: const Text('إرسال')),
          ],
        ),
      ),
    );
    model.dispose(); diff.dispose();
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
          try { await _recordContact(); await context.read<AppState>().sendOffer(listing: listing, amount: amount); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العرض'))); }
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
      ListTile(leading: const Icon(Icons.image_outlined, color: AppColors.gold), title: const Text('مشاركة كصورة'), onTap: () { Navigator.pop(sheetContext); Navigator.push(context, MaterialPageRoute(builder: (_) => _ShareImageScreen(listing: listing, link: deepLink))); } ),
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

class _ShareImageScreen extends StatefulWidget {
  const _ShareImageScreen({required this.listing, required this.link});
  final PhoneListing listing;
  final String link;
  @override State<_ShareImageScreen> createState()=>_ShareImageScreenState();
}
class _ShareImageScreenState extends State<_ShareImageScreen> {
  final key=GlobalKey();
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>_capture());}
  Future<void> _capture() async {
    try {
      if(widget.listing.imageUrls.isNotEmpty) await precacheImage(NetworkImage(widget.listing.imageUrls.first),context);
      await Future<void>.delayed(const Duration(milliseconds:250));
      final boundary=key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if(boundary==null)return;
      final image=await boundary.toImage(pixelRatio:1);
      final data=await image.toByteData(format:ui.ImageByteFormat.png);
      if(data==null)return;
      final dir=await getTemporaryDirectory();
      final file=File(dir.path+'/phonek_share.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)],text:widget.listing.title+'\n'+widget.listing.city+'\n'+widget.link);
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إنشاء صورة المشاركة: '+e.toString())));
    }
  }
  @override Widget build(BuildContext context) {
    final content = SizedBox(
      width: 1080,
      height: 1350,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(60),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.listing.imageUrls.isNotEmpty)
              SizedBox(height: 650, width: 1080, child: Image.network(widget.listing.imageUrls.first, fit: BoxFit.contain)),
            const SizedBox(height: 30),
            Text(widget.listing.title, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text(widget.listing.priceOnCall ? 'اتصل للسعر' : AppFormatters.priceSDG(widget.listing.displayedPrice), style: const TextStyle(fontSize: 44, color: AppColors.gold, fontWeight: FontWeight.bold)),
            Text(widget.listing.city, style: const TextStyle(fontSize: 30, color: AppColors.textSecondary)),
            const Spacer(),
            const Text('PhoneK | فونك', style: TextStyle(fontSize: 32, color: AppColors.gold, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('مشاركة كصورة')),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(child: RepaintBoundary(key: key, child: content)),
      ),
    );
  }
}
