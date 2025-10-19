import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/config/api_config.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';

class ShareNoteDialog extends StatefulWidget {
  final String noteId;
  final String noteTitle;

  const ShareNoteDialog({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  State<ShareNoteDialog> createState() => _ShareNoteDialogState();
}

class _ShareNoteDialogState extends State<ShareNoteDialog> {
  bool _loading = true;
  List _groups = [];
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() => _loading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.apiGroups),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _groups = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        throw Exception('Failed to load groups');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _shareToGroup() async {
    if (_selectedGroupId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn nhóm')),
        );
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Token not found');

      // Get note details
      final noteResponse = await http.get(
        Uri.parse('${ApiConfig.apiNotes}/${widget.noteId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (noteResponse.statusCode != 200) {
        throw Exception('Failed to get note: ${noteResponse.statusCode}');
      }

      final noteData = jsonDecode(noteResponse.body);

      // Prepare tags - handle both string and array
      String tagsStr = '';
      try {
        if (noteData['tags'] != null) {
          if (noteData['tags'] is List) {
            tagsStr = (noteData['tags'] as List).map((e) => e.toString()).join(',');
          } else if (noteData['tags'] is String) {
            tagsStr = noteData['tags'];
          }
        }
      } catch (e) {
        // If tags parsing fails, just use empty string
        tagsStr = '';
      }

      // Create a copy of the note in the group
      final response = await http.post(
        Uri.parse(ApiConfig.apiNotes),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': noteData['title'] ?? 'Untitled',
          'content': noteData['content'] ?? '',
          'tags': tagsStr,
          'groupId': _selectedGroupId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã chia sẻ ghi chú vào nhóm'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        final errorBody = response.body;
        throw Exception('Failed to share note: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('Share note error: $e'); // Debug logging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.share, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Chia sẻ ghi chú',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ghi chú: ${widget.noteTitle}',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Chọn nhóm để chia sẻ:',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_off,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Chưa có nhóm nào',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tạo nhóm trong tab Groups',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final groupId = group['_id'];
                    final isSelected = _selectedGroupId == groupId;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.primaryLight.withOpacity(0.3),
                        child: Icon(
                          Icons.group,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        group['name'] ?? 'Unnamed',
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${group['members']?.length ?? 0} thành viên',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.success)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedGroupId = groupId;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _groups.isEmpty ? null : _shareToGroup,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Chia sẻ'),
        ),
      ],
    );
  }
}
