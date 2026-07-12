import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/report_service.dart';
import '../../utils/app_colors.dart';
import 'profile_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  LatLng? _currentLatLng;
  final MapController _mapController = MapController();
  Stream<Position>? _positionStream;
  bool _hasCentered = false;
  List<ReportRecord> _reports = [];
  String? _selectedReportId;
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
        desiredAccuracy: LocationAccuracy.best,
      );
      final newLocation = LatLng(pos.latitude, pos.longitude);
      
      setState(() {
        _currentLatLng = newLocation;
      });
      
      // Wait a bit for the map to initialize, then center
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && !_hasCentered && _currentLatLng != null) {
        _mapController.move(_currentLatLng!, 14);
        _hasCentered = true;
      }

      // Live updates for higher accuracy
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      );
      _positionStream!.listen((p) {
        final point = LatLng(p.latitude, p.longitude);
        if (mounted) {
          setState(() => _currentLatLng = point);
          // Only update map position if user hasn't manually moved it
          // For now, we'll update it to follow the user
          try {
            _mapController.move(point, _mapController.camera.zoom);
          } catch (e) {
            debugPrint('Error moving map: $e');
          }
        }
      });
    } catch (_) {
      // Location error handled silently
    }
  }

  Future<void> _loadReports() async {
    try {
      final items = await ReportService.fetchForCurrentUser(limit: 100);
      if (mounted) {
        setState(() => _reports = items);
      }
    } catch (_) {}
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.statusPending;
      case 'responding':
        return AppColors.statusResponding;
      case 'resolved':
        return AppColors.statusResolved;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    ReportService.refresh.removeListener(_loadReports);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safezone PH'),
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
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'My Reports',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Map preview with OSM and markers
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLatLng ?? const LatLng(14.5995, 120.9842),
                          initialZoom: 14,
                          onMapReady: () {
                            // Recenter when map is ready and we have location
                            if (_currentLatLng != null && !_hasCentered) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _mapController.move(_currentLatLng!, 14);
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
                          // User marker
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
                          // Barangay hall marker
                          if (_barangayHallLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _barangayHallLocation!,
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.account_balance,
                                    color: AppColors.mapBarangayHall,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          // Report markers for this user
                          MarkerLayer(
                            markers: _reports
                                .map(
                                  (r) => Marker(
                                    point: LatLng(r.lat, r.lng),
                                    width: 28,
                                    height: 28,
                                    child: Icon(
                                      Icons.location_on,
                                      size: 24,
                                      color: r.id == _selectedReportId ? AppColors.mapReportMarker : AppColors.reportAccident,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_reports.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No reports yet.'),
              )
            else
              Column(
                children: _reports.map((r) {
                  final bool isSelected = r.id == _selectedReportId;
                  return Card(
                    elevation: 0,
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Row(
                        children: [
                          Expanded(child: Text(r.type)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(r.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getStatusColor(r.status).withOpacity(0.3)),
                            ),
                            child: Text(
                              r.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(r.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        r.description.isEmpty ? 'No details' : r.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() => _selectedReportId = r.id);
                        _mapController.move(LatLng(r.lat, r.lng), 16);
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// Legend dots and report tiles removed


