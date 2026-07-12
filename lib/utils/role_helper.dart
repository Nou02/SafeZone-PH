import 'package:supabase_flutter/supabase_flutter.dart';

class RoleHelper {
  static const String cityAdmin = 'city_admin';
  static const String headBarangayOfficial = 'head_barangay_official';
  static const String barangayOfficial = 'barangay_official';

  static String? getCurrentUserRole() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    
    final email = user.email;
    if (email == 'illinoispss@gmail.com') {
      return cityAdmin;
    }
    
    return user.userMetadata?['role'] as String?;
  }

  static bool isCityAdmin() {
    return getCurrentUserRole() == cityAdmin;
  }

  static bool isHeadBarangayOfficial() {
    return getCurrentUserRole() == headBarangayOfficial;
  }

  static bool isBarangayOfficial() {
    return getCurrentUserRole() == barangayOfficial;
  }

  static String? getBarangayId() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    
    // For officials, check 'barangay_id'
    // For regular users, check 'user_barangay_id'
    return user.userMetadata?['barangay_id'] as String? ?? 
           user.userMetadata?['user_barangay_id'] as String?;
  }
}

