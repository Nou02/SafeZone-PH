import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/report_service.dart';
import 'package:file_picker/file_picker.dart';
import 'profile_screen.dart';
import '../../utils/app_colors.dart';

class ReportScreen extends StatefulWidget {
  final String? initialType;
  const ReportScreen({super.key, this.initialType});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final List<String> types = const ['Crime', 'Accident', 'Hazard'];
  late String selectedType;
  final TextEditingController descriptionController = TextEditingController();
  final MapController _mapController = MapController();
  LatLng? _currentLatLng;
  bool _locating = true;
  Stream<Position>? _positionStream;
  bool _hasInitialCentered = false;
  DateTime? _lastMapMove;
  final List<String> notifyTargets = const [
    'Barangay Officials',
    'Police Officials',
    'Ambulance',
    'Family Members',
  ];
  String selectedNotify = 'Barangay Officials';
  List<PlatformFile> _pickedFiles = const [];

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType != null && types.contains(widget.initialType)
        ? widget.initialType!
        : 'Crime';
    _initLocation();
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final initialLocation = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLatLng = initialLocation;
        _locating = false;
      });

      // Center map on initial location
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _mapController.move(initialLocation, 15);
          _hasInitialCentered = true;
        }
      }

      // Start live updates with optimized settings for mobile
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20, // Update every 20 meters instead of 5
        ),
      );
      _positionStream!.listen((p) {
        if (!mounted) return;
        final newPoint = LatLng(p.latitude, p.longitude);
        setState(() => _currentLatLng = newPoint);
        
        // Only recenter map occasionally, not on every update
        // Recenter if it's been more than 5 seconds since last move
        final now = DateTime.now();
        if (!_hasInitialCentered || 
            _lastMapMove == null || 
            now.difference(_lastMapMove!).inSeconds > 5) {
          _mapController.move(newPoint, _mapController.camera.zoom);
          _lastMapMove = now;
        }
      });
    } catch (_) {
      setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeZone PH'),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
          children: [
            const Text(
              'Create Report',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Type of incident
            const Text('Type of Incident', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _OutlinedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    items: types
                        .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedType = v ?? selectedType),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Who to notify
            const Text('Notify', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _OutlinedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedNotify,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    items: notifyTargets
                        .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedNotify = v ?? selectedNotify),
                  ),
                ),
              ),
            ),

            // Description
            const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _OutlinedBox(
              child: TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add details',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Upload button placeholder
            _OutlinedBox(
              child: InkWell(
                onTap: () async {
                  try {
                    final files = await ReportService.pickMedia();
                    setState(() => _pickedFiles = files);
                    if (files.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${files.length} file(s) selected')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Select failed: $e')),
                    );
                  }
                },
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload_file, size: 18),
                        const SizedBox(width: 8),
                        Text(_pickedFiles.isEmpty
                            ? 'Upload Photos/Videos'
                            : 'Selected: ${_pickedFiles.length}'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text('Auto Location Tag', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            // Location preview / live map (OpenStreetMap via flutter_map)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: _currentLatLng != null
                    ? FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLatLng!,
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.safezoneph.safezone_ph',
                          ),
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
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: _locating
                              ? const CircularProgressIndicator()
                              : const Text('Location unavailable. Enable permissions.'),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Send button
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_currentLatLng == null) return;
                  // Only add notification prefix if not family members
                  final descToSave = selectedNotify == 'Family Members'
                      ? descriptionController.text
                      : '[Notify: $selectedNotify]\n${descriptionController.text}';
                  ReportService.createReport(
                    type: selectedType,
                    description: descToSave,
                    lat: _currentLatLng!.latitude,
                    lng: _currentLatLng!.longitude,
                    filesToUpload: _pickedFiles,
                    notifyTarget: selectedNotify,
                  ).then((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted')),
                    );
                  }).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to submit: $e')),
                    );
                  });
                },
                child: const Text('Send Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedBox extends StatelessWidget {
  final Widget child;
  const _OutlinedBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}


