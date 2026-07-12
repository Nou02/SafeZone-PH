import 'package:flutter/material.dart';
import '../../data/family_service.dart';
import '../family_management_screen.dart';

class FamilyNotificationsScreen extends StatefulWidget {
  const FamilyNotificationsScreen({super.key});

  @override
  State<FamilyNotificationsScreen> createState() => _FamilyNotificationsScreenState();
}

class _FamilyNotificationsScreenState extends State<FamilyNotificationsScreen> {
  List<Map<String, dynamic>> _families = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _selectedFamilyId;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  Future<void> _loadFamilies() async {
    setState(() => _loading = true);
    try {
      final families = await FamilyService.getUserFamilies();
      setState(() {
        _families = families;
        _loading = false;
        if (families.isNotEmpty && _selectedFamilyId == null) {
          _selectedFamilyId = families.first['id'] as String;
          _loadNotifications();
        }
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading families: $e')),
        );
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (_selectedFamilyId == null) return;

    setState(() => _loading = true);
    try {
      final notifications = await FamilyService.getFamilyNotifications(_selectedFamilyId!);
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FamilyManagementScreen(),
                ),
              ).then((_) => _loadFamilies());
            },
            tooltip: 'Manage Families',
          ),
        ],
      ),
      body: _loading && _families.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _families.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    if (_families.length > 1) _buildFamilySelector(),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _notifications.isEmpty
                              ? _buildEmptyNotifications()
                              : _buildNotificationsList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Family Groups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a family to receive family notifications',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FamilyManagementScreen(),
                  ),
                ).then((_) => _loadFamilies());
              },
              icon: const Icon(Icons.add),
              label: const Text('Create or Join Family'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFamilyId,
          isExpanded: true,
          items: _families.map((family) {
            return DropdownMenuItem<String>(
              value: family['id'] as String,
              child: Row(
                children: [
                  Icon(Icons.group, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      family['name'] as String? ?? 'Family',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (family['user_role'] == 'owner')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Owner',
                        style: TextStyle(fontSize: 10, color: Colors.orange[900]),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedFamilyId = value);
            _loadNotifications();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Family notifications will appear here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final createdAt = DateTime.parse(notification['created_at'] as String);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Colors.orange[100],
                child: Icon(Icons.family_restroom, color: Colors.orange[900]),
              ),
              title: Text(
                notification['title'] as String? ?? 'Family Notification',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(notification['message'] as String? ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}

