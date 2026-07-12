import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/role_helper.dart';

class GeneratePasscodeScreen extends StatefulWidget {
  const GeneratePasscodeScreen({super.key});

  @override
  State<GeneratePasscodeScreen> createState() => _GeneratePasscodeScreenState();
}

class _GeneratePasscodeScreenState extends State<GeneratePasscodeScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _generatedPasscodes = [];
  bool _loading = true;
  String? _barangayId;
  String? _barangayName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final barangayId = RoleHelper.getBarangayId();
      if (barangayId != null) {
        _barangayId = barangayId;
        // Get barangay name
        final barangayRes = await _client
            .from('barangays')
            .select('name')
            .eq('id', barangayId)
            .maybeSingle();
        if (barangayRes != null) {
          _barangayName = barangayRes['name'] as String?;
        }

        // Load generated passcodes
        final passcodesRes = await _client
            .from('barangay_official_passcodes')
            .select()
            .eq('barangay_id', barangayId)
            .order('created_at', ascending: false);
        setState(() {
          _generatedPasscodes = List<Map<String, dynamic>>.from(passcodesRes);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _generatePasscode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _generateNewPasscode() async {
    if (_barangayId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barangay ID not found')),
      );
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final passcode = _generatePasscode();
      await _client.from('barangay_official_passcodes').insert({
        'barangay_id': _barangayId,
        'generated_by_user_id': userId,
        'passcode': passcode,
      });
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passcode generated: $passcode'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate: $e')),
      );
    }
  }

  Future<void> _copyPasscode(String passcode) async {
    // For web, we can use clipboard
    // For mobile, this would need the clipboard package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Passcode: $passcode (tap to copy)'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Passcodes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _generateNewPasscode,
            tooltip: 'Generate new passcode',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _barangayId == null
              ? const Center(
                  child: Text('Barangay ID not found. Please verify as Head Barangay Official first.'),
                )
              : Column(
                  children: [
                    if (_barangayName != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          'Barangay: $_barangayName',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: _generatedPasscodes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.vpn_key_outlined, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No passcodes generated yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: _generateNewPasscode,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Generate First Passcode'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _generatedPasscodes.length,
                              itemBuilder: (context, index) {
                                final passcode = _generatedPasscodes[index];
                                final isUsed = passcode['used_by_user_id'] != null;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: isUsed ? Colors.grey.shade100 : null,
                                  child: ListTile(
                                    leading: Icon(
                                      isUsed ? Icons.check_circle : Icons.vpn_key,
                                      color: isUsed ? Colors.green : Colors.blue,
                                    ),
                                    title: Text(
                                      passcode['passcode'] ?? 'N/A',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isUsed ? Colors.grey : null,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isUsed)
                                          const Text(
                                            'Used',
                                            style: TextStyle(color: Colors.green),
                                          )
                                        else
                                          const Text(
                                            'Available',
                                            style: TextStyle(color: Colors.blue),
                                          ),
                                        Text(
                                          'Created: ${_formatDate(passcode['created_at'])}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    trailing: isUsed
                                        ? null
                                        : IconButton(
                                            icon: const Icon(Icons.copy),
                                            onPressed: () => _copyPasscode(passcode['passcode']),
                                            tooltip: 'Copy passcode',
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }
}

