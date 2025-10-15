import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';
import 'package:schedule_app/widgets/cards/app_card.dart';
import 'package:schedule_app/widgets/cards/note_card.dart';

import 'add_note_screen.dart';
import 'add_member_dialog.dart';
import 'edit_note_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _group = {};
  List _notes = [];
  List _members = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchGroupDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroupDetails() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final url = Uri.parse('http://10.0.2.2:5000/api/groups/${widget.groupId}');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _group = data;
          _notes = data['notes'] ?? [];
          _members = data['members'] ?? [];
          _loading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("API Error: ${response.statusCode}"),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection Error: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  void _navigateToAddNote() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddNoteScreen(groupId: widget.groupId),
      ),
    );

    if (result == true) _fetchGroupDetails();
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa ghi chú này khỏi nhóm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final url = Uri.parse('http://10.0.2.2:5000/api/notes/$noteId');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa ghi chú'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _fetchGroupDetails();
      } else {
        throw Exception('Failed to delete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddMemberDialog(
          groupId: widget.groupId,
          onMemberAdded: _fetchGroupDetails,
        );
      },
    );
  }

  Color _getNoteColor(int index) {
    final colors = [
      AppColors.categoryBlue,
      AppColors.categoryPurple,
      AppColors.categoryGreen,
      AppColors.categoryYellow,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final groupName = _group['name'] ?? loc.group;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupName),
            if (_members.isNotEmpty)
              Text(
                '${_members.length} thành viên',
                style: AppTypography.textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: _showAddMemberDialog,
            tooltip: 'Thêm thành viên',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ghi chú', icon: Icon(Icons.note_outlined, size: 20)),
            Tab(text: 'Thành viên', icon: Icon(Icons.people_outlined, size: 20)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotesTab(loc),
                _buildMembersTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddNote,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm ghi chú'),
      ),
    );
  }

  Widget _buildNotesTab(AppLocalizations loc) {
    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingXxl,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.note_add_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Chưa có ghi chú nào',
                style: AppTypography.textTheme.titleMedium,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Thêm ghi chú đầu tiên cho nhóm của bạn',
                style: AppTypography.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _navigateToAddNote,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm ghi chú'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchGroupDetails,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index] as Map<String, dynamic>;
          return NoteCard(
            title: note['title'] ?? loc.noTitle,
            content: note['content'] ?? 'Không có nội dung',
            backgroundColor: _getNoteColor(index),
            groupName: _group['name'],
            hasAttachment: note['attachments'] != null && 
                          (note['attachments'] as List).isNotEmpty,
            onTap: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => EditNoteScreen(note: note),
                ),
              );
              if (result == true) _fetchGroupDetails();
            },
            onEdit: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => EditNoteScreen(note: note),
                ),
              );
              if (result == true) _fetchGroupDetails();
            },
            onDelete: () => _deleteNote(note['_id']),
          );
        },
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingXxl,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_add_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Chưa có thành viên',
                style: AppTypography.textTheme.titleMedium,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Mời bạn bè tham gia nhóm',
                style: AppTypography.textTheme.bodyMedium,
              ),
              SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _showAddMemberDialog,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Thêm thành viên'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchGroupDetails,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          final memberName = member['name'] ?? 'Người dùng ${index + 1}';
          final memberEmail = member['email'] ?? '';
          
          return AppCard(
            padding: AppSpacing.paddingLg,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                  child: Text(
                    memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: AppTypography.cardTitle,
                      ),
                      if (memberEmail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          memberEmail,
                          style: AppTypography.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: Text(
                    'Thành viên',
                    style: AppTypography.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
