import 'package:flutter_test/flutter_test.dart';

import 'package:phonek/data/catalog_data.dart';

void main() {
  test('expanded catalog has exact requested additions and no duplicates', () {
    expect(CatalogData.phoneModelsByBrand['Samsung']!.length, 286);
    expect(CatalogData.phoneModelsByBrand['HONOR']!.length, 283);
    expect(CatalogData.phoneModelsByBrand['Apple']!.length, 294);
    expect(CatalogData.phoneModelsByBrand['Huawei']!.length, 250);
    expect(CatalogData.phoneModelsByBrand['Xiaomi']!.length, 141);

    for (final brand in ['Samsung', 'HONOR', 'Apple', 'Huawei', 'Xiaomi']) {
      final models = CatalogData.phoneModelsByBrand[brand]!;
      final normalized = models.map((model) => model.toLowerCase()).toList();
      expect(normalized.toSet().length, models.length, reason: 'Duplicate model in $brand');
    }
  });

  test('Sudan city catalog preserves legacy values and has unique entries', () {
    const legacy = ['الخرطوم','أم درمان','بحري','شندي','عطبرة','بورتسودان','مدني','كسلا','الأبيض','نيالا'];
    for (final city in legacy) {
      expect(CatalogData.cities, contains(city));
    }
    expect(CatalogData.cities.toSet().length, CatalogData.cities.length);
    expect(CatalogData.citiesByState.length, 18);
  });
}
