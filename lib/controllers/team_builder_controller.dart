// lib/controllers/team_builder_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamMember {
  final String userId;
  final String status; // 'pending', 'accepted', 'declined'

  TeamMember({
    required this.userId,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'status': status,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      userId: json['user_id'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}

class TeamBuilderController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;

  // ------------------------------------------------------------
  // UI STATE
  // ------------------------------------------------------------
  final TextEditingController teamNameCtrl = TextEditingController();
  final TextEditingController orgCtrl = TextEditingController();
  final TextEditingController jobDescCtrl = TextEditingController();

  String? selectedQualification;
  DateTime? scheduledDate;
  DateTime? deadline;
  
  bool loadingWorkers = false;
  bool loadingTeams = false;
  bool creatingTeam = false;

  List<String> selectedMemberIds = [];
  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> teams = [];

  // For the dropdown predefined categories
  final List<String> qualificationCategories = const [
    "ICT",
    "Nursing",
    "Business",
    "Medical",
    "Agriculture",
    "Nutrition",
  ];

  // ------------------------------------------------------------
  // Supervisor ID
  // ------------------------------------------------------------
  String getSupervisorId() {
    final user = db.auth.currentUser;
    return user?.id ?? "";
  }

  // ------------------------------------------------------------
  // FETCH WORKERS BY QUALIFICATION
  // ------------------------------------------------------------
  Future<void> fetchWorkers() async {
    if (selectedQualification == null) return;

    loadingWorkers = true;
    notifyListeners();

    try {
      final res = await db
          .from("profiles")
          .select("id, first_name, last_name, qualification, role")
          .eq("role", "field_worker")
          .ilike("qualification", "%${selectedQualification!}%");

      workers = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('fetchWorkers error: $e');
      workers = [];
    }

    loadingWorkers = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // SELECT / UNSELECT MEMBERS
  // ------------------------------------------------------------
  void toggleSelection(String id) {
    if (selectedMemberIds.contains(id)) {
      selectedMemberIds.remove(id);
    } else {
      selectedMemberIds.add(id);
    }
    notifyListeners();
  }

  void resetTeamBuilder() {
    selectedQualification = null;
    selectedMemberIds.clear();
    workers.clear();
    scheduledDate = null;
    deadline = null;
    teamNameCtrl.clear();
    orgCtrl.clear();
    jobDescCtrl.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // FETCH TEAMS
  // ------------------------------------------------------------
  Future<void> fetchTeams() async {
    loadingTeams = true;
    notifyListeners();

    try {
      final supervisorId = getSupervisorId();
      
      // Fetch teams with their schedules
      final res = await db
          .from("team")
          .select('*, job_schedule(*)')
          .eq('created_by', supervisorId);
      
      teams = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('fetchTeams error: $e');
      teams = [];
    }

    loadingTeams = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // SET SCHEDULED DATE
  // ------------------------------------------------------------
  void setScheduledDate(DateTime date) {
    scheduledDate = date;
    
    // Auto-set deadline to 7 days after scheduled date if not set
    if (deadline == null || deadline!.isBefore(date)) {
      deadline = date.add(const Duration(days: 7));
    }
    
    notifyListeners();
  }

  // ------------------------------------------------------------
  // SET DEADLINE
  // ------------------------------------------------------------
  void setDeadline(DateTime date) {
    // Ensure deadline is at least scheduled date + 2 days
    if (scheduledDate != null) {
      final minDeadline = scheduledDate!.add(const Duration(days: 2));
      if (date.isBefore(minDeadline)) {
        deadline = minDeadline;
        notifyListeners();
        return;
      }
    }
    
    deadline = date;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // VALIDATE DATES
  // ------------------------------------------------------------
  String? validateDates() {
    if (scheduledDate == null) {
      return 'Please select a scheduled date';
    }
    
    if (deadline == null) {
      return 'Please select a deadline';
    }
    
    final minDeadline = scheduledDate!.add(const Duration(days: 2));
    if (deadline!.isBefore(minDeadline)) {
      return 'Deadline must be at least 2 days after scheduled date';
    }
    
    return null;
  }

  // ------------------------------------------------------------
  // CHECK MEMBER AVAILABILITY
  // ------------------------------------------------------------
  Future<Map<String, List<String>>> checkMemberAvailability() async {
    if (scheduledDate == null || deadline == null) {
      return {'available': selectedMemberIds, 'conflicting': []};
    }

    List<String> conflicting = [];
    List<String> available = [];

    try {
      for (final memberId in selectedMemberIds) {
        // Check if member has conflicting schedules
        final conflicts = await db
    .from('team')
    .select('id, job_schedule!inner(*)')
    .contains(
      'members',
      jsonEncode([
        {'user_id': memberId, 'status': 'accepted'}
      ]),
    )
    .or(
      'job_schedule.scheduled_date.lte.${deadline!.toIso8601String()},'
      'job_schedule.deadline.gte.${scheduledDate!.toIso8601String()}'
    );

        if (conflicts.isEmpty) {
          available.add(memberId);
        } else {
          conflicting.add(memberId);
        }
      }
    } catch (e) {
      debugPrint('checkMemberAvailability error: $e');
      // If check fails, assume all are available
      available = selectedMemberIds;
    }

    return {'available': available, 'conflicting': conflicting};
  }

  // ------------------------------------------------------------
  // CREATE TEAM WITH SCHEDULE
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> createTeam() async {
    creatingTeam = true;
    notifyListeners();

    try {
      final supervisorId = getSupervisorId();
      if (supervisorId.isEmpty) {
        throw Exception("Supervisor not logged in.");
      }

      final name = teamNameCtrl.text.trim();
      final org = orgCtrl.text.trim();
      final jobDesc = jobDescCtrl.text.trim();

      if (name.isEmpty || org.isEmpty || selectedMemberIds.isEmpty) {
        throw Exception("Provide all team details and pick members.");
      }

      // Validate dates
      final dateError = validateDates();
      if (dateError != null) {
        throw Exception(dateError);
      }

      // Create team members with pending status
      final members = selectedMemberIds.map((id) {
        return TeamMember(userId: id, status: 'pending').toJson();
      }).toList();

      // Insert team
      final teamInserted = await db.from("team").insert({
        "team_name": name,
        "organization": org,
        "created_by": supervisorId,
        "members": members,
        "created_at": DateTime.now().toIso8601String(),
      }).select().single();

      final teamId = teamInserted['id'];

      // Insert job schedule
      await db.from('job_schedule').insert({
        'team_id': teamId,
        'job_description': jobDesc.isEmpty ? 'General field work' : jobDesc,
        'scheduled_date': scheduledDate!.toIso8601String().split('T')[0],
        'deadline': deadline!.toIso8601String().split('T')[0],
      });

      // Send notifications to selected members
      await sendNotifications(teamId, name, selectedMemberIds);

      await fetchTeams();
      selectedMemberIds.clear();

      return teamInserted;
    } catch (e) {
      debugPrint('createTeam error: $e');
      rethrow;
    } finally {
      creatingTeam = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // SEND NOTIFICATIONS TO SELECTED MEMBERS
  // ------------------------------------------------------------
  Future<void> sendNotifications(
      dynamic teamId, String teamName, List<String> memberIds) async {
    for (final uid in memberIds) {
      await db.from("notifications").insert({
        "user_id": uid,
        "message":
            "You have been invited to join team '$teamName' (Team ID: $teamId). Scheduled: ${scheduledDate?.toString().split(' ')[0]}, Deadline: ${deadline?.toString().split(' ')[0]}",
        "status": "unread",
        "created_at": DateTime.now().toIso8601String(),
      });
    }
  }

  // ------------------------------------------------------------
  // GET ACCEPTED MEMBERS COUNT
  // ------------------------------------------------------------
  int getAcceptedMembersCount(List<dynamic> members) {
    int count = 0;
    for (final member in members) {
      if (member is Map && member['status'] == 'accepted') {
        count++;
      }
    }
    return count;
  }

  // ------------------------------------------------------------
  // GET PENDING MEMBERS COUNT
  // ------------------------------------------------------------
  int getPendingMembersCount(List<dynamic> members) {
    int count = 0;
    for (final member in members) {
      if (member is Map && member['status'] == 'pending') {
        count++;
      }
    }
    return count;
  }

  // ------------------------------------------------------------
  // CHECK IF SCHEDULE IS ACTIVE
  // ------------------------------------------------------------
  bool isScheduleActive(Map<String, dynamic>? schedule) {
    if (schedule == null) return false;
    
    final now = DateTime.now();
    final scheduled = DateTime.parse(schedule['scheduled_date']);
    final deadline = DateTime.parse(schedule['deadline']);
    
    return now.isAfter(scheduled.subtract(const Duration(days: 1))) && 
           now.isBefore(deadline.add(const Duration(days: 2)));
  }

  // ------------------------------------------------------------
  // GET SCHEDULE STATUS
  // ------------------------------------------------------------
  String getScheduleStatus(Map<String, dynamic>? schedule) {
    if (schedule == null) return 'No schedule';
    
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
}