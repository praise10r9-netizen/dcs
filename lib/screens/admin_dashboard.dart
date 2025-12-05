// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminController adminCtrl = AdminController();
  final AuthController authCtrl = AuthController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    adminCtrl.fetchUsers();
    adminCtrl.fetchForms();
    adminCtrl.fetchDataSets();
    adminCtrl.fetchPendingSupervisors();
  }

  @override
  void dispose() {
    adminCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await _showConfirmDialog(
                'Logout',
                'Are you sure you want to logout?',
              );
              if (confirm == true && mounted) {
                await authCtrl.logout(context);
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description),
                label: Text('Forms'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storage),
                label: Text('Data Sets'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_user),
                label: Text('Authorize'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assessment),
                label: Text('Reports'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: AnimatedBuilder(
              animation: adminCtrl,
              builder: (context, _) {
                if (adminCtrl.loading && _selectedIndex == 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildSelectedScreen();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewScreen();
      case 1:
        return _buildUsersScreen();
      case 2:
        return _buildFormsScreen();
      case 3:
        return _buildDataSetsScreen();
      case 4:
        return _buildAuthorizationScreen();
      case 5:
        return _buildReportsScreen();
      default:
        return const Center(child: Text('Unknown screen'));
    }
  }

  // ============================================================
  // OVERVIEW SCREEN
  // ============================================================
  Widget _buildOverviewScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                'Total Users',
                adminCtrl.users.length.toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                'Total Forms',
                adminCtrl.forms.length.toString(),
                Icons.description,
                Colors.green,
              ),
              _buildStatCard(
                'Total Responses',
                adminCtrl.dataSets.length.toString(),
                Icons.inbox,
                Colors.orange,
              ),
              _buildStatCard(
                'Pending Approvals',
                adminCtrl.pendingSupervisors.length.toString(),
                Icons.pending_actions,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRecentActivityList(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList() {
    final recentForms = adminCtrl.forms.take(5).toList();
    
    if (recentForms.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No recent activity')),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentForms.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final form = recentForms[index];
          return ListTile(
            leading: const Icon(Icons.description),
            title: Text(form['form_name'] ?? 'Untitled'),
            subtitle: Text('Created: ${_formatDate(form['created_at'])}'),
            trailing: Chip(
              label: Text(form['subject'] ?? 'N/A'),
              backgroundColor: Colors.blue.shade100,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // USERS SCREEN
  // ============================================================
  Widget _buildUsersScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'User Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add User'),
              ),
            ],
          ),
        ),
        Expanded(
          child: adminCtrl.loading
              ? const Center(child: CircularProgressIndicator())
              : adminCtrl.users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: adminCtrl.users.length,
                      itemBuilder: (context, index) {
                        final user = adminCtrl.users[index];
                        return _buildUserCard(user);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'unknown';
    final Color roleColor = _getRoleColor(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.2),
          child: Text(
            (user['first_name']?[0] ?? 'U').toUpperCase(),
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text('${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? 'No email'),
            Text('Qualification: ${user['qualification'] ?? 'N/A'}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                role.toUpperCase(),
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: roleColor.withOpacity(0.2),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditUserDialog(user);
                } else if (value == 'delete') {
                  _confirmDeleteUser(user['id']);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMS SCREEN
  // ============================================================
  Widget _buildFormsScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Forms Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Create form functionality coming soon')),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Form'),
              ),
            ],
          ),
        ),
        Expanded(
          child: adminCtrl.loading
              ? const Center(child: CircularProgressIndicator())
              : adminCtrl.forms.isEmpty
                  ? const Center(child: Text('No forms found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: adminCtrl.forms.length,
                      itemBuilder: (context, index) {
                        final form = adminCtrl.forms[index];
                        return _buildFormCard(form);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFormCard(Map<String, dynamic> form) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.description, color: Colors.blue),
        title: Text(form['form_name'] ?? 'Untitled Form'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject: ${form['subject'] ?? 'N/A'}'),
            Text('Created: ${_formatDate(form['created_at'])}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDeleteForm(form['form_id']),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(form['description'] ?? 'No description'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to form details or responses
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Responses'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA SETS SCREEN
  // ============================================================
  Widget _buildDataSetsScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Data Sets',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => adminCtrl.fetchDataSets(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: adminCtrl.loading
              ? const Center(child: CircularProgressIndicator())
              : adminCtrl.dataSets.isEmpty
                  ? const Center(child: Text('No data sets found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: adminCtrl.dataSets.length,
                      itemBuilder: (context, index) {
                        final dataSet = adminCtrl.dataSets[index];
                        return _buildDataSetCard(dataSet);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDataSetCard(Map<String, dynamic> dataSet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.storage, color: Colors.orange),
        title: Text('Response #${dataSet['response_id']}'),
        subtitle: Text('Submitted: ${_formatDate(dataSet['created_at'])}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDeleteDataSet(dataSet['response_id']),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Response Data:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(dataSet['response_data']?.toString() ?? 'No data'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AUTHORIZATION SCREEN
  // ============================================================
  Widget _buildAuthorizationScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Authorize Supervisors',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (adminCtrl.pendingSupervisors.isNotEmpty)
                Chip(
                  label: Text('${adminCtrl.pendingSupervisors.length} Pending'),
                  backgroundColor: Colors.orange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
        Expanded(
          child: adminCtrl.loading
              ? const Center(child: CircularProgressIndicator())
              : adminCtrl.pendingSupervisors.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text('No pending supervisor approvals'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: adminCtrl.pendingSupervisors.length,
                      itemBuilder: (context, index) {
                        final user = adminCtrl.pendingSupervisors[index];
                        return _buildAuthorizationCard(user);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAuthorizationCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    (user['first_name']?[0] ?? 'S').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(user['email'] ?? 'No email'),
                      Text('Qualification: ${user['qualification'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _rejectSupervisor(user['id']),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveSupervisor(user['id']),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORTS SCREEN
  // ============================================================
  Widget _buildReportsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Reports',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildReportCard(
                'User Activity Report',
                'View detailed user activity logs',
                Icons.person_search,
                Colors.blue,
                () => _generateReport('user_activity'),
              ),
              _buildReportCard(
                'Data Collection Report',
                'Analyze data collection trends',
                Icons.trending_up,
                Colors.green,
                () => _generateReport('data_collection'),
              ),
              _buildReportCard(
                'Form Performance',
                'Track form submission rates',
                Icons.assessment,
                Colors.orange,
                () => _generateReport('form_performance'),
              ),
              _buildReportCard(
                'System Health',
                'Monitor system status',
                Icons.health_and_safety,
                Colors.purple,
                () => _generateReport('system_health'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'supervisor':
        return Colors.blue;
      case 'field_worker':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // ============================================================
  // DIALOG METHODS
  // ============================================================
  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final qualificationCtrl = TextEditingController();
    String selectedRole = 'field_worker';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New User'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: qualificationCtrl,
                  decoration: const InputDecoration(labelText: 'Qualification'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'field_worker', child: Text('Field Worker')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value != null) selectedRole = value;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                await adminCtrl.createUser(
                  email: emailCtrl.text,
                  password: passwordCtrl.text,
                  firstName: firstNameCtrl.text,
                  lastName: lastNameCtrl.text,
                  role: selectedRole,
                  qualification: qualificationCtrl.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User created successfully')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit user functionality coming soon')),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(String userId) async {
    final confirm = await _showConfirmDialog(
      'Delete User',
      'Are you sure you want to delete this user?',
    );
    if (confirm == true) {
      await adminCtrl.deleteUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted')),
        );
      }
    }
  }

  void _confirmDeleteForm(int formId) async {
    final confirm = await _showConfirmDialog(
      'Delete Form',
      'Are you sure you want to delete this form?',
    );
    if (confirm == true) {
      await adminCtrl.deleteForm(formId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form deleted')),
        );
      }
    }
  }

  void _confirmDeleteDataSet(int responseId) async {
    final confirm = await _showConfirmDialog(
      'Delete Response',
      'Are you sure you want to delete this response?',
    );
    if (confirm == true) {
      await adminCtrl.deleteDataSet(responseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response deleted')),
        );
      }
    }
  }

  void _approveSupervisor(String userId) async {
    await adminCtrl.approveSupervisor(userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supervisor approved'), backgroundColor: Colors.green),
      );
    }
  }

  void _rejectSupervisor(String userId) async {
    final confirm = await _showConfirmDialog(
      'Reject Supervisor',
      'Are you sure you want to reject this supervisor request?',
    );
    if (confirm == true) {
      await adminCtrl.rejectSupervisor(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supervisor rejected')),
        );
      }
    }
  }

  void _generateReport(String reportType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generating $reportType report...')),
    );
  }
}