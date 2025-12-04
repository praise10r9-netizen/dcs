// lib/controllers/eda_controller.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FieldDistribution {
  final String fieldName;
  final String dataType;
  final Map<String, int> frequencies;
  final List<num>? numericValues;
  final double? mean;
  final double? median;
  final double? stdDev;
  final num? min;
  final num? max;
  
  FieldDistribution({
    required this.fieldName,
    required this.dataType,
    required this.frequencies,
    this.numericValues,
    this.mean,
    this.median,
    this.stdDev,
    this.min,
    this.max,
  });
}

class CorrelationPair {
  final String field1;
  final String field2;
  final double correlation;
  final String strength; // 'strong', 'moderate', 'weak'
  
  CorrelationPair({
    required this.field1,
    required this.field2,
    required this.correlation,
    required this.strength,
  });
}

class TrendAnalysis {
  final String fieldName;
  final List<Map<String, dynamic>> dataPoints;
  final String trendDirection; // 'increasing', 'decreasing', 'stable'
  final double? slope;
  
  TrendAnalysis({
    required this.fieldName,
    required this.dataPoints,
    required this.trendDirection,
    this.slope,
  });
}

class AnomalyDetection {
  final String fieldName;
  final List<Map<String, dynamic>> anomalies;
  final int totalAnomalies;
  final double anomalyPercentage;
  
  AnomalyDetection({
    required this.fieldName,
    required this.anomalies,
    required this.totalAnomalies,
    required this.anomalyPercentage,
  });
}

class EDAController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;
  
  // State
  bool analyzing = false;
  bool analysisComplete = false;
  double analysisProgress = 0.0;
  
  // Analysis Results
  List<FieldDistribution> distributions = [];
  List<CorrelationPair> correlations = [];
  List<TrendAnalysis> trends = [];
  List<AnomalyDetection> anomalies = [];
  
  Map<String, dynamic> summaryStatistics = {};
  
  // Background timer for periodic analysis
  Timer? _analysisTimer;
  
  // ------------------------------------------------------------
  // START BACKGROUND ANALYSIS
  // ------------------------------------------------------------
  void startBackgroundAnalysis(int formId, {Duration interval = const Duration(minutes: 5)}) {
    // Initial analysis
    performEDA(formId);
    
    // Set up periodic analysis
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(interval, (timer) {
      performEDA(formId);
    });
  }
  
  // ------------------------------------------------------------
  // STOP BACKGROUND ANALYSIS
  // ------------------------------------------------------------
  void stopBackgroundAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
  }
  
  // ------------------------------------------------------------
  // PERFORM COMPLETE EDA
  // ------------------------------------------------------------
  Future<void> performEDA(int formId) async {
    analyzing = true;
    analysisProgress = 0.0;
    analysisComplete = false;
    notifyListeners();
    
    try {
      // Fetch responses
      final responses = await db
          .from('data_sets')
          .select()
          .eq('form_id', formId)
          .order('created_at');
      
      if (responses.isEmpty) {
        analyzing = false;
        notifyListeners();
        return;
      }
      
      final dataList = List<Map<String, dynamic>>.from(responses);
      
      // Step 1: Analyze Distributions (25%)
      await _analyzeDistributions(dataList);
      analysisProgress = 0.25;
      notifyListeners();
      
      // Step 2: Calculate Correlations (50%)
      await _analyzeCorrelations(dataList);
      analysisProgress = 0.50;
      notifyListeners();
      
      // Step 3: Detect Trends (75%)
      await _analyzeTrends(dataList);
      analysisProgress = 0.75;
      notifyListeners();
      
      // Step 4: Find Anomalies (100%)
      await _detectAnomalies(dataList);
      analysisProgress = 1.0;
      notifyListeners();
      
      // Generate summary statistics
      _generateSummaryStatistics(dataList);
      
      analysisComplete = true;
    } catch (e) {
      debugPrint('performEDA error: $e');
    }
    
    analyzing = false;
    notifyListeners();
  }
  
  // ------------------------------------------------------------
  // ANALYZE DISTRIBUTIONS
  // ------------------------------------------------------------
  Future<void> _analyzeDistributions(List<Map<String, dynamic>> dataList) async {
    distributions.clear();
    
    // Get all field names
    Set<String> allFields = {};
    for (var response in dataList) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null) {
        allFields.addAll(data.keys);
      }
    }
    
    // Analyze each field
    for (var fieldName in allFields) {
      List<dynamic> values = [];
      for (var response in dataList) {
        final data = response['response_data'] as Map<String, dynamic>?;
        if (data != null && data[fieldName] != null) {
          values.add(data[fieldName]);
        }
      }
      
      if (values.isEmpty) continue;
      
      // Detect data type
      final dataType = _detectDataType(values);
      
      if (dataType == 'numeric') {
        final numericValues = values.map((v) => num.parse(v.toString())).toList();
        distributions.add(FieldDistribution(
          fieldName: fieldName,
          dataType: dataType,
          frequencies: _calculateNumericFrequencies(numericValues),
          numericValues: numericValues,
          mean: _calculateMean(numericValues),
          median: _calculateMedian(numericValues),
          stdDev: _calculateStdDev(numericValues),
          min: numericValues.reduce((a, b) => a < b ? a : b),
          max: numericValues.reduce((a, b) => a > b ? a : b),
        ));
      } else if (dataType == 'categorical') {
        distributions.add(FieldDistribution(
          fieldName: fieldName,
          dataType: dataType,
          frequencies: _calculateCategoricalFrequencies(values),
        ));
      }
    }
  }
  
  // ------------------------------------------------------------
  // ANALYZE CORRELATIONS
  // ------------------------------------------------------------
  Future<void> _analyzeCorrelations(List<Map<String, dynamic>> dataList) async {
    correlations.clear();
    
    // Get numeric fields
    final numericFields = distributions
        .where((d) => d.dataType == 'numeric')
        .toList();
    
    // Calculate correlations between numeric fields
    for (int i = 0; i < numericFields.length; i++) {
      for (int j = i + 1; j < numericFields.length; j++) {
        final field1 = numericFields[i];
        final field2 = numericFields[j];
        
        if (field1.numericValues != null && field2.numericValues != null) {
          final corr = _calculatePearsonCorrelation(
            field1.numericValues!,
            field2.numericValues!,
          );
          
          if (corr != null && corr.abs() > 0.3) {
            correlations.add(CorrelationPair(
              field1: field1.fieldName,
              field2: field2.fieldName,
              correlation: corr,
              strength: _getCorrelationStrength(corr),
            ));
          }
        }
      }
    }
    
    // Sort by absolute correlation value
    correlations.sort((a, b) => b.correlation.abs().compareTo(a.correlation.abs()));
  }
  
  // ------------------------------------------------------------
  // ANALYZE TRENDS
  // ------------------------------------------------------------
  Future<void> _analyzeTrends(List<Map<String, dynamic>> dataList) async {
    trends.clear();
    
    // Get numeric fields
    final numericFields = distributions
        .where((d) => d.dataType == 'numeric')
        .toList();
    
    for (var field in numericFields) {
      List<Map<String, dynamic>> dataPoints = [];
      
      for (int i = 0; i < dataList.length; i++) {
        final response = dataList[i];
        final data = response['response_data'] as Map<String, dynamic>?;
        
        if (data != null && data[field.fieldName] != null) {
          dataPoints.add({
            'x': i.toDouble(),
            'y': num.parse(data[field.fieldName].toString()).toDouble(),
            'timestamp': response['created_at'],
          });
        }
      }
      
      if (dataPoints.length > 2) {
        final slope = _calculateLinearRegressionSlope(dataPoints);
        final direction = _determineTrendDirection(slope);
        
        trends.add(TrendAnalysis(
          fieldName: field.fieldName,
          dataPoints: dataPoints,
          trendDirection: direction,
          slope: slope,
        ));
      }
    }
  }
  
  // ------------------------------------------------------------
  // DETECT ANOMALIES
  // ------------------------------------------------------------
  Future<void> _detectAnomalies(List<Map<String, dynamic>> dataList) async {
    anomalies.clear();
    
    // Get numeric fields
    final numericFields = distributions
        .where((d) => d.dataType == 'numeric')
        .toList();
    
    for (var field in numericFields) {
      if (field.numericValues == null || field.mean == null || field.stdDev == null) {
        continue;
      }
      
      List<Map<String, dynamic>> fieldAnomalies = [];
      
      // Z-score method for anomaly detection
      final threshold = 3.0; // 3 standard deviations
      
      for (int i = 0; i < dataList.length; i++) {
        final response = dataList[i];
        final data = response['response_data'] as Map<String, dynamic>?;
        
        if (data != null && data[field.fieldName] != null) {
          final value = num.parse(data[field.fieldName].toString());
          final zScore = (value - field.mean!) / field.stdDev!;
          
          if (zScore.abs() > threshold) {
            fieldAnomalies.add({
              'response_id': response['response_id'],
              'value': value,
              'z_score': zScore,
              'timestamp': response['created_at'],
            });
          }
        }
      }
      
      if (fieldAnomalies.isNotEmpty) {
        anomalies.add(AnomalyDetection(
          fieldName: field.fieldName,
          anomalies: fieldAnomalies,
          totalAnomalies: fieldAnomalies.length,
          anomalyPercentage: (fieldAnomalies.length / dataList.length) * 100,
        ));
      }
    }
  }
  
  // ------------------------------------------------------------
  // GENERATE SUMMARY STATISTICS
  // ------------------------------------------------------------
  void _generateSummaryStatistics(List<Map<String, dynamic>> dataList) {
    summaryStatistics = {
      'total_responses': dataList.length,
      'total_fields': distributions.length,
      'numeric_fields': distributions.where((d) => d.dataType == 'numeric').length,
      'categorical_fields': distributions.where((d) => d.dataType == 'categorical').length,
      'correlations_found': correlations.length,
      'anomalies_detected': anomalies.fold<int>(0, (sum, a) => sum + a.totalAnomalies),
      'analysis_timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  // ------------------------------------------------------------
  // CALCULATE MEAN
  // ------------------------------------------------------------
  double _calculateMean(List<num> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
  
  // ------------------------------------------------------------
  // CALCULATE MEDIAN
  // ------------------------------------------------------------
  double _calculateMedian(List<num> values) {
    if (values.isEmpty) return 0;
    final sorted = List<num>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
    return sorted[middle].toDouble();
  }
  
  // ------------------------------------------------------------
  // CALCULATE STANDARD DEVIATION
  // ------------------------------------------------------------
  double _calculateStdDev(List<num> values) {
    if (values.isEmpty) return 0;
    final mean = _calculateMean(values);
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }
  
  // ------------------------------------------------------------
  // CALCULATE PEARSON CORRELATION
  // ------------------------------------------------------------
  double? _calculatePearsonCorrelation(List<num> x, List<num> y) {
    if (x.length != y.length || x.length < 2) return null;
    
    final n = x.length;
    final meanX = _calculateMean(x);
    final meanY = _calculateMean(y);
    
    double numerator = 0;
    double denomX = 0;
    double denomY = 0;
    
    for (int i = 0; i < n; i++) {
      final diffX = x[i] - meanX;
      final diffY = y[i] - meanY;
      numerator += diffX * diffY;
      denomX += diffX * diffX;
      denomY += diffY * diffY;
    }
    
    final denom = math.sqrt(denomX * denomY);
    if (denom == 0) return null;
    
    return numerator / denom;
  }
  
  // ------------------------------------------------------------
  // CALCULATE LINEAR REGRESSION SLOPE
  // ------------------------------------------------------------
  double _calculateLinearRegressionSlope(List<Map<String, dynamic>> points) {
    if (points.length < 2) return 0;
    
    final n = points.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    
    for (var point in points) {
      final x = point['x'] as double;
      final y = point['y'] as double;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    return slope;
  }
  
  // ------------------------------------------------------------
  // DETERMINE TREND DIRECTION
  // ------------------------------------------------------------
  String _determineTrendDirection(double slope) {
    if (slope > 0.1) return 'increasing';
    if (slope < -0.1) return 'decreasing';
    return 'stable';
  }
  
  // ------------------------------------------------------------
  // GET CORRELATION STRENGTH
  // ------------------------------------------------------------
  String _getCorrelationStrength(double corr) {
    final abs = corr.abs();
    if (abs >= 0.7) return 'strong';
    if (abs >= 0.4) return 'moderate';
    return 'weak';
  }
  
  // ------------------------------------------------------------
  // CALCULATE NUMERIC FREQUENCIES (FOR HISTOGRAM)
  // ------------------------------------------------------------
  Map<String, int> _calculateNumericFrequencies(List<num> values) {
    if (values.isEmpty) return {};
    
    final sorted = List<num>.from(values)..sort();
    final min = sorted.first;
    final max = sorted.last;
    final range = max - min;
    
    // Create 10 bins
    final binSize = range / 10;
    Map<String, int> frequencies = {};
    
    for (var value in values) {
      final binIndex = ((value - min) / binSize).floor().clamp(0, 9);
      final binLabel = '${(min + binIndex * binSize).toStringAsFixed(1)}-${(min + (binIndex + 1) * binSize).toStringAsFixed(1)}';
      frequencies[binLabel] = (frequencies[binLabel] ?? 0) + 1;
    }
    
    return frequencies;
  }
  
  // ------------------------------------------------------------
  // CALCULATE CATEGORICAL FREQUENCIES
  // ------------------------------------------------------------
  Map<String, int> _calculateCategoricalFrequencies(List<dynamic> values) {
    Map<String, int> frequencies = {};
    
    for (var value in values) {
      final key = value.toString();
      frequencies[key] = (frequencies[key] ?? 0) + 1;
    }
    
    return frequencies;
  }
  
  // ------------------------------------------------------------
  // DETECT DATA TYPE
  // ------------------------------------------------------------
  String _detectDataType(List<dynamic> values) {
    if (values.isEmpty) return 'unknown';
    
    final sample = values.first;
    if (sample is num || num.tryParse(sample.toString()) != null) {
      return 'numeric';
    }
    
    return 'categorical';
  }
  
  @override
  void dispose() {
    stopBackgroundAnalysis();
    super.dispose();
  }
}