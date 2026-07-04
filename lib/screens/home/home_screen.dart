import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../medications/medications_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../profile/profile_screen.dart';
import '../adherence/adherence_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _todayData;
  Map<String, dynamic>? _statsData;
  bool _isLoading = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getToday(),
        ApiService.getStats(),
        ApiService.getMe(),
      ]);

      setState(() {
        _todayData = results[0]['data'];
        _statsData = results[1]['data'];
        _userName = results[2]['data']['user']['first_name'];
        _isLoading = false;
      });

      _rescheduleNotifications(results[0]['data']);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rescheduleNotifications(Map<String, dynamic>? todayData) async {
    final schedules = todayData?['schedules'] as List? ?? [];
    for (final schedule in schedules) {
      if (schedule['action'] != null) continue;

      final medName = schedule['medication_name'] ?? 'Medication';
      final dosage = '${schedule['dosage']} ${schedule['unit'] ?? ''}';
      final timeStr = schedule['scheduled_time'] as String?;
      if (timeStr == null) continue;

      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;
        final medId = schedule['medication_id']?.hashCode ?? 0;
        final schedIdx = schedules.indexOf(schedule);

        await NotificationService.instance.scheduleDailyReminder(
          id: medId + schedIdx,
          medicationName: medName,
          dosage: dosage,
          hour: hour,
          minute: minute,
        );
      }
    }
  }
  Future<void> _logDose(
  Map<String, dynamic> schedule,
  String action,
) async {
  try {
    final response = await ApiService.logDose({
      'schedule_id': schedule['schedule_id'],
      'medication_id': schedule['medication_id'],
      'action': action,
      'scheduled_at': DateTime.now().toUtc().toIso8601String(),
      'taken_at': action == 'taken'
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    });

    if (response['status'] == 'success') {
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'taken'
                  ? '✓ Dose logged — great job!'
                  : 'Dose skipped.',
            ),
            backgroundColor: action == 'taken'
                ? AppColors.success
                : AppColors.textMuted,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Refresh the home screen data
      await _loadData();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log dose. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

  Future<void> _logout() async {
    await ApiService.clearTokens();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
  switch (_currentIndex) {
    case 0:
      return _buildHomeTab();
    case 1:
      return const MedicationsScreen();
    case 2:
      return const AdherenceScreen();
    case 3:
      return const AiChatScreen();
    case 4:
      return const ProfileScreen();
    default:
      return _buildHomeTab();
   }
  }

  Widget _buildHomeTab() {
    final adherence = _todayData?['adherence_percentage'] ?? 0;
    final totalDoses = _todayData?['total_doses'] ?? 0;
    final takenDoses = _todayData?['taken_doses'] ?? 0;
    final streak = _statsData?['streak']?['current_streak'] ?? 0;
    final weekly = _statsData?['adherence']?['weekly'] ?? 0;
    final schedules = _todayData?['schedules'] as List? ?? [];

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning,',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        _userName ?? 'there 👋',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Adherence ring card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Circular progress
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: adherence / 100,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          Center(
                            child: Text(
                              '$adherence%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Adherence",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$takenDoses of $totalDoses doses taken',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🔥 $streak day streak',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick stats row
              Row(
                children: [
                  _buildStatCard('Weekly', '$weekly%', Icons.bar_chart_rounded),
                  const SizedBox(width: 12),
                  _buildStatCard('Streak', '$streak days', Icons.local_fire_department_rounded),
                  const SizedBox(width: 12),
                  _buildStatCard('Today', '$totalDoses doses', Icons.medication_rounded),
                ],
              ),

              const SizedBox(height: 24),

              // Today's schedule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Schedule",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Schedule list
              if (schedules.isEmpty)
                _buildEmptySchedule()
              else
                ...schedules.map((schedule) => _buildScheduleCard(schedule)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
  final action = schedule['action'];
  final isTaken = action == 'taken';
  final isMissed = action == 'missed';
  final isLogged = action != null;

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isTaken
            ? AppColors.success.withValues(alpha: 0.3)
            : isMissed
                ? AppColors.danger.withValues(alpha: 0.3)
                : AppColors.cardBorder,
      ),
    ),
    child: Column(
      children: [
        Row(
          children: [
            // Medication icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isTaken
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.medication_rounded,
                color: isTaken ? AppColors.success : AppColors.primary,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // Medication info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule['medication_name'] ?? 'Medication',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${schedule['dosage']} ${schedule['unit']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Status badge
            if (isLogged)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isTaken
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isTaken ? '✓ Taken' : '✗ Skipped',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isTaken ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
          ],
        ),

        // Action buttons — only show if not logged yet
        if (!isLogged) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              // Taken button
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _logDose(schedule, 'taken'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Taken',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Skip button
              Expanded(
                child: GestureDetector(
                  onTap: () => _logDose(schedule, 'skipped'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Text(
                      'Skip',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

  Widget _buildEmptySchedule() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.medication_outlined,
            color: AppColors.textMuted,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No medications scheduled today',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first medication to get started',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
  return BottomNavigationBar(
    currentIndex: _currentIndex,
    onTap: (index) => setState(() => _currentIndex = index),
    items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.medication_outlined),
        activeIcon: Icon(Icons.medication_rounded),
        label: 'Medications',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_outlined),
        activeIcon: Icon(Icons.bar_chart_rounded),
        label: 'Stats',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.smart_toy_outlined),
        activeIcon: Icon(Icons.smart_toy_rounded),
        label: 'AI Chat',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  );
 }
}