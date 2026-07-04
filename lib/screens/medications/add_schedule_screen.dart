import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class AddScheduleScreen extends StatefulWidget {
  final String medicationId;
  final String medicationName;
  final String? dosageLabel;
  final Map<String, dynamic>? schedule;

  const AddScheduleScreen({
    super.key,
    required this.medicationId,
    required this.medicationName,
    this.dosageLabel,
    this.schedule,
  });

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  String _frequencyType = 'once_daily';
  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _frequencies = [
    {'value': 'once_daily', 'label': 'Once daily', 'times': 1},
    {'value': 'twice_daily', 'label': 'Twice daily', 'times': 2},
    {'value': 'three_times_daily', 'label': 'Three times daily', 'times': 3},
    {'value': 'prn', 'label': 'As needed (PRN)', 'times': 0},
  ];

  bool get _isEditing => widget.schedule != null;

  String? get _scheduleId {
    final schedule = widget.schedule;
    if (schedule == null) return null;
    return (schedule['id'] ?? schedule['schedule_id'])?.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _loadSchedule() {
    final schedule = widget.schedule;
    if (schedule == null) return;

    final frequency = schedule['frequency_type']?.toString();
    if (frequency != null &&
        _frequencies.any((item) => item['value'] == frequency)) {
      _frequencyType = frequency;
    }

    final parsedTimes = _parseTimes(schedule);
    if (parsedTimes.isNotEmpty || _frequencyType == 'prn') {
      _times = parsedTimes;
    }
  }

  List<TimeOfDay> _parseTimes(Map<String, dynamic> schedule) {
    final rawTimes = schedule['times'];
    if (rawTimes is List) {
      return rawTimes
          .map((value) => _parseTime(value?.toString()))
          .whereType<TimeOfDay>()
          .toList();
    }

    final scheduledTime = (schedule['scheduled_time'] ?? schedule['time'])
        ?.toString();
    final parsedTime = _parseTime(scheduledTime);
    return parsedTime == null ? [] : [parsedTime];
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;

    final parts = value.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  void _onFrequencyChanged(String value) {
    final freq = _frequencies.firstWhere((f) => f['value'] == value);
    final count = freq['times'] as int;

    setState(() {
      _frequencyType = value;
      if (count == 0) {
        _times = [];
      } else {
        _times = List.generate(
          count,
          (i) => TimeOfDay(hour: 8 + (i * 6), minute: 0),
        );
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _times[index] = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _saveSchedule() async {
    if (_isEditing && _scheduleId == null) {
      setState(() => _errorMessage = 'Schedule ID is missing.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final timesJson = _times.map(_formatTime).toList();
      final payload = {
        'frequency_type': _frequencyType,
        'times': timesJson,
        'start_date': DateTime.now().toIso8601String().split('T')[0],
        'timezone': AppConfig.defaultTimezone,
      };

      final response = _isEditing
          ? await ApiService.updateSchedule(
              scheduleId: _scheduleId!,
              data: payload,
            )
          : await ApiService.createSchedule(
              medicationId: widget.medicationId,
              data: payload,
            );

      if (response['status'] != 'success') {
        setState(() {
          _errorMessage = response['message'] ?? 'Could not save schedule.';
        });
        return;
      }

      await NotificationService.instance.cancelForTimes(
        baseId: widget.medicationId.hashCode,
        count: 8,
      );
      await NotificationService.instance.scheduleForTimes(
        baseId: widget.medicationId.hashCode,
        medicationName: widget.medicationName,
        dosage: widget.dosageLabel ?? widget.medicationName,
        times: timesJson,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Schedule updated with reminders'
                  : 'Schedule created with reminders',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _errorMessage = ApiService.messageFromError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSchedule() async {
    final scheduleId = _scheduleId;
    if (scheduleId == null) {
      setState(() => _errorMessage = 'Schedule ID is missing.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Schedule'),
        content: const Text('This reminder schedule will be removed.'),
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.deleteSchedule(scheduleId);
      if (response['status'] != 'success') {
        setState(() {
          _errorMessage = response['message'] ?? 'Could not delete schedule.';
        });
        return;
      }

      await NotificationService.instance.cancelForTimes(
        baseId: widget.medicationId.hashCode,
        count: 8,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _errorMessage = ApiService.messageFromError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Schedule' : 'Set Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _isLoading ? null : _deleteSchedule,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.medication_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.medicationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How often?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ..._frequencies.map((freq) {
              final isSelected = _frequencyType == freq['value'];
              return GestureDetector(
                onTap: () => _onFrequencyChanged(freq['value'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        freq['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_times.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'What time?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ..._times.asMap().entries.map((entry) {
                final index = entry.key;
                final time = entry.value;
                final labels = ['Morning', 'Afternoon', 'Evening'];
                final label = index < labels.length
                    ? labels[index]
                    : 'Dose ${index + 1}';

                return GestureDetector(
                  onTap: () => _pickTime(index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          time.format(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildError(_errorMessage!),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveSchedule,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Save Schedule'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
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
    );
  }
}
