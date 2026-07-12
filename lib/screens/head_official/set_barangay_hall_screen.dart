import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/role_helper.dart';
import '../../utils/app_colors.dart';

class SetBarangayHallScreen extends StatefulWidget {
  const SetBarangayHallScreen({super.key});

  @override
  State<SetBarangayHallScreen> createState() => _SetBarangayHallScreenState();
}

class _SetBarangayHallScreenState extends State<SetBarangayHallScreen> {
  final MapController _mapController = MapController();
  final SupabaseClient _client = Supabase.instance.client;
  LatLng? _currentLatLng;
  LatLng? _selectedLocation;
  bool _locating = true;
  bool _saving = false;
  String? _barangayId;
  String? _barangayName;
  LatLng? _existingHallLocation;

  @override
  void initState() {
    super.initState();
    _loadBarangayInfo();
    _initLocation();
  }

  Future<void> _loadBarangayInfo() async {
    try {
      final barangayId = RoleHelper.getBarangayId();
      if (barangayId != null) {
        _barangayId = barangayId;
        final response = await _client
            .from('barangays')
            .select('name, barangay_hall_lat, barangay_hall_lng')
            .eq('id', barangayId)
            .maybeSingle();
        
        if (response != null) {
          setState(() {
            _barangayName = response['name'] as String?;
            final lat = response['barangay_hall_lat'];
            final lng = response['barangay_hall_lng'];
            if (lat != null && lng != null) {
              _existingHallLocation = LatLng(
                (lat as num).toDouble(),
                (lng as num).toDouble(),
              );
              _selectedLocation = _existingHallLocation;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading barangay info: $e');
    }
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _locating = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _locating = false;
        // If no existing location, center on current location
        if (_selectedLocation == null) {
          _selectedLocation = _currentLatLng;
          _mapController.move(_currentLatLng!, 16);
        } else {
          _mapController.move(_selectedLocation!, 16);
        }
      });
    } catch (_) {
      setState(() => _locating = false);
    }
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null || _barangayId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    final barangayId = _barangayId;
    if (barangayId == null) return;

    setState(() => _saving = true);
    try {
      await _client
          .from('barangays')
          .update({
            'barangay_hall_lat': _selectedLocation!.latitude,
            'barangay_hall_lng': _selectedLocation!.longitude,
          })
          .eq('id', barangayId);
      
      if (!mounted) return;
      setState(() {
        _existingHallLocation = _selectedLocation;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barangay hall location saved!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Barangay Hall Location'),
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _saveLocation,
              tooltip: 'Save location',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_barangayName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                'Barangay: $_barangayName',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _locating
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation ?? 
                              _currentLatLng ?? 
                              const LatLng(14.5995, 120.9842),
                          initialZoom: 16,
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedLocation = point;
                            });
                            _mapController.move(point, _mapController.camera.zoom);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.safezoneph.safezone_ph',
                          ),
                          MarkerLayer(
                            markers: [
                              // Current user location
                              if (_currentLatLng != null)
                                Marker(
                                  point: _currentLatLng!,
                                  width: 16,
                                  height: 16,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.mapUserLocation,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              // Selected barangay hall location
                              if (_selectedLocation != null)
                                Marker(
                                  point: _selectedLocation!,
                                  width: 48,
                                  height: 48,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 48,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      // Instructions overlay
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _existingHallLocation != null
                                        ? 'Tap on the map to update the barangay hall location'
                                        : 'Tap on the map to set the barangay hall location',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

