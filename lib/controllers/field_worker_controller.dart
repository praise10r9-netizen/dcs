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
  // FETCH MY TEAMS (only accepted teams with active schedules)
  // ------------------------------------------------------------
  Future<void> fetchMyTeams() async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    loadingTeams = true;
    notifyListeners();

    try {
      // Fetch all teams with schedules
      final res = await db.from('team').select('*, job_schedule(*)');

      debugPrint('Fetched ${res.length} teams from database');

      // Filter teams where user is accepted
      myTeams = List<Map<String, dynamic>>.from(res).where((team) {
        final members = team['members'];
        List<dynamic> membersList = [];
        
        // Parse members JSON
        if (members is String) {
          try {
            membersList = jsonDecode(members) as List;
          } catch (e) {
            debugPrint('Error parsing members JSON for team ${team['id']}: $e');
            return false;
          }
        } else if (members is List) {
          membersList = List.from(members);
        } else if (members is Map) {
          // Handle case where members might be a map
          membersList = [members];
        }

        debugPrint('Team ${team['id']} (${team['team_name']}): ${membersList.length} members');

        // Check if user is accepted in this team
        bool isAccepted = false;
        for (final member in membersList) {
          debugPrint('Checking member: $member');
          if (member is Map) {
            final memberUserId = member['user_id']?.toString();
            final memberStatus = member['status']?.toString();
            
            debugPrint('Member userId: $memberUserId, status: $memberStatus, current user: $userId');
            
            if (memberUserId == userId && memberStatus == 'accepted') {
              isAccepted = true;
              debugPrint('User is accepted in team ${team['id']}');
              break;
            }
          }
        }

        if (!isAccepted) {
          debugPrint('User not accepted in team ${team['id']}');
          return false;
        }

        // Check if schedule exists and is active or in grace period
        final schedules = team['job_schedule'];
        if (schedules == null) {
          debugPrint('No schedule for team ${team['id']}');
          return false;
        }

        if (schedules is List && schedules.isEmpty) {
          debugPrint('Empty schedule list for team ${team['id']}');
          return false;
        }

        final schedule = schedules is List ? schedules[0] : schedules;
        final isActive = _isScheduleActiveOrGrace(schedule);
        
        debugPrint('Team ${team['id']} schedule active: $isActive');
        
        return isActive;
      }).toList();

      debugPrint('Filtered to ${myTeams.length} accepted teams for user');
    } catch (e) {
      debugPrint('fetchMyTeams error: $e');
      myTeams = [];
    }

    loadingTeams = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // CHECK IF SCHEDULE IS ACTIVE OR IN GRACE PERIOD
  // ------------------------------------------------------------
  bool _isScheduleActiveOrGrace(dynamic schedule) {
    if (schedule == null) return false;
    
    try {
      final now = DateTime.now();
      final scheduled = DateTime.parse(schedule['scheduled_date']);
      final deadline = DateTime.parse(schedule['deadline']);
      final gracePeriod = deadline.add(const Duration(days: 2));
      
      // Active if between scheduled date and grace period end
      return now.isAfter(scheduled.subtract(const Duration(days: 1))) && 
             now.isBefore(gracePeriod);
    } catch (e) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // EXTRACT TEAM ID FROM NOTIFICATION MESSAGE
  // ------------------------------------------------------------
  int? extractTeamIdFromNotification(String message) {
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
      debugPrint('Attempting to join team $teamId for user $userId');

      // Fetch team with schedule
      final teamRow = await db
          .from('team')
          .select('*, job_schedule(*)')
          .eq('id', teamId)
          .single();

      debugPrint('Team fetched: ${teamRow['team_name']}');

      // Parse members - handle both JSON string and array
      final members = teamRow['members'];
      List<Map<String, dynamic>> membersList = [];
      
      if (members is String) {
        final decoded = jsonDecode(members);
        if (decoded is List) {
          membersList = decoded.map((m) => Map<String, dynamic>.from(m as Map)).toList();
        }
      } else if (members is List) {
        membersList = members.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      }

      debugPrint('Parsed ${membersList.length} members');

      // Find user and update status to accepted
      bool found = false;
      for (int i = 0; i < membersList.length; i++) {
        final memberUserId = membersList[i]['user_id']?.toString();
        debugPrint('Checking member $i: userId=$memberUserId');
        
        if (memberUserId == userId) {
          membersList[i]['status'] = 'accepted';
          found = true;
          debugPrint('Updated member $i status to accepted');
          break;
        }
      }

      if (!found) {
        throw Exception('You are not invited to this team');
      }

      // Check schedule conflicts
      final schedules = teamRow['job_schedule'];
      if (schedules != null && schedules.isNotEmpty) {
        final schedule = schedules is List ? schedules[0] : schedules;
        final scheduledDate = DateTime.parse(schedule['scheduled_date']);
        final deadline = DateTime.parse(schedule['deadline']);
        
        debugPrint('Checking conflicts for dates: $scheduledDate to $deadline');
        
        final conflicts = await _checkScheduleConflicts(
          userId, 
          scheduledDate, 
          deadline,
          excludeTeamId: teamId,
        );

        if (conflicts.isNotEmpty) {
          debugPrint('Found ${conflicts.length} conflicts');
          throw Exception(
            'Schedule conflict detected with ${conflicts.length} other team(s). '
            'Please decline one of them first.'
          );
        }
      }

      // Update team with accepted status - store as JSON array
      debugPrint('Updating team members to: $membersList');
      
      await db.from('team').update({
        'members': membersList, // Supabase will handle JSON serialization
      }).eq('id', teamId);

      debugPrint('Team updated successfully');

      // Mark notification as read
      await markNotificationAsRead(notificationId);
      debugPrint('Notification marked as read');

      // Refresh teams list
      await fetchMyTeams();
      debugPrint('Teams refreshed, found ${myTeams.length} teams');

      // Auto-select the newly joined team if it appears
      if (myTeams.any((t) => t['id'] == teamId)) {
        selectedTeamId = teamId.toString();
        await fetchTeamForms(teamId);
        debugPrint('Team selected and forms fetched');
      } else {
        debugPrint('Warning: Team $teamId not found in myTeams after acceptance');
      }
    } catch (e) {
      debugPrint('joinTeam error: $e');
      rethrow;
    } finally {
      joiningTeam = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // CHECK SCHEDULE CONFLICTS
  // ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _checkScheduleConflicts(
    String userId,
    DateTime scheduledDate,
    DateTime deadline,
    {int? excludeTeamId}
  ) async {
    try {
      final allTeams = await db.from('team').select('*, job_schedule(*)');
      
      List<Map<String, dynamic>> conflicts = [];
      
      for (final team in allTeams) {
        // Skip the team we're trying to join
        if (excludeTeamId != null && team['id'] == excludeTeamId) continue;
        
        // Check if user is accepted in this team
        final members = team['members'];
        List<dynamic> membersList = [];
        
        if (members is String) {
          membersList = jsonDecode(members);
        } else if (members is List) {
          membersList = List.from(members);
        }
        
        bool isAccepted = false;
        for (final member in membersList) {
          if (member is Map && 
              member['user_id'] == userId && 
              member['status'] == 'accepted') {
            isAccepted = true;
            break;
          }
        }
        
        if (!isAccepted) continue;
        
        // Check schedule overlap
        final schedules = team['job_schedule'];
        if (schedules == null || (schedules is List && schedules.isEmpty)) continue;
        
        final schedule = schedules is List ? schedules[0] : schedules;
        final teamScheduled = DateTime.parse(schedule['scheduled_date']);
        final teamDeadline = DateTime.parse(schedule['deadline']);
        
        // Check for overlap (including grace period)
        final gracePeriod = teamDeadline.add(const Duration(days: 2));
        final newGracePeriod = deadline.add(const Duration(days: 2));
        
        if (scheduledDate.isBefore(gracePeriod) && newGracePeriod.isAfter(teamScheduled)) {
          conflicts.add(team);
        }
      }
      
      return conflicts;
    } catch (e) {
      debugPrint('_checkScheduleConflicts error: $e');
      return [];
    }
  }

  // ------------------------------------------------------------
  // DECLINE TEAM INVITATION
  // ------------------------------------------------------------
  Future<void> declineTeamInvitation(int teamId, int notificationId) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('User not logged in');

    try {
      // Fetch team
      final teamRow = await db
          .from('team')
          .select('members')
          .eq('id', teamId)
          .maybeSingle();

      if (teamRow == null) {
        throw Exception('Team not found');
      }

      // Parse members
      final members = teamRow['members'];
      List<dynamic> membersList = [];
      
      if (members is String) {
        membersList = jsonDecode(members);
      } else if (members is List) {
        membersList = List.from(members);
      }

      // Find user and update status to declined
      for (int i = 0; i < membersList.length; i++) {
        if (membersList[i] is Map && membersList[i]['user_id'] == userId) {
          membersList[i]['status'] = 'declined';
          break;
        }
      }

      // Update team
      await db.from('team').update({
        'members': membersList,
      }).eq('id', teamId);

      // Delete notification
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
      debugPrint('Fetching forms for team $teamId');

      final teamRow = await db
          .from('team')
          .select('resources')
          .eq('id', teamId)
          .single();

      debugPrint('Team resources: ${teamRow['resources']}');

      if (teamRow['resources'] == null) {
        debugPrint('No resources found for team $teamId');
        availableForms = [];
        loadingForms = false;
        notifyListeners();
        return;
      }

      // Parse resources
      List<dynamic> resourceIds = [];
      final resources = teamRow['resources'];
      
      if (resources is String) {
        try {
          resourceIds = jsonDecode(resources);
        } catch (e) {
          debugPrint('Error parsing resources JSON: $e');
        }
      } else if (resources is List) {
        resourceIds = List.from(resources);
      }

      debugPrint('Parsed resource IDs: $resourceIds');

      if (resourceIds.isEmpty) {
        debugPrint('No form IDs in resources');
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
      debugPrint('Fetched ${availableForms.length} forms');
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
  // GET TEAM SCHEDULE STATUS
  // ------------------------------------------------------------
  String getTeamScheduleStatus(Map<String, dynamic> team) {
    final schedules = team['job_schedule'];
    if (schedules == null || (schedules is List && schedules.isEmpty)) {
      return 'No schedule';
    }

    final schedule = schedules is List ? schedules[0] : schedules;
    final now = DateTime.now();
    final scheduled = DateTime.parse(schedule['scheduled_date']);
    final deadline = DateTime.parse(schedule['deadline']);
    final gracePeriod = deadline.add(const Duration(days: 2));

    if (now.isBefore(scheduled)) {
      return 'Upcoming';
    } else if (now.isAfter(scheduled) && now.isBefore(deadline)) {
      return 'Active';
    } else if (now.isAfter(deadline) && now.isBefore(gracePeriod)) {
      return 'Grace Period';
    } else {
      return 'Completed';
    }
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