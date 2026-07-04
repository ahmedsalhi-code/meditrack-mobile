import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'add_medication_screen.dart';
import 'add_schedule_screen.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Map<String, dynamic>> _allMedications = [];
  List<Map<String, dynamic>> _filteredMedications = [];
  bool _isLoading = true;
  String? _errorMessage;
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';

  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadMedications();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredMedications = _allMedications.where((med) {
        final matchesSearch = query.isEmpty ||
            (med['name']?.toString().toLowerCase().contains(query) ?? false) ||
            (med['category']?.toString().toLowerCase().contains(query) ??
                false);
        final matchesCategory =
            _selectedCategory == 'All' || med['category'] == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _loadMedications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getMedications();
      if (response['status'] != 'success') {
        setState(() {
          _errorMessage = response['message'] ?? 'Could not load medications.';
          _isLoading = false;
        });
        return;
      }

      final data = response['data'];
      final rawMeds = data is Map<String, dynamic> ? data['medications'] : null;
      final meds = rawMeds is List
          ? rawMeds
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : <Map<String, dynamic>>[];

      final cats = meds
          .map((m) => m['category']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _allMedications = meds;
        _filteredMedications = List.from(meds);
        _categories = ['All', ...cats];
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = ApiService.messageFromError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddMedication() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMedicationScreen(),
      ),
    );
    await _loadMedications();
  }

  Future<void> _openEditMedication(Map<String, dynamic> medication) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(medication: medication),
      ),
    );

    if (updated == true) {
      await _loadMedications();
    }
  }

  Future<void> _openAddSchedule(Map<String, dynamic> medication) async {
    final medicationId = _medicationId(medication);
    if (medicationId == null) {
      _showSnack('Medication ID is missing.', isError: true);
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddScheduleScreen(
          medicationId: medicationId,
          medicationName: medication['name']?.toString() ?? 'Medication',
          dosageLabel: _dosageLabel(medication),
        ),
      ),
    );

    if (changed == true) {
      await _loadMedications();
    }
  }

  Future<void> _openEditSchedule(
    Map<String, dynamic> medication,
    Map<String, dynamic> schedule,
  ) async {
    final medicationId = _medicationId(medication);
    if (medicationId == null) {
      _showSnack('Medication ID is missing.', isError: true);
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddScheduleScreen(
          medicationId: medicationId,
          medicationName: medication['name']?.toString() ?? 'Medication',
          dosageLabel: _dosageLabel(medication),
          schedule: schedule,
        ),
      ),
    );

    if (changed == true) {
      await _loadMedications();
    }
  }

  Future<void> _deleteMedication(Map<String, dynamic> medication) async {
    final medicationId = _medicationId(medication);
    if (medicationId == null) {
      _showSnack('Medication ID is missing.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Medication'),
        content: Text(
          'Delete ${medication['name'] ?? 'this medication'} and its reminders?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.deleteMedication(medicationId);
      if (response['status'] != 'success') {
        _showSnack(
          response['message'] ?? 'Could not delete medication.',
          isError: true,
        );
        return;
      }

      await NotificationService.instance.cancelForTimes(
        baseId: medicationId.hashCode,
        count: 8,
      );
      _showSnack('Medication deleted.');
      await _loadMedications();
    } catch (e) {
      _showSnack(ApiService.messageFromError(e), isError: true);
    }
  }

  Future<void> _showMedicationActions(Map<String, dynamic> medication) async {
    var schedules = _extractSchedules(medication);
    final medicationId = _medicationId(medication);

    if (schedules.isEmpty && medicationId != null) {
      try {
        final response = await ApiService.getMedicationSchedules(
          medicationId: medicationId,
        );
        if (response['status'] == 'success') {
          schedules = _extractSchedulesFromData(response['data']);
        }
      } catch (_) {
        // The action sheet can still expose medication editing and adding.
      }
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  medication['name']?.toString() ?? 'Medication',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _dosageLabel(medication),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildSheetAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit medication',
                  onTap: () {
                    Navigator.pop(context);
                    _openEditMedication(medication);
                  },
                ),
                _buildSheetAction(
                  icon: Icons.alarm_add_outlined,
                  label: 'Add schedule',
                  onTap: () {
                    Navigator.pop(context);
                    _openAddSchedule(medication);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Schedules',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                if (schedules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No editable schedules returned by the API yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ...schedules.map((schedule) {
                    return _buildSheetAction(
                      icon: Icons.schedule_outlined,
                      label: _scheduleTitle(schedule),
                      subtitle: _scheduleSubtitle(schedule),
                      onTap: () {
                        Navigator.pop(context);
                        _openEditSchedule(medication, schedule);
                      },
                    );
                  }),
                const SizedBox(height: 8),
                _buildSheetAction(
                  icon: Icons.delete_outline,
                  label: 'Delete medication',
                  color: AppColors.danger,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMedication(medication);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
    Color color = AppColors.textDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }

  String? _medicationId(Map<String, dynamic> medication) {
    return (medication['id'] ?? medication['medication_id'])?.toString();
  }

  String _dosageLabel(Map<String, dynamic> medication) {
    final dosage = medication['dosage']?.toString() ?? '';
    final unit = medication['unit']?.toString() ?? '';
    final form = medication['form']?.toString() ?? '';
    final dose = '$dosage $unit'.trim();
    if (form.isEmpty) return dose;
    if (dose.isEmpty) return form;
    return '$dose · $form';
  }

  List<Map<String, dynamic>> _extractSchedules(
    Map<String, dynamic> medication,
  ) {
    final raw = medication['schedules'] ??
        medication['active_schedules'] ??
        medication['schedule'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => (item['id'] ?? item['schedule_id']) != null)
          .toList();
    }

    if (raw is Map && (raw['id'] ?? raw['schedule_id']) != null) {
      return [Map<String, dynamic>.from(raw)];
    }

    return [];
  }

  List<Map<String, dynamic>> _extractSchedulesFromData(dynamic data) {
    final raw = data is Map<String, dynamic>
        ? data['schedules'] ?? data['schedule']
        : data;

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => (item['id'] ?? item['schedule_id']) != null)
          .toList();
    }

    if (raw is Map && (raw['id'] ?? raw['schedule_id']) != null) {
      return [Map<String, dynamic>.from(raw)];
    }

    return [];
  }

  String _scheduleTitle(Map<String, dynamic> schedule) {
    final frequency = schedule['frequency_type']?.toString();
    switch (frequency) {
      case 'once_daily':
        return 'Once daily';
      case 'twice_daily':
        return 'Twice daily';
      case 'three_times_daily':
        return 'Three times daily';
      case 'prn':
        return 'As needed';
      default:
        return 'Schedule';
    }
  }

  String _scheduleSubtitle(Map<String, dynamic> schedule) {
    final times = _scheduleTimes(schedule);
    if (times.isEmpty) return 'No fixed time';
    return times.join(', ');
  }

  List<String> _scheduleTimes(Map<String, dynamic> schedule) {
    final rawTimes = schedule['times'];
    if (rawTimes is List) {
      return rawTimes
          .map((value) => value?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .map(_shortTime)
          .toList();
    }

    final scheduledTime = (schedule['scheduled_time'] ?? schedule['time'])
        ?.toString();
    if (scheduledTime == null || scheduledTime.isEmpty) return [];
    return [_shortTime(scheduledTime)];
  }

  String _shortTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('My Medications'),
        actions: [
          if (_allMedications.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filteredMedications.length} of ${_allMedications.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadMedications,
              child: _allMedications.isEmpty ? _buildEmpty() : _buildList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMedication,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Medication',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSearchAndFilter()),
        if (_errorMessage != null)
          SliverToBoxAdapter(child: _buildError(_errorMessage!)),
        if (_filteredMedications.isEmpty)
          SliverToBoxAdapter(child: _buildNoResults())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildMedicationCard(_filteredMedications[index]),
                childCount: _filteredMedications.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search medications...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textMuted,
                      ),
                      onPressed: _searchController.clear,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _applyFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
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
                message,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.search_off_rounded,
              color: AppColors.textMuted,
              size: 40,
            ),
            SizedBox(height: 12),
            Text(
              'No medications match your search',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> med) {
    return GestureDetector(
      onTap: () {
        _showMedicationActions(med);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.medication_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dosageLabel(med),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      med['category'] ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: med['is_active'] == true
                        ? AppColors.success
                        : AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  med['is_active'] == true ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        if (_errorMessage != null) _buildError(_errorMessage!),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No medications yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to add\nyour first medication',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
