import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/report_service.dart';
import '../../utils/app_colors.dart';
import 'profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final SupabaseClient _client = Supabase.instance.client;
  LatLng? _currentLatLng;
  List<ReportRecord> _reports = [];
  bool _hasCentered = false;
  LatLng? _barangayHallLocation;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadReports();
    _loadBarangayHall();
    ReportService.refresh.addListener(_loadReports);
  }

  Future<void> _loadBarangayHall() async {
    try {
      final user = _client.auth.currentUser;
      final userBarangayId = user?.userMetadata?['user_barangay_id'] as String?;
      
      if (userBarangayId == null) return;

      final response = await _client
          .from('barangays')
          .select('id, name, barangay_hall_lat, barangay_hall_lng')
          .eq('id', userBarangayId)
          .maybeSingle();

      if (response != null) {
        final lat = response['barangay_hall_lat'] as num?;
        final lng = response['barangay_hall_lng'] as num?;
        
        if (lat != null && lng != null) {
          setState(() {
            _barangayHallLocation = LatLng(lat.toDouble(), lng.toDouble());
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading barangay hall: $e');
    }
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final newLocation = LatLng(pos.latitude, pos.longitude);
      
      setState(() {
        _currentLatLng = newLocation;
      });
      
      // Wait a bit for the map to initialize, then center
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && !_hasCentered && _currentLatLng != null) {
        _mapController.move(_currentLatLng!, 15);
        _hasCentered = true;
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  Future<void> _loadReports() async {
    try {
      final items = await ReportService.fetchLatest(limit: 500);
      if (mounted) {
        setState(() => _reports = items);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    ReportService.refresh.removeListener(_loadReports);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show map immediately with a fallback center; move when location arrives
    final LatLng fallbackCenter = LatLng(14.5995, 120.9842);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Map'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLatLng ?? fallbackCenter,
            initialZoom: 14,
            onMapReady: () {
              // Recenter when map is ready and we have location
              if (_currentLatLng != null && !_hasCentered) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapController.move(_currentLatLng!, 15);
                  _hasCentered = true;
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.safezoneph.safezone_ph',
            ),
            // Report markers (loaded asynchronously after first paint)
            MarkerLayer(
              markers: _reports
                  .map((r) => Marker(
                        point: LatLng(r.lat, r.lng),
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.location_on, color: AppColors.mapReportMarker, size: 30),
                      ))
                  .toList(),
            ),
            // Barangay hall marker
            if (_barangayHallLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _barangayHallLocation!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.account_balance,
                      color: AppColors.mapBarangayHall,
                      size: 32,
                    ),
                  ),
                ],
              ),
            // User marker when available
            if (_currentLatLng != null)
              MarkerLayer(
                markers: [
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
                ],
              ),
          ],
        ),
      ),
    );
  }
}


