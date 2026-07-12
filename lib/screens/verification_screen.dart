import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _passcodeController = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;
  bool _isVerifying = false;
  String? _errorMessage;

  // Verify passcode and return the role type
  // Returns: 'head_barangay_official', 'barangay_official', or null
  Future<Map<String, dynamic>?> _verifyPasscode(String passcode) async {
    final trimmedPasscode = passcode.trim().toUpperCase();
    
    try {
      // First, check if it's a Head Barangay Official passcode
      final barangayRes = await _client
          .from('barangays')
          .select('id, name, head_official_passcode')
          .eq('head_official_passcode', trimmedPasscode)
          .maybeSingle();
      
      if (barangayRes != null) {
        return {
          'role': 'head_barangay_official',
          'barangay_id': barangayRes['id'],
          'barangay_name': barangayRes['name'],
        };
      }
      
      // Then, check if it's a Barangay Official passcode
      final passcodeRes = await _client
          .from('barangay_official_passcodes')
          .select('id, barangay_id, used_by_user_id, expires_at')
          .eq('passcode', trimmedPasscode)
          .filter('used_by_user_id', 'is', null)
          .maybeSingle();
      
      if (passcodeRes != null) {
        // Check if expired
        final expiresAt = passcodeRes['expires_at'];
        if (expiresAt != null) {
          final expiry = DateTime.parse(expiresAt.toString());
          if (expiry.isBefore(DateTime.now())) {
            return null; // Expired
          }
        }
        
        return {
          'role': 'barangay_official',
          'passcode_id': passcodeRes['id'],
          'barangay_id': passcodeRes['barangay_id'],
        };
      }
    } catch (e) {
      // Error checking passcode
      return null;
    }
    
    return null; // Invalid passcode
  }

  Future<void> _submitVerification() async {
    if (_passcodeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a passcode';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await _verifyPasscode(_passcodeController.text);
      
      if (result != null) {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          setState(() {
            _errorMessage = 'User not authenticated';
            _isVerifying = false;
          });
          return;
        }

        final role = result['role'] as String;
        final barangayId = result['barangay_id'] as String?;

        // Update user metadata
        final userData = <String, dynamic>{
          'role': role,
          'verified_at': DateTime.now().toIso8601String(),
        };

        if (barangayId != null) {
          userData['barangay_id'] = barangayId;
        }

        if (role == 'head_barangay_official' && result['barangay_name'] != null) {
          userData['barangay_name'] = result['barangay_name'];
        }

        await _client.auth.updateUser(UserAttributes(data: userData));
        
        // Refresh session to update JWT token with new metadata
        await _client.auth.refreshSession();

        // If it's a Barangay Official passcode, mark it as used
        if (role == 'barangay_official' && result['passcode_id'] != null) {
          try {
            final currentUser = _client.auth.currentUser;
            final userName = (currentUser?.userMetadata?['full_name'] as String?)?.trim() ?? 
                            currentUser?.email?.split('@').first ?? 'Unknown';
            final userEmail = currentUser?.email ?? '';
            
            final updateResult = await _client
                .from('barangay_official_passcodes')
                .update({
                  'used_by_user_id': userId,
                  'used_by_name': userName,
                  'used_by_email': userEmail,
                  'used_at': DateTime.now().toIso8601String(),
                })
                .eq('id', result['passcode_id'])
                .select();
            
            if (updateResult.isEmpty) {
              debugPrint('Warning: Passcode update returned no rows. Passcode ID: ${result['passcode_id']}');
            }
          } catch (updateError) {
            debugPrint('Error updating passcode: $updateError');
            // Don't fail the verification if update fails, but log it
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification succeeded but failed to mark passcode as used: $updateError'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }

        if (!mounted) return;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              role == 'head_barangay_official'
                  ? 'Successfully verified as Head Barangay Official'
                  : 'Successfully verified as Barangay Official',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid or expired passcode. Please try again.';
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
        _isVerifying = false;
      });
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final role = user?.userMetadata?['role'] as String?;
    final isVerified = role == 'head_barangay_official' || role == 'barangay_official';

    return Dialog(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Barangay Official Verification',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusResolved.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.statusResolved.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.statusResolved),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            role == 'head_barangay_official'
                                ? 'You are verified as a Head Barangay Official'
                                : 'You are verified as a Barangay Official',
                            style: TextStyle(color: AppColors.statusResolved),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Enter a passcode to verify your role:\n• Head Barangay Official passcode (from City Admin)\n• Barangay Official passcode (from Head Official)',
                    style: TextStyle(color: Colors.grey),
                  ),
                if (!isVerified) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Passcode',
                      hintText: 'Enter verification passcode',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: !_isVerifying,
                    onSubmitted: (_) => _submitVerification(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isVerifying ? null : _submitVerification,
                      child: _isVerifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verify'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

