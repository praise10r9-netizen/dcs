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

    // Show form details modal immediately after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFormDetailsModal();
    });
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'preview') {
                _openPreview();
              } else if (value == 'share') {
                _shareForm();
              } else if (value == 'edit_details') {
                _showFormDetailsModal();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit_details',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Edit Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.remove_red_eye, size: 20),
                    SizedBox(width: 12),
                    Text('Preview'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Row(
        children: [
          // LEFT SIDEBAR
          Container(
            width: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                for (final f in commonFields)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: IconButton(
                      tooltip: f['label'],
                      icon: Icon(_iconForType(f['type']!), size: 24),
                      onPressed: () {
                        _addFieldFromType(f['type']!, defaultLabel: f['label']!);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color.fromARGB(255, 5, 38, 70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz, size: 24),
                    tooltip: 'More',
                    onPressed: _openMoreDialog,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // CANVAS
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (context, _) {
                  if (ctrl.fields.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dashboard_customize_outlined, 
                            size: 80, 
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No fields yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose from the left toolbar to add fields',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
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
                        key: ValueKey('field-${index}-${field.fieldType}-${field.label}'),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            field.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              field.fieldType.toUpperCase(),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _iconForType(field.fieldType),
                              color: const Color.fromARGB(255, 5, 38, 70),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.settings_outlined),
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
          ),
        ],
      ),
    );
  }

  // Form details modal that appears immediately
  void _showFormDetailsModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Form Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                //textfields for name, subject, description
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Form Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (v) {
                    ctrl.updateFormName(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (v) => ctrl.updateSubject(v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (v) => ctrl.updateDescription(v),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveForm();
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                  
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'More Fields',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final f in moreFields)
                      ElevatedButton.icon(
                        icon: Icon(_iconForType(f['type']!)),
                        label: Text(f['label']!),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Edit ${field.fieldType}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
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
                    const SizedBox(height: 20),
                    TextField(
                      controller: labelCtrl,
                      decoration: InputDecoration(
                        labelText: 'Label',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (field.fieldType == 'text' || field.fieldType == 'email')
                      TextField(
                        controller: placeholderCtrl,
                        decoration: InputDecoration(
                          labelText: 'Placeholder',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    if (field.fieldType == 'number') ...[
                      TextField(
                        controller: minCtrl,
                        decoration: InputDecoration(
                          labelText: 'Min (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: maxCtrl,
                        decoration: InputDecoration(
                          labelText: 'Max (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    SwitchListTile(
                      title: const Text('Required'),
                      value: requiredFlag,
                      onChanged: (v) => setS(() => requiredFlag = v),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Options for radio/checkbox/dropdown
                    if (field.fieldType == 'radio' || field.fieldType == 'checkbox' || field.fieldType == 'dropdown') ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Options',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (int i = 0; i < optionCtrls.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: optionCtrls[i],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${i + 1}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => setS(() => optionCtrls.removeAt(i)),
                              ),
                            ],
                          ),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add option'),
                        onPressed: () => setS(() => optionCtrls.add(TextEditingController())),
                      )
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
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
        CustomFormModel(
          formName: _nameCtrl.text,
          subject: _subjectCtrl.text,
          description: _descCtrl.text,
          creatorId: ctrl.form?.creatorId ?? '',
        );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FormPreviewScreen(
          form: previewForm,
          fields: List<FormFieldModel>.from(ctrl.fields),
        ),
      ),
    );
  }

  // Share form
  Future<void> _shareForm() async {
    // Save the form first if not saved
    if (ctrl.form?.formId == null) {
      final id = await ctrl.saveFormToDb();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form saved (ID: $id)')),
      );
    }

    // Fetch available teams
    final teams = await ctrl.fetchTeams();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: 400,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Share Form With Team',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: teams.length,
                    itemBuilder: (ctx, i) {
                      final team = teams[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            team['team_name'] ?? 'Team ${team['id']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.send, color: Colors.blue),
                            onPressed: () async {
                              await ctrl.shareFormToTeam(team['id']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Form shared with ${team['team_name']}'),
                                ),
                              );
                              Navigator.pop(ctx);
                            },
                          ),
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
  }

  // Save to Supabase
  Future<void> _saveForm() async {
    try {
      if (ctrl.form == null) {
        final user = Supabase.instance.client.auth.currentUser;
        final creatorId = user?.id ?? 'unknown';
        ctrl.createNewForm(
          creatorId: creatorId,
          name: _nameCtrl.text.isEmpty ? 'Untitled' : _nameCtrl.text,
        );
      }
      ctrl.updateFormName(_nameCtrl.text);
      ctrl.updateSubject(_subjectCtrl.text);
      ctrl.updateDescription(_descCtrl.text);

      final id = await ctrl.saveFormToDb();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form saved (ID: $id)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving form: $e')),
      );
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
          Text(
            form.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          for (final f in fields) _buildPreviewField(f),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Submit (preview only)',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewField(FormFieldModel f) {
    switch (f.fieldType) {
      case 'text':
      case 'email':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            decoration: InputDecoration(
              labelText: f.label,
              hintText: f.rules.placeholder,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: f.fieldType == 'email' 
                ? TextInputType.emailAddress 
                : TextInputType.text,
          ),
        );

      case 'number':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            decoration: InputDecoration(
              labelText: f.label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
        );

      case 'radio':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...?f.rules.options?.map(
                (o) => RadioListTile(
                  value: o,
                  groupValue: null,
                  onChanged: (_) {},
                  title: Text(o),
                ),
              ),
            ],
          ),
        );

      case 'checkbox':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...?f.rules.options?.map(
                (o) => CheckboxListTile(
                  value: false,
                  onChanged: (_) {},
                  title: Text(o),
                ),
              ),
            ],
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text('Unsupported preview for ${f.fieldType}'),
        );
    }
  }
}