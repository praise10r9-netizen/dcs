// lib/screens/live_data_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/live_data_controller.dart';
import '../controllers/eda_controller.dart';

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  final LiveDataController ctrl = LiveDataController();
  final EDAController edaCtrl = EDAController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int? selectedFormId;
  bool isMonitoring = false;

  @override
  void initState() {
    super.initState();
    ctrl.fetchMyForms();
    edaCtrl.addListener(_onEDAUpdate);
  }

  @override
  void dispose() {
    ctrl.stopRealtimeMonitoring();
    edaCtrl.removeListener(_onEDAUpdate);
    edaCtrl.stopBackgroundAnalysis();
    ctrl.dispose();
    edaCtrl.dispose();
    super.dispose();
  }

  void _onEDAUpdate() {
    if (mounted) setState(() {});
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
                edaCtrl.performEDA(selectedFormId!);
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
  // DRAWER
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
                          final responseCount = ctrl.responsesPerForm[formId] ?? 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: isSelected ? Colors.blue.shade100 : Colors.white,
                            child: ListTile(
                              title: Text(
                                form['form_name'] ?? 'Untitled',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text('$responseCount response${responseCount != 1 ? 's' : ''}'),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                              onTap: () {
                                setState(() {
                                  selectedFormId = formId;
                                  isMonitoring = false;
                                });
                                ctrl.fetchFormResponses(formId);
                                edaCtrl.performEDA(formId);
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
          const Text('Select a form from the menu', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.menu),
            label: const Text('Open Menu'),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // MAIN VIEW
  // ------------------------------------------------------------
  Widget _buildStatsAndResponsesView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFormHeader(),
          _buildStatisticsCards(),
          _buildEDAInsights(),
          const Divider(height: 32),
          _buildResponsesListHeader(),
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
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ctrl.selectedForm?['form_name'] ?? 'Form',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (ctrl.selectedForm?['subject'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Subject: ${ctrl.selectedForm!['subject']}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
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
          const Text('Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildStatCard('Total', summary['total'].toString(), Colors.blue, Icons.inbox),
              _buildStatCard('Today', summary['today'].toString(), Colors.green, Icons.today),
              _buildStatCard('This Week', summary['this_week'].toString(), Colors.orange, Icons.calendar_view_week),
              _buildStatCard('This Month', summary['this_month'].toString(), Colors.purple, Icons.calendar_month),
            ],
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // EDA INSIGHTS
  // ------------------------------------------------------------
  Widget _buildEDAInsights() {
    if (ctrl.responses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Data Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (edaCtrl.analyzing)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 16),
          if (edaCtrl.analyzing)
            _buildAnalysisProgress()
          else if (edaCtrl.analysisComplete)
            Column(
              children: [
                _buildEDASummary(),
                const SizedBox(height: 16),
                _buildDistributionsSection(),
                const SizedBox(height: 16),
                _buildCorrelationsSection(),
                const SizedBox(height: 16),
                _buildTrendsSection(),
                const SizedBox(height: 16),
                _buildAnomaliesSection(),
              ],
            )
          else
            _buildStartAnalysisButton(),
        ],
      ),
    );
  }

  Widget _buildAnalysisProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          const Text('Analyzing data...'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: edaCtrl.analysisProgress,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 8),
          Text('${(edaCtrl.analysisProgress * 100).toInt()}%'),
        ],
      ),
    );
  }

  Widget _buildStartAnalysisButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.analytics),
        label: const Text('Analyze Data'),
        onPressed: () {
          if (selectedFormId != null) {
            edaCtrl.performEDA(selectedFormId!);
          }
        },
      ),
    );
  }

  Widget _buildEDASummary() {
    final stats = edaCtrl.summaryStatistics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.purple.shade50]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize, color: Colors.blue),
              SizedBox(width: 8),
              Text('Analysis Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildSummaryChip('Fields', stats['total_fields']?.toString() ?? '0', Icons.view_column),
              _buildSummaryChip('Numeric', stats['numeric_fields']?.toString() ?? '0', Icons.numbers),
              _buildSummaryChip('Categorical', stats['categorical_fields']?.toString() ?? '0', Icons.category),
              _buildSummaryChip('Correlations', stats['correlations_found']?.toString() ?? '0', Icons.link),
              _buildSummaryChip('Anomalies', stats['anomalies_detected']?.toString() ?? '0', Icons.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildDistributionsSection() {
    if (edaCtrl.distributions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.green),
              SizedBox(width: 8),
              Text('Field Distributions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...edaCtrl.distributions.take(3).map((dist) => _buildDistributionCard(dist)),
          if (edaCtrl.distributions.length > 3)
            TextButton(
              onPressed: () => _showAllDistributions(),
              child: Text('View all ${edaCtrl.distributions.length} fields'),
            ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(FieldDistribution dist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(dist.fieldName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Chip(
                  label: Text(dist.dataType, style: const TextStyle(fontSize: 11)),
                  backgroundColor: dist.dataType == 'numeric' ? Colors.blue.shade100 : Colors.orange.shade100,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dist.dataType == 'numeric' && dist.mean != null) ...[
              Text('Mean: ${dist.mean!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
              Text('Median: ${dist.median!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
              Text('Std Dev: ${dist.stdDev!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
              Text('Range: ${dist.min} - ${dist.max}', style: const TextStyle(fontSize: 12)),
            ] else ...[
              Text('Unique values: ${dist.frequencies.length}', style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationsSection() {
    if (edaCtrl.correlations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub, color: Colors.orange),
              SizedBox(width: 8),
              Text('Correlations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...edaCtrl.correlations.take(3).map((corr) => _buildCorrelationCard(corr)),
          if (edaCtrl.correlations.length > 3)
            TextButton(
              onPressed: () => _showAllCorrelations(),
              child: Text('View all ${edaCtrl.correlations.length} correlations'),
            ),
        ],
      ),
    );
  }

  Widget _buildCorrelationCard(CorrelationPair corr) {
    Color strengthColor = corr.strength == 'strong'
        ? Colors.red
        : corr.strength == 'moderate'
            ? Colors.orange
            : Colors.yellow;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: strengthColor.withOpacity(0.2),
          child: Icon(Icons.link, color: strengthColor, size: 20),
        ),
        title: Text('${corr.field1} ↔ ${corr.field2}', style: const TextStyle(fontSize: 13)),
        subtitle: Text('Correlation: ${corr.correlation.toStringAsFixed(3)}', style: const TextStyle(fontSize: 11)),
        trailing: Chip(
          label: Text(corr.strength.toUpperCase(), style: const TextStyle(fontSize: 10)),
          backgroundColor: strengthColor.withOpacity(0.3),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTrendsSection() {
    if (edaCtrl.trends.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.purple),
              SizedBox(width: 8),
              Text('Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...edaCtrl.trends.take(3).map((trend) => _buildTrendCard(trend)),
          if (edaCtrl.trends.length > 3)
            TextButton(
              onPressed: () => _showAllTrends(),
              child: Text('View all ${edaCtrl.trends.length} trends'),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(TrendAnalysis trend) {
    IconData trendIcon = trend.trendDirection == 'increasing'
        ? Icons.trending_up
        : trend.trendDirection == 'decreasing'
            ? Icons.trending_down
            : Icons.trending_flat;

    Color trendColor = trend.trendDirection == 'increasing'
        ? Colors.green
        : trend.trendDirection == 'decreasing'
            ? Colors.red
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(trendIcon, color: trendColor),
        title: Text(trend.fieldName, style: const TextStyle(fontSize: 13)),
        subtitle: Text('Direction: ${trend.trendDirection}', style: const TextStyle(fontSize: 11)),
        trailing: trend.slope != null
            ? Text('Slope: ${trend.slope!.toStringAsFixed(3)}', style: TextStyle(fontSize: 11, color: trendColor))
            : null,
      ),
    );
  }

  Widget _buildAnomaliesSection() {
    if (edaCtrl.anomalies.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Anomalies Detected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...edaCtrl.anomalies.take(3).map((anomaly) => _buildAnomalyCard(anomaly)),
          if (edaCtrl.anomalies.length > 3)
            TextButton(
              onPressed: () => _showAllAnomalies(),
              child: Text('View all ${edaCtrl.anomalies.length} fields with anomalies'),
            ),
        ],
      ),
    );
  }

  Widget _buildAnomalyCard(AnomalyDetection anomaly) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Text(anomaly.totalAnomalies.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        title: Text(anomaly.fieldName, style: const TextStyle(fontSize: 13)),
        subtitle: Text('${anomaly.anomalyPercentage.toStringAsFixed(1)}% of responses', style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.error_outline, color: Colors.red),
      ),
    );
  }

  void _showAllDistributions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Field Distributions'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.distributions.length,
            itemBuilder: (ctx, i) => _buildDistributionCard(edaCtrl.distributions[i]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showAllCorrelations() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Correlations'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.correlations.length,
            itemBuilder: (ctx, i) => _buildCorrelationCard(edaCtrl.correlations[i]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showAllTrends() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Trends'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.trends.length,
            itemBuilder: (ctx, i) => _buildTrendCard(edaCtrl.trends[i]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showAllAnomalies() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Anomalies'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.anomalies.length,
            itemBuilder: (ctx, i) => _buildAnomalyCard(edaCtrl.anomalies[i]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  // ------------------------------------------------------------
  // RESPONSES LIST HEADER
  // ------------------------------------------------------------
  Widget _buildResponsesListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Responses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [Icon(Icons.download), SizedBox(width: 8), Text('Export CSV')],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'export') _exportData();
            },
          ),
        ],
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
              Text('No responses yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
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

  Widget _buildResponseCard(Map<String, dynamic> response, int index) {
    final responseData = response['response_data'] as Map<String, dynamic>?;
    final createdAt = DateTime.parse(response['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
        ),
        title: Text('Response #${response['response_id']}'),
        subtitle: Text('Submitted: ${_formatDateTime(createdAt)}', style: const TextStyle(fontSize: 12)),
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
                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(_formatValue(entry.value), style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                        const Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const Padding(padding: EdgeInsets.all(16), child: Text('No data')),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value is List) return value.join(', ');
    return value.toString();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _exportData() {
    final csvData = ctrl.exportResponsesAsCSV();
    if (csvData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }

    Clipboard.setData(ClipboardData(text: csvData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV data copied to clipboard'), backgroundColor: Colors.green),
    );
  }

  void _confirmDelete(int responseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Response?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ctrl.deleteResponse(responseId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response deleted')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}