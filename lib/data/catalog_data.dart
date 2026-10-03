/// بيانات الكتالوج الثابتة المستخدمة في نماذج الإضافة والفلاتر.
class CatalogData {
  static const List<String> cities = [
    'الخرطوم', 'أم درمان', 'بحري', 'شندي', 'عطبرة', 'بورتسودان', 'مدني', 'كسلا', 'الأبيض', 'نيالا',
  ];

  static const List<String> brands = [
    'iPhone', 'Samsung', 'Tecno', 'Infinix', 'Xiaomi', 'Realme', 'Honor', 'Oppo',
  ];

  static const Map<String, List<String>> phoneModelsByBrand = {
    'iPhone': ['iPhone 11', 'iPhone 12', 'iPhone 13', 'iPhone 13 Pro', 'iPhone 14', 'iPhone 15', 'iPhone 15 Pro'],
    'Samsung': ['Galaxy A15', 'Galaxy A25', 'Galaxy A35', 'Galaxy A55', 'Galaxy A73 5G', 'Galaxy S23', 'Galaxy S24'],
    'Tecno': ['Spark 10', 'Spark 20', 'Camon 20', 'Camon 30', 'Phantom X2'],
    'Infinix': ['Hot 30', 'Hot 40', 'Note 30', 'Note 40', 'Zero 30'],
    'Xiaomi': ['Redmi Note 12', 'Redmi Note 13', 'Redmi 13C', 'Poco X6', 'Xiaomi 13T'],
    'Realme': ['C53', 'C55', 'C67', '11 Pro', '12 Pro'],
    'Honor': ['X7b', 'X8b', '90 Lite', '90', 'Magic6 Lite'],
    'Oppo': ['A58', 'A78', 'Reno 10', 'Reno 11', 'Find X5'],
  };
}
