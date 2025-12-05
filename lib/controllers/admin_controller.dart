// lib/controllers/admin_controller.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;

  // State
  bool loading = false;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> forms = [];
  List<Map<String, dynamic>> dataSets = [];
  List<Map<String, dynamic>> pendingSupervisors = [];

  // ============================================================
  // FETCH USERS
  // ============================================================
  Future<void> fetchUsers() async {
    loading = true;
    notifyListeners();

    try {
      final response = await db
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      users = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('fetchUsers error: $e');
      users = [];
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // FETCH FORMS
  // ============================================================
  Future<void> fetchForms() async {
    loading = true;
    notifyListeners();

    try {
      final response = await db
          .from('custom_form')
          .select()
          .order('created_at', ascending: false);

      forms = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('fetchForms error: $e');
      forms = [];
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // FETCH DATA SETS
  // ============================================================
  Future<void> fetchDataSets() async {
    loading = true;
    notifyListeners();

    try {
      final response = await db
          .from('data_sets')
          .select()
          .order('created_at', ascending: false)
          .limit(100); // Limit to recent 100 responses

      dataSets = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('fetchDataSets error: $e');
      dataSets = [];
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // FETCH PENDING SUPERVISORS (Supervisors awaiting approval)
  // ============================================================
  Future<void> fetchPendingSupervisors() async {
    loading = true;
    notifyListeners();

    try {
      // Fetch supervisors where role is 'supervisor' but not yet approved
      // You might need to add an 'approved' or 'status' field to profiles table
      // For now, we'll fetch all supervisors
      final response = await db
          .from('profiles')
          .select()
          .eq('role', 'supervisor')
          .order('created_at', ascending: false);

      // Filter for pending (you can add a status field in your database)
      // For demo purposes, showing all supervisors
      pendingSupervisors = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('fetchPendingSupervisors error: $e');
      pendingSupervisors = [];
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // CREATE USER
  // ============================================================
  Future<void> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    required String qualification,
  }) async {
    loading = true;
    notifyListeners();

    try {
      // Create auth user
      final authResponse = await db.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Insert into profiles
        await db.from('profiles').insert({
          'id': authResponse.user!.id,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'role': role,
          'qualification': qualification,
        });

        await fetchUsers();
      }
    } catch (e) {
      debugPrint('createUser error: $e');
      rethrow;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // UPDATE USER
  // ============================================================
  Future<void> updateUser({
    required String userId,
    String? firstName,
    String? lastName,
    String? role,
    String? qualification,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (role != null) updates['role'] = role;
      if (qualification != null) updates['qualification'] = qualification;

      await db.from('profiles').update(updates).eq('id', userId);

      await fetchUsers();
    } catch (e) {
      debugPrint('updateUser error: $e');
      rethrow;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // DELETE USER
  // ============================================================
  Future<void> deleteUser(String userId) async {
    loading = true;
    notifyListeners();

    try {
      // Note: Deleting from auth requires admin privileges
      // This will only delete from profiles table
      await db.from('profiles').delete().eq('id', userId);

      users.removeWhere((user) => user['id'] == userId);
    } catch (e) {
      debugPrint('deleteUser error: $e');
      rethrow;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // DELETE FORM
  // ============================================================
  Future<void> deleteForm(int formId) async {
    loading = true;
    notifyListeners();

    try {
      await db.from('custom_form').delete().eq('form_id', formId);

      forms.removeWhere((form) => form['form_id'] == formId);
    } catch (e) {
      debugPrint('deleteForm error: $e');
      rethrow;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // DELETE DATA SET
  // ============================================================
  Future<void> deleteDataSet(int responseId) async {
    loading = true;
    notifyListeners();

    try {
      await db.from('data_sets').delete().eq('response_id', responseId);

      dataSets.removeWhere((ds) => ds['response_id'] == responseId);
    } catch (e) {
      debugPrint('deleteDataSet error: $e');
      rethrow;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // APPROVE SUPERVISOR
  // ============================================================
  Future<void> approveSupervisor(String userId) async {
    loading = true;
    notifyListeners();

    try {
      // Update user status to approved
      // You might want to add an 'approved' field to your profiles table
      await db.from('profiles').update({
        'role': 'supervisor',
        // 'approved': true, // Add this field to your schema if needed
      }).eq('id', userId);

      // Send notification
      await db.from('notifications').insert({
        'user_id': userId,
        'message': 'Your supervisor account has been approved!',
        'status': 'unread',
      });

      pendingSupervisors.removeWhere((user) => user['id'] == userId);
    } catch (e) {
      debugPrint('approveSupervisor error: $e');
      rethrow;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // REJECT SUPERVISOR
  // ============================================================
  Future<void> rejectSupervisor(String userId) async {
    loading = true;
    notifyListeners();

    try {
      // Change role back to field_worker or delete the request
      await db.from('profiles').update({
        'role': 'field_worker',
      }).eq('id', userId);

      // Send notification
      await db.from('notifications').insert({
        'user_id': userId,
        'message': 'Your supervisor request has been rejected.',
        'status': 'unread',
      });

      pendingSupervisors.removeWhere((user) => user['id'] == userId);
    } catch (e) {
      debugPrint('rejectSupervisor error: $e');
      rethrow;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // GET STATISTICS
  // ============================================================
  Future<Map<String, int>> getStatistics() async {
    try {
      final userCount = users.length;
      final formCount = forms.length;
      final dataSetCount = dataSets.length;
      final pendingCount = pendingSupervisors.length;

      return {
        'users': userCount,
        'forms': formCount,
        'responses': dataSetCount,
        'pending': pendingCount,
      };
    } catch (e) {
      debugPrint('getStatistics error: $e');
      return {
        'users': 0,
        'forms': 0,
        'responses': 0,
        'pending': 0,
      };
    }
  }

  // ============================================================
  // GENERATE REPORT
  // ============================================================
  Future<Map<String, dynamic>> generateReport(String reportType) async {
    try {
      switch (reportType) {
        case 'user_activity':
          return await _generateUserActivityReport();
        case 'data_collection':
          return await _generateDataCollectionReport();
        case 'form_performance':
          return await _generateFormPerformanceReport();
        case 'system_health':
          return await _generateSystemHealthReport();
        default:
          return {'error': 'Unknown report type'};
      }
    } catch (e) {
      debugPrint('generateReport error: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _generateUserActivityReport() async {
    // Implement user activity report logic
    return {
      'total_users': users.length,
      'active_users': users.where((u) => u['role'] != null).length,
      'by_role': {
        'admins': users.where((u) => u['role'] == 'admin').length,
        'supervisors': users.where((u) => u['role'] == 'supervisor').length,
        'field_workers': users.where((u) => u['role'] == 'field_worker').length,
      },
    };
  }

  Future<Map<String, dynamic>> _generateDataCollectionReport() async {
    // Implement data collection report logic
    return {
      'total_responses': dataSets.length,
      'forms_count': forms.length,
      'avg_responses_per_form': forms.isEmpty ? 0 : dataSets.length / forms.length,
    };
  }

  Future<Map<String, dynamic>> _generateFormPerformanceReport() async {
    // Implement form performance report logic
    final formResponses = <int, int>{};
    
    for (var dataSet in dataSets) {
      final formId = dataSet['form_id'] as int?;
      if (formId != null) {
        formResponses[formId] = (formResponses[formId] ?? 0) + 1;
      }
    }

    return {
      'forms_with_responses': formResponses.length,
      'total_forms': forms.length,
      'form_responses': formResponses,
    };
  }

  Future<Map<String, dynamic>> _generateSystemHealthReport() async {
    // Implement system health report logic
    return {
      'status': 'healthy',
      'users': users.length,
      'forms': forms.length,
      'responses': dataSets.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}