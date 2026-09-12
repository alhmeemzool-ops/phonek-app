import 'package:flutter_test/flutter_test.dart';
import 'package:phonek_app/features/merchant_badges/badge_model.dart';

void main() {
  group('PhoneK merchant badge rules', () {
    test('no identity verification means no badge', () {
      expect(levelForStatus(sales: 5000, identityVerified: false, licenseVerified: true, rating: 5), 0);
    });

    test('identity verification activates level 1 at zero sales', () {
      expect(levelForStatus(sales: 0, identityVerified: true, licenseVerified: false, rating: 0), 1);
    });

    test('15 and 40 successful orders unlock levels 2 and 3', () {
      expect(levelForStatus(sales: 15, identityVerified: true, licenseVerified: false, rating: 0), 2);
      expect(levelForStatus(sales: 40, identityVerified: true, licenseVerified: false, rating: 0), 3);
    });

    test('level 4 requires the shop license in addition to 80 sales', () {
      expect(levelForStatus(sales: 80, identityVerified: true, licenseVerified: false, rating: 5), 3);
      expect(levelForStatus(sales: 80, identityVerified: true, licenseVerified: true, rating: 5), 4);
    });

    test('level 5 requires rating strictly above 4.2', () {
      expect(levelForStatus(sales: 150, identityVerified: true, licenseVerified: true, rating: 4.2), 4);
      expect(levelForStatus(sales: 150, identityVerified: true, licenseVerified: true, rating: 4.21), 5);
    });

    test('levels 6 through 10 follow the exact order thresholds', () {
      const sales = [300, 600, 1200, 2500, 5000];
      for (var i = 0; i < sales.length; i++) {
        expect(
          levelForStatus(sales: sales[i], identityVerified: true, licenseVerified: true, rating: 5),
          i + 6,
        );
      }
    });

    test('legendary remains level 10 above 5000 sales', () {
      expect(levelForStatus(sales: 9000, identityVerified: true, licenseVerified: true, rating: 5), 10);
    });
  });
}
