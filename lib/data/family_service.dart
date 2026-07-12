import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class FamilyService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Create a new family
  static Future<Map<String, dynamic>> createFamily(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be signed in to create a family.');
    }

    // Generate join code
    final codeResponse = await _client.rpc('generate_family_join_code');
    final joinCode = codeResponse as String;

    // Create family
    final family = await _client
        .from('families')
        .insert({
          'name': name,
          'join_code': joinCode,
          'created_by': userId,
        })
        .select()
        .single();

    // Add creator as owner
    await _client.from('family_members').insert({
      'family_id': family['id'],
      'user_id': userId,
      'role': 'owner',
    });

    return family;
  }

  /// Join a family using a join code
  static Future<Map<String, dynamic>> joinFamily(String joinCode) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be signed in to join a family.');
    }

    // Find family by join code using RPC function (bypasses RLS)
    final familyResponseJson = await _client
        .rpc('validate_family_join_code', params: {'p_join_code': joinCode.toUpperCase()});

    if (familyResponseJson == null) {
      throw Exception('Invalid join code. Please check and try again.');
    }

    // Parse JSON response
    final familyResponse = familyResponseJson as Map<String, dynamic>;
    final familyId = familyResponse['id'] as String;

    // Check if already a member
    final existingMember = await _client
        .from('family_members')
        .select()
        .eq('family_id', familyId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('You are already a member of this family.');
    }

    // Add as member
    await _client.from('family_members').insert({
      'family_id': familyId,
      'user_id': userId,
      'role': 'member',
    });

    return familyResponse;
  }

  /// Get user's families
  static Future<List<Map<String, dynamic>>> getUserFamilies() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Use a join query to get families with member role
    final response = await _client
        .from('family_members')
        .select('family_id, role, families(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    if (response.isEmpty) return [];

    // Transform the response
    return response.map((member) {
      final family = (member['families'] as Map<String, dynamic>?);
      if (family == null) return null;
      return {
        ...family,
        'user_role': member['role'],
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  /// Get family members with their names
  static Future<List<Map<String, dynamic>>> getFamilyMembers(String familyId) async {
    // Use RPC function to get user names (bypasses RLS and can access auth.users)
    final userNamesResponse = await _client
        .rpc('get_user_names_for_family', params: {'p_family_id': familyId});

    // Get member details (role, joined_at)
    final membersResponse = await _client
        .from('family_members')
        .select('user_id, role, joined_at')
        .eq('family_id', familyId)
        .order('joined_at', ascending: false);

    if (membersResponse.isEmpty) return [];

    // Create a map of user_id -> name/email for quick lookup
    final nameMap = <String, Map<String, String>>{};
    for (final nameData in userNamesResponse) {
      nameMap[nameData['user_id'] as String] = {
        'full_name': nameData['full_name'] as String? ?? 'Unknown',
        'email': nameData['email'] as String? ?? 'Unknown',
      };
    }

    // Combine member data with names
    return membersResponse.map((member) {
      final userId = member['user_id'] as String;
      final nameData = nameMap[userId] ?? {'full_name': 'Unknown', 'email': 'Unknown'};
      return {
        'user_id': userId,
        'full_name': nameData['full_name'],
        'email': nameData['email'],
        'role': member['role'],
        'joined_at': member['joined_at'],
      };
    }).toList();
  }

  /// Remove a member from family (owner only)
  static Future<void> removeMember(String familyId, String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('You must be signed in.');
    }

    // Check if current user is owner
    final memberResponse = await _client
        .from('family_members')
        .select('role')
        .eq('family_id', familyId)
        .eq('user_id', currentUserId)
        .maybeSingle();

    if (memberResponse == null || memberResponse['role'] != 'owner') {
      throw Exception('Only family owners can remove members.');
    }

    // Don't allow removing the owner
    final targetMember = await _client
        .from('family_members')
        .select('role')
        .eq('family_id', familyId)
        .eq('user_id', userId)
        .maybeSingle();

    if (targetMember != null && targetMember['role'] == 'owner') {
      throw Exception('Cannot remove the family owner.');
    }

    await _client
        .from('family_members')
        .delete()
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  /// Leave a family
  static Future<void> leaveFamily(String familyId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be signed in.');
    }

    // Check if user is owner
    final memberResponse = await _client
        .from('family_members')
        .select('role')
        .eq('family_id', familyId)
        .eq('user_id', userId)
        .maybeSingle();

    if (memberResponse != null && memberResponse['role'] == 'owner') {
      throw Exception('Family owners cannot leave. Transfer ownership or delete the family first.');
    }

    await _client
        .from('family_members')
        .delete()
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  /// Get family notifications
  static Future<List<Map<String, dynamic>>> getFamilyNotifications(String familyId, {int limit = 50}) async {
    final notifications = await _client
        .from('family_notifications')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(notifications);
  }

  /// Send notification to family (called from report creation)
  static Future<void> notifyFamily({
    required String familyId,
    required String reportType,
    required String reportId,
    String? description,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('Cannot send family notification: user not logged in');
        return;
      }

      final response = await _client.functions.invoke(
        'notify-family-members',
        body: {
          'family_id': familyId,
          'report_type': reportType,
          'report_id': reportId,
          'description': (description != null && description.isNotEmpty && description.length > 100)
              ? '${description.substring(0, 100)}...' 
              : (description ?? ''),
          'sent_by': userId,
        },
      );

      debugPrint('Family notification response: ${response.data}');
    } catch (e) {
      debugPrint('Failed to send family notifications: $e');
      // Don't throw - family notifications are optional
    }
  }
}

