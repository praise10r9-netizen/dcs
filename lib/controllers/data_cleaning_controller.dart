// lib/controllers/data_cleaning_controller.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CleaningStatus { pending, in_progress, completed, failed }

class DataQualityIssue {
  final String fieldName;
  final String issueType; // 'missing', 'outlier', 'invalid', 'duplicate'
  final dynamic originalValue;
  final dynamic suggestedValue;
  final String severity; // 'low', 'medium', 'high'
  
  DataQualityIssue({
    required this.fieldName,
    required this.issueType,
    required this.originalValue,
    this.suggestedValue,
    required this.severity,
  });
}

class CleaningRule {
  final String id;
  final String fieldName;
  final String ruleType; // 'fill_missing', 'remove_outlier', 'standardize', 'validate'
  final Map<String, dynamic> parameters;
  final bool autoApply;
  
  CleaningRule({
    required this.id,
    required this.fieldName,
    required this.ruleType,
    required this.parameters,
    this.autoApply = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'field_name': fieldName,
    'rule_type': ruleType,
    'parameters': parameters,
    'auto_apply': autoApply,
  };
  
  factory CleaningRule.fromJson(Map<String, dynamic> json) {
    return CleaningRule(
      id: json['id'] ?? '',
      fieldName: json['field_name'] ?? '',
      ruleType: json['rule_type'] ?? '',
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      autoApply: json['auto_apply'] ?? false,
    );
  }
}

class DataCleaningController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;
  
  // State
  bool loading = false;
  bool analyzing = false;
  bool cleaning = false;
  
  List<Map<String, dynamic>> rawResponses = [];
  List<Map<String, dynamic>> cleanedResponses = [];
  List<DataQualityIssue> detectedIssues = [];
  List<CleaningRule> activeRules = [];
  
  Map<String, dynamic> qualityMetrics = {};
  Map<String, dynamic> fieldStatistics = {};
  
  int? selectedFormId;
  
  // ------------------------------------------------------------
  // GET CURRENT USER ROLE
  // ------------------------------------------------------------
  Future<String?> getUserRole() async {
    try {
      final user = db.auth.currentUser;
      if (user == null) return null;
      
      final result = await db
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      
      return result['role'];
    } catch (e) {
      debugPrint('getUserRole error: $e');
      return null;
    }
  }
  
  // ------------------------------------------------------------
  // FETCH FORMS FOR CLEANING (Supervisor only)
  // ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchFormsForCleaning() async {
    try {
      final user = db.auth.currentUser;
      if (user == null) return [];
      
      final forms = await db
          .from('custom_form')
          .select('form_id, form_name, subject, created_at')
          .eq('created_by', user.id)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(forms);
    } catch (e) {
      debugPrint('fetchFormsForCleaning error: $e');
      return [];
    }
  }
  
  // ------------------------------------------------------------
  // LOAD RESPONSES FOR CLEANING
  // ------------------------------------------------------------
  Future<void> loadResponsesForCleaning(int formId) async {
    loading = true;
    selectedFormId = formId;
    notifyListeners();
    
    try {
      final responses = await db
          .from('data_sets')
          .select()
          .eq('form_id', formId)
          .order('created_at', ascending: false);
      
      rawResponses = List<Map<String, dynamic>>.from(responses);
      cleanedResponses = List<Map<String, dynamic>>.from(responses);
      
      // Analyze data quality
      await analyzeDataQuality();
    } catch (e) {
      debugPrint('loadResponsesForCleaning error: $e');
    }
    
    loading = false;
    notifyListeners();
  }
  
  // ------------------------------------------------------------
  // ANALYZE DATA QUALITY
  // ------------------------------------------------------------
  Future<void> analyzeDataQuality() async {
    analyzing = true;
    detectedIssues.clear();
    notifyListeners();
    
    try {
      // Collect all field names
      Set<String> allFields = {};
      for (var response in rawResponses) {
        final data = response['response_data'] as Map<String, dynamic>?;
        if (data != null) {
          allFields.addAll(data.keys);
        }
      }
      
      // Analyze each field
      for (var fieldName in allFields) {
        await _analyzeField(fieldName);
      }
      
      // Calculate overall quality metrics
      _calculateQualityMetrics();
    } catch (e) {
      debugPrint('analyzeDataQuality error: $e');
    }
    
    analyzing = false;
    notifyListeners();
  }
  
  // ------------------------------------------------------------
  // ANALYZE INDIVIDUAL FIELD
  // ------------------------------------------------------------
  Future<void> _analyzeField(String fieldName) async {
    List<dynamic> values = [];
    int missingCount = 0;
    int totalCount = rawResponses.length;
    
    // Collect values
    for (var response in rawResponses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data == null || !data.containsKey(fieldName) || data[fieldName] == null) {
        missingCount++;
      } else {
        values.add(data[fieldName]);
      }
    }
    
    // Check for missing values
    if (missingCount > 0) {
      final severity = missingCount / totalCount > 0.3 ? 'high' : 
                      missingCount / totalCount > 0.1 ? 'medium' : 'low';
      
      detectedIssues.add(DataQualityIssue(
        fieldName: fieldName,
        issueType: 'missing',
        originalValue: null,
        suggestedValue: _getSuggestedFillValue(values),
        severity: severity,
      ));
    }
    
    // Check for outliers (numeric fields)
    if (values.isNotEmpty && values.first is num) {
      final outliers = _detectOutliers(values.cast<num>());
      for (var outlier in outliers) {
        detectedIssues.add(DataQualityIssue(
          fieldName: fieldName,
          issueType: 'outlier',
          originalValue: outlier,
          suggestedValue: _getMedian(values.cast<num>()),
          severity: 'medium',
        ));
      }
    }
    
    // Store field statistics
    fieldStatistics[fieldName] = {
      'total': totalCount,
      'missing': missingCount,
      'missing_percentage': (missingCount / totalCount * 100).toStringAsFixed(1),
      'unique_values': values.toSet().length,
      'data_type': _detectDataType(values),
    };
  }
  
  // ------------------------------------------------------------
  // DETECT OUTLIERS USING IQR METHOD
  // ------------------------------------------------------------
  List<num> _detectOutliers(List<num> values) {
    if (values.length < 4) return [];
    
    values.sort();
    final q1Index = (values.length * 0.25).floor();
    final q3Index = (values.length * 0.75).floor();
    
    final q1 = values[q1Index];
    final q3 = values[q3Index];
    final iqr = q3 - q1;
    
    final lowerBound = q1 - 1.5 * iqr;
    final upperBound = q3 + 1.5 * iqr;
    
    return values.where((v) => v < lowerBound || v > upperBound).toList();
  }
  
  // ------------------------------------------------------------
  // GET MEDIAN
  // ------------------------------------------------------------
  num _getMedian(List<num> values) {
    if (values.isEmpty) return 0;
    values.sort();
    final middle = values.length ~/ 2;
    if (values.length % 2 == 0) {
      return (values[middle - 1] + values[middle]) / 2;
    }
    return values[middle];
  }
  
  // ------------------------------------------------------------
  // GET SUGGESTED FILL VALUE
  // ------------------------------------------------------------
  dynamic _getSuggestedFillValue(List<dynamic> values) {
    if (values.isEmpty) return null;
    
    if (values.first is num) {
      return _getMedian(values.cast<num>());
    } else if (values.first is String) {
      // Return most frequent value
      final frequency = <String, int>{};
      for (var v in values) {
        frequency[v.toString()] = (frequency[v.toString()] ?? 0) + 1;
      }
      return frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }
    
    return null;
  }
  
  // ------------------------------------------------------------
  // DETECT DATA TYPE
  // ------------------------------------------------------------
  String _detectDataType(List<dynamic> values) {
    if (values.isEmpty) return 'unknown';
    
    if (values.first is num) return 'numeric';
    if (values.first is bool) return 'boolean';
    if (values.first is List) return 'array';
    
    // Check if string values are dates
    if (values.first is String) {
      try {
        DateTime.parse(values.first);
        return 'date';
      } catch (e) {
        return 'text';
      }
    }
    
    return 'text';
  }
  
  // ------------------------------------------------------------
  // CALCULATE QUALITY METRICS
  // ------------------------------------------------------------
  void _calculateQualityMetrics() {
    int totalIssues = detectedIssues.length;
    int highSeverity = detectedIssues.where((i) => i.severity == 'high').length;
    int mediumSeverity = detectedIssues.where((i) => i.severity == 'medium').length;
    int lowSeverity = detectedIssues.where((i) => i.severity == 'low').length;
    
    double completeness = 0.0;
    if (fieldStatistics.isNotEmpty) {
      double totalCompleteness = 0.0;
      fieldStatistics.forEach((field, stats) {
        num fieldCompleteness = 1 - (stats['missing'] / stats['total']);
        totalCompleteness += fieldCompleteness;
      });
      completeness = totalCompleteness / fieldStatistics.length;
    }
    
    qualityMetrics = {
      'total_issues': totalIssues,
      'high_severity': highSeverity,
      'medium_severity': mediumSeverity,
      'low_severity': lowSeverity,
      'completeness_score': (completeness * 100).toStringAsFixed(1),
      'quality_score': _calculateOverallQuality(completeness, totalIssues),
      'total_records': rawResponses.length,
    };
  }
  
  // ------------------------------------------------------------
  // CALCULATE OVERALL QUALITY SCORE
  // ------------------------------------------------------------
  String _calculateOverallQuality(double completeness, int issues) {
    double score = completeness * 100;
    
    // Deduct points for issues
    score -= (issues * 2);
    
    if (score < 0) score = 0;
    if (score > 100) score = 100;
    
    return score.toStringAsFixed(1);
  }
  
  // ------------------------------------------------------------
  // CREATE CLEANING RULE
  // ------------------------------------------------------------
  Future<void> createCleaningRule(CleaningRule rule) async {
    try {
      final user = db.auth.currentUser;
      if (user == null) return;
      
      await db.from('cleaning_rules').insert({
        'form_id': selectedFormId,
        'created_by': user.id,
        'field_name': rule.fieldName,
        'rule_type': rule.ruleType,
        'parameters': rule.parameters,
        'auto_apply': rule.autoApply,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      activeRules.add(rule);
      notifyListeners();
    } catch (e) {
      debugPrint('createCleaningRule error: $e');
      rethrow;
    }
  }
  
  // ------------------------------------------------------------
  // APPLY CLEANING RULES
  // ------------------------------------------------------------
  Future<void> applyCleaningRules() async {
    cleaning = true;
    notifyListeners();
    
    try {
      cleanedResponses = List<Map<String, dynamic>>.from(rawResponses);
      
      for (var rule in activeRules) {
        switch (rule.ruleType) {
          case 'fill_missing':
            _applyFillMissing(rule);
            break;
          case 'remove_outlier':
            _applyRemoveOutlier(rule);
            break;
          case 'standardize':
            _applyStandardize(rule);
            break;
          case 'validate':
            _applyValidate(rule);
            break;
        }
      }
      
      // Save cleaned data
      await _saveCleanedData();
    } catch (e) {
      debugPrint('applyCleaningRules error: $e');
    }
    
    cleaning = false;
    notifyListeners();
  }
  
  // ------------------------------------------------------------
  // APPLY FILL MISSING RULE
  // ------------------------------------------------------------
  void _applyFillMissing(CleaningRule rule) {
    final fillValue = rule.parameters['fill_value'];
    
    for (var response in cleanedResponses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null) {
        if (!data.containsKey(rule.fieldName) || data[rule.fieldName] == null) {
          data[rule.fieldName] = fillValue;
        }
      }
    }
  }
  
  // ------------------------------------------------------------
  // APPLY REMOVE OUTLIER RULE
  // ------------------------------------------------------------
  void _applyRemoveOutlier(CleaningRule rule) {
    final replaceValue = rule.parameters['replace_value'];
    final threshold = rule.parameters['threshold'] ?? 1.5;
    
    // Collect numeric values
    List<num> values = [];
    for (var response in cleanedResponses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null && data[rule.fieldName] is num) {
        values.add(data[rule.fieldName]);
      }
    }
    
    final outliers = _detectOutliers(values);
    
    // Replace outliers
    for (var response in cleanedResponses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null && outliers.contains(data[rule.fieldName])) {
        data[rule.fieldName] = replaceValue;
      }
    }
  }
  
  // ------------------------------------------------------------
  // APPLY STANDARDIZE RULE
  // ------------------------------------------------------------
  void _applyStandardize(CleaningRule rule) {
    final format = rule.parameters['format'];
    
    for (var response in cleanedResponses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null && data[rule.fieldName] != null) {
        // Apply standardization based on format
        if (format == 'lowercase') {
          data[rule.fieldName] = data[rule.fieldName].toString().toLowerCase();
        } else if (format == 'uppercase') {
          data[rule.fieldName] = data[rule.fieldName].toString().toUpperCase();
        } else if (format == 'trim') {
          data[rule.fieldName] = data[rule.fieldName].toString().trim();
        }
      }
    }
  }
  
  // ------------------------------------------------------------
  // APPLY VALIDATE RULE
  // ------------------------------------------------------------
  void _applyValidate(CleaningRule rule) {
    // Mark invalid records for review
    final validationType = rule.parameters['validation_type'];
    
    for (var response in cleanedResponses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null) {
        bool isValid = true;
        
        if (validationType == 'email') {
          isValid = _isValidEmail(data[rule.fieldName]?.toString() ?? '');
        } else if (validationType == 'number') {
          isValid = num.tryParse(data[rule.fieldName]?.toString() ?? '') != null;
        }
        
        if (!isValid) {
          response['validation_flag'] = '${rule.fieldName}_invalid';
        }
      }
    }
  }
  
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }
  
  // ------------------------------------------------------------
  // SAVE CLEANED DATA
  // ------------------------------------------------------------
  Future<void> _saveCleanedData() async {
    try {
      // Create cleaned dataset record
      final cleaned = await db.from('cleaned_datasets').insert({
        'form_id': selectedFormId,
        'original_count': rawResponses.length,
        'cleaned_count': cleanedResponses.length,
        'quality_score': qualityMetrics['quality_score'],
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      final cleanedId = cleaned['id'];
      
      // Save cleaned responses
      for (var response in cleanedResponses) {
        await db.from('cleaned_responses').insert({
          'cleaned_dataset_id': cleanedId,
          'original_response_id': response['response_id'],
          'cleaned_data': response['response_data'],
        });
      }
    } catch (e) {
      debugPrint('_saveCleanedData error: $e');
      rethrow;
    }
  }
  
  // ------------------------------------------------------------
  // EXPORT CLEANED DATA (CSV format)
  // ------------------------------------------------------------
  String exportCleanedDataAsCSV() {
    if (cleanedResponses.isEmpty) return '';
    
    Set<String> allFields = {};
    for (var response in cleanedResponses) {
      final data = response['response_data'] as Map<String, dynamic>?;
      if (data != null) {
        allFields.addAll(data.keys);
      }
    }
    
    final header = ['Response ID', ...allFields].join(',');
    
    final rows = cleanedResponses.map((response) {
      final data = response['response_data'] as Map<String, dynamic>?;
      final values = [
        response['response_id'].toString(),
        ...allFields.map((field) {
          final value = data?[field];
          if (value is List) {
            return '"${value.join(', ')}"';
          }
          return '"${value ?? ''}"';
        }),
      ];
      return values.join(',');
    }).join('\n');
    
    return '$header\n$rows';
  }
  
  // ------------------------------------------------------------
  // GET ISSUES BY SEVERITY
  // ------------------------------------------------------------
  List<DataQualityIssue> getIssuesBySeverity(String severity) {
    return detectedIssues.where((i) => i.severity == severity).toList();
  }
  
  // ------------------------------------------------------------
  // GET ISSUES BY TYPE
  // ------------------------------------------------------------
  List<DataQualityIssue> getIssuesByType(String type) {
    return detectedIssues.where((i) => i.issueType == type).toList();
  }
}