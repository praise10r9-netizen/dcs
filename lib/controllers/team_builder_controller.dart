
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamBuilderController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;

  // ------------------------------------------------------------
  // UI STATE
  // ------------------------------------------------------------
  final TextEditingController teamNameCtrl = TextEditingController();
  final TextEditingController orgCtrl = TextEditingController();

  String? selectedQualification;
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
    notifyListeners();
  }

  // ------------------------------------------------------------
  // FETCH TEAMS
  // ------------------------------------------------------------
  Future<void> fetchTeams() async {
    loadingTeams = true;
    notifyListeners();

    try {
      final res = await db.from("team").select();
      teams = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      teams = [];
    }

    loadingTeams = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // DUPLICATE CHECK
  // ------------------------------------------------------------
  bool isDuplicateTeam(String teamName, List<String> members) {
    for (final t in teams) {
      final existingName = t["team_name"]?.toString().toLowerCase();
      final incomingName = teamName.toLowerCase();

      if (existingName == incomingName) return true;

      final m = t["members"];
      if (m is List) {
        final existingMembers = m.map((e) => e.toString()).toSet();
        final newMembers = members.toSet();
        if (existingMembers.length == newMembers.length &&
            existingMembers.containsAll(newMembers)) {
          return true;
        }
      }
    }
    return false;
  }

  // ------------------------------------------------------------
  // CREATE TEAM
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

      if (name.isEmpty || org.isEmpty || selectedMemberIds.isEmpty) {
        throw Exception("Provide all team details and pick members.");
      }

      // Duplicate guard
      if (isDuplicateTeam(name, selectedMemberIds)) {
        throw Exception("A team with same name or members already exists.");
      }

      // JSON ARRAY OF STRINGS
      final membersJson = selectedMemberIds;

      final inserted = await db.from("team").insert({
        "team_name": name,
        "organization": org,
        "created_by": supervisorId,
        "members": membersJson,
        "created_at": DateTime.now().toIso8601String(),
      }).select().single();

      await sendNotifications(inserted["id"], selectedMemberIds);

      await fetchTeams();
      selectedMemberIds.clear();

      return inserted;
    } catch (e) {
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
      dynamic teamId, List<String> memberIds) async {
    for (final uid in memberIds) {
      await db.from("notifications").insert({
        "user_id": uid,
        "message":
            "You have been selected to join a research/survey team (Team ID: $teamId).",
        "status": "unread",
        "created_at": DateTime.now().toIso8601String(),
      });
    }
  }
}
