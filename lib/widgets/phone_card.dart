import 'package:flutter/material.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class PhoneCard extends StatelessWidget {
  final PhoneListing listing;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const PhoneCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = listing.oldPrice != null && listing.oldPrice! > listing.price;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.grey[850],
                      child: const Center(
                        child: Icon(Icons.phone_android, size: 56, color: Colors.white24),
                      ),
                    ),
                  ),
                  // علامة PhoneK المائية
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('PhoneK', style: TextStyle(color: AppColors.gold, fontSize: 9)),
                    ),
                  ),
                  if (listing.isFeatured)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(text: 'مميز', color: AppColors.gold, textColor: Colors.black),
                    ),
                  if (listing.status == ListingStatus.sold)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: _Badge(text: 'تم البيع', color: AppColors.danger, textColor: Colors.white),
                    ),
                  if (listing.condition == DeviceCondition.cracked)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: _Badge(text: 'به عيوب', color: AppColors.warning, textColor: Colors.black),
                    ),
                  Positioned(
                    top: 4,
                    left: listing.condition == DeviceCondition.cracked ? 70 : 6,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.danger : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    listing.isIphone && listing.batteryHealthPercent != null
                        ? '${listing.storage} • بطارية ${listing.batteryHealthPercent}%'
                        : '${listing.storage} • ${listing.ram}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(listing.city,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (listing.priceOnCall)
                    const Text('اتصل للسعر', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13))
                  else
                    Row(
                      children: [
                        Text(
                          AppFormatters.priceSDG(listing.price),
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            AppFormatters.priceSDG(listing.oldPrice!),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  const _Badge({required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
