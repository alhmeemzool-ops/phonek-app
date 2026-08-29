import 'package:flutter_test/flutter_test.dart';
import 'package:phonek_app/models/phone_model.dart';

void main() {
  group('PhoneListing', () {
    test('detects iPhone listings by brand', () {
      final listing = PhoneListing(
        id: 'test-iphone',
        title: 'iPhone 13 Pro',
        brand: 'iPhone',
        price: 450000,
        storage: '128GB',
        ram: '6GB',
        city: 'الخرطوم',
        imageUrls: const [],
        seller: const SellerInfo(
          id: 'seller',
          name: 'بائع تجريبي',
          phone: '+249000000000',
          city: 'الخرطوم',
        ),
        createdAt: DateTime(2026, 1, 1),
      );

      expect(listing.isIphone, isTrue);
    });

    test('matches Supabase enum names for listing persistence', () {
      expect(DeviceCondition.newDevice.name, 'newDevice');
      expect(DeviceCondition.minorScratches.name, 'minorScratches');
      expect(WarrantyType.storeWarranty.name, 'storeWarranty');
      expect(ListingStatus.pendingReview.name, 'pendingReview');
    });

    test('keeps a listing without images valid for the fallback UI', () {
      final listing = PhoneListing(
        id: 'test-no-image',
        title: 'Samsung Galaxy',
        brand: 'Samsung',
        price: 120000,
        storage: '128GB',
        ram: '6GB',
        city: 'بحري',
        imageUrls: const [],
        seller: const SellerInfo(
          id: 'seller',
          name: 'بائع تجريبي',
          phone: '+249000000000',
          city: 'بحري',
        ),
        createdAt: DateTime(2026, 1, 1),
      );

      expect(listing.imageUrls, isEmpty);
      expect(listing.isIphone, isFalse);
    });
  });
}
