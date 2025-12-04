// lib/screens/supervisor_data_cleaning_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/data_cleaning_controller.dart';

class SupervisorDataCleaningScreen extends StatefulWidget {
  const SupervisorDataCleaningScreen({super.key});

  @override
  State<SupervisorDataCleaningScreen> createState() =>
      _SupervisorDataCleaningScreenState();
}

class _SupervisorDataCleaningScreenState
    extends State<SupervisorDataCleaningScreen> {
  final DataCleaningController ctrl = DataCleaningController();
  List<Map<String, dynamic>> forms = [];
  bool loadingForms = false;

  @override
  void initState() {
    super.initState();
    _loadForms();
  }

  Future<void> _loadForms() async {
    setState(() {
      loadingForms = true;
    });

    forms = await ctrl.fetchFormsForCleaning();

    setState(() {
      loadingForms = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Cleaning & Preparation'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.selectedFormId == null) {
            return _buildFormSelection();
          }

          return _buildCleaningInterface();
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // FORM SELECTION VIEW
  // ------------------------------------------------------------
  Widget _buildFormSelection() {
    if (loadingForms) {
      return const Center(child: CircularProgressIndicator());
    }

    if (forms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No forms available',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a form to clean',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: forms.length,
              itemBuilder: (context, index) {
                final form = forms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.cleaning_services,
                          color: Colors.blue.shade700,),
                    ),
                    title: Text(
                      form['form_name'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(form['subject'] ?? ''),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      await ctrl.loadResponsesForCleaning(form['form_id']);
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
  // CLEANING INTERFACE
  // ------------------------------------------------------------
  Widget _buildCleaningInterface() {
    return Column(
      children: [
        // Quality Overview Card
        _buildQualityOverview(),

        // Tab Bar
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue.shade700,
                  tabs: const [
                    Tab(text: 'Issues', icon: Icon(Icons.warning_amber, size: 20)),
                    Tab(text: 'Rules', icon: Icon(Icons.rule, size: 20)),
                    Tab(text: 'Statistics', icon: Icon(Icons.bar_chart, size: 20)),
                    Tab(text: 'Preview', icon: Icon(Icons.preview, size: 20)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildIssuesTab(),
                      _buildRulesTab(),
                      _buildStatisticsTab(),
                      _buildPreviewTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action Buttons
        _buildActionButtons(),
      ],
    );
  }

  // ------------------------------------------------------------
  // QUALITY OVERVIEW CARD
  // ------------------------------------------------------------
  Widget _buildQualityOverview() {
    final metrics = ctrl.qualityMetrics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data Quality Score',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    ctrl.selectedFormId = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Quality Score',
                  '${metrics['quality_score'] ?? 0}%',
                  Icons.star,
                  _getQualityColor(
                      double.tryParse(metrics['quality_score'] ?? '0') ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Completeness',
                  '${metrics['completeness_score'] ?? 0}%',
                  Icons.check_circle,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Total Issues',
                  '${metrics['total_issues'] ?? 0}',
                  Icons.warning,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  // ------------------------------------------------------------
  // ISSUES TAB
  // ------------------------------------------------------------
  Widget _buildIssuesTab() {
    if (ctrl.analyzing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.detectedIssues.isEmpty) {
      return const Center(child: Text('No issues detected!'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildIssueSection('High Severity', 'high', Colors.red),
        _buildIssueSection('Medium Severity', 'medium', Colors.orange),
        _buildIssueSection('Low Severity', 'low', Colors.yellow),
      ],
    );
  }

  Widget _buildIssueSection(String title, String severity, Color color) {
    final issues = ctrl.getIssuesBySeverity(severity);

    if (issues.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              '$title (${issues.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...issues.map((issue) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_getIssueIcon(issue.issueType), color: color),
                title: Text(issue.fieldName),
                subtitle: Text(
                    '${_getIssueTypeLabel(issue.issueType)} - ${issue.issueType}'),
                trailing: issue.suggestedValue != null
                    ? TextButton(
                        child: const Text('Fix'),
                        onPressed: () => _showFixDialog(issue),
                      )
                    : null,
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  IconData _getIssueIcon(String type) {
    switch (type) {
      case 'missing':
        return Icons.error_outline;
      case 'outlier':
        return Icons.warning_amber;
      case 'invalid':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  String _getIssueTypeLabel(String type) {
    switch (type) {
      case 'missing':
        return 'Missing Value';
      case 'outlier':
        return 'Outlier Detected';
      case 'invalid':
        return 'Invalid Value';
      default:
        return type;
    }
  }

  // ------------------------------------------------------------
  // RULES TAB
  // ------------------------------------------------------------
  Widget _buildRulesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create New Rule'),
            onPressed: _showCreateRuleDialog,
          ),
        ),
        Expanded(
          child: ctrl.activeRules.isEmpty
              ? const Center(child: Text('No cleaning rules yet'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ctrl.activeRules.length,
                  itemBuilder: (context, index) {
                    final rule = ctrl.activeRules[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(_getRuleIcon(rule.ruleType)),
                        title: Text(rule.fieldName),
                        subtitle: Text(_getRuleLabel(rule.ruleType)),
                        trailing: Switch(
                          value: rule.autoApply,
                          onChanged: (value) {},
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getRuleIcon(String type) {
    switch (type) {
      case 'fill_missing':
        return Icons.add_circle;
      case 'remove_outlier':
        return Icons.delete_sweep;
      case 'standardize':
        return Icons.format_align_center;
      default:
        return Icons.rule;
    }
  }

  String _getRuleLabel(String type) {
    switch (type) {
      case 'fill_missing':
        return 'Fill Missing Values';
      case 'remove_outlier':
        return 'Remove Outliers';
      case 'standardize':
        return 'Standardize Format';
      default:
        return type;
    }
  }

  // ------------------------------------------------------------
  // STATISTICS TAB
  // ------------------------------------------------------------
  Widget _buildStatisticsTab() {
    final stats = ctrl.fieldStatistics;

    if (stats.isEmpty) {
      return const Center(child: Text('No statistics available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: stats.entries.map((entry) {
        final fieldName = entry.key;
        final fieldStats = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fieldName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStatRow('Data Type', fieldStats['data_type'] ?? 'unknown'),
                _buildStatRow('Total Records', '${fieldStats['total'] ?? 0}'),
                _buildStatRow('Missing Values', '${fieldStats['missing'] ?? 0}'),
                _buildStatRow('Missing %',
                    '${fieldStats['missing_percentage'] ?? 0}%'),
                _buildStatRow(
                    'Unique Values', '${fieldStats['unique_values'] ?? 0}'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PREVIEW TAB
  // ------------------------------------------------------------
  Widget _buildPreviewTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ctrl.cleanedResponses.take(10).length,
      itemBuilder: (context, index) {
        final response = ctrl.cleanedResponses[index];
        final data = response['response_data'] as Map<String, dynamic>?;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text('Response #${response['response_id']}'),
            children: [
              if (data != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(e.key,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(e.value?.toString() ?? 'null'),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // ACTION BUTTONS
  // ------------------------------------------------------------
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
              onPressed: () {
                final csv = ctrl.exportCleanedDataAsCSV();
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard')),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: ctrl.cleaning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Apply Cleaning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: ctrl.cleaning ? null : _applyCleaningRules,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DIALOGS
  // ------------------------------------------------------------
  void _showFixDialog(DataQualityIssue issue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fix: ${issue.fieldName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue: ${_getIssueTypeLabel(issue.issueType)}'),
            const SizedBox(height: 8),
            Text('Suggested value: ${issue.suggestedValue}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Create auto-fix rule
              Navigator.pop(ctx);
            },
            child: const Text('Apply Fix'),
          ),
        ],
      ),
    );
  }

  void _showCreateRuleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Cleaning Rule'),
        content: const Text('Rule creation dialog - Coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCleaningRules() async {
    try {
      await ctrl.applyCleaningRules();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleaning rules applied successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}