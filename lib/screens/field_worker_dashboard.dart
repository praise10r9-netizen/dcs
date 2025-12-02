// lib/screens/field_worker_dashboard.dart
import 'package:flutter/material.dart';
import '../controllers/field_worker_controller.dart';
import 'form_filling_screen.dart';

class FieldWorkerDashboard extends StatefulWidget {
  const FieldWorkerDashboard({super.key});

  @override
  State<FieldWorkerDashboard> createState() => _FieldWorkerDashboardState();
}

class _FieldWorkerDashboardState extends State<FieldWorkerDashboard> {
  final FieldWorkerController ctrl = FieldWorkerController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    ctrl.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Worker Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.refreshAll(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          return IndexedStack(
            index: _selectedIndex,
            children: [
              _buildNotificationsTab(),
              _buildMyTeamsTab(),
              _buildFormsTab(),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('${ctrl.getUnreadNotificationCount()}'),
              isLabelVisible: ctrl.getUnreadNotificationCount() > 0,
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'My Teams',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Forms',
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // NOTIFICATIONS TAB
  // ------------------------------------------------------------
  Widget _buildNotificationsTab() {
    if (ctrl.loadingNotifications) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notifications', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: ctrl.fetchNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: ctrl.notifications.length,
        itemBuilder: (context, index) {
          final notification = ctrl.notifications[index];
          final isUnread = notification['status'] == 'unread';
          final teamId = ctrl.extractTeamIdFromNotification(
            notification['message'] ?? '',
          );

          return Card(
            color: isUnread ? Colors.blue.shade50 : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                isUnread ? Icons.mark_email_unread : Icons.mail,
                color: isUnread ? Colors.blue : Colors.grey,
              ),
              title: Text(
                notification['message'] ?? '',
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                _formatDateTime(notification['created_at']),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  if (isUnread)
                    const PopupMenuItem(
                      value: 'read',
                      child: Text('Mark as read'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'read') {
                    await ctrl.markNotificationAsRead(notification['id']);
                  } else if (value == 'delete') {
                    await ctrl.deleteNotification(notification['id']);
                  }
                },
              ),
              onTap: () {
                if (teamId != null && isUnread) {
                  _showTeamInvitationDialog(notification, teamId);
                }
              },
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // MY TEAMS TAB
  // ------------------------------------------------------------
  Widget _buildMyTeamsTab() {
    if (ctrl.loadingTeams) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.myTeams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('You are not part of any team yet', 
                style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('Check notifications for team invitations',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: ctrl.fetchMyTeams,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: ctrl.myTeams.length,
        itemBuilder: (context, index) {
          final team = ctrl.myTeams[index];
          final isSelected = ctrl.selectedTeamId == team['id'].toString();

          return Card(
            color: isSelected ? Colors.green.shade50 : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isSelected ? Colors.green : Colors.blue,
                child: const Icon(Icons.group, color: Colors.white),
              ),
              title: Text(
                team['team_name'] ?? 'Team ${team['id']}',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Organization: ${team['organization'] ?? 'N/A'}'),
                  Text(
                    'Created: ${_formatDateTime(team['created_at'])}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              trailing: Icon(
                isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                color: isSelected ? Colors.green : Colors.grey,
              ),
              onTap: () async {
                await ctrl.selectTeam(team['id']);
                setState(() {
                  _selectedIndex = 2; // Switch to Forms tab
                });
              },
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // FORMS TAB
  // ------------------------------------------------------------
  Widget _buildFormsTab() {
    if (ctrl.selectedTeamId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No team selected', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('Select a team from "My Teams" tab to view forms',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (ctrl.loadingForms) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.availableForms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No forms available for this team',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                if (ctrl.selectedTeamId != null) {
                  ctrl.fetchTeamForms(int.parse(ctrl.selectedTeamId!));
                }
              },
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ctrl.availableForms.length,
      itemBuilder: (context, index) {
        final form = ctrl.availableForms[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.assignment, color: Colors.white),
            ),
            title: Text(
              form['form_name'] ?? 'Untitled Form',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject: ${form['subject'] ?? 'N/A'}'),
                Text(
                  form['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              _showFormDetails(form);
            },
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // SHOW TEAM INVITATION DIALOG
  // ------------------------------------------------------------
  void _showTeamInvitationDialog(Map<String, dynamic> notification, int teamId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team Invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message'] ?? ''),
            const SizedBox(height: 16),
            const Text(
              'Would you like to join this team?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ctrl.declineTeamInvitation(notification['id']);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invitation declined')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: ctrl.joiningTeam
                ? null
                : () async {
                    try {
                      await ctrl.joinTeam(teamId, notification['id']);
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Successfully joined team!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      setState(() {
                        _selectedIndex = 1; // Switch to My Teams tab
                      });
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
            child: ctrl.joiningTeam
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Accept'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SHOW FORM DETAILS
  // ------------------------------------------------------------
  void _showFormDetails(Map<String, dynamic> form) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      form['form_name'] ?? 'Untitled Form',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildDetailRow('Subject', form['subject'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildDetailRow('Description', form['description'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Created',
                _formatDateTime(form['created_at']),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Fill Form'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormFillingScreen(
                        formId: form['form_id'],
                        formName: form['form_name'] ?? 'Untitled Form',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HELPER WIDGETS
  // ------------------------------------------------------------
  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }
}