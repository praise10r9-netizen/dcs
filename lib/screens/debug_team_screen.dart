// lib/screens/debug_team_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugTeamScreen extends StatefulWidget {
  const DebugTeamScreen({super.key});

  @override
  State<DebugTeamScreen> createState() => _DebugTeamScreenState();
}

class _DebugTeamScreenState extends State<DebugTeamScreen> {
  final db = Supabase.instance.client;
  bool loading = false;
  String output = '';
  String? userId;

  @override
  void initState() {
    super.initState();
    userId = db.auth.currentUser?.id;
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      loading = true;
      output = 'Running diagnostics...\n\n';
    });

    final buffer = StringBuffer();
    
    try {
      // 1. Check current user
      buffer.writeln('=== CURRENT USER ===');
      buffer.writeln('User ID: $userId');
      buffer.writeln('Email: ${db.auth.currentUser?.email}');
      buffer.writeln('');

      // 2. Fetch all teams
      buffer.writeln('=== ALL TEAMS ===');
      final teams = await db.from('team').select('*, job_schedule(*)');
      buffer.writeln('Total teams in database: ${teams.length}');
      buffer.writeln('');

      // 3. Check each team
      for (final team in teams) {
        buffer.writeln('--- Team ${team['id']}: ${team['team_name']} ---');
        buffer.writeln('Created by: ${team['created_by']}');
        buffer.writeln('Organization: ${team['organization']}');
        
        // Parse members
        final members = team['members'];
        buffer.writeln('Members raw data type: ${members.runtimeType}');
        buffer.writeln('Members raw data: $members');
        
        List<dynamic> membersList = [];
        if (members is String) {
          try {
            membersList = jsonDecode(members);
            buffer.writeln('Members parsed from JSON string');
          } catch (e) {
            buffer.writeln('ERROR parsing members JSON: $e');
          }
        } else if (members is List) {
          membersList = List.from(members);
          buffer.writeln('Members already a list');
        }
        
        buffer.writeln('Members list length: ${membersList.length}');
        
        // Check each member
        for (int i = 0; i < membersList.length; i++) {
          final member = membersList[i];
          buffer.writeln('  Member $i type: ${member.runtimeType}');
          buffer.writeln('  Member $i data: $member');
          
          if (member is Map) {
            final memberUserId = member['user_id']?.toString();
            final memberStatus = member['status']?.toString();
            buffer.writeln('  - user_id: $memberUserId');
            buffer.writeln('  - status: $memberStatus');
            
            if (memberUserId == userId) {
              buffer.writeln('  ✅ THIS IS CURRENT USER!');
              if (memberStatus == 'accepted') {
                buffer.writeln('  ✅ STATUS IS ACCEPTED!');
              } else {
                buffer.writeln('  ⚠️  STATUS IS: $memberStatus');
              }
            }
          }
        }
        
        // Check resources
        final resources = team['resources'];
        buffer.writeln('Resources: $resources');
        buffer.writeln('Resources type: ${resources.runtimeType}');
        
        List<dynamic> resourceIds = [];
        if (resources is String) {
          try {
            resourceIds = jsonDecode(resources);
          } catch (e) {
            buffer.writeln('ERROR parsing resources: $e');
          }
        } else if (resources is List) {
          resourceIds = List.from(resources);
        }
        buffer.writeln('Resource IDs: $resourceIds');
        
        // Check schedule
        final schedules = team['job_schedule'];
        buffer.writeln('Schedules: $schedules');
        buffer.writeln('Schedules type: ${schedules.runtimeType}');
        
        if (schedules != null) {
          final schedule = schedules is List ? (schedules.isEmpty ? null : schedules[0]) : schedules;
          if (schedule != null) {
            buffer.writeln('Schedule data: $schedule');
            buffer.writeln('Scheduled date: ${schedule['scheduled_date']}');
            buffer.writeln('Deadline: ${schedule['deadline']}');
            
            try {
              final scheduledDate = DateTime.parse(schedule['scheduled_date']);
              final deadline = DateTime.parse(schedule['deadline']);
              final now = DateTime.now();
              final gracePeriod = deadline.add(const Duration(days: 2));
              
              buffer.writeln('Now: $now');
              buffer.writeln('Grace period ends: $gracePeriod');
              buffer.writeln('Is active? ${now.isAfter(scheduledDate.subtract(const Duration(days: 1))) && now.isBefore(gracePeriod)}');
            } catch (e) {
              buffer.writeln('ERROR parsing dates: $e');
            }
          }
        }
        
        buffer.writeln('');
      }

      // 4. Try to fetch with the same logic as controller
      buffer.writeln('=== FILTERED TEAMS (Controller Logic) ===');
      final filteredTeams = List<Map<String, dynamic>>.from(teams).where((team) {
        final members = team['members'];
        List<dynamic> membersList = [];
        
        if (members is String) {
          try {
            membersList = jsonDecode(members) as List;
          } catch (_) {
            return false;
          }
        } else if (members is List) {
          membersList = List.from(members);
        }

        bool isAccepted = false;
        for (final member in membersList) {
          if (member is Map && 
              member['user_id']?.toString() == userId && 
              member['status']?.toString() == 'accepted') {
            isAccepted = true;
            break;
          }
        }

        if (!isAccepted) return false;

        final schedules = team['job_schedule'];
        if (schedules == null || (schedules is List && schedules.isEmpty)) return false;

        final schedule = schedules is List ? schedules[0] : schedules;
        try {
          final now = DateTime.now();
          final scheduled = DateTime.parse(schedule['scheduled_date']);
          final deadline = DateTime.parse(schedule['deadline']);
          final gracePeriod = deadline.add(const Duration(days: 2));
          
          return now.isAfter(scheduled.subtract(const Duration(days: 1))) && 
                 now.isBefore(gracePeriod);
        } catch (e) {
          return false;
        }
      }).toList();
      
      buffer.writeln('Filtered teams count: ${filteredTeams.length}');
      for (final team in filteredTeams) {
        buffer.writeln('- ${team['team_name']} (ID: ${team['id']})');
      }

    } catch (e) {
      buffer.writeln('ERROR: $e');
    }

    setState(() {
      output = buffer.toString();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Team Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: output));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                output,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}