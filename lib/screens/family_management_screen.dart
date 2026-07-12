import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/family_service.dart';
import 'package:flutter/services.dart';

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _families = [];
  bool _loading = true;
  final TextEditingController _familyNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  String _getInitial(String? fullName, String? email) {
    final name = fullName ?? email ?? 'U';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Future<void> _loadFamilies() async {
    setState(() => _loading = true);
    try {
      final families = await FamilyService.getUserFamilies();
      setState(() {
        _families = families;
        _loading = false;
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

  Future<void> _createFamily() async {
    final name = _familyNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a family name')),
      );
      return;
    }

    try {
      final family = await FamilyService.createFamily(name);
      _familyNameController.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Family "${family['name']}" created!'),
            action: SnackBarAction(
              label: 'View Code',
              onPressed: () => _showJoinCode(family['join_code'] as String, family['name'] as String),
            ),
          ),
        );
        _loadFamilies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating family: $e')),
        );
      }
    }
  }

  Future<void> _joinFamily() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a join code')),
      );
      return;
    }

    try {
      final family = await FamilyService.joinFamily(code);
      _joinCodeController.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${family['name']}" family!')),
        );
        _loadFamilies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining family: $e')),
        );
      }
    }
  }

  void _showJoinCode(String code, String familyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Join Code for "$familyName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with family members:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: SelectableText(
                code,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.orange[900],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFamilyDetails(Map<String, dynamic> family) async {
    try {
      final members = await FamilyService.getFamilyMembers(family['id'] as String);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(family['name'] as String? ?? 'Family'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Members:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...members.map((member) {
                  final isCurrentUser = member['user_id'] == _client.auth.currentUser?.id;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        _getInitial(member['full_name'] as String?, member['email'] as String?),
                      ),
                    ),
                    title: Text(
                      member['full_name'] as String? ?? member['email'] as String? ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (member['role'] == 'owner')
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
                        if (family['user_role'] == 'owner' && 
                            member['role'] != 'owner' && 
                            !isCurrentUser)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            color: Colors.red,
                            onPressed: () async {
                              try {
                                await FamilyService.removeMember(
                                  family['id'] as String,
                                  member['user_id'] as String,
                                );
                                Navigator.of(ctx).pop();
                                _showFamilyDetails(family);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Member removed')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            if (family['user_role'] == 'owner')
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showJoinCode(family['join_code'] as String, family['name'] as String);
                },
                child: const Text('Show Join Code'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Families'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Create Family Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.add_circle_outline, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Create Family',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _familyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Family Name',
                              hintText: 'Enter family name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _createFamily,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Family'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Join Family Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group_add, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Join Family',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _joinCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Join Code',
                              hintText: 'Enter 6-character code',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 6,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _joinFamily,
                            icon: const Icon(Icons.login),
                            label: const Text('Join Family'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // My Families
                  const Text(
                    'My Families',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_families.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.family_restroom, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No families yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._families.map((family) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: Icon(Icons.family_restroom, color: Colors.orange[900]),
                          ),
                          title: Text(family['name'] as String? ?? 'Family'),
                          subtitle: Text(
                            family['user_role'] == 'owner' ? 'Owner' : 'Member',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (family['user_role'] == 'owner')
                                IconButton(
                                  icon: const Icon(Icons.qr_code),
                                  onPressed: () => _showJoinCode(
                                    family['join_code'] as String,
                                    family['name'] as String,
                                  ),
                                  tooltip: 'Show Join Code',
                                ),
                              IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () => _showFamilyDetails(family),
                                tooltip: 'View Details',
                              ),
                            ],
                          ),
                          onTap: () => _showFamilyDetails(family),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

