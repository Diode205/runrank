import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // -------------------------------------------------------
  // CHECK LOGIN STATUS
  // -------------------------------------------------------
  static bool userIsLoggedIn() {
    return _supabase.auth.currentUser != null;
  }

  // -------------------------------------------------------
  // LOGIN
  // -------------------------------------------------------
  static Future<bool> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session != null;
    } catch (e) {
      // ignore: avoid_print
      print("LOGIN FAILED: $e");
      return false;
    }
  }

  // -------------------------------------------------------
  // LOGOUT
  // -------------------------------------------------------
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // -------------------------------------------------------
  // REGISTER USER + INSERT PROFILE DATA
  // -------------------------------------------------------
  static Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String dob,
    required String ukaNumber,
    required String club,
    required String membershipType,
  }) async {
    try {
      // 1) Create user in Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null,
      );

      final user = response.user;

      if (user == null) {
        // ignore: avoid_print
        print("❌ Sign-up returned null user");
        return false;
      }

      final userId = user.id;
      // ignore: avoid_print
      print("✅ USER CREATED: $userId");

      // 2) Insert profile row (matches table EXACTLY)
      await _supabase.from('user_profiles').insert({
        "id": userId,
        "email": email,
        "full_name": fullName,
        "date_of_birth": dob,
        "uka_number": ukaNumber,
        "club": club,
        "membership_type": membershipType,
        "is_admin": false,
        "admin_since": null,
        // NEW ▶ store member_since (ISO string from today)
        "member_since": DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      // ignore: avoid_print
      print("REGISTRATION FAILED: $e");
      return false;
    }
  }

  // -------------------------------------------------------
  // SUBMIT RACE RESULT
  // -------------------------------------------------------
  static Future<bool> submitRaceResult({
    required String raceName,
    required String gender,
    required int age,
    required String distance,
    required int finishSeconds,
    required String level,
    required double ageGrade,
    DateTime? raceDate,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      // ignore: avoid_print
      print('submitRaceResult: no logged-in user');
      return false;
    }

    try {
      await client.from('race_results').insert({
        'user_id': user.id,
        'race_name': raceName,
        'distance': distance,
        'time_seconds': finishSeconds,
        'gender': gender,
        'age': age,
        'level': level,
        'age_grade': ageGrade,
        'raceDate': raceDate?.toIso8601String(),
      });

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error submitting result: $e');
      return false;
    }
  }

  // -------------------------------------------------------
  // FETCH RACE HISTORY
  // -------------------------------------------------------
  static Future<List<Map<String, dynamic>>> fetchRaceHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('race_results')
        .select()
        .eq('user_id', user.id)
        .order('raceDate', ascending: false)
        .order('created_at', ascending: false);

    return response.cast<Map<String, dynamic>>();
  }

  // -------------------------------------------------------
  // UPDATE NAME
  // -------------------------------------------------------
  static Future<bool> updateName(String newName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('user_profiles')
          .update({'full_name': newName})
          .eq('id', user.id);

      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Update name failed: $e");
      return false;
    }
  }

  // -------------------------------------------------------
  // UPDATE PASSWORD (when user already logged in)
  // -------------------------------------------------------
  static Future<bool> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Password update failed: $e");
      return false;
    }
  }

  // -------------------------------------------------------
  // SEND PASSWORD RESET EMAIL (FORGOT PASSWORD)
  // -------------------------------------------------------
  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Password reset email failed: $e");
      return false;
    }
  }
}
