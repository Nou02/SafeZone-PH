import 'package:flutter/material.dart';
import '../tabs/report_screen.dart';
import '../tabs/profile_screen.dart';
import '../../data/report_service.dart';
import '../../utils/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedType = 'Crime';

  void selectType(String type) {
    setState(() => selectedType = type);
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
          padding: const EdgeInsets.all(16),
          children: [
            // Big CTA button
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: 64,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ReportScreen(initialType: selectedType)),
                    );
                  },
                  child: const Text('Report an Incident'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick actions card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _QuickActionTile(
                    icon: Icons.local_police,
                    label: 'Crime',
                    selected: selectedType == 'Crime',
                    highlightColor: AppColors.reportCrime,
                    onTap: () => selectType('Crime'),
                  ),
                  const Divider(height: 1),
                  _QuickActionTile(
                    icon: Icons.car_crash_outlined,
                    label: 'Accident',
                    selected: selectedType == 'Accident',
                    highlightColor: AppColors.reportAccident,
                    onTap: () => selectType('Accident'),
                  ),
                  const Divider(height: 1),
                  _QuickActionTile(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Hazard',
                    selected: selectedType == 'Hazard',
                    highlightColor: AppColors.reportHazard,
                    onTap: () => selectType('Hazard'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Community Alerts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<ReportRecord>>(
              future: ReportService.fetchLatest(limit: 10),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ));
                }
                final reports = snapshot.data!;
                if (reports.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No community alerts yet.'),
                  );
                }
                return Column(
                  children: reports.map((rr) {
                    String timeAgo = _timeAgo(rr.createdAt);
                    final images = _imageUrls(rr);
                    // Use the same icons as the quick-action buttons:
                    // Crime -> local_taxi_outlined, Accident -> car_crash_outlined, Hazard -> local_fire_department_outlined
                    final IconData typeIcon = rr.type == 'Hazard'
                        ? Icons.local_fire_department_outlined
                        : rr.type == 'Accident'
                            ? Icons.car_crash_outlined
                            : Icons.local_police;
                    // Get status color
                    Color statusColor;
                    String statusText = rr.status;
                    switch (rr.status.toLowerCase()) {
                      case 'pending':
                        statusColor = AppColors.statusPending;
                        break;
                      case 'responding':
                        statusColor = AppColors.statusResponding;
                        break;
                      case 'resolved':
                        statusColor = AppColors.statusResolved;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }
                    
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: ListTile(
                        leading: Icon(typeIcon, color: AppColors.primary),
                        title: Row(
                          children: [
                            Expanded(child: Text(rr.type)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                statusText.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(rr.description.isEmpty ? 'No details' : rr.description),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (images.isNotEmpty)
                              IconButton(
                                tooltip: 'View attachment',
                                icon: const Icon(Icons.image_outlined),
                                onPressed: () => _showImages(context, images),
                              ),
                            Text(timeAgo, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 4) return '${weeks}w ago';
  final months = (diff.inDays / 30).floor();
  if (months < 12) return '${months}mo ago';
  final years = (diff.inDays / 365).floor();
  return '${years}y ago';
}

List<String> _imageUrls(ReportRecord r) {
  final exts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  return r.mediaUrls.where((u) {
    final lower = u.toLowerCase();
    return exts.any((e) => lower.contains(e));
  }).toList();
}

void _showImages(BuildContext context, List<String> urls) {
  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.9,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: urls.length == 1
              ? InteractiveViewer(child: Image.network(urls.first, fit: BoxFit.contain))
              : PageView.builder(
                  itemCount: urls.length,
                  itemBuilder: (_, i) => InteractiveViewer(
                    child: Image.network(urls[i], fit: BoxFit.contain),
                  ),
                ),
        ),
      );
    },
  );
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color highlightColor;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.highlightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseCircle = Colors.grey.shade200;
    final Color circleBg = selected ? highlightColor.withOpacity(0.15) : baseCircle;
    final Color iconColor = selected ? highlightColor : Colors.black87;

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: circleBg,
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}


