import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safezone_ph/screens/login_screen.dart';
import '../admin/manage_barangays_screen.dart';
import '../head_official/manage_barangay_officials_screen.dart';
import '../verification_screen.dart';
import '../../utils/role_helper.dart';
import '../../data/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController familyPhoneController = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;
  
  List<Map<String, dynamic>> _barangays = [];
  String? _selectedBarangayId;
  bool _loadingBarangays = false;

  @override
  void initState() {
    super.initState();
    final user = _client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    nameController.text = (meta['full_name'] ?? '') as String;
    phoneController.text = (meta['phone'] ?? '') as String;
    familyPhoneController.text = (meta['family_phone'] ?? '') as String;
    _selectedBarangayId = meta['user_barangay_id'] as String?;
  }

  Future<void> _loadBarangays() async {
    if (_loadingBarangays) return;
    setState(() => _loadingBarangays = true);
    try {
      final response = await _client
          .from('barangays')
          .select('id, name')
          .order('name');
      setState(() {
        _barangays = List<Map<String, dynamic>>.from(response);
        _loadingBarangays = false;
      });
    } catch (e) {
      setState(() {
        _barangays = [];
        _loadingBarangays = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    familyPhoneController.dispose();
    super.dispose();
  }

  String? get _userRole => RoleHelper.getCurrentUserRole();

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final email = user?.email ?? 'Unknown';
    final displayName =
        (user?.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
            ? user!.userMetadata!['full_name'] as String
            : 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Center(child: Text(email, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            subtitle: const Text('Edit your profile details'),
            onTap: () => _openEditProfile(context),
          ),
          // Show verification option for users who aren't verified yet
          if (_userRole == null && !RoleHelper.isCityAdmin()) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Barangay Official Verification'),
              subtitle: const Text('Verify your account with a passcode'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const VerificationScreen(),
                ).then((_) {
                  setState(() {}); // Refresh to show updated verification status
                });
              },
            ),
          ],
          // Show role-specific options
          if (RoleHelper.isCityAdmin()) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Manage Barangays'),
              subtitle: const Text('Add barangays and generate Head Official passcodes'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageBarangaysScreen(),
                  ),
                );
              },
            ),
          ],
          if (RoleHelper.isHeadBarangayOfficial()) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Barangay Officials'),
              subtitle: const Text('Generate passcodes and manage officials'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageBarangayOfficialsScreen(),
                  ),
                );
              },
            ),
          ],
          // Show verification status if verified
          if (_userRole == RoleHelper.headBarangayOfficial || _userRole == RoleHelper.barangayOfficial) ...[
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.verified_user,
                color: Colors.green,
              ),
              title: Text(
                _userRole == RoleHelper.headBarangayOfficial
                    ? 'Head Barangay Official'
                    : 'Barangay Official',
              ),
              subtitle: Text(
                _client.auth.currentUser?.userMetadata?['barangay_name'] as String? ?? 'Verified',
              ),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await _client.auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  void _openEditProfile(BuildContext context) {
    // Load barangays when opening the dialog
    _loadBarangays();
    
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Update your personal details and emergency contact.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone number'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: familyPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Family member phone (emergency contact)',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _loadingBarangays
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String>(
                            value: _selectedBarangayId,
                            decoration: const InputDecoration(
                              labelText: 'Barangay',
                              hintText: 'Select your barangay',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('None selected'),
                              ),
                              ..._barangays.map((barangay) {
                                return DropdownMenuItem<String>(
                                  value: barangay['id'] as String,
                                  child: Text(barangay['name'] as String),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedBarangayId = value;
                              });
                            },
                          ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            final selectedBarangay = _barangays
                                .firstWhere(
                                  (b) => b['id'] == _selectedBarangayId,
                                  orElse: () => {},
                                );
                            
                            final oldBarangayId = _client.auth.currentUser?.userMetadata?['user_barangay_id'] as String?;
                            
                            await _client.auth.updateUser(
                              UserAttributes(
                                data: {
                                  'full_name': nameController.text.trim(),
                                  'phone': phoneController.text.trim(),
                                  'family_phone': familyPhoneController.text.trim(),
                                  'user_barangay_id': _selectedBarangayId,
                                  'user_barangay_name': selectedBarangay['name'] as String?,
                                },
                              ),
                            );
                            
                            // Re-initialize notifications if barangay was just set or changed
                            if (_selectedBarangayId != null && (oldBarangayId == null || _selectedBarangayId != oldBarangayId)) {
                              try {
                                final notificationService = NotificationService();
                                await notificationService.reinitialize();
                                debugPrint('✅ Notifications re-initialized after profile update');
                              } catch (e) {
                                debugPrint('⚠️ Failed to re-initialize notifications: $e');
                              }
                            }
                            
                            if (!mounted) return;
                            setState(() {});
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile updated')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Update failed: $e')),
                            );
                          }
                        },
                        child: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


