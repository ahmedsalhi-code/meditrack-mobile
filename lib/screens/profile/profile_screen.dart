import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _remindersEnabled = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadReminderSetting();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiService.getMe();
      if (response['status'] == 'success') {
        setState(() {
          _user = response['data']['user'];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Could not load profile.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = ApiService.messageFromError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReminderSetting() async {
    final enabled = await NotificationService.instance.areRemindersEnabled();
    if (mounted) {
      setState(() => _remindersEnabled = enabled);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
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
              'Log Out',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ApiService.clearTokens();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showNotificationSettings() {
    var remindersEnabled = _remindersEnabled;
    var isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                      'Notifications',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Control local medication reminders on this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: remindersEnabled,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Medication reminders'),
                      subtitle: Text(
                        remindersEnabled
                            ? 'Reminders will be scheduled when schedules are created.'
                            : 'All local reminders are disabled on this device.',
                      ),
                      onChanged: isSaving
                          ? null
                          : (value) async {
                              setSheetState(() => isSaving = true);
                              await NotificationService.instance
                                  .setRemindersEnabled(value);

                              if (!mounted) return;
                              setState(() => _remindersEnabled = value);
                              setSheetState(() {
                                remindersEnabled = value;
                                isSaving = false;
                              });
                              _showSnack(
                                value
                                    ? 'Medication reminders enabled.'
                                    : 'Medication reminders disabled.',
                              );
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacySecurity() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  'Privacy & Security',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your login token is stored in secure device storage. '
                  'Deleting your account will request permanent removal on the server.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildSheetAction(
                  icon: Icons.delete_forever_outlined,
                  label: 'Delete account',
                  color: AppColors.danger,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteAccount();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account if the server supports '
          'account deletion. This action cannot be undone.',
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

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.deleteAccount();
      if (response['status'] != 'success') {
        setState(() => _isLoading = false);
        _showSnack(
          response['message'] ?? 'Could not delete account.',
          isError: true,
        );
        return;
      }

      await ApiService.clearTokens();
      await NotificationService.instance.cancelAll();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(ApiService.messageFromError(e), isError: true);
    }
  }

  void _showComingSoon(String feature) {
    _showSnack('$feature is not available in this build yet.');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
      ),
    );
  }

  Widget _buildSheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.textDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_errorMessage != null) ...[
                    _buildError(_errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  _buildProfileCard(),
                  const SizedBox(height: 20),
                  _buildSettingsMenu(),
                  const SizedBox(height: 20),
                  _buildDangerMenu(),
                  const SizedBox(height: 32),
                  Text(
                    'Healfill v1.0.0',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final firstName = _user?['first_name']?.toString() ?? '';
    final lastName = _user?['last_name']?.toString() ?? '';
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$firstName $lastName'.trim(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?['email']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (_user?['subscription_tier'] ?? 'free').toString().toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person_outline,
            label: 'Edit Profile',
            onTap: () => _showComingSoon('Edit profile'),
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            trailingText: _remindersEnabled ? 'On' : 'Off',
            onTap: _showNotificationSettings,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.security_outlined,
            label: 'Privacy & Security',
            onTap: _showPrivacySecurity,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () => _showComingSoon('Help & support'),
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.star_outline,
            label: 'Upgrade to Premium',
            onTap: () => _showComingSoon('Premium'),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerMenu() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            onTap: _logout,
            color: AppColors.danger,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.delete_forever_outlined,
            label: 'Delete Account',
            onTap: _deleteAccount,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? trailingText,
    Color color = AppColors.textDark,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: trailingText == null
          ? const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textMuted,
            )
          : Text(
              trailingText,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.cardBorder,
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
