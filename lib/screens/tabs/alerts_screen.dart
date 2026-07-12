import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/report_service.dart';
import '../../utils/role_helper.dart';
import '../../utils/app_colors.dart';
import 'profile_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  List<ReportRecord> _reports = [];
  bool _loading = true;
  String? _barangayId;
  String? _barangayName;

  @override
  void initState() {
    super.initState();
    _loadBarangayInfo();
    ReportService.refresh.addListener(_loadReports);
  }

  Future<void> _loadBarangayInfo() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Get barangay_id from user metadata (for officials)
    final barangayId = RoleHelper.getBarangayId();
    if (barangayId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _barangayId = barangayId;
    });

    // Get barangay name
    try {
      final response = await _client
          .from('barangays')
          .select('name')
          .eq('id', barangayId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _barangayName = response['name'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading barangay name: $e');
    }
    
    // Load reports after getting barangay info
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (_barangayId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final reports = await ReportService.fetchByBarangay(_barangayId!, limit: 200);
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading reports: $e');
      setState(() {
        _loading = false;
      });
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
        title: Text(_barangayName != null ? 'Alerts - $_barangayName' : 'Alerts'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _barangayId == null
              ? const Center(
                  child: Text('Unable to load barangay information'),
                )
              : _reports.isEmpty
                  ? const Center(
                      child: Text('No reports found for your barangay'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final type = report.type;
                          final description = report.description;
                          final createdAt = report.createdAt;
                          final mediaUrls = report.mediaUrls;
                          
                          // Get icon for report type
                          IconData iconData;
                          Color iconColor;
                          switch (type.toLowerCase()) {
                            case 'crime':
                              iconData = Icons.gavel;
                              iconColor = AppColors.reportCrime;
                              break;
                            case 'accident':
                              iconData = Icons.car_crash;
                              iconColor = AppColors.reportAccident;
                              break;
                            case 'hazard':
                              iconData = Icons.warning;
                              iconColor = AppColors.reportHazard;
                              break;
                            default:
                              iconData = Icons.report;
                              iconColor = Colors.grey;
                          }
                          
                          // Get status color
                          Color statusColor;
                          String statusText = report.status;
                          switch (report.status.toLowerCase()) {
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
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.black.withOpacity(0.06)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconColor.withOpacity(0.1),
                                child: Icon(iconData, color: iconColor, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      type,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: statusColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      statusText.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showStatusDialog(context, report);
                              },
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _timeAgo(createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: mediaUrls.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.attachment),
                                      onPressed: () {
                                        // Show media dialog
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => Dialog(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AppBar(
                                                  title: const Text('Attachments'),
                                                  automaticallyImplyLeading: false,
                                                  actions: [
                                                    IconButton(
                                                      icon: const Icon(Icons.close),
                                                      onPressed: () => Navigator.of(ctx).pop(),
                                                    ),
                                                  ],
                                                ),
                                                Flexible(
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: mediaUrls.length,
                                                    itemBuilder: (ctx, idx) {
                                                      final url = mediaUrls[idx];
                                                      final isImage = url.toLowerCase().contains('.jpg') ||
                                                          url.toLowerCase().contains('.jpeg') ||
                                                          url.toLowerCase().contains('.png');
                                                      
                                                      return Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: isImage
                                                            ? Image.network(url)
                                                            : Text('Video: $url'),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
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

  void _showStatusDialog(BuildContext context, ReportRecord report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Status: ${report.type}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              report.description.isEmpty ? 'No details' : report.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select new status:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.pending, color: AppColors.statusPending),
              title: const Text('Pending'),
              trailing: report.status == 'pending' ? const Icon(Icons.check) : null,
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ReportService.updateStatus(report.id, 'pending');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status updated to Pending')),
                    );
                    _loadReports();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update status: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency, color: AppColors.statusResponding),
              title: const Text('Responding'),
              trailing: report.status == 'responding' ? const Icon(Icons.check) : null,
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ReportService.updateStatus(report.id, 'responding');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status updated to Responding')),
                    );
                    _loadReports();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update status: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.statusResolved),
              title: const Text('Resolved'),
              trailing: report.status == 'resolved' ? const Icon(Icons.check) : null,
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ReportService.updateStatus(report.id, 'resolved');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status updated to Resolved')),
                    );
                    _loadReports();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update status: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

