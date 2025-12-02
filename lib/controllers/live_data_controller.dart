// lib/controllers/live_data_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveDataController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;

  // State
  bool loading = false;
  List<Map<String, dynamic>> forms = [];
  List<Map<String, dynamic>> responses = [];
  Map<String, dynamic>? selectedForm;
  
  // Real-time subscription
  RealtimeChannel? _subscription;

  // Statistics
  int totalResponses = 0;
  Map<int, int> responsesPerForm = {};

  // ------------------------------------------------------------
  // GET SUPERVISOR ID
  // ------------------------------------------------------------
  String? getSupervisorId() {
    return db.auth.currentUser?.id;
  }

  // ------------------------------------------------------------
  // FETCH FORMS CREATED BY SUPERVISOR
  // ------------------------------------------------------------
  Future<void> fetchMyForms() async {
    final supervisorId = getSupervisorId();
    if (supervisorId == null) return;

    loading = true;
    notifyListeners();

    try {
      final res = await db
          .from('custom_form')
          .select()
          .eq('created_by', supervisorId)
          .order('created_at', ascending: false);

      forms = List<Map<String, dynamic>>.from(res);

      // Count responses for each form
      for (final form in forms) {
        final count = await _getResponseCount(form['form_id']);
        responsesPerForm[form['form_id']] = count;
      }
    } catch (e) {
      debugPrint('fetchMyForms error: $e');
      forms = [];
    }

    loading = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // GET RESPONSE COUNT FOR A FORM
  // ------------------------------------------------------------
  Future<int> _getResponseCount(int formId) async {
  try {
    final res = await db
        .from('data_sets')
        .select()
        .eq('form_id', formId)
        .count(CountOption.exact);

    return res.count ?? 0;
  } catch (e) {
    debugPrint('_getResponseCount error: $e');
    return 0;
  }
}


  // ------------------------------------------------------------
  // FETCH RESPONSES FOR A SPECIFIC FORM
  // ------------------------------------------------------------
  Future<void> fetchFormResponses(int formId) async {
    loading = true;
    notifyListeners();

    try {
      final res = await db
          .from('data_sets')
          .select()
          .eq('form_id', formId)
          .order('created_at', ascending: false);

      responses = List<Map<String, dynamic>>.from(res);
      totalResponses = responses.length;

      // Find and set selected form
      selectedForm = forms.firstWhere(
        (f) => f['form_id'] == formId,
        orElse: () => {},
      );
    } catch (e) {
      debugPrint('fetchFormResponses error: $e');
      responses = [];
    }

    loading = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // START REAL-TIME MONITORING
  // ------------------------------------------------------------
  void startRealtimeMonitoring(int formId) {
    stopRealtimeMonitoring();

    _subscription = db
        .channel('data_sets_${formId}_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'data_sets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'form_id',
            value: formId,
          ),
          callback: (payload) {
            debugPrint('New response received: ${payload.newRecord}');
            _handleNewResponse(payload.newRecord);
          },
        )
        .subscribe();

    debugPrint('Real-time monitoring started for form $formId');
  }

  // ------------------------------------------------------------
  // HANDLE NEW RESPONSE FROM REALTIME
  // ------------------------------------------------------------
  void _handleNewResponse(Map<String, dynamic> newRecord) {
    // Add to beginning of list
    responses.insert(0, newRecord);
    totalResponses = responses.length;
    
    // Update count
    final formId = newRecord['form_id'];
    if (formId != null) {
      responsesPerForm[formId] = (responsesPerForm[formId] ?? 0) + 1;
    }

    notifyListeners();
  }

  // ------------------------------------------------------------
  // STOP REAL-TIME MONITORING
  // ------------------------------------------------------------
  void stopRealtimeMonitoring() {
    if (_subscription != null) {
      db.removeChannel(_subscription!);
      _subscription = null;
      debugPrint('Real-time monitoring stopped');
    }
  }

  // ------------------------------------------------------------
  // EXPORT RESPONSES AS CSV DATA
  // ------------------------------------------------------------
  String exportResponsesAsCSV() {
    if (responses.isEmpty) return '';

    // Get all unique keys from all responses
    final Set<String> allKeys = {};
    for (final response in responses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null) {
        allKeys.addAll(data.keys);
      }
    }

    // Build CSV header
    final header = ['Response ID', 'Created At', ...allKeys].join(',');
    
    // Build CSV rows
    final rows = responses.map((response) {
      final data = response['response_data'] as Map<String, dynamic>?;
      final values = [
        response['response_id'].toString(),
        response['created_at'].toString(),
        ...allKeys.map((key) {
          final value = data?[key];
          if (value is List) {
            return '"${value.join(', ')}"';
          }
          return '"${value ?? ''}"';
        }),
      ];
      return values.join(',');
    }).join('\n');

    return '$header\n$rows';
  }

  // ------------------------------------------------------------
  // GET RESPONSE SUMMARY
  // ------------------------------------------------------------
  Map<String, dynamic> getResponseSummary() {
    if (responses.isEmpty) {
      return {
        'total': 0,
        'today': 0,
        'this_week': 0,
        'this_month': 0,
      };
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;

    for (final response in responses) {
      final createdAt = DateTime.parse(response['created_at']);
      
      if (createdAt.isAfter(today)) {
        todayCount++;
      }
      if (createdAt.isAfter(weekAgo)) {
        weekCount++;
      }
      if (createdAt.isAfter(monthAgo)) {
        monthCount++;
      }
    }

    return {
      'total': responses.length,
      'today': todayCount,
      'this_week': weekCount,
      'this_month': monthCount,
    };
  }

  // ------------------------------------------------------------
  // DELETE RESPONSE
  // ------------------------------------------------------------
  Future<void> deleteResponse(int responseId) async {
    try {
      await db.from('data_sets').delete().eq('response_id', responseId);
      
      responses.removeWhere((r) => r['response_id'] == responseId);
      totalResponses = responses.length;
      
      notifyListeners();
    } catch (e) {
      debugPrint('deleteResponse error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    stopRealtimeMonitoring();
    super.dispose();
  }
}