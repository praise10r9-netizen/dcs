// lib/screens/team_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/team_builder_controller.dart';

class TeamBuilderScreen extends StatefulWidget {
  const TeamBuilderScreen({super.key});

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  final TeamBuilderController ctrl = TeamBuilderController();

  @override
  void initState() {
    super.initState();
    ctrl.fetchTeams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Team Builder"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reset",
            onPressed: () {
              ctrl.resetTeamBuilder();
              setState(() {});
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Info Section
                _buildSectionTitle('Team Information'),
                const SizedBox(height: 12),
                
                TextField(
                  controller: ctrl.teamNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Team Name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: ctrl.orgCtrl,
                  decoration: const InputDecoration(
                    labelText: "Organization",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: ctrl.jobDescCtrl,
                  decoration: const InputDecoration(
                    labelText: "Job Description",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    hintText: 'Describe the task/job for this team',
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                // Schedule Section
                _buildSectionTitle('Job Schedule'),
                const SizedBox(height: 12),

                _buildDateSelector(
                  label: 'Scheduled Start Date',
                  date: ctrl.scheduledDate,
                  onTap: () => _selectScheduledDate(),
                  icon: Icons.calendar_today,
                ),
                const SizedBox(height: 12),

                _buildDateSelector(
                  label: 'Deadline',
                  date: ctrl.deadline,
                  onTap: () => _selectDeadline(),
                  icon: Icons.event,
                  helperText: 'Must be at least 2 days after start date',
                ),

                const SizedBox(height: 24),

                // Member Selection Section
                _buildSectionTitle('Select Team Members'),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Qualification Category',
                    prefixIcon: Icon(Icons.school),
                  ),
                  value: ctrl.selectedQualification,
                  items: ctrl.qualificationCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    ctrl.selectedQualification = v;
                    setState(() {});
                  },
                ),

                const SizedBox(height: 12),

                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text("Load Workers"),
                  onPressed: ctrl.selectedQualification == null
                      ? null
                      : () async {
                          await ctrl.fetchWorkers();
                          setState(() {});
                        },
                ),

                const SizedBox(height: 20),

                if (ctrl.loadingWorkers)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildWorkersSection(context),

                const SizedBox(height: 20),

                // Selected Members Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text(
                        "Selected Members: ${ctrl.selectedMemberIds.length}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (ctrl.selectedMemberIds.isNotEmpty &&
                          ctrl.scheduledDate != null &&
                          ctrl.deadline != null) ...[
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Check Availability'),
                          onPressed: _checkAvailability,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Create Team Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: ctrl.creatingTeam
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_circle),
                    label: const Text(
                      "Create Team & Send Invitations",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: ctrl.creatingTeam ? null : _handleCreateTeam,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // DATE SELECTOR
  // ------------------------------------------------------------
  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
    String? helperText,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          helperText: helperText,
          suffixIcon: date != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      if (label.contains('Scheduled')) {
                        ctrl.scheduledDate = null;
                      } else {
                        ctrl.deadline = null;
                      }
                    });
                  },
                )
              : null,
        ),
        child: Text(
          date != null
              ? DateFormat('EEEE, MMM dd, yyyy').format(date)
              : 'Tap to select date',
          style: TextStyle(
            color: date != null ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SELECT SCHEDULED DATE
  // ------------------------------------------------------------
  Future<void> _selectScheduledDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: ctrl.scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        ctrl.setScheduledDate(date);
      });
    }
  }

  // ------------------------------------------------------------
  // SELECT DEADLINE
  // ------------------------------------------------------------
  Future<void> _selectDeadline() async {
    final minDate = ctrl.scheduledDate?.add(const Duration(days: 2)) ??
        DateTime.now().add(const Duration(days: 2));

    final date = await showDatePicker(
      context: context,
      initialDate: ctrl.deadline ?? minDate,
      firstDate: minDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        ctrl.setDeadline(date);
      });
    }
  }

  // ------------------------------------------------------------
  // CHECK AVAILABILITY
  // ------------------------------------------------------------
  Future<void> _checkAvailability() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final availability = await ctrl.checkMemberAvailability();
    
    if (!mounted) return;
    Navigator.pop(context);

    final available = availability['available'] ?? [];
    final conflicting = availability['conflicting'] ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Availability Check'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (available.isNotEmpty) ...[
                const Text(
                  'Available Members:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text('${available.length} member(s)'),
                const SizedBox(height: 12),
              ],
              if (conflicting.isNotEmpty) ...[
                const Text(
                  'Members with Conflicts:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  '${conflicting.length} member(s) have overlapping schedules',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: They can still accept, but will need to manage multiple commitments.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // WORKERS SECTION
  // ------------------------------------------------------------
  Widget _buildWorkersSection(BuildContext context) {
    if (ctrl.workers.isEmpty) {
      return const Text(
        "No workers found for selected qualification.",
        style: TextStyle(color: Colors.grey),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ctrl.workers.length,
      itemBuilder: (_, i) {
        final w = ctrl.workers[i];
        final id = w["id"];
        final selected = ctrl.selectedMemberIds.contains(id);

        return Card(
          child: CheckboxListTile(
            title: Text("${w['first_name']} ${w['last_name']}"),
            subtitle: Text("Qualification: ${w['qualification']}"),
            value: selected,
            onChanged: (checked) {
              ctrl.toggleSelection(id);
            },
            secondary: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showWorkerDetails(context, w),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // WORKER DETAILS
  // ------------------------------------------------------------
  void _showWorkerDetails(BuildContext ctx, Map<String, dynamic> worker) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${worker['first_name']} ${worker['last_name']}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 20),
              Text("Qualification: ${worker['qualification']}"),
              const SizedBox(height: 10),
              Text("User ID: ${worker['id']}"),
              const SizedBox(height: 10),
              Text("Role: ${worker['role']}"),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // HANDLE CREATE TEAM
  // ------------------------------------------------------------
  Future<void> _handleCreateTeam() async {
    try {
      final team = await ctrl.createTeam();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text("Success!"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Team '${team["team_name"]}' created successfully."),
              const SizedBox(height: 12),
              Text(
                "Invitations sent to ${ctrl.selectedMemberIds.length} member(s).",
              ),
              const SizedBox(height: 8),
              if (ctrl.scheduledDate != null)
                Text(
                  "Start: ${DateFormat('MMM dd, yyyy').format(ctrl.scheduledDate!)}",
                  style: const TextStyle(fontSize: 12),
                ),
              if (ctrl.deadline != null)
                Text(
                  "Deadline: ${DateFormat('MMM dd, yyyy').format(ctrl.deadline!)}",
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ctrl.resetTeamBuilder();
              },
              child: const Text("Create Another"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Go back to dashboard
              },
              child: const Text("Done"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}