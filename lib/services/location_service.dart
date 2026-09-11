import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('فعّل خدمة الموقع في الهاتف');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('صلاحية الموقع غير متاحة');
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return null;
      final p = places.first;
      return [p.name, p.street, p.subLocality, p.locality, p.administrativeArea].whereType<String>().where((v) => v.trim().isNotEmpty).join('، ');
    } catch (_) {
      return null;
    }
  }
}
