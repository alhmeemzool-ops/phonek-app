import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, required this.initialLatitude, required this.initialLongitude});
  final double initialLatitude;
  final double initialLongitude;
  @override State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _selected;
  String? _address;
  @override void initState() { super.initState(); _selected = LatLng(widget.initialLatitude, widget.initialLongitude); _resolve(_selected); }
  Future<void> _resolve(LatLng p) async { final a = await LocationService.reverseGeocode(p.latitude, p.longitude); if (mounted) setState(() => _address = a); }
  void _select(LatLng p) { setState(() => _selected = p); _resolve(p); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('موقع المحل')),
    body: Stack(children: [
      GoogleMap(initialCameraPosition: CameraPosition(target: _selected, zoom: 16), myLocationEnabled: true, myLocationButtonEnabled: true, zoomControlsEnabled: false, onTap: _select,
        markers: {Marker(markerId: const MarkerId('shop'), position: _selected, draggable: true, onDragEnd: _select)}),
      Positioned(left: 16, right: 16, bottom: 24, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_address ?? 'جارٍ تحديد العنوان...', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('${_selected.latitude.toStringAsFixed(6)}, ${_selected.longitude.toStringAsFixed(6)}', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        ElevatedButton.icon(onPressed: () => Navigator.pop(context, {'latitude': _selected.latitude, 'longitude': _selected.longitude, 'address': _address}), icon: const Icon(Icons.check), label: const Text('تأكيد موقع المحل')),
      ]))))
    ]),
  );
}
