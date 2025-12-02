// lib/controllers/form_response_controller.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/form_builder_controller.dart';

class FormResponseController extends ChangeNotifier {
  final SupabaseClient db = Supabase.instance.client;

  // Form metadata
  CustomFormModel? form;
  List<FormFieldModel> fields = [];

  // Response data: key = field_description, value = user input
  Map<String, dynamic> responseData = {};

  // State
  bool loading = false;
  bool submitting = false;

  // Validation errors
  Map<String, String> validationErrors = {};

  // ------------------------------------------------------------
  // LOAD FORM AND FIELDS
  // ------------------------------------------------------------
  Future<void> loadForm(int formId) async {
    loading = true;
    notifyListeners();

    try {
      // Fetch form metadata
      final formRow = await db
          .from('custom_form')
          .select()
          .eq('form_id', formId)
          .maybeSingle();

      if (formRow == null) {
        throw Exception('Form not found');
      }

      form = CustomFormModel.fromDb(Map<String, dynamic>.from(formRow));

      // Fetch form fields
      final fieldsRes = await db
          .from('form_fields')
          .select()
          .eq('form_id', formId)
          .order('field_id');

      fields.clear();
      responseData.clear();
      validationErrors.clear();

      if (fieldsRes is List) {
        for (final row in fieldsRes) {
          final field = FormFieldModel.fromDb(Map<String, dynamic>.from(row as Map));
          fields.add(field);
          
          // Initialize response data based on field type
          if (field.fieldType == 'checkbox') {
            responseData[field.label] = <String>[]; // Multiple values
          } else {
            responseData[field.label] = null;
          }
        }
      }
    } catch (e) {
      debugPrint('loadForm error: $e');
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // UPDATE RESPONSE DATA
  // ------------------------------------------------------------
  void updateResponse(String fieldLabel, dynamic value) {
    responseData[fieldLabel] = value;
    
    // Clear validation error for this field
    validationErrors.remove(fieldLabel);
    notifyListeners();
  }

  // ------------------------------------------------------------
  // UPDATE CHECKBOX (multiple selection)
  // ------------------------------------------------------------
  void updateCheckbox(String fieldLabel, String option, bool isChecked) {
    List<String> currentValues = List<String>.from(responseData[fieldLabel] ?? []);
    
    if (isChecked) {
      if (!currentValues.contains(option)) {
        currentValues.add(option);
      }
    } else {
      currentValues.remove(option);
    }
    
    responseData[fieldLabel] = currentValues;
    validationErrors.remove(fieldLabel);
    notifyListeners();
  }

  // ------------------------------------------------------------
  // VALIDATE FORM
  // ------------------------------------------------------------
  bool validateForm() {
    validationErrors.clear();
    bool isValid = true;

    for (final field in fields) {
      final value = responseData[field.label];
      final rules = field.rules;

      // Check required fields
      if (rules.required) {
        if (value == null || 
            (value is String && value.trim().isEmpty) ||
            (value is List && value.isEmpty)) {
          validationErrors[field.label] = 'This field is required';
          isValid = false;
          continue;
        }
      }

      // Skip further validation if field is empty and not required
      if (value == null || (value is String && value.trim().isEmpty)) {
        continue;
      }

      // Validate based on field type
      switch (field.fieldType) {
        case 'email':
          if (value is String && !_isValidEmail(value)) {
            validationErrors[field.label] = 'Invalid email address';
            isValid = false;
          }
          break;

        case 'number':
          if (value is String) {
            final num? numValue = num.tryParse(value);
            if (numValue == null) {
              validationErrors[field.label] = 'Invalid number';
              isValid = false;
            } else {
              // Check min/max
              if (rules.min != null && numValue < rules.min!) {
                validationErrors[field.label] = 'Minimum value is ${rules.min}';
                isValid = false;
              }
              if (rules.max != null && numValue > rules.max!) {
                validationErrors[field.label] = 'Maximum value is ${rules.max}';
                isValid = false;
              }
            }
          }
          break;

        case 'text':
          if (value is String) {
            // Check min/max length
            if (rules.min != null && value.length < rules.min!) {
              validationErrors[field.label] = 'Minimum length is ${rules.min} characters';
              isValid = false;
            }
            if (rules.max != null && value.length > rules.max!) {
              validationErrors[field.label] = 'Maximum length is ${rules.max} characters';
              isValid = false;
            }
          }
          break;
      }
    }

    notifyListeners();
    return isValid;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // ------------------------------------------------------------
  // SUBMIT RESPONSE
  // ------------------------------------------------------------
  Future<int> submitResponse() async {
    if (form == null) {
      throw Exception('Form not loaded');
    }

    if (!validateForm()) {
      throw Exception('Please fix validation errors');
    }

    submitting = true;
    notifyListeners();

    try {
      // Prepare response data (only include non-empty values)
      final cleanedData = <String, dynamic>{};
      responseData.forEach((key, value) {
        if (value != null) {
          if (value is String && value.trim().isNotEmpty) {
            cleanedData[key] = value.trim();
          } else if (value is List && value.isNotEmpty) {
            cleanedData[key] = value;
          } else if (value is! String && value is! List) {
            cleanedData[key] = value;
          }
        }
      });

      // Insert into data_sets table
      final inserted = await db.from('data_sets').insert({
        'form_id': form!.formId,
        'response_data': cleanedData,
      }).select().single();

      final responseId = inserted['response_id'] as int;

      // Clear form after successful submission
      responseData.clear();
      validationErrors.clear();

      return responseId;
    } catch (e) {
      debugPrint('submitResponse error: $e');
      rethrow;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // SAVE AS DRAFT (optional feature)
  // ------------------------------------------------------------
  Map<String, dynamic> getDraftData() {
    return {
      'form_id': form?.formId,
      'response_data': responseData,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  void loadDraftData(Map<String, dynamic> draftData) {
    if (draftData['response_data'] is Map) {
      responseData = Map<String, dynamic>.from(draftData['response_data']);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // RESET FORM
  // ------------------------------------------------------------
  void resetForm() {
    for (final field in fields) {
      if (field.fieldType == 'checkbox') {
        responseData[field.label] = <String>[];
      } else {
        responseData[field.label] = null;
      }
    }
    validationErrors.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // GET PROGRESS
  // ------------------------------------------------------------
  double getProgress() {
    if (fields.isEmpty) return 0.0;
    
    int filledFields = 0;
    for (final field in fields) {
      final value = responseData[field.label];
      if (value != null) {
        if (value is String && value.trim().isNotEmpty) {
          filledFields++;
        } else if (value is List && value.isNotEmpty) {
          filledFields++;
        } else if (value is! String && value is! List) {
          filledFields++;
        }
      }
    }
    
    return filledFields / fields.length;
  }

  // ------------------------------------------------------------
  // GET FIELD VALUE
  // ------------------------------------------------------------
  dynamic getFieldValue(String fieldLabel) {
    return responseData[fieldLabel];
  }

  // ------------------------------------------------------------
  // CHECK IF FIELD HAS ERROR
  // ------------------------------------------------------------
  String? getFieldError(String fieldLabel) {
    return validationErrors[fieldLabel];
  }
}