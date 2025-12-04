// lib/screens/form_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/form_builder_controller.dart';

class FormBuilderScreen extends StatefulWidget {
  const FormBuilderScreen({super.key});

  /// Optionally pass an existing formId to edit
  final int? editFormId = null;

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  late FormBuilderController ctrl;

  // simple controllers for form meta
  final _nameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl = FormBuilderController();

    // Example: create new form using current logged-in user id
    final user = Supabase.instance.client.auth.currentUser;
    final creatorId = user?.id ?? 'unknown';
    ctrl.createNewForm(creatorId: creatorId, name: 'New Form');

    _nameCtrl.text = ctrl.form?.formName ?? '';
    _subjectCtrl.text = ctrl.form?.subject ?? '';
    _descCtrl.text = ctrl.form?.description ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // Common field types for left toolbar
  static const List<Map<String, String>> commonFields = [
    {'type': 'text', 'label': 'Text'},
    {'type': 'email', 'label': 'Email'},
    {'type': 'number', 'label': 'Number'},
    {'type': 'radio', 'label': 'Radio'},
    {'type': 'checkbox', 'label': 'Checkbox'},
  ];

  // Additional fields in More dialog
  static const List<Map<String, String>> moreFields = [
    {'type': 'date', 'label': 'Date'},
    {'type': 'time', 'label': 'Time'},
    {'type': 'photo', 'label': 'Photo'},
    {'type': 'signature', 'label': 'Signature'},
    {'type': 'dropdown', 'label': 'Dropdown'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ctrl.form?.formName ?? 'Form Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye),
            tooltip: 'Preview',
            onPressed: () => _openPreview(),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save to DB',
            onPressed: () async => _saveForm(),
          ),
        IconButton(
  icon: const Icon(Icons.share),
  tooltip: 'Share',
  onPressed: () async {
    // Save the form first if not saved
    if (ctrl.form?.formId == null) {
      final id = await ctrl.saveFormToDb();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Form saved (ID: $id)')));
    }

    // Fetch available teams
    final teams = await ctrl.fetchTeams();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: 400,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Share Form With Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: teams.length,
                    itemBuilder: (ctx, i) {
                      final team = teams[i];
                      return ListTile(
                        title: Text(team['team_name'] ?? 'Team ${team['id']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: () async {
                            await ctrl.shareFormToTeam(team['id']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Form shared with ${team['team_name']}')),
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
),
 
        ],
      ),
      body: Row(
        children: [
          // LEFT SIDEBAR
          Container(
            width: 72,
            color: Colors.grey.shade200,
            child: Column(
              children: [
                const SizedBox(height: 12),
                for (final f in commonFields)
                  IconButton(
                    tooltip: f['label'],
                    icon: Icon(_iconForType(f['type']!)),
                    onPressed: () {
                      _addFieldFromType(f['type']!, defaultLabel: f['label']!);
                    },
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  tooltip: 'More',
                  onPressed: _openMoreDialog,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // CANVAS
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Form metadata editor
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Form name'),
                            onChanged: (v) => ctrl.updateFormName(v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _subjectCtrl,
                            decoration: const InputDecoration(labelText: 'Subject'),
                            onChanged: (v) => ctrl.updateSubject(v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _descCtrl,
                            decoration: const InputDecoration(labelText: 'Description'),
                            onChanged: (v) => ctrl.updateDescription(v),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Canvas area
                  Expanded(
                    child: AnimatedBuilder(
                      animation: ctrl,
                      builder: (context, _) {
                        if (ctrl.fields.isEmpty) {
                          return Center(child: Text('No fields on canvas — choose from left toolbar or More.'));
                        }
                        return ReorderableListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: ctrl.fields.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              // ReorderableListView uses a different newIndex semantics
                              if (newIndex > oldIndex) newIndex -= 1;
                              ctrl.moveField(oldIndex, newIndex);
                            });
                          },
                          itemBuilder: (context, index) {
                            final field = ctrl.fields[index];
                            return Card(
                              key: ValueKey('field-$index-${field.fieldType}-${field.label}'),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(field.label),
                                subtitle: Text(field.fieldType),
                                leading: Icon(_iconForType(field.fieldType)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.settings),
                                  onPressed: () => _openFieldSettings(index),
                                ),
                                onTap: () => _openFieldSettings(index),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'email':
        return Icons.email;
      case 'number':
        return Icons.numbers;
      case 'radio':
        return Icons.radio_button_checked;
      case 'checkbox':
        return Icons.check_box;
      case 'date':
        return Icons.date_range;
      case 'time':
        return Icons.access_time;
      case 'photo':
        return Icons.photo_camera;
      case 'signature':
        return Icons.brush;
      case 'dropdown':
        return Icons.list;
      default:
        return Icons.help_outline;
    }
  }

  void _addFieldFromType(String type, {required String defaultLabel}) {
    final f = FormFieldModel(fieldType: type, label: defaultLabel, rules: FieldRules());
    setState(() => ctrl.addField(f));
  }

  // central modal for more fields
  void _openMoreDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('More fields', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in moreFields)
                        ElevatedButton.icon(
                          icon: Icon(_iconForType(f['type']!)),
                          label: Text(f['label']!),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _addFieldFromType(f['type']!, defaultLabel: f['label']!);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // bottom sheet for editing a field (slides up)
  void _openFieldSettings(int index) {
    final field = ctrl.fields[index];

    final labelCtrl = TextEditingController(text: field.label);
    final placeholderCtrl = TextEditingController(text: field.rules.placeholder ?? '');
    final minCtrl = TextEditingController(text: field.rules.min?.toString() ?? '');
    final maxCtrl = TextEditingController(text: field.rules.max?.toString() ?? '');
    bool requiredFlag = field.rules.required;
    List<TextEditingController> optionCtrls = (field.rules.options ?? []).map((o) => TextEditingController(text: o)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (ctx, setS) {
            void save() {
              final updated = FormFieldModel(
                fieldId: field.fieldId,
                fieldType: field.fieldType,
                label: labelCtrl.text.trim().isEmpty ? field.label : labelCtrl.text.trim(),
                rules: FieldRules(
                  required: requiredFlag,
                  min: int.tryParse(minCtrl.text),
                  max: int.tryParse(maxCtrl.text),
                  placeholder: placeholderCtrl.text.trim().isEmpty ? null : placeholderCtrl.text.trim(),
                  options: optionCtrls.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
                ),
              );
              ctrl.updateField(index, updated);
              Navigator.pop(ctx);
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('Edit ${field.fieldType}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              ctrl.removeField(index);
                            });
                            Navigator.pop(ctx);
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label')),
                    const SizedBox(height: 8),
                    if (field.fieldType == 'text' || field.fieldType == 'email')
                      TextField(controller: placeholderCtrl, decoration: const InputDecoration(labelText: 'Placeholder')),
                    if (field.fieldType == 'number') ...[
                      TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min (optional)'), keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: 'Max (optional)'), keyboardType: TextInputType.number),
                    ],
                    SwitchListTile(
                      title: const Text('Required'),
                      value: requiredFlag,
                      onChanged: (v) => setS(() => requiredFlag = v),
                    ),
                    const SizedBox(height: 8),
                    // Options for radio/checkbox/dropdown
                    if (field.fieldType == 'radio' || field.fieldType == 'checkbox' || field.fieldType == 'dropdown') ...[
                      const SizedBox(height: 8),
                      const Align(alignment: Alignment.centerLeft, child: Text('Options')),
                      const SizedBox(height: 8),
                      for (int i = 0; i < optionCtrls.length; i++)
                        Row(
                          children: [
                            Expanded(child: TextField(controller: optionCtrls[i], decoration: InputDecoration(labelText: 'Option ${i + 1}'))),
                            IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setS(() => optionCtrls.removeAt(i))),
                          ],
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add option'),
                        onPressed: () => setS(() => optionCtrls.add(TextEditingController())),
                      )
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: save, child: const Text('Save')),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Preview the current form (full-screen)
  void _openPreview() {
    final previewForm = ctrl.form ??
        CustomFormModel(formName: _nameCtrl.text, subject: _subjectCtrl.text, description: _descCtrl.text, creatorId: ctrl.form?.creatorId ?? '');
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => FormPreviewScreen(form: previewForm, fields: List<FormFieldModel>.from(ctrl.fields))));
  }

  // Save to Supabase
  Future<void> _saveForm() async {
    try {
      if (ctrl.form == null) {
        final user = Supabase.instance.client.auth.currentUser;
        final creatorId = user?.id ?? 'unknown';
        ctrl.createNewForm(creatorId: creatorId, name: _nameCtrl.text.isEmpty ? 'Untitled' : _nameCtrl.text);
      }
      ctrl.updateFormName(_nameCtrl.text);
      ctrl.updateSubject(_subjectCtrl.text);
      ctrl.updateDescription(_descCtrl.text);

      final id = await ctrl.saveFormToDb();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Form saved (ID: $id)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving form: $e')));
    }
  }
}

/// Preview Screen (simple renderer)
class FormPreviewScreen extends StatelessWidget {
  final CustomFormModel form;
  final List<FormFieldModel> fields;

  const FormPreviewScreen({super.key, required this.form, required this.fields});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview — ${form.formName}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(form.description),
          const SizedBox(height: 12),
          for (final f in fields) _buildPreviewField(f),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: () {}, child: const Text('Submit (preview only)')),
        ],
      ),
    );
  }

  Widget _buildPreviewField(FormFieldModel f) {
    switch (f.fieldType) {
      case 'text':
      case 'email':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            decoration: InputDecoration(labelText: f.label, hintText: f.rules.placeholder),
            keyboardType: f.fieldType == 'email' ? TextInputType.emailAddress : TextInputType.text,
          ),
        );

      case 'number':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            decoration: InputDecoration(labelText: f.label),
            keyboardType: TextInputType.number,
          ),
        );

      case 'radio':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...?f.rules.options?.map((o) => RadioListTile(value: o, groupValue: null, onChanged: (_) {}, title: Text(o))),
            ],
          ),
        );

      case 'checkbox':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...?f.rules.options?.map((o) => CheckboxListTile(value: false, onChanged: (_) {}, title: Text(o))),
            ],
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Unsupported preview for ${f.fieldType}'),
        );
    }
  }
}
