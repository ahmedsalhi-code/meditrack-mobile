// lib/screens/medications/add_medication_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'add_schedule_screen.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedUnit = 'mg';
  String _selectedForm = 'tablet';
  String _selectedCategory = 'General';

  final List<String> _units = [
    'mg', 'mcg', 'ml', 'units', 'g', 'IU'
  ];

  final List<String> _forms = [
    'tablet', 'capsule', 'liquid', 'injection', 'patch', 'drops'
  ];

  final List<String> _categories = [
    'General', 'Antidiabetic', 'Antihypertensive', 'Antibiotic',
    'Antidepressant', 'Anticoagulant', 'Cholesterol', 'Pain Relief',
    'Vitamin', 'Supplement', 'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMedication() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Medication name is required.');
      return;
    }

    if (_dosageController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Dosage is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.createMedication({
        'name': _nameController.text.trim(),
        'dosage': double.parse(_dosageController.text.trim()),
        'unit': _selectedUnit,
        'form': _selectedForm,
        'category': _selectedCategory,
        'notes': _notesController.text.trim(),
        'start_date': DateTime.now().toIso8601String().split('T')[0],
      });

      if (response['status'] == 'success') {
  final medicationId = response['data']['medication']['id'];
  final medicationName = response['data']['medication']['name'];

  if (mounted) {
    // Go directly to schedule creation
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddScheduleScreen(
          medicationId: medicationId,
          medicationName: medicationName,
        ),
      ),
    );
  }
}
    } catch (e) {
      setState(() => _errorMessage = 'Could not save medication.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Add Medication'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveMedication,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medication Name
            _buildLabel('Medication Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Metformin',
                prefixIcon: Icon(
                  Icons.medication_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Dosage + Unit row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Dosage'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dosageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 500',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Unit'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _selectedUnit,
                        items: _units,
                        onChanged: (val) =>
                            setState(() => _selectedUnit = val!),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Form
            _buildLabel('Form'),
            const SizedBox(height: 8),
            _buildDropdown(
              value: _selectedForm,
              items: _forms,
              onChanged: (val) => setState(() => _selectedForm = val!),
            ),

            const SizedBox(height: 20),

            // Category
            _buildLabel('Category'),
            const SizedBox(height: 8),
            _buildDropdown(
              value: _selectedCategory,
              items: _categories,
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),

            const SizedBox(height: 20),

            // Notes
            _buildLabel('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any special instructions...',
                alignLabelWithHint: true,
              ),
            ),

            // Error
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveMedication,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save Medication'),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textMedium,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
            fontFamily: 'Inter',
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}