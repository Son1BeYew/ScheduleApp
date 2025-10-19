import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/config/api_config.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';
import 'admin_users_screen.dart';
import 'admin_groups_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
          _loading = false;
        });
      } else if (response.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn không có quyền truy cập'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống kê tổng quan',
                      style: AppTypography.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildStatsGrid(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Quản lý',
                      style: AppTypography.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildManagementButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    if (_stats == null) return const SizedBox();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      children: [
        _buildStatCard(
          icon: Icons.people,
          title: 'Người dùng',
          value: _stats!['totalUsers']?.toString() ?? '0',
          color: AppColors.primary,
          subtitle: '+${_stats!['newUsersThisWeek'] ?? 0} tuần này',
        ),
        _buildStatCard(
          icon: Icons.note,
          title: 'Ghi chú',
          value: _stats!['totalNotes']?.toString() ?? '0',
          color: AppColors.success,
        ),
        _buildStatCard(
          icon: Icons.calendar_today,
          title: 'Lịch học',
          value: _stats!['totalSchedules']?.toString() ?? '0',
          color: AppColors.secondary,
        ),
        _buildStatCard(
          icon: Icons.group,
          title: 'Nhóm',
          value: _stats!['totalGroups']?.toString() ?? '0',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTypography.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManagementButtons() {
    return Column(
      children: [
        _buildManagementButton(
          icon: Icons.people_outline,
          title: 'Quản lý người dùng',
          subtitle: 'Xem và quản lý tất cả người dùng',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildManagementButton(
          icon: Icons.group_outlined,
          title: 'Quản lý nhóm',
          subtitle: 'Xem và quản lý tất cả nhóm',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminGroupsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildManagementButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
