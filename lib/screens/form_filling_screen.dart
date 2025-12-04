// lib/screens/form_filling_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/form_response_controller.dart';

class FormFillingScreen extends StatefulWidget {
  final int formId;
  final String formName;

  const FormFillingScreen({
    super.key,
    required this.formId,
    required this.formName,
  });

  @override
  State<FormFillingScreen> createState() => _FormFillingScreenState();
}

class _FormFillingScreenState extends State<FormFillingScreen> {
  final FormResponseController ctrl = FormResponseController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    try {
      await ctrl.loadForm(widget.formId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading form: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.formName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Form',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Form?'),
                  content: const Text('This will clear all your entries.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ctrl.resetForm();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ctrl.form == null || ctrl.fields.isEmpty) {
            return const Center(
              child: Text('No form data available'),
            );
          }

          return Column(
            children: [
              // Progress indicator
              _buildProgressBar(),

              // Form content
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Form header
                    _buildFormHeader(),
                    const SizedBox(height: 24),

                    // Form fields
                    for (int i = 0; i < ctrl.fields.length; i++) ...[
                      _buildFormField(ctrl.fields[i], i),
                      const SizedBox(height: 20),
                    ],

                    const SizedBox(height: 32),

                    // Submit button
                    _buildSubmitButton(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // PROGRESS BAR
  // ------------------------------------------------------------
  Widget _buildProgressBar() {
    final progress = ctrl.getProgress();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: ${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(progress * ctrl.fields.length).toInt()}/${ctrl.fields.length} fields',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FORM HEADER
  // ------------------------------------------------------------
  Widget _buildFormHeader() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctrl.form!.formName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (ctrl.form!.subject.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Subject: ${ctrl.form!.subject}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (ctrl.form!.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ctrl.form!.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD FORM FIELD
  // ------------------------------------------------------------
  Widget _buildFormField(dynamic field, int index) {
    final error = ctrl.getFieldError(field.label);
    final hasError = error != null;

    return Card(
      elevation: hasError ? 2 : 1,
      color: hasError ? Colors.red.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Field label with required indicator
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (field.rules.required)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Field input based on type
            _buildFieldInput(field),

            // Error message
            if (hasError) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD FIELD INPUT BY TYPE
  // ------------------------------------------------------------
  Widget _buildFieldInput(dynamic field) {
    switch (field.fieldType) {
      case 'text':
        return _buildTextInput(field);
      case 'email':
        return _buildEmailInput(field);
      case 'number':
        return _buildNumberInput(field);
      case 'radio':
        return _buildRadioInput(field);
      case 'checkbox':
        return _buildCheckboxInput(field);
      case 'dropdown':
        return _buildDropdownInput(field);
      case 'date':
        return _buildDateInput(field);
      case 'time':
        return _buildTimeInput(field);
      case 'photo':
        return _buildPhotoInput(field);
      case 'signature':
        return _buildSignatureInput(field);
      default:
        return Text('Unsupported field type: ${field.fieldType}');
    }
  }

  // ------------------------------------------------------------
  // TEXT INPUT
  // ------------------------------------------------------------
  Widget _buildTextInput(dynamic field) {
    return TextFormField(
      initialValue: ctrl.getFieldValue(field.label)?.toString(),
      decoration: InputDecoration(
        hintText: field.rules.placeholder ?? 'Enter text',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      maxLines: 3,
      minLines: 1,
      onChanged: (value) => ctrl.updateResponse(field.label, value),
    );
  }

  // ------------------------------------------------------------
  // EMAIL INPUT
  // ------------------------------------------------------------
  Widget _buildEmailInput(dynamic field) {
    return TextFormField(
      initialValue: ctrl.getFieldValue(field.label)?.toString(),
      decoration: InputDecoration(
        hintText: field.rules.placeholder ?? 'Enter email',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: const Icon(Icons.email),
      ),
      keyboardType: TextInputType.emailAddress,
      onChanged: (value) => ctrl.updateResponse(field.label, value),
    );
  }

  // ------------------------------------------------------------
  // NUMBER INPUT
  // ------------------------------------------------------------
  Widget _buildNumberInput(dynamic field) {
    return TextFormField(
      initialValue: ctrl.getFieldValue(field.label)?.toString(),
      decoration: InputDecoration(
        hintText: 'Enter number',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: const Icon(Icons.numbers),
        helperText: _getNumberHelperText(field.rules),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) => ctrl.updateResponse(field.label, value),
    );
  }

  String? _getNumberHelperText(dynamic rules) {
    if (rules.min != null && rules.max != null) {
      return 'Range: ${rules.min} - ${rules.max}';
    } else if (rules.min != null) {
      return 'Min: ${rules.min}';
    } else if (rules.max != null) {
      return 'Max: ${rules.max}';
    }
    return null;
  }

  // ------------------------------------------------------------
  // RADIO INPUT
  // ------------------------------------------------------------
  Widget _buildRadioInput(dynamic field) {
    final options = field.rules.options ?? <String>[];
    final currentValue = ctrl.getFieldValue(field.label);

    return Column(
      children: options.map<Widget>((option) {
        return RadioListTile<String>(
          title: Text(option),
          value: option,
          groupValue: currentValue,
          onChanged: (value) {
            if (value != null) {
              ctrl.updateResponse(field.label, value);
            }
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  // ------------------------------------------------------------
  // CHECKBOX INPUT
  // ------------------------------------------------------------
  Widget _buildCheckboxInput(dynamic field) {
    final options = field.rules.options ?? <String>[];
    final currentValues = List<String>.from(ctrl.getFieldValue(field.label) ?? []);

    return Column(
      children: options.map<Widget>((option) {
        return CheckboxListTile(
          title: Text(option),
          value: currentValues.contains(option),
          onChanged: (isChecked) {
            ctrl.updateCheckbox(field.label, option, isChecked ?? false);
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  // ------------------------------------------------------------
  // DROPDOWN INPUT
  // ------------------------------------------------------------
  Widget _buildDropdownInput(dynamic field) {
    final options = field.rules.options ?? <String>[];
    final currentValue = ctrl.getFieldValue(field.label);

    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      hint: const Text('Select an option'),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          ctrl.updateResponse(field.label, value);
        }
      },
    );
  }

  // ------------------------------------------------------------
  // DATE INPUT
  // ------------------------------------------------------------
  Widget _buildDateInput(dynamic field) {
    final currentValue = ctrl.getFieldValue(field.label);
    final displayText = currentValue ?? 'Select date';

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          final formatted = DateFormat('yyyy-MM-dd').format(date);
          ctrl.updateResponse(field.label, formatted);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade50,
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(displayText),
      ),
    );
  }

  // ------------------------------------------------------------
  // TIME INPUT
  // ------------------------------------------------------------
  Widget _buildTimeInput(dynamic field) {
    final currentValue = ctrl.getFieldValue(field.label);
    final displayText = currentValue ?? 'Select time';

    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          final formatted = time.format(context);
          ctrl.updateResponse(field.label, formatted);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade50,
          prefixIcon: const Icon(Icons.access_time),
        ),
        child: Text(displayText),
      ),
    );
  }

  // ------------------------------------------------------------
  // PHOTO INPUT (Placeholder)
  // ------------------------------------------------------------
  Widget _buildPhotoInput(dynamic field) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          const Icon(Icons.photo_camera, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('Photo capture coming soon'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo capture feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SIGNATURE INPUT (Placeholder)
  // ------------------------------------------------------------
  Widget _buildSignatureInput(dynamic field) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          const Icon(Icons.brush, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('Signature capture coming soon'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Add Signature'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signature feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SUBMIT BUTTON
  // ------------------------------------------------------------
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: ctrl.submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send),
        label: Text(
          ctrl.submitting ? 'Submitting...' : 'Submit Response',
          style: const TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        onPressed: ctrl.submitting ? null : _handleSubmit,
      ),
    );
  }

  // ------------------------------------------------------------
  // HANDLE SUBMIT
  // ------------------------------------------------------------
  Future<void> _handleSubmit() async {
    try {
      final responseId = await ctrl.submitResponse();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Success!'),
            ],
          ),
          content: Text('Response submitted successfully! (ID: $responseId)'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Go back to dashboard
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      // Scroll to first error
      if (ctrl.validationErrors.isNotEmpty) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }
}