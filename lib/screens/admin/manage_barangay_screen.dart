import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageBarangayScreen extends StatefulWidget {
  const ManageBarangayScreen({super.key});

  @override
  State<ManageBarangayScreen> createState() => _ManageBarangayScreenState();
}

class _ManageBarangayScreenState extends State<ManageBarangayScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _officials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOfficials();
  }

  Future<void> _loadOfficials() async {
    setState(() => _loading = true);
    try {
      final response = await _client
          .from('barangay_officials')
          .select()
          .order('name');
      setState(() {
        _officials = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      // Table might not exist yet, show empty list
      setState(() {
        _officials = [];
        _loading = false;
      });
    }
  }

  Future<void> _addOfficial() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final positionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Barangay Official',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                    controller: positionController,
                    decoration: const InputDecoration(labelText: 'Position (e.g., Barangay Captain)'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await _client.from('barangay_officials').insert({
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'position': positionController.text.trim(),
        });
        if (!mounted) return;
        _loadOfficials();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official added')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    }
  }

  Future<void> _deleteOfficial(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Official?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('barangay_officials').delete().eq('id', id);
        if (!mounted) return;
        _loadOfficials();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _setVerificationPasscode() async {
    final passcodeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set Verification Passcode',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This passcode will be used by users to verify themselves as Barangay Officials.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Verification Passcode',
                      hintText: 'Enter a secure passcode',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Set Passcode'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true && passcodeController.text.trim().isNotEmpty) {
      try {
        // Store passcode in a settings table or update a single row
        // For now, we'll use a simple approach: store in a 'verification_settings' table
        await _client.from('verification_settings').upsert({
          'id': 'main',
          'verification_passcode': passcodeController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification passcode updated')),
        );
      } catch (e) {
        // If table doesn't exist, try storing in barangay_officials as a fallback
        // This is a workaround - in production, create the verification_settings table
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update passcode. Please create verification_settings table. Error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Barangay Officials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: _setVerificationPasscode,
            tooltip: 'Set verification passcode',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addOfficial,
            tooltip: 'Add official',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _officials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No barangay officials yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _addOfficial,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Official'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _officials.length,
                  itemBuilder: (context, index) {
                    final official = _officials[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(official['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (official['position'] != null)
                              Text('${official['position']}'),
                            if (official['phone'] != null)
                              Text('${official['phone']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteOfficial(official['id']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

