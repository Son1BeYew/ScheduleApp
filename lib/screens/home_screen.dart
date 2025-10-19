import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';
import 'package:schedule_app/widgets/cards/app_card.dart';
import 'package:schedule_app/widgets/cards/timeline_card.dart';
import 'package:schedule_app/widgets/weather_widget.dart';
import 'package:schedule_app/config/api_config.dart';

import 'add_note_screen.dart';
import 'login_screen.dart';
import 'notes_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';
import 'group_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoggedIn = false;
  bool _loading = true;
  String _name = '';
  String _avatar = '';
  List _todaySchedules = [];
  int _totalNotes = 0;
  int _totalGroups = 0;
  List _recentNotes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String? _getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      return payloadMap['id'];
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (!mounted) return;
    if (token == null) {
      setState(() {
        _isLoggedIn = false;
        _name = '';
        _avatar = '';
        _todaySchedules = [];
        _loading = false;
      });
      return;
    }

    final userId = _getUserIdFromToken(token);
    if (userId == null) {
      setState(() {
        _isLoggedIn = false;
        _loading = false;
      });
      return;
    }

    setState(() => _isLoggedIn = true);

    try {
      final userFuture = http.get(
        Uri.parse('${ApiConfig.apiUsers}/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final scheduleFuture = http.get(
        Uri.parse('${ApiConfig.apiSchedules}/$userId/today'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final notesFuture = http.get(
        Uri.parse(ApiConfig.apiNotes),
        headers: {'Authorization': 'Bearer $token'},
      );

      final groupsFuture = http.get(
        Uri.parse(ApiConfig.apiGroups),
        headers: {'Authorization': 'Bearer $token'},
      );

      final results = await Future.wait([
        userFuture,
        scheduleFuture,
        notesFuture,
        groupsFuture,
      ]);

      if (!mounted) return;
      if (results[0].statusCode == 200) {
        final userData = jsonDecode(results[0].body);
        _name = userData['name'] ?? '';
        _avatar = userData['avatar'] ?? '';
      }

      if (results[1].statusCode == 200) {
        _todaySchedules = jsonDecode(results[1].body);
      }

      if (results[2].statusCode == 200) {
        final notes = jsonDecode(results[2].body) as List;
        _totalNotes = notes.length;
        // Get 3 most recent notes
        _recentNotes = notes.take(3).toList();
      }

      if (results[3].statusCode == 200) {
        final groups = jsonDecode(results[3].body) as List;
        _totalGroups = groups.length;
      }
    } catch (_) {
      // Silent fail
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAvatarTap(BuildContext context) async {
    if (_isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
      if (!mounted) return;
      await _loadData();
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (result == true && mounted) await _loadData();
    }
  }

  String _timeOfDayGreeting(AppLocalizations loc) {
    final hour = DateTime.now().hour;
    if (hour < 12) return loc.goodMorning;
    if (hour < 18) return loc.goodAfternoon;
    return loc.goodEvening;
  }

  bool _isCurrentSchedule(dynamic item) {
    if (item is! Map) return false;
    final raw = item['time'];
    if (raw is! String || raw.isEmpty) return false;

    final parts = raw.split('-');
    final start = _parseTime(parts.first.trim());
    DateTime? end;
    if (parts.length > 1) end = _parseTime(parts[1].trim());
    if (start == null) return false;
    end ??= start.add(const Duration(hours: 1));
    final now = DateTime.now();
    return (now.isAtSameMomentAs(start) || now.isAfter(start)) &&
        now.isBefore(end);
  }

  DateTime? _parseTime(String raw) {
    final now = DateTime.now();
    final sanitized = raw.replaceAll(RegExp('[^0-9a-zA-Z: ]'), '').trim();
    final formats = [
      DateFormat.Hm(),
      DateFormat('HH:mm:ss'),
      DateFormat('hh:mm a'),
      DateFormat('h:mm a'),
    ];
    for (final format in formats) {
      try {
        final parsed = format.parseStrict(sanitized);
        return DateTime(
          now.year,
          now.month,
          now.day,
          parsed.hour,
          parsed.minute,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final dayLabel = DateFormat('EEEE', loc.localeName).format(now);
    final dateLabel = DateFormat('d MMMM, yyyy', loc.localeName).format(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () => _loadData(showLoader: false),
                child: ListView(
                  padding: EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    _buildHeader(context, loc, dayLabel, dateLabel),
                    SizedBox(height: AppSpacing.sectionSpacing),
                    const WeatherWidget(),
                    SizedBox(height: AppSpacing.sectionSpacing),
                    _buildQuickStats(context, loc),
                    SizedBox(height: AppSpacing.sectionSpacing),
                    _buildTodaySchedule(context, loc),
                    SizedBox(height: AppSpacing.sectionSpacing),
                    _buildRecentNotes(context, loc),
                    SizedBox(height: AppSpacing.sectionSpacing),
                    _buildQuickActions(context, loc),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations loc,
    String dayLabel,
    String dateLabel,
  ) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_timeOfDayGreeting(loc)},',
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoggedIn ? _name : loc.guest,
                  style: AppTypography.greeting.copyWith(fontSize: 24),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: AppSpacing.iconXs,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$dayLabel, $dateLabel',
                      style: AppTypography.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          GestureDetector(
            onTap: () => _onAvatarTap(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage: _isLoggedIn && _avatar.isNotEmpty
                    ? NetworkImage(ApiConfig.getEndpoint(_avatar))
                    : const AssetImage('images/avatar.png') as ImageProvider,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, AppLocalizations loc) {
    final todaySchedulesCount = _todaySchedules.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_note,
            label: 'Lịch hôm nay',
            value: todaySchedulesCount.toString(),
            color: AppColors.primary,
            gradient: AppColors.gradientBlue,
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildStatCard(
            icon: Icons.description_outlined,
            label: 'Ghi chú',
            value: _totalNotes.toString(),
            color: AppColors.success,
            gradient: LinearGradient(
              colors: [Colors.green.shade100, Colors.green.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroupScreen()),
            ),
            child: _buildStatCard(
              icon: Icons.groups_outlined,
              label: 'Nhóm',
              value: _totalGroups.toString(),
              color: Colors.purple,
              gradient: LinearGradient(
                colors: [Colors.purple.shade100, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Gradient gradient,
  }) {
    return AppCard(
      gradient: gradient,
      padding: EdgeInsets.all(AppSpacing.lg),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppSpacing.iconMd),
          SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTodaySchedule(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(loc.todaySchedule, style: AppTypography.textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: AppSpacing.iconSm,
              ),
              label: Text(loc.viewAll),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        if (_isLoggedIn && _todaySchedules.isNotEmpty)

          ...List.generate(_todaySchedules.length, (index) {
            final schedule = _todaySchedules[index] as Map<String, dynamic>;
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: TimelineCard(
                time: schedule['time'] ?? '--:--',
                endTime: schedule['endTime'],
                title: schedule['title'] ?? loc.noTitle,
                description: schedule['description'] ?? '',
                isActive: _isCurrentSchedule(schedule),
              ),
            );
          })

        else if (_isLoggedIn)
          _buildEmptyState(
            icon: Icons.event_available_outlined,
            title: loc.noSchedule,
            subtitle: loc.noScheduleYet,
            actionLabel: loc.addSchedule,
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScheduleScreen()),
            ),
          )
        else
          _buildEmptyState(
            icon: Icons.login_rounded,
            title: loc.loginToView,
            subtitle: loc.loginToManage,
            actionLabel: loc.login,
            onAction: () => _onAvatarTap(context),
          ),
      ],
    );
  }

  Widget _buildRecentNotes(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ghi chú gần đây', style: AppTypography.textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotesScreen()),
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: AppSpacing.iconSm,
              ),
              label: Text(loc.viewAll),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        if (_isLoggedIn && _recentNotes.isNotEmpty)
          ...List.generate(_recentNotes.length, (index) {
            final note = _recentNotes[index] as Map<String, dynamic>;
            final hasAttachment =
                note['attachments'] != null &&
                (note['attachments'] as List).isNotEmpty;
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: EdgeInsets.all(AppSpacing.md),
                onTap: () {
                  // Navigate to note detail if needed
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasAttachment
                            ? Icons.attach_file
                            : Icons.description_outlined,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note['title'] ?? 'Không có tiêu đề',
                            style: AppTypography.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (note['content'] != null &&
                              note['content'].toString().isNotEmpty)
                            Text(
                              note['content'],
                              style: AppTypography.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          })
        else if (_isLoggedIn)
          _buildEmptyState(
            icon: Icons.note_outlined,
            title: 'Chưa có ghi chú',
            subtitle: 'Tạo ghi chú đầu tiên của bạn',
            actionLabel: loc.note,
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddNoteScreen()),
            ),
          )
        else
          _buildEmptyState(
            icon: Icons.login_rounded,
            title: loc.loginToView,
            subtitle: 'Đăng nhập để xem ghi chú',
            actionLabel: loc.login,
            onAction: () => _onAvatarTap(context),
          ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return AppCard(
      gradient: AppColors.gradientPurple,
      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.primary),
          SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: AppTypography.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.quickActions, style: AppTypography.textTheme.titleLarge),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.note_add_outlined,
                label: loc.note,
                color: AppColors.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddNoteScreen()),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.folder_outlined,
                label: loc.notesList,
                color: AppColors.accent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotesScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(AppSpacing.lg),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Icon(icon, color: color, size: AppSpacing.iconLg),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: AppTypography.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
