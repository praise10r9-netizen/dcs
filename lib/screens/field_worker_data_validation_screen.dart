// lib/screens/field_worker_data_validation_screen.dart
import 'package:flutter/material.dart';
import '../controllers/data_cleaning_controller.dart';

class FieldWorkerDataValidationScreen extends StatefulWidget {
  const FieldWorkerDataValidationScreen({super.key});

  @override
  State<FieldWorkerDataValidationScreen> createState() =>
      _FieldWorkerDataValidationScreenState();
}

class _FieldWorkerDataValidationScreenState
    extends State<FieldWorkerDataValidationScreen> {
  final DataCleaningController ctrl = DataCleaningController();
  List<Map<String, dynamic>> myResponses = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadMyResponses();
  }

  Future<void> _loadMyResponses() async {
    setState(() {
      loading = true;
    });

    try {
      final userId = ctrl.db.auth.currentUser?.id;
      if (userId != null) {
        // Fetch responses from forms the user has access to
        final responses = await ctrl.db
            .from('data_sets')
            .select('*, custom_form!inner(*)')
            .order('created_at', ascending: false);

        setState(() {
          myResponses = List<Map<String, dynamic>>.from(responses);
        });
      }
    } catch (e) {
      debugPrint('Error loading responses: $e');
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Data Validation'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : myResponses.isEmpty
              ? _buildEmptyState()
              : _buildResponsesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No responses to validate',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your submitted data will appear here',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myResponses.length,
      itemBuilder: (context, index) {
        final response = myResponses[index];
        final formData = response['custom_form'] as Map<String, dynamic>?;
        final responseData = response['response_data'] as Map<String, dynamic>?;

        // Simple validation: check for missing required fields
        final hasMissingData = _checkMissingData(responseData);
        final hasIncompleteData = _checkIncompleteData(responseData);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasMissingData
                    ? Colors.red.shade50
                    : hasIncompleteData
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasMissingData
                    ? Icons.error
                    : hasIncompleteData
                        ? Icons.warning_amber
                        : Icons.check_circle,
                color: hasMissingData
                    ? Colors.red
                    : hasIncompleteData
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
            title: Text(
              formData?['form_name'] ?? 'Response',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${response['response_id']}'),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(response['created_at']),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: _buildStatusChip(hasMissingData, hasIncompleteData),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Response Data:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (responseData != null)
                      ...responseData.entries.map((entry) {
                        final isMissing = entry.value == null ||
                            entry.value.toString().trim().isEmpty;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isMissing ? Icons.error_outline : Icons.check,
                                size: 16,
                                color: isMissing ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isMissing
                                        ? Colors.red.shade700
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry.value?.toString() ?? '(Missing)',
                                  style: TextStyle(
                                    color: isMissing
                                        ? Colors.red.shade700
                                        : Colors.black87,
                                    fontStyle:
                                        isMissing ? FontStyle.italic : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    if (hasMissingData || hasIncompleteData)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'This response has some quality issues. '
                                'The supervisor will review and clean the data.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool hasMissing, bool hasIncomplete) {
    String label;
    Color color;

    if (hasMissing) {
      label = 'Issues';
      color = Colors.red;
    } else if (hasIncomplete) {
      label = 'Warning';
      color = Colors.orange;
    } else {
      label = 'Valid';
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _checkMissingData(Map<String, dynamic>? data) {
    if (data == null) return true;
    return data.values
        .any((value) => value == null || value.toString().trim().isEmpty);
  }

  bool _checkIncompleteData(Map<String, dynamic>? data) {
    if (data == null) return false;
    // Check if more than 20% of fields are missing
    final missingCount = data.values
        .where((value) => value == null || value.toString().trim().isEmpty)
        .length;
    return missingCount > 0 && missingCount / data.length < 0.2;
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