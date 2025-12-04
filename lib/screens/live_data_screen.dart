// lib/screens/live_data_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/live_data_controller.dart';

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  final LiveDataController ctrl = LiveDataController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  void _closeDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
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
      drawer: _buildDrawer(),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.loading && ctrl.forms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return selectedFormId == null
              ? _buildEmptyState()
              : _buildStatsAndResponsesView();
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // DRAWER (COLLAPSIBLE SIDEBAR)
  // ------------------------------------------------------------
  Widget _buildDrawer() {
    return Drawer(
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          return Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.description, color: Colors.blue, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'My Forms',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                            color: isSelected
                                ? Colors.blue.shade100
                                : Colors.white,
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
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.blue)
                                  : null,
                              onTap: () {
                                setState(() {
                                  selectedFormId = formId;
                                  isMonitoring = false;
                                });
                                ctrl.fetchFormResponses(formId);
                                _closeDrawer();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.touch_app, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Select a form from the menu',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.menu),
            label: const Text('Open Menu'),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STATS AND RESPONSES VIEW
  // ------------------------------------------------------------
  Widget _buildStatsAndResponsesView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Form Title and Controls
          _buildFormHeader(),

          // Statistics Cards
          _buildStatisticsCards(),

          // Charts Section
          _buildChartsSection(),

          // Live Monitoring Toggle
          _buildLiveMonitoringSection(),

          const Divider(height: 32),

          // Responses List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Responses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
                  ],
                  onSelected: (value) {
                    if (value == 'export') {
                      _exportData();
                    }
                  },
                ),
              ],
            ),
          ),

          // Responses List
          _buildResponsesList(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FORM HEADER
  // ------------------------------------------------------------
  Widget _buildFormHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ctrl.selectedForm?['form_name'] ?? 'Form',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (ctrl.selectedForm?['subject'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Subject: ${ctrl.selectedForm!['subject']}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STATISTICS CARDS
  // ------------------------------------------------------------
  Widget _buildStatisticsCards() {
    final summary = ctrl.getResponseSummary();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _buildStatCard(
                    'Total',
                    summary['total'].toString(),
                    Colors.blue,
                    Icons.inbox,
                  ),
                  _buildStatCard(
                    'Today',
                    summary['today'].toString(),
                    Colors.green,
                    Icons.today,
                  ),
                  _buildStatCard(
                    'This Week',
                    summary['this_week'].toString(),
                    Colors.orange,
                    Icons.calendar_view_week,
                  ),
                  _buildStatCard(
                    'This Month',
                    summary['this_month'].toString(),
                    Colors.purple,
                    Icons.calendar_month,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CHARTS SECTION
  // ------------------------------------------------------------
  Widget _buildChartsSection() {
    if (ctrl.responses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Response Trends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildResponseChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseChart() {
    // Group responses by date
    final Map<String, int> responsesPerDay = {};
    
    for (final response in ctrl.responses) {
      final date = DateTime.parse(response['created_at']);
      final dateKey = '${date.month}/${date.day}';
      responsesPerDay[dateKey] = (responsesPerDay[dateKey] ?? 0) + 1;
    }

    if (responsesPerDay.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    final sortedEntries = responsesPerDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
        barGroups: sortedEntries.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: Colors.blue,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      sortedEntries[value.toInt()].key,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LIVE MONITORING SECTION
  // ------------------------------------------------------------
  Widget _buildLiveMonitoringSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isMonitoring ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMonitoring ? Colors.red : Colors.green,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isMonitoring ? Icons.stop_circle : Icons.play_circle_filled,
              size: 48,
              color: isMonitoring ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              isMonitoring ? 'Live Monitoring Active' : 'Start Live Monitoring',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isMonitoring ? Colors.red.shade900 : Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMonitoring
                  ? 'New responses will appear automatically'
                  : 'Monitor responses in real-time',
              style: TextStyle(
                fontSize: 14,
                color: isMonitoring ? Colors.red.shade700 : Colors.green.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: Icon(isMonitoring ? Icons.stop : Icons.wifi),
                label: Text(isMonitoring ? 'Stop Monitoring' : 'Start Live'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMonitoring ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _toggleMonitoring,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // RESPONSES LIST
  // ------------------------------------------------------------
  Widget _buildResponsesList() {
    if (ctrl.responses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No responses yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: ctrl.responses.length,
      itemBuilder: (context, index) {
        final response = ctrl.responses[index];
        return _buildResponseCard(response, index);
      },
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
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ctrl.stopRealtimeMonitoring();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live monitoring stopped'),
          duration: Duration(seconds: 2),
        ),
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