// lib/controllers/field_worker_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FieldWorkerController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;

  // ------------------------------------------------------------
  // STATE
  // ------------------------------------------------------------
  bool loadingNotifications = false;
  bool loadingTeams = false;
  bool loadingForms = false;
  bool joiningTeam = false;

  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> myTeams = [];
  List<Map<String, dynamic>> availableForms = [];

  String? selectedTeamId;

  // ------------------------------------------------------------
  // GET CURRENT USER ID
  // ------------------------------------------------------------
  String? getCurrentUserId() {
    return db.auth.currentUser?.id;
  }

  // ------------------------------------------------------------
  // FETCH NOTIFICATIONS
  // ------------------------------------------------------------
  Future<void> fetchNotifications() async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    loadingNotifications = true;
    notifyListeners();

    try {
      final res = await db
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      notifications = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('fetchNotifications error: $e');
      notifications = [];
    }

    loadingNotifications = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // MARK NOTIFICATION AS READ
  // ------------------------------------------------------------
  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      await db
          .from('notifications')
          .update({'status': 'read'})
          .eq('id', notificationId);

      // Update local state
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['status'] = 'read';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('markNotificationAsRead error: $e');
    }
  }

  // ------------------------------------------------------------
  // DELETE NOTIFICATION
  // ------------------------------------------------------------
  Future<void> deleteNotification(int notificationId) async {
    try {
      await db.from('notifications').delete().eq('id', notificationId);

      notifications.removeWhere((n) => n['id'] == notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('deleteNotification error: $e');
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // FETCH MY TEAMS (teams where user is a member)
  // ------------------------------------------------------------
  Future<void> fetchMyTeams() async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    loadingTeams = true;
    notifyListeners();

    try {
      final res = await db.from('team').select();

      // Filter teams where current user is in members array
      myTeams = List<Map<String, dynamic>>.from(res).where((team) {
        final members = team['members'];
        if (members is String) {
          try {
            final membersList = jsonDecode(members) as List;
            return membersList.contains(userId);
          } catch (_) {
            return false;
          }
        } else if (members is List) {
          return members.contains(userId);
        }
        return false;
      }).toList();
    } catch (e) {
      debugPrint('fetchMyTeams error: $e');
      myTeams = [];
    }

    loadingTeams = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // EXTRACT TEAM ID FROM NOTIFICATION MESSAGE
  // ------------------------------------------------------------
  int? extractTeamIdFromNotification(String message) {
    // Expected format: "... (Team ID: 123)..."
    final regex = RegExp(r'Team ID:\s*(\d+)');
    final match = regex.firstMatch(message);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  // ------------------------------------------------------------
  // JOIN TEAM (Accept invitation)
  // ------------------------------------------------------------
  Future<void> joinTeam(int teamId, int notificationId) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('User not logged in');

    joiningTeam = true;
    notifyListeners();

    try {
      // Fetch team to verify user is in members
      final teamRow = await db
          .from('team')
          .select()
          .eq('id', teamId)
          .maybeSingle();

      if (teamRow == null) {
        throw Exception('Team not found');
      }

      // Verify user is in members list
      final members = teamRow['members'];
      List<dynamic> membersList = [];
      
      if (members is String) {
        membersList = jsonDecode(members);
      } else if (members is List) {
        membersList = List.from(members);
      }

      if (!membersList.contains(userId)) {
        throw Exception('You are not invited to this team');
      }

      // Mark notification as read/accepted
      await markNotificationAsRead(notificationId);

      // Refresh teams list
      await fetchMyTeams();

      // Auto-select the newly joined team
      selectedTeamId = teamId.toString();
      await fetchTeamForms(teamId);
    } catch (e) {
      debugPrint('joinTeam error: $e');
      rethrow;
    } finally {
      joiningTeam = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // DECLINE TEAM INVITATION
  // ------------------------------------------------------------
  Future<void> declineTeamInvitation(int notificationId) async {
    try {
      await deleteNotification(notificationId);
    } catch (e) {
      debugPrint('declineTeamInvitation error: $e');
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // FETCH FORMS FOR A SPECIFIC TEAM
  // ------------------------------------------------------------
  Future<void> fetchTeamForms(int teamId) async {
    loadingForms = true;
    notifyListeners();

    try {
      // Fetch team resources
      final teamRow = await db
          .from('team')
          .select('resources')
          .eq('id', teamId)
          .maybeSingle();

      if (teamRow == null || teamRow['resources'] == null) {
        availableForms = [];
        loadingForms = false;
        notifyListeners();
        return;
      }

      // Parse resources (array of form IDs)
      List<dynamic> resourceIds = [];
      if (teamRow['resources'] is String) {
        resourceIds = jsonDecode(teamRow['resources']);
      } else if (teamRow['resources'] is List) {
        resourceIds = List.from(teamRow['resources']);
      }

      if (resourceIds.isEmpty) {
        availableForms = [];
        loadingForms = false;
        notifyListeners();
        return;
      }

      // Fetch forms by IDs
      final formsRes = await db
          .from('custom_form')
          .select()
          .inFilter('form_id', resourceIds);

      availableForms = List<Map<String, dynamic>>.from(formsRes);
    } catch (e) {
      debugPrint('fetchTeamForms error: $e');
      availableForms = [];
    }

    loadingForms = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // SELECT TEAM
  // ------------------------------------------------------------
  Future<void> selectTeam(int teamId) async {
    selectedTeamId = teamId.toString();
    notifyListeners();
    await fetchTeamForms(teamId);
  }

  // ------------------------------------------------------------
  // GET UNREAD NOTIFICATION COUNT
  // ------------------------------------------------------------
  int getUnreadNotificationCount() {
    return notifications.where((n) => n['status'] == 'unread').length;
  }

  // ------------------------------------------------------------
  // REFRESH ALL DATA
  // ------------------------------------------------------------
  Future<void> refreshAll() async {
    await Future.wait([
      fetchNotifications(),
      fetchMyTeams(),
    ]);
  }
}