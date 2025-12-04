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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          "Team Builder",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Reset",
            onPressed: () {
              ctrl.resetTeamBuilder();
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Info Section
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Team Information', Icons.info_outline),
                      const SizedBox(height: 20),
                      
                      _buildTextField(
                        controller: ctrl.teamNameCtrl,
                        label: "Team Name",
                        icon: Icons.group_rounded,
                        hint: 'Enter team name',
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: ctrl.orgCtrl,
                        label: "Organization",
                        icon: Icons.business_rounded,
                        hint: 'Enter organization name',
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: ctrl.jobDescCtrl,
                        label: "Job Description",
                        icon: Icons.description_rounded,
                        hint: 'Describe the task/job for this team',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Schedule Section
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Job Schedule', Icons.schedule_rounded),
                      const SizedBox(height: 20),

                      _buildDateSelector(
                        label: 'Scheduled Start Date',
                        date: ctrl.scheduledDate,
                        onTap: () => _selectScheduledDate(),
                        icon: Icons.calendar_today_rounded,
                      ),
                      const SizedBox(height: 16),

                      _buildDateSelector(
                        label: 'Deadline',
                        date: ctrl.deadline,
                        onTap: () => _selectDeadline(),
                        icon: Icons.event_rounded,
                        helperText: 'Must be at least 2 days after start date',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Member Selection Section
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Select Team Members', Icons.people_rounded),
                      const SizedBox(height: 20),

                      _buildDropdown(),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.search_rounded, size: 20),
                          label: const Text(
                            "Load Workers",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: ctrl.selectedQualification == null
                              ? null
                              : () async {
                                  await ctrl.fetchWorkers();
                                  setState(() {});
                                },
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (ctrl.loadingWorkers)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        _buildWorkersSection(context),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Selected Members Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.blue[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.people_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Selected Members",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${ctrl.selectedMemberIds.length} ${ctrl.selectedMemberIds.length == 1 ? 'member' : 'members'}",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (ctrl.selectedMemberIds.isNotEmpty &&
                          ctrl.scheduledDate != null &&
                          ctrl.deadline != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.check_circle_outline_rounded, size: 20),
                            label: const Text(
                              'Check Availability',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[700],
                              side: BorderSide(color: Colors.blue[700]!, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _checkAvailability,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

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
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_circle_rounded, size: 24),
                    label: const Text(
                      "Create Team & Send Invitations",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.green[600]!.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: ctrl.creatingTeam ? null : _handleCreateTeam,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // CARD WRAPPER
  // ------------------------------------------------------------
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[700], size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // TEXT FIELD
  // ------------------------------------------------------------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ------------------------------------------------------------
  // DROPDOWN
  // ------------------------------------------------------------
  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Qualification Category',
        prefixIcon: const Icon(Icons.school_rounded, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      value: ctrl.selectedQualification,
      items: ctrl.qualificationCategories
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(fontSize: 15)),
              ))
          .toList(),
      onChanged: (v) {
        ctrl.selectedQualification = v;
        setState(() {});
      },
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
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          prefixIcon: Icon(icon, size: 22),
          helperText: helperText,
          helperStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: date != null
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
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
              : Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[600]),
        ),
        child: Text(
          date != null
              ? DateFormat('EEEE, MMM dd, yyyy').format(date)
              : 'Tap to select date',
          style: TextStyle(
            color: date != null ? Colors.grey[800] : Colors.grey[500],
            fontSize: 15,
            fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.event_available_rounded, color: Colors.blue[700]),
            ),
            const SizedBox(width: 12),
            const Text('Availability Check'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (available.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Members',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${available.length} member(s)',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (conflicting.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_rounded, color: Colors.orange[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Members with Conflicts',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${conflicting.length} member(s) have overlapping schedules',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: They can still accept, but will need to manage multiple commitments.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.person_off_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                "No workers found for selected qualification.",
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Workers (${ctrl.workers.length})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ctrl.workers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final w = ctrl.workers[i];
            final id = w["id"];
            final selected = ctrl.selectedMemberIds.contains(id);

            return Container(
              decoration: BoxDecoration(
                color: selected ? Colors.blue[50] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? Colors.blue[300]! : Colors.grey[200]!,
                  width: selected ? 2 : 1,
                ),
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  "${w['first_name']} ${w['last_name']}",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.grey[800],
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Qualification: ${w['qualification']}",
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
                value: selected,
                activeColor: Colors.blue[600],
                onChanged: (checked) {
                  ctrl.toggleSelection(id);
                },
                secondary: IconButton(
                  icon: Icon(Icons.info_outline_rounded, color: Colors.blue[600]),
                  onPressed: () => _showWorkerDetails(context, w),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // WORKER DETAILS
  // ------------------------------------------------------------
  void _showWorkerDetails(BuildContext ctx, Map<String, dynamic> worker) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      "${worker['first_name'][0]}${worker['last_name'][0]}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${worker['first_name']} ${worker['last_name']}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          worker['role'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 20),
              _buildDetailRow(Icons.school_rounded, "Qualification", worker['qualification']),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.badge_rounded, "User ID", worker['id']),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 32),
              ),
              const SizedBox(width: 12),
              const Text("Success!", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Team '${team["team_name"]}' created successfully.",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mail_rounded, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          "Invitations sent to ${ctrl.selectedMemberIds.length} member(s)",
                          style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                        ),
                      ],
                    ),
                    if (ctrl.scheduledDate != null || ctrl.deadline != null) ...[
                      const SizedBox(height: 12),
                      if (ctrl.scheduledDate != null)
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              "Start: ${DateFormat('MMM dd, yyyy').format(ctrl.scheduledDate!)}",
                              style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                            ),
                          ],
                        ),
                      if (ctrl.deadline != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.event_rounded, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              "Deadline: ${DateFormat('MMM dd, yyyy').format(ctrl.deadline!)}",
                              style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ctrl.resetTeamBuilder();
              },
              child: const Text("Create Another", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}