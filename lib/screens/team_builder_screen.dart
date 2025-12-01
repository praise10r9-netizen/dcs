import 'package:flutter/material.dart';
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
            tooltip: "Reset Team Builder",
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

                // ------------------------------------------------------
                // TEAM NAME INPUT
                // ------------------------------------------------------
                TextField(
                  controller: ctrl.teamNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Team Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // ------------------------------------------------------
                // ORGANIZATION INPUT
                // ------------------------------------------------------
                TextField(
                  controller: ctrl.orgCtrl,
                  decoration: const InputDecoration(
                    labelText: "Organization",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // ------------------------------------------------------
                // QUALIFICATION DROPDOWN
                // ------------------------------------------------------
                const Text("Select Qualification Category",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  value: ctrl.selectedQualification,
                  items: ctrl.qualificationCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    ctrl.selectedQualification = v;
                    setState(() {});
                  },
                ),

                const SizedBox(height: 12),

                // ------------------------------------------------------
                // LOAD WORKERS BUTTON
                // ------------------------------------------------------
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

                // ------------------------------------------------------
                // WORKERS LIST
                // ------------------------------------------------------
                if (ctrl.loadingWorkers)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildWorkersSection(context),

                const SizedBox(height: 20),

                // ------------------------------------------------------
                // SELECTED MEMBERS COUNT
                // ------------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Selected Members: ${ctrl.selectedMemberIds.length}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 40),

                // ------------------------------------------------------
                // CREATE TEAM BUTTON
                // ------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: ctrl.creatingTeam
                        ? const CircularProgressIndicator()
                        : const Text("Create Team"),
                    onPressed: ctrl.creatingTeam
                        ? null
                        : () async {
                            try {
                              final team = await ctrl.createTeam();

                              if (!mounted) return;

                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Team Created"),
                                  content: Text(
                                      "Team '${team["team_name"]}' created successfully."),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("OK"),
                                    ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // WORKERS SECTION
  // ---------------------------------------------------------------------
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
          child: ListTile(
            title: Text("${w['first_name']} ${w['last_name']}"),
            subtitle: Text("Qualification: ${w['qualification']}"),
            trailing: Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? Colors.blue : Colors.grey,
            ),
            onTap: () {
              _showWorkerDetails(context, w);
            },
            onLongPress: () {
              ctrl.toggleSelection(id);
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // WORKER DETAILS BOTTOM SHEET
  // ---------------------------------------------------------------------
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

              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text("Select / Unselect"),
                onPressed: () {
                  ctrl.toggleSelection(worker['id']);
                  Navigator.pop(ctx);
                },
              )
            ],
          ),
        );
      },
    );
  }
}
