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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Data Collection',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (isMonitoring)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: Colors.blue.shade700),
              tooltip: 'Refresh',
              iconSize: 24,
              onPressed: () {
                if (selectedFormId != null) {
                  ctrl.fetchFormResponses(selectedFormId!);
                  edaCtrl.performEDA(selectedFormId!);
                } else {
                  ctrl.fetchMyForms();
                }
              },
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.loading && ctrl.forms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return selectedFormId == null
              ? _buildFormsListView()
              : _buildStatsAndResponsesView();
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // FORMS LIST VIEW (Main Screen)
  // ------------------------------------------------------------
  Widget _buildFormsListView() {
    if (ctrl.forms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No forms created yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a form to start collecting data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade200),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Forms',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select a form to view responses',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.forms.length,
            itemBuilder: (context, index) {
              final form = ctrl.forms[index];
              final formId = form['form_id'];
              final responseCount = ctrl.responsesPerForm[formId] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    form['form_name'] ?? 'Untitled',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: responseCount > 0
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                size: 14,
                                color: responseCount > 0
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$responseCount response${responseCount != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: responseCount > 0
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      selectedFormId = formId;
                      isMonitoring = false;
                    });
                    ctrl.fetchFormResponses(formId);
                    edaCtrl.performEDA(formId);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // MAIN VIEW
  // ------------------------------------------------------------
  Widget _buildStatsAndResponsesView() {
    return Column(
      children: [
        _buildFormHeader(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                
                _buildEDAInsights(),
                const Divider(height: 32, thickness: 1),
                _buildResponsesListHeader(),
                _buildResponsesList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // FORM HEADER
  // ------------------------------------------------------------
  Widget _buildFormHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.blue.shade700),
            onPressed: () {
              setState(() {
                selectedFormId = null;
                isMonitoring = false;
              });
            },
            tooltip: 'Back to forms',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctrl.selectedForm?['form_name'] ?? 'Form',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (ctrl.selectedForm?['subject'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.subject_rounded,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ctrl.selectedForm!['subject'],
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
              const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Data Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (edaCtrl.analyzing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Analyzing data...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: edaCtrl.analysisProgress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(edaCtrl.analysisProgress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartAnalysisButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.analytics_rounded),
        label: const Text('Analyze Data'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_rounded, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'Analysis Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSummaryChip(
                'Fields',
                stats['total_fields']?.toString() ?? '0',
                Icons.view_column_rounded,
              ),
              _buildSummaryChip(
                'Numeric',
                stats['numeric_fields']?.toString() ?? '0',
                Icons.numbers_rounded,
              ),
              _buildSummaryChip(
                'Categorical',
                stats['categorical_fields']?.toString() ?? '0',
                Icons.category_rounded,
              ),
              _buildSummaryChip(
                'Correlations',
                stats['correlations_found']?.toString() ?? '0',
                Icons.link_rounded,
              ),
              _buildSummaryChip(
                'Anomalies',
                stats['anomalies_detected']?.toString() ?? '0',
                Icons.warning_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionsSection() {
    if (edaCtrl.distributions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Text(
                'Field Distributions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...edaCtrl.distributions.take(3).map((dist) => _buildDistributionCard(dist)),
          if (edaCtrl.distributions.length > 3)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('View all ${edaCtrl.distributions.length} fields'),
                onPressed: () => _showAllDistributions(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(FieldDistribution dist) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dist.fieldName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dist.dataType == 'numeric'
                      ? Colors.blue.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dist.dataType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dist.dataType == 'numeric'
                        ? Colors.blue.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dist.dataType == 'numeric' && dist.mean != null) ...[
            _buildStatRow('Mean', dist.mean!.toStringAsFixed(2)),
            _buildStatRow('Median', dist.median!.toStringAsFixed(2)),
            _buildStatRow('Std Dev', dist.stdDev!.toStringAsFixed(2)),
            _buildStatRow('Range', '${dist.min} - ${dist.max}'),
          ] else ...[
            _buildStatRow('Unique values', dist.frequencies.length.toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationsSection() {
    if (edaCtrl.correlations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Text(
                'Correlations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...edaCtrl.correlations.take(3).map((corr) => _buildCorrelationCard(corr)),
          if (edaCtrl.correlations.length > 3)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('View all ${edaCtrl.correlations.length} correlations'),
                onPressed: () => _showAllCorrelations(),
              ),
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
            : Colors.yellow.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: strengthColor.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: strengthColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.link_rounded, color: strengthColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${corr.field1} ↔ ${corr.field2}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Correlation: ${corr.correlation.toStringAsFixed(3)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: strengthColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              corr.strength.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: strengthColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsSection() {
    if (edaCtrl.trends.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Colors.purple, size: 24),
              SizedBox(width: 12),
              Text(
                'Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...edaCtrl.trends.take(3).map((trend) => _buildTrendCard(trend)),
          if (edaCtrl.trends.length > 3)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('View all ${edaCtrl.trends.length} trends'),
                onPressed: () => _showAllTrends(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(TrendAnalysis trend) {
    IconData trendIcon = trend.trendDirection == 'increasing'
        ? Icons.trending_up_rounded
        : trend.trendDirection == 'decreasing'
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    Color trendColor = trend.trendDirection == 'increasing'
        ? Colors.green
        : trend.trendDirection == 'decreasing'
            ? Colors.red
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: trendColor.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(trendIcon, color: trendColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trend.fieldName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Direction: ${trend.trendDirection}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (trend.slope != null)
            Text(
              'Slope: ${trend.slope!.toStringAsFixed(3)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: trendColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesSection() {
    if (edaCtrl.anomalies.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Text(
                'Anomalies Detected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...edaCtrl.anomalies.take(3).map((anomaly) => _buildAnomalyCard(anomaly)),
          if (edaCtrl.anomalies.length > 3)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('View all ${edaCtrl.anomalies.length} fields with anomalies'),
                onPressed: () => _showAllAnomalies(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnomalyCard(AnomalyDetection anomaly) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                anomaly.totalAnomalies.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anomaly.fieldName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${anomaly.anomalyPercentage.toStringAsFixed(1)}% of responses',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
        ],
      ),
    );
  }

  void _showAllDistributions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('All Field Distributions'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.distributions.length,
            itemBuilder: (ctx, i) => _buildDistributionCard(edaCtrl.distributions[i]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void _showAllCorrelations() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('All Correlations'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.correlations.length,
            itemBuilder: (ctx, i) => _buildCorrelationCard(edaCtrl.correlations[i]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void _showAllTrends() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('All Trends'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.trends.length,
            itemBuilder: (ctx, i) => _buildTrendCard(edaCtrl.trends[i]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void _showAllAnomalies() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('All Anomalies'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: edaCtrl.anomalies.length,
            itemBuilder: (ctx, i) => _buildAnomalyCard(edaCtrl.anomalies[i]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          )
        ],
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
          const Icon(Icons.list_alt_rounded, color: Colors.blue, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Responses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: PopupMenuButton(
              icon: Icon(Icons.more_vert_rounded, color: Colors.blue.shade700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded),
                      SizedBox(width: 12),
                      Text('Export CSV'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'export') _exportData();
              },
            ),
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
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No responses yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Responses will appear here once submitted',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
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

  Widget _buildResponseCard(Map<String, dynamic> response, int index) {
    final responseData = response['response_data'] as Map<String, dynamic>?;
    final createdAt = DateTime.parse(response['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            'Response #${response['response_id']}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 0),
                Text(
                  'Submitted: ${_formatDateTime(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () => _confirmDelete(response['response_id']),
          ),
          children: [
            if (responseData != null && responseData.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: responseData.entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatValue(entry.value),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No data',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: csvData));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('CSV data copied to clipboard'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _confirmDelete(int responseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Response?'),
          ],
        ),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ctrl.deleteResponse(responseId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Response deleted'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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