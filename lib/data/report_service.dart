import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'family_service.dart';

class ReportRecord {
  final String id;
  final String userId;
  final String type;
  final String description;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final List<String> mediaUrls;
  final String status; // 'pending', 'responding', 'resolved'

  ReportRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.mediaUrls,
    this.status = 'pending',
  });

  static ReportRecord fromJson(Map<String, dynamic> json, List<String> mediaUrls) {
    return ReportRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      description: (json['description'] ?? '') as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrls: mediaUrls,
      status: (json['status'] as String?) ?? 'pending',
    );
  }
}

class ReportService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String reportsTable = 'reports';
  static const String mediaTable = 'report_media';
  static const String bucket = 'reports-media';

  // Notifier to let UI know a new report was created (to refresh markers/lists)
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  static Future<List<PlatformFile>> pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
    );
    return result?.files ?? <PlatformFile>[];
  }

  static Future<ReportRecord> createReport({
    required String type,
    required String description,
    required double lat,
    required double lng,
    List<PlatformFile>? filesToUpload,
    String? notifyTarget, // 'Barangay Officials', 'Family Members', etc.
  }) async {
    // Require authenticated user
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be signed in to create a report.');
    }

    // Get user's barangay_id from metadata
    final user = _client.auth.currentUser;
    final userBarangayId = user?.userMetadata?['user_barangay_id'] as String?;

    // Insert report first
    final insertData = {
      'user_id': userId,
      'type': type,
      'description': description,
      'lat': lat,
      'lng': lng,
    };
    
    // Add barangay_id if available
    if (userBarangayId != null) {
      insertData['barangay_id'] = userBarangayId;
    }
    
    // Set default status to 'pending'
    insertData['status'] = 'pending';
    
    final insertRes = await _client.from(reportsTable).insert(insertData)
        .select('id, user_id, type, description, lat, lng, created_at, status').single();

    final String reportId = insertRes['id'] as String;

    // Upload media
    // Only upload files if caller provided them. Do NOT open a picker here.
    final files = filesToUpload ?? <PlatformFile>[];
    final List<String> urls = [];
    for (final f in files) {
      final String path = '$reportId/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      if (f.bytes != null) {
        await _client.storage.from(bucket).uploadBinary(path, f.bytes!);
      } else if (f.path != null) {
        await _client.storage.from(bucket).upload(path, File(f.path!));
      }
      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
      urls.add(publicUrl);
      await _client.from(mediaTable).insert({
        'report_id': reportId,
        'path': path,
      });
    }

    final record = ReportRecord.fromJson(insertRes, urls);
    
    // Handle notifications based on target
    if (notifyTarget == 'Family Members') {
      // Notify family members only (don't add to community alerts)
      try {
        // Get user's families
        final families = await _client
            .from('family_members')
            .select('family_id')
            .eq('user_id', userId);
        
        if (families.isNotEmpty) {
          // Notify all families the user belongs to
          for (final family in families) {
            final familyId = family['family_id'] as String;
            try {
              await FamilyService.notifyFamily(
                familyId: familyId,
                reportType: type,
                reportId: reportId,
                description: description,
              );
            } catch (e) {
              debugPrint('Failed to notify family $familyId: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to send family notifications: $e');
      }
    } else if (notifyTarget == 'Barangay Officials' && userBarangayId != null) {
      // Trigger notifications to users in the same barangay (community alerts)
      try {
        debugPrint('Calling notify-barangay-users for barangay: $userBarangayId');
        final response = await _client.functions.invoke(
          'notify-barangay-users',
          body: {
            'barangay_id': userBarangayId,
            'report_type': type,
            'report_id': reportId,
            'description': description.length > 100 
                ? '${description.substring(0, 100)}...' 
                : description,
          },
        );
        debugPrint('Notification response: $response');
      } catch (e, stackTrace) {
        debugPrint('Failed to send notifications: $e');
        debugPrint('Stack trace: $stackTrace');
        if (e.toString().contains('not found') || e.toString().contains('404')) {
          debugPrint('⚠️ Edge Function "notify-barangay-users" not deployed.');
        }
      }
    }
    
    // Notify listeners to refresh views (e.g., Map markers, lists)
    refresh.value++;
    return record;
  }

  static Future<List<ReportRecord>> fetchLatest({int limit = 20}) async {
    final rows = await _client
        .from(reportsTable)
        .select('id, user_id, type, description, lat, lng, created_at, status')
        .order('created_at', ascending: false)
        .limit(limit);

    final List<ReportRecord> result = [];
    for (final row in rows) {
      final mediaRows =
          await _client.from(mediaTable).select('path').eq('report_id', row['id'] as String);
      final urls = mediaRows
          .map<String>((m) => _client.storage.from(bucket).getPublicUrl(m['path'] as String))
          .toList();
      result.add(ReportRecord.fromJson(Map<String, dynamic>.from(row as Map), urls));
    }
    return result;
  }

  static Future<List<ReportRecord>> fetchForCurrentUser({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from(reportsTable)
        .select('id, user_id, type, description, lat, lng, created_at, status')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    final List<ReportRecord> result = [];
    for (final row in rows) {
      final mediaRows =
          await _client.from(mediaTable).select('path').eq('report_id', row['id'] as String);
      final urls = mediaRows
          .map<String>((m) => _client.storage.from(bucket).getPublicUrl(m['path'] as String))
          .toList();
      result.add(ReportRecord.fromJson(Map<String, dynamic>.from(row as Map), urls));
    }
    return result;
  }

  static Future<List<ReportRecord>> fetchByBarangay(String barangayId, {int limit = 100}) async {
    final rows = await _client
        .from(reportsTable)
        .select('id, user_id, type, description, lat, lng, created_at, status')
        .eq('barangay_id', barangayId)
        .order('created_at', ascending: false)
        .limit(limit);

    final List<ReportRecord> result = [];
    for (final row in rows) {
      final mediaRows =
          await _client.from(mediaTable).select('path').eq('report_id', row['id'] as String);
      final urls = mediaRows
          .map<String>((m) => _client.storage.from(bucket).getPublicUrl(m['path'] as String))
          .toList();
      result.add(ReportRecord.fromJson(Map<String, dynamic>.from(row as Map), urls));
    }
    return result;
  }

  static Future<void> updateStatus(String reportId, String status) async {
    try {
      final response = await _client
          .from(reportsTable)
          .update({'status': status})
          .eq('id', reportId)
          .select();
      
      if (response.isEmpty) {
        throw Exception('No report found with ID: $reportId');
      }
      
      // Notify listeners to refresh views
      refresh.value++;
    } catch (e) {
      debugPrint('Error updating report status: $e');
      rethrow;
    }
  }
}


