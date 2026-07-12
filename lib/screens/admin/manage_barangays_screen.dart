import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_colors.dart';

class ManageBarangaysScreen extends StatefulWidget {
  const ManageBarangaysScreen({super.key});

  @override
  State<ManageBarangaysScreen> createState() => _ManageBarangaysScreenState();
}

class _ManageBarangaysScreenState extends State<ManageBarangaysScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _barangays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    setState(() => _loading = true);
    try {
      final response = await _client
          .from('barangays')
          .select()
          .order('name');
      setState(() {
        _barangays = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _barangays = [];
        _loading = false;
      });
    }
  }

  String _generatePasscode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _addBarangay() async {
    final nameController = TextEditingController();
    final passcodeController = TextEditingController(text: _generatePasscode());

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
                    'Add Barangay',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Barangay Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passcodeController,
                    decoration: InputDecoration(
                      labelText: 'Head Official Passcode',
                      hintText: 'Unique passcode for Head Barangay Official',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          passcodeController.text = _generatePasscode();
                        },
                        tooltip: 'Generate new passcode',
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Users who enter this passcode will become Head Barangay Officials for this barangay.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
        await _client.from('barangays').insert({
          'name': nameController.text.trim(),
          'head_official_passcode': passcodeController.text.trim().toUpperCase(),
        });
        if (!mounted) return;
        _loadBarangays();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barangay "${nameController.text.trim()}" added with passcode: ${passcodeController.text.trim()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    }
  }

  Future<void> _regeneratePasscode(String barangayId, String currentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Passcode?'),
        content: const Text('This will invalidate the current passcode. Users will need the new passcode to become Head Barangay Officials.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final newPasscode = _generatePasscode();
        await _client
            .from('barangays')
            .update({'head_official_passcode': newPasscode.toUpperCase()})
            .eq('id', barangayId);
        if (!mounted) return;
        _loadBarangays();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New passcode for $currentName: $newPasscode'),
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate: $e')),
        );
      }
    }
  }

  Future<void> _deleteBarangay(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Barangay?'),
        content: Text('This will delete "$name" and all associated data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('barangays').delete().eq('id', id);
        if (!mounted) return;
        _loadBarangays();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barangay deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Barangays'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addBarangay,
            tooltip: 'Add barangay',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _barangays.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_city_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No barangays yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _addBarangay,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Barangay'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _barangays.length,
                  itemBuilder: (context, index) {
                    final barangay = _barangays[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.location_city),
                        ),
                        title: Text(barangay['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('Passcode: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  barangay['head_official_passcode'] ?? 'N/A',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.orange),
                              onPressed: () => _regeneratePasscode(
                                barangay['id'],
                                barangay['name'],
                              ),
                              tooltip: 'Regenerate passcode',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteBarangay(
                                barangay['id'],
                                barangay['name'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

