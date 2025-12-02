// lib/screens/live_data_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/live_data_controller.dart';

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  final LiveDataController ctrl = LiveDataController();
  int? selectedFormId;
  bool isMonitoring = false;

  @override
  void initState() {
    super.initState();
    ctrl.fetchMyForms();
  }

  @override
  void dispose() {
    ctrl.stopRealtimeMonitoring();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Data Collection'),
        actions: [
          if (isMonitoring)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (selectedFormId != null) {
                ctrl.fetchFormResponses(selectedFormId!);
              } else {
                ctrl.fetchMyForms();
              }
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.loading && ctrl.forms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Row(
            children: [
              // Left sidebar - Forms list
              _buildFormsList(),

              // Right side - Responses
              Expanded(
                child: selectedFormId == null
                    ? _buildEmptyState()
                    : _buildResponsesView(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // FORMS LIST (LEFT SIDEBAR)
  // ------------------------------------------------------------
  Widget _buildFormsList() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.description, color: Colors.blue),
                SizedBox(width: 12),
                Text(
                  'My Forms',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ctrl.forms.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No forms created yet',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: ctrl.forms.length,
                    itemBuilder: (context, index) {
                      final form = ctrl.forms[index];
                      final formId = form['form_id'];
                      final isSelected = selectedFormId == formId;
                      final responseCount =
                          ctrl.responsesPerForm[formId] ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        color: isSelected ? Colors.blue.shade100 : Colors.white,
                        child: ListTile(
                          title: Text(
                            form['form_name'] ?? 'Untitled',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '$responseCount response${responseCount != 1 ? 's' : ''}',
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.chevron_right,
                                  color: Colors.blue)
                              : null,
                          onTap: () {
                            setState(() {
                              selectedFormId = formId;
                              isMonitoring = false;
                            });
                            ctrl.fetchFormResponses(formId);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Select a form to view responses',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // RESPONSES VIEW
  // ------------------------------------------------------------
  Widget _buildResponsesView() {
    return Column(
      children: [
        // Header with stats and controls
        _buildResponsesHeader(),

        // Responses list
        Expanded(
          child: ctrl.responses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No responses yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wifi),
                        label: const Text('Start Live Monitoring'),
                        onPressed: _toggleMonitoring,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ctrl.responses.length,
                  itemBuilder: (context, index) {
                    final response = ctrl.responses[index];
                    return _buildResponseCard(response, index);
                  },
                ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // RESPONSES HEADER
  // ------------------------------------------------------------
  Widget _buildResponsesHeader() {
    final summary = ctrl.getResponseSummary();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ctrl.selectedForm?['form_name'] ?? 'Form Responses',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(isMonitoring ? Icons.stop : Icons.wifi),
                label: Text(isMonitoring ? 'Stop Monitoring' : 'Start Live'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMonitoring ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _toggleMonitoring,
              ),
              const SizedBox(width: 8),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text('Export CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 8),
                        Text('Refresh'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'export') {
                    _exportData();
                  } else if (value == 'refresh') {
                    ctrl.fetchFormResponses(selectedFormId!);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Total', summary['total'].toString(), Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard('Today', summary['today'].toString(), Colors.green),
              const SizedBox(width: 12),
              _buildStatCard('This Week', summary['this_week'].toString(), Colors.orange),
              const SizedBox(width: 12),
              _buildStatCard('This Month', summary['this_month'].toString(), Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Color.fromARGB(222, 247, 245, 208),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // RESPONSE CARD
  // ------------------------------------------------------------
  Widget _buildResponseCard(Map<String, dynamic> response, int index) {
    final responseData = response['response_data'] as Map<String, dynamic>?;
    final createdAt = DateTime.parse(response['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text('Response #${response['response_id']}'),
        subtitle: Text(
          'Submitted: ${_formatDateTime(createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(response['response_id']),
        ),
        children: [
          if (responseData != null && responseData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: responseData.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatValue(entry.value),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data'),
            ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value is List) {
      return value.join(', ');
    }
    return value.toString();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ------------------------------------------------------------
  // TOGGLE MONITORING
  // ------------------------------------------------------------
  void _toggleMonitoring() {
    if (selectedFormId == null) return;

    setState(() {
      isMonitoring = !isMonitoring;
    });

    if (isMonitoring) {
      ctrl.startRealtimeMonitoring(selectedFormId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live monitoring started - New responses will appear automatically'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ctrl.stopRealtimeMonitoring();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live monitoring stopped')),
      );
    }
  }

  // ------------------------------------------------------------
  // EXPORT DATA
  // ------------------------------------------------------------
  void _exportData() {
    final csvData = ctrl.exportResponsesAsCSV();
    if (csvData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: csvData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV data copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ------------------------------------------------------------
  // CONFIRM DELETE
  // ------------------------------------------------------------
  void _confirmDelete(int responseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Response?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ctrl.deleteResponse(responseId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Response deleted')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}