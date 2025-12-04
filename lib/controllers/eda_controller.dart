// lib/controllers/eda_controller.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EDAResult {
  final String fieldName;
  final String dataType;
  final Map<String, dynamic> statistics;
  final List<Map<String, dynamic>> distribution;
  final List<Map<String, dynamic>> trends;
  final Map<String, double>? correlations;
  final List<String> patterns;
  final DateTime analyzedAt;

  EDAResult({
    required this.fieldName,
    required this.dataType,
    required this.statistics,
    required this.distribution,
    required this.trends,
    this.correlations,
    required this.patterns,
    required this.analyzedAt,
  });

  Map<String, dynamic> toJson() => {
        'field_name': fieldName,
        'data_type': dataType,
        'statistics': statistics,
        'distribution': distribution,
        'trends': trends,
        'correlations': correlations,
        'patterns': patterns,
        'analyzed_at': analyzedAt.toIso8601String(),
      };

  factory EDAResult.fromJson(Map<String, dynamic> json) {
    return EDAResult(
      fieldName: json['field_name'] ?? '',
      dataType: json['data_type'] ?? '',
      statistics: Map<String, dynamic>.from(json['statistics'] ?? {}),
      distribution: List<Map<String, dynamic>>.from(json['distribution'] ?? []),
      trends: List<Map<String, dynamic>>.from(json['trends'] ?? []),
      correlations: json['correlations'] != null
          ? Map<String, double>.from(json['correlations'])
          : null,
      patterns: List<String>.from(json['patterns'] ?? []),
      analyzedAt: DateTime.parse(json['analyzed_at']),
    );
  }
}

class EDAController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;

  // State
  bool analyzing = false;
  bool autoAnalyzeEnabled = true;
  Map<String, EDAResult> results = {};
  Map<String, dynamic> overallInsights = {};
  
  Timer? _autoAnalyzeTimer;
  int? _currentFormId;

  // ------------------------------------------------------------
  // START AUTO-ANALYSIS
  // ------------------------------------------------------------
  void startAutoAnalysis(int formId, {Duration interval = const Duration(minutes: 5)}) {
    _currentFormId = formId;
    stopAutoAnalysis();

    // Run immediately
    performEDA(formId);

    // Schedule periodic analysis
    _autoAnalyzeTimer = Timer.periodic(interval, (_) {
      if (autoAnalyzeEnabled) {
        performEDA(formId);
      }
    });

    debugPrint('Auto-analysis started for form $formId');
  }

  // ------------------------------------------------------------
  // STOP AUTO-ANALYSIS
  // ------------------------------------------------------------
  void stopAutoAnalysis() {
    _autoAnalyzeTimer?.cancel();
    _autoAnalyzeTimer = null;
    debugPrint('Auto-analysis stopped');
  }

  // ------------------------------------------------------------
  // PERFORM EDA
  // ------------------------------------------------------------
  Future<void> performEDA(int formId) async {
    if (analyzing) return;

    analyzing = true;
    notifyListeners();

    try {
      // Fetch all responses for the form
      final responses = await db
          .from('data_sets')
          .select('response_data, created_at')
          .eq('form_id', formId)
          .order('created_at', ascending: true);

      if (responses.isEmpty) {
        analyzing = false;
        notifyListeners();
        return;
      }

      // Extract all field names
      final Set<String> allFields = {};
      for (final response in responses) {
        final data = response['response_data'] as Map<String, dynamic>?;
        if (data != null) {
          allFields.addAll(data.keys);
        }
      }

      // Analyze each field
      results.clear();
      for (final fieldName in allFields) {
        final result = await _analyzeField(fieldName, responses);
        if (result != null) {
          results[fieldName] = result;
        }
      }

      // Generate overall insights
      _generateOverallInsights(responses);
    } catch (e) {
      debugPrint('EDA error: $e');
    }

    analyzing = false;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // ANALYZE INDIVIDUAL FIELD
  // ------------------------------------------------------------
  Future<EDAResult?> _analyzeField(
    String fieldName,
    List<dynamic> responses,
  ) async {
    try {
      // Extract values with timestamps
      final List<Map<String, dynamic>> dataPoints = [];
      for (final response in responses) {
        final data = response['response_data'] as Map<String, dynamic>?;
        final createdAt = response['created_at'];

        if (data != null && data.containsKey(fieldName)) {
          dataPoints.add({
            'value': data[fieldName],
            'timestamp': DateTime.parse(createdAt),
          });
        }
      }

      if (dataPoints.isEmpty) return null;

      // Detect data type
      final firstValue = dataPoints.first['value'];
      final dataType = _detectDataType(firstValue);

      // Calculate statistics
      final statistics = _calculateStatistics(dataPoints, dataType);

      // Calculate distribution
      final distribution = _calculateDistribution(dataPoints, dataType);

      // Calculate trends
      final trends = _calculateTrends(dataPoints, dataType);

      // Detect patterns
      final patterns = _detectPatterns(dataPoints, dataType, statistics);

      return EDAResult(
        fieldName: fieldName,
        dataType: dataType,
        statistics: statistics,
        distribution: distribution,
        trends: trends,
        patterns: patterns,
        analyzedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error analyzing field $fieldName: $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // DETECT DATA TYPE
  // ------------------------------------------------------------
  String _detectDataType(dynamic value) {
    if (value == null) return 'null';
    if (value is num) return 'numeric';
    if (value is bool) return 'boolean';
    if (value is List) return 'array';

    if (value is String) {
      // Check if it's a date
      try {
        DateTime.parse(value);
        return 'date';
      } catch (_) {}

      // Check if it's numeric string
      if (num.tryParse(value) != null) {
        return 'numeric';
      }

      return 'text';
    }

    return 'unknown';
  }

  // ------------------------------------------------------------
  // CALCULATE STATISTICS
  // ------------------------------------------------------------
  Map<String, dynamic> _calculateStatistics(
    List<Map<String, dynamic>> dataPoints,
    String dataType,
  ) {
    final statistics = <String, dynamic>{
      'count': dataPoints.length,
      'missing': 0,
    };

    if (dataType == 'numeric') {
      final values = dataPoints
          .map((dp) {
            final value = dp['value'];
            if (value is num) return value.toDouble();
            if (value is String) return double.tryParse(value);
            return null;
          })
          .where((v) => v != null)
          .cast<double>()
          .toList();

      if (values.isNotEmpty) {
        values.sort();

        final sum = values.reduce((a, b) => a + b);
        final mean = sum / values.length;
        final median = _calculateMedian(values);
        final mode = _calculateMode(values);
        final stdDev = _calculateStdDev(values, mean);
        final min = values.first;
        final max = values.last;
        final range = max - min;
        final q1 = _calculatePercentile(values, 0.25);
        final q3 = _calculatePercentile(values, 0.75);
        final iqr = q3 - q1;

        statistics.addAll({
          'mean': mean.toStringAsFixed(2),
          'median': median.toStringAsFixed(2),
          'mode': mode?.toStringAsFixed(2),
          'std_dev': stdDev.toStringAsFixed(2),
          'min': min.toStringAsFixed(2),
          'max': max.toStringAsFixed(2),
          'range': range.toStringAsFixed(2),
          'q1': q1.toStringAsFixed(2),
          'q3': q3.toStringAsFixed(2),
          'iqr': iqr.toStringAsFixed(2),
          'coefficient_of_variation': ((stdDev / mean) * 100).toStringAsFixed(2),
        });
      }
    } else if (dataType == 'text' || dataType == 'array') {
      // Calculate frequency distribution
      final frequencyMap = <String, int>{};
      for (final dp in dataPoints) {
        final value = dp['value'].toString();
        frequencyMap[value] = (frequencyMap[value] ?? 0) + 1;
      }

      final uniqueCount = frequencyMap.length;
      final mostCommon = frequencyMap.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      statistics.addAll({
        'unique_values': uniqueCount,
        'most_common': mostCommon.key,
        'most_common_count': mostCommon.value,
        'diversity_index': (uniqueCount / dataPoints.length).toStringAsFixed(2),
      });
    } else if (dataType == 'boolean') {
      int trueCount = 0;
      int falseCount = 0;

      for (final dp in dataPoints) {
        final value = dp['value'];
        if (value == true || value == 'true') {
          trueCount++;
        } else {
          falseCount++;
        }
      }

      statistics.addAll({
        'true_count': trueCount,
        'false_count': falseCount,
        'true_percentage': ((trueCount / dataPoints.length) * 100).toStringAsFixed(1),
      });
    }

    return statistics;
  }

  // ------------------------------------------------------------
  // CALCULATE DISTRIBUTION
  // ------------------------------------------------------------
  List<Map<String, dynamic>> _calculateDistribution(
    List<Map<String, dynamic>> dataPoints,
    String dataType,
  ) {
    if (dataType == 'numeric') {
      // Create histogram bins
      final values = dataPoints
          .map((dp) {
            final value = dp['value'];
            if (value is num) return value.toDouble();
            if (value is String) return double.tryParse(value);
            return null;
          })
          .where((v) => v != null)
          .cast<double>()
          .toList();

      if (values.isEmpty) return [];

      values.sort();
      final min = values.first;
      final max = values.last;
      final binCount = min == max ? 1 : sqrt(values.length).ceil().clamp(5, 20);
      final binWidth = (max - min) / binCount;

      final bins = <Map<String, dynamic>>[];
      for (int i = 0; i < binCount; i++) {
        final binStart = min + (i * binWidth);
        final binEnd = binStart + binWidth;
        final count = values.where((v) => v >= binStart && v < binEnd).length;

        bins.add({
          'range': '${binStart.toStringAsFixed(1)}-${binEnd.toStringAsFixed(1)}',
          'count': count,
          'percentage': ((count / values.length) * 100).toStringAsFixed(1),
        });
      }

      return bins;
    } else {
      // Frequency distribution for categorical data
      final frequencyMap = <String, int>{};
      for (final dp in dataPoints) {
        final value = dp['value'].toString();
        frequencyMap[value] = (frequencyMap[value] ?? 0) + 1;
      }

      final distribution = frequencyMap.entries
          .map((entry) => {
                'category': entry.key,
                'count': entry.value,
                'percentage': ((entry.value / dataPoints.length) * 100)
                    .toStringAsFixed(1),
              })
          .toList();

      distribution.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return distribution.take(10).toList();
    }
  }

  // ------------------------------------------------------------
  // CALCULATE TRENDS
  // ------------------------------------------------------------
  List<Map<String, dynamic>> _calculateTrends(
    List<Map<String, dynamic>> dataPoints,
    String dataType,
  ) {
    if (dataPoints.length < 2) return [];

    // Group by time intervals (daily, weekly)
    final dailyGroups = <String, List<dynamic>>{};

    for (final dp in dataPoints) {
      final timestamp = dp['timestamp'] as DateTime;
      final dateKey = '${timestamp.year}-${timestamp.month}-${timestamp.day}';

      if (!dailyGroups.containsKey(dateKey)) {
        dailyGroups[dateKey] = [];
      }
      dailyGroups[dateKey]!.add(dp['value']);
    }

    final trends = <Map<String, dynamic>>[];

    if (dataType == 'numeric') {
      // Calculate daily averages
      for (final entry in dailyGroups.entries) {
        final values = entry.value
            .map((v) {
              if (v is num) return v.toDouble();
              if (v is String) return double.tryParse(v);
              return null;
            })
            .where((v) => v != null)
            .cast<double>()
            .toList();

        if (values.isNotEmpty) {
          final average = values.reduce((a, b) => a + b) / values.length;
          trends.add({
            'date': entry.key,
            'average': average.toStringAsFixed(2),
            'count': values.length,
          });
        }
      }
    } else {
      // Count daily submissions
      for (final entry in dailyGroups.entries) {
        trends.add({
          'date': entry.key,
          'count': entry.value.length,
        });
      }
    }

    trends.sort((a, b) => a['date'].compareTo(b['date']));
    return trends;
  }

  // ------------------------------------------------------------
  // DETECT PATTERNS
  // ------------------------------------------------------------
  List<String> _detectPatterns(
    List<Map<String, dynamic>> dataPoints,
    String dataType,
    Map<String, dynamic> statistics,
  ) {
    final patterns = <String>[];

    if (dataType == 'numeric') {
      final mean = double.tryParse(statistics['mean'] ?? '0') ?? 0;
      final stdDev = double.tryParse(statistics['std_dev'] ?? '0') ?? 0;
      final cv = double.tryParse(statistics['coefficient_of_variation'] ?? '0') ?? 0;

      // Check for high variability
      if (cv > 50) {
        patterns.add('High variability detected (CV: ${cv.toStringAsFixed(1)}%)');
      } else if (cv < 10) {
        patterns.add('Low variability - data is consistent');
      }

      // Check for outliers
      final values = dataPoints
          .map((dp) {
            final value = dp['value'];
            if (value is num) return value.toDouble();
            if (value is String) return double.tryParse(value);
            return null;
          })
          .where((v) => v != null)
          .cast<double>()
          .toList();

      final outliers = values.where((v) => (v - mean).abs() > 2 * stdDev).length;
      if (outliers > 0) {
        patterns.add('$outliers potential outlier(s) detected');
      }

      // Check for trend
      if (dataPoints.length >= 5) {
        final recentValues = values.sublist(max(0, values.length - 5));
        final isIncreasing = recentValues.every((v) =>
            recentValues.indexOf(v) == 0 ||
            v >= recentValues[recentValues.indexOf(v) - 1]);
        final isDecreasing = recentValues.every((v) =>
            recentValues.indexOf(v) == 0 ||
            v <= recentValues[recentValues.indexOf(v) - 1]);

        if (isIncreasing) {
          patterns.add('Increasing trend in recent submissions');
        } else if (isDecreasing) {
          patterns.add('Decreasing trend in recent submissions');
        }
      }
    } else if (dataType == 'text') {
      final uniqueValues = statistics['unique_values'] as int? ?? 0;
      final totalCount = statistics['count'] as int? ?? 0;

      if (uniqueValues == totalCount) {
        patterns.add('All responses are unique - high diversity');
      } else if (uniqueValues < totalCount * 0.2) {
        patterns.add('Limited response diversity - only $uniqueValues unique values');
      }

      // Check for dominant response
      final mostCommonCount = statistics['most_common_count'] as int? ?? 0;
      if (mostCommonCount > totalCount * 0.5) {
        patterns.add('Dominant response: "${statistics['most_common']}" (${((mostCommonCount / totalCount) * 100).toStringAsFixed(0)}%)');
      }
    }

    // Check submission timing patterns
    final hourDistribution = <int, int>{};
    for (final dp in dataPoints) {
      final timestamp = dp['timestamp'] as DateTime;
      final hour = timestamp.hour;
      hourDistribution[hour] = (hourDistribution[hour] ?? 0) + 1;
    }

    if (hourDistribution.isNotEmpty) {
      final peakHour = hourDistribution.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      if (peakHour.value > dataPoints.length * 0.3) {
        patterns.add('Peak submission time: ${peakHour.key}:00 - ${peakHour.key + 1}:00');
      }
    }

    return patterns;
  }

  // ------------------------------------------------------------
  // GENERATE OVERALL INSIGHTS
  // ------------------------------------------------------------
  void _generateOverallInsights(List<dynamic> responses) {
    overallInsights = {
      'total_responses': responses.length,
      'data_quality_score': _calculateDataQualityScore(responses),
      'response_rate_trend': _calculateResponseRateTrend(responses),
      'peak_submission_days': _getPeakSubmissionDays(responses),
      'field_completion_rates': _calculateFieldCompletionRates(responses),
    };
  }

  double _calculateDataQualityScore(List<dynamic> responses) {
    if (responses.isEmpty) return 0.0;

    int totalFields = 0;
    int completedFields = 0;

    for (final response in responses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null) {
        totalFields += data.length;
        completedFields += data.values
            .where((v) => v != null && v.toString().trim().isNotEmpty)
            .length;
      }
    }

    return totalFields > 0 ? (completedFields / totalFields) * 100 : 0.0;
  }

  String _calculateResponseRateTrend(List<dynamic> responses) {
    if (responses.length < 2) return 'insufficient_data';

    final now = DateTime.now();
    final last24h = responses.where((r) {
      final createdAt = DateTime.parse(r['created_at']);
      return now.difference(createdAt).inHours <= 24;
    }).length;

    final previous24h = responses.where((r) {
      final createdAt = DateTime.parse(r['created_at']);
      final diff = now.difference(createdAt);
      return diff.inHours > 24 && diff.inHours <= 48;
    }).length;

    if (last24h > previous24h * 1.2) return 'increasing';
    if (last24h < previous24h * 0.8) return 'decreasing';
    return 'stable';
  }

  List<String> _getPeakSubmissionDays(List<dynamic> responses) {
    final dayCount = <String, int>{};

    for (final response in responses) {
      final createdAt = DateTime.parse(response['created_at']);
      final dayKey = '${createdAt.year}-${createdAt.month}-${createdAt.day}';
      dayCount[dayKey] = (dayCount[dayKey] ?? 0) + 1;
    }

    final sortedDays = dayCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedDays.take(3).map((e) => e.key).toList();
  }

  Map<String, double> _calculateFieldCompletionRates(List<dynamic> responses) {
    final fieldCounts = <String, int>{};
    final fieldCompleted = <String, int>{};

    for (final response in responses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null) {
        for (final entry in data.entries) {
          fieldCounts[entry.key] = (fieldCounts[entry.key] ?? 0) + 1;
          if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
            fieldCompleted[entry.key] = (fieldCompleted[entry.key] ?? 0) + 1;
          }
        }
      }
    }

    final completionRates = <String, double>{};
    for (final field in fieldCounts.keys) {
      final rate = (fieldCompleted[field] ?? 0) / fieldCounts[field]!;
      completionRates[field] = rate * 100;
    }

    return completionRates;
  }

  // ------------------------------------------------------------
  // HELPER METHODS
  // ------------------------------------------------------------
  double _calculateMedian(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
    return sorted[middle];
  }

  double? _calculateMode(List<double> values) {
    final frequencyMap = <double, int>{};
    for (final value in values) {
      frequencyMap[value] = (frequencyMap[value] ?? 0) + 1;
    }

    if (frequencyMap.isEmpty) return null;

    final maxFreq = frequencyMap.values.reduce(max);
    return frequencyMap.entries
        .firstWhere((e) => e.value == maxFreq)
        .key;
  }

  double _calculateStdDev(List<double> values, double mean) {
    if (values.length < 2) return 0;
    final variance = values
            .map((v) => pow(v - mean, 2))
            .reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }

  double _calculatePercentile(List<double> sortedValues, double percentile) {
    final index = (percentile * (sortedValues.length - 1)).round();
    return sortedValues[index];
  }

  @override
  void dispose() {
    stopAutoAnalysis();
    super.dispose();
  }
}