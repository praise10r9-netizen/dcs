// lib/controllers/form_builder_controller.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Models and Controller live here (single file for clarity).

/// Field rules stored as JSON in DB
class FieldRules {
  bool required;
  int? min;
  int? max;
  String? placeholder;
  List<String>? options; // for radios/checkboxes/dropdowns

  FieldRules({
    this.required = false,
    this.min,
    this.max,
    this.placeholder,
    this.options,
  });

  Map<String, dynamic> toJson() => {
        'required': required,
        'min': min,
        'max': max,
        'placeholder': placeholder,
        'options': options,
      };

  factory FieldRules.fromJson(Map<String, dynamic>? json) {
    if (json == null) return FieldRules();
    return FieldRules(
      required: json['required'] ?? false,
      min: json['min'],
      max: json['max'],
      placeholder: json['placeholder'],
      options: (json['options'] is List) ? List<String>.from(json['options']) : null,
    );
  }
}

/// A single field in a form
class FormFieldModel {
  int? fieldId; // DB id if saved
  String fieldType; // "text", "email", "number", "radio", "checkbox"
  String label;
  FieldRules rules;

  FormFieldModel({
    this.fieldId,
    required this.fieldType,
    required this.label,
    FieldRules? rules,
  }) : rules = rules ?? FieldRules();

  Map<String, dynamic> toJsonForDb(int formId) {
    return {
      'form_id': formId,
      'field_type': fieldType,
      'field_description': label,
      'field_rules': jsonEncode(rules.toJson()), // store JSON as text/json
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'field_id': fieldId,
      'field_type': fieldType,
      'field_description': label,
      'field_rules': rules.toJson(),
    };
  }

  factory FormFieldModel.fromDb(Map<String, dynamic> row) {
    final rulesRaw = row['field_rules'];
    Map<String, dynamic>? parsed;
    if (rulesRaw is String) {
      try {
        parsed = jsonDecode(rulesRaw) as Map<String, dynamic>?;
      } catch (_) {
        parsed = null;
      }
    } else if (rulesRaw is Map) {
      parsed = Map<String, dynamic>.from(rulesRaw);
    }
    return FormFieldModel(
      fieldId: row['field_id'],
      fieldType: row['field_type'],
      label: row['field_description'] ?? '',
      rules: FieldRules.fromJson(parsed),
    );
  }
}

/// Form metadata
class CustomFormModel {
  int? formId;
  String formName;
  String subject;
  String description;
  String creatorId; // uuid of supervisor

  CustomFormModel({
    this.formId,
    required this.formName,
    required this.subject,
    required this.description,
    required this.creatorId,
  });

  Map<String, dynamic> toJsonForDb() => {
        'form_name': formName,
        'subject': subject,
        'description': description,
        'created_by': creatorId,
      };

  factory CustomFormModel.fromDb(Map<String, dynamic> row) {
    return CustomFormModel(
      formId: row['form_id'],
      formName: row['form_name'] ?? '',
      subject: row['subject'] ?? '',
      description: row['description'] ?? '',
      creatorId: row['created_by']?.toString() ?? '',
    );
  }
}

/// Controller for the Form Builder
class FormBuilderController extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  // Current form metadata
  CustomFormModel? form;

  // Fields placed on canvas (order matters)
  final List<FormFieldModel> fields = [];

  bool saving = false;

  // Initialize a new blank form with creator id
  void createNewForm({required String creatorId, String name = 'Untitled Form'}) {
    form = CustomFormModel(
      formName: name,
      subject: '',
      description: '',
      creatorId: creatorId,
    );
    fields.clear();
    notifyListeners();
  }

  // Load existing form + fields for editing
  Future<void> loadExistingForm(int formId) async {
    // fetch form
    final f = await supabase.from('custom_form').select().eq('form_id', formId).maybeSingle();
    if (f == null) throw Exception('Form not found');

    form = CustomFormModel.fromDb(Map<String, dynamic>.from(f as Map));
    // fetch fields
    final ff = await supabase.from('form_fields').select().eq('form_id', formId).order('field_id');
    fields.clear();
    for (final r in ff) {
      fields.add(FormFieldModel.fromDb(Map<String, dynamic>.from(r as Map)));
    }
      notifyListeners();
  }

  // update metadata
  void updateFormName(String v) {
    if (form == null) return;
    form!.formName = v;
    notifyListeners();
  }

  void updateSubject(String v) {
    if (form == null) return;
    form!.subject = v;
    notifyListeners();
  }

  void updateDescription(String v) {
    if (form == null) return;
    form!.description = v;
    notifyListeners();
  }

  // Field CRUD (canvas operations)
  void addField(FormFieldModel f) {
    fields.add(f);
    notifyListeners();
  }

  void updateField(int index, FormFieldModel f) {
    if (index < 0 || index >= fields.length) return;
    fields[index] = f;
    notifyListeners();
  }

  void removeField(int index) {
    if (index < 0 || index >= fields.length) return;
    fields.removeAt(index);
    notifyListeners();
  }

  void moveField(int from, int to) {
    if (from == to) return;
    if (from < 0 || from >= fields.length) return;
    if (to < 0 || to >= fields.length) return;
    final item = fields.removeAt(from);
    fields.insert(to, item);
    notifyListeners();
  }

  /// Save the form and its fields to DB. If form.formId is null -> create; else update.
  Future<int> saveFormToDb() async {
    if (form == null) throw Exception('No form initialized');
    saving = true;
    notifyListeners();

    try {
      int formId;
      if (form!.formId == null) {
        // insert
        final inserted = await supabase
            .from('custom_form')
            .insert(form!.toJsonForDb())
            .select()
            .single();
        formId = inserted['form_id'] as int;
        form!.formId = formId;
      } else {
        formId = form!.formId!;
        await supabase.from('custom_form').update(form!.toJsonForDb()).eq('form_id', formId);
      }

      // Save fields: simple approach -> upsert by deleting existing (for simplicity) then inserting.
      // Option A: delete existing fields for this form then re-insert current fields (keeps logic simple)
      await supabase.from('form_fields').delete().eq('form_id', formId);

      for (final f in fields) {
        await supabase.from('form_fields').insert({
          'form_id': formId,
          'field_type': f.fieldType,
          'field_description': f.label,
          'field_rules': f.rules.toJson(), // Supabase supports json column
        });
      }

      return formId;
    } catch (e) {
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

   Future<List<Map<String, dynamic>>> fetchTeams() async {
    try {
      final res = await supabase.from('team').select('id, team_name, resources');
       return List<Map<String, dynamic>>.from(res);
      
    } catch (e) {
      debugPrint('fetchTeams error: $e');
      return [];
    }
  }

  Future<void> shareFormToTeam(int teamId) async {
    if (form == null || form!.formId == null) throw Exception('Form must be saved before sharing');

    try {
      // Fetch current resources
      final teamRow = await supabase.from('team').select('resources').eq('id', teamId).maybeSingle();
      List<dynamic> resources = [];
      if (teamRow != null && teamRow['resources'] != null) {
        if (teamRow['resources'] is String) {
          resources = jsonDecode(teamRow['resources']);
        } else if (teamRow['resources'] is List) {
          resources = List.from(teamRow['resources']);
        }
      }

      // Avoid duplicates
      if (!resources.contains(form!.formId)) {
        resources.add(form!.formId);
      }

      await supabase.from('team').update({'resources': resources}).eq('id', teamId);
    } catch (e) {
      debugPrint('shareFormToTeam error: $e');
      rethrow;
    }
  }
}
