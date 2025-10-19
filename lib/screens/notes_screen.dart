import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';
import 'package:schedule_app/widgets/cards/note_card.dart';
import 'package:schedule_app/config/api_config.dart';

import 'edit_note_screen.dart';
import 'share_note_dialog.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isLoading = true;
  List _notes = [];
  String _error = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        throw Exception('Token not found');
      }

      final url = Uri.parse(ApiConfig.apiNotes);
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _notes = jsonDecode(response.body);
        });
      } else {
        throw Exception('Failed to load notes: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa ghi chú này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Token not found');

      final url = Uri.parse('${ApiConfig.apiNotes}/$noteId');
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
        _fetchNotes();
      } else {
        throw Exception('Failed to delete note: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _navigateToEditScreen({Map<String, dynamic>? note}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(note: note),
      ),
    );
    if (result == true) {
      _fetchNotes();
    }
  }

  void _showShareDialog(Map<String, dynamic> note) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ShareNoteDialog(
        noteId: note['_id'],
        noteTitle: note['title'] ?? 'Untitled',
      ),
    );
    
    if (result == true) {
      _fetchNotes();
    }
  }

  List _getFilteredNotes() {
    if (_searchQuery.isEmpty) return _notes;
    return _notes.where((note) {
      final title = (note['title'] ?? '').toString().toLowerCase();
      final content = (note['content'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || content.contains(query);
    }).toList();
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
    final filteredNotes = _getFilteredNotes();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(loc.notes),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _NotesSearchDelegate(
                  notes: _notes,
                  onNoteSelected: (note) {
                    _navigateToEditScreen(note: note);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(filteredNotes, loc),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToEditScreen(),
        icon: const Icon(Icons.add_rounded),
        label: Text(loc.newNote),
      ),
    );
  }

  Widget _buildBody(List filteredNotes, AppLocalizations loc) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.error,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Có lỗi xảy ra',
              style: AppTypography.textTheme.titleMedium,
            ),
            SizedBox(height: AppSpacing.sm),
            Padding(
              padding: AppSpacing.horizontalXxl,
              child: Text(
                _error,
                style: AppTypography.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _fetchNotes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (filteredNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.note_add_outlined
                  : Icons.search_off_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              _searchQuery.isEmpty
                  ? 'Chưa có ghi chú nào'
                  : 'Không tìm thấy kết quả',
              style: AppTypography.textTheme.titleMedium,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              _searchQuery.isEmpty
                  ? 'Bắt đầu tạo ghi chú đầu tiên của bạn'
                  : 'Thử tìm kiếm với từ khóa khác',
              style: AppTypography.textTheme.bodyMedium,
            ),
            if (_searchQuery.isEmpty) ...[
              SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => _navigateToEditScreen(),
                icon: const Icon(Icons.add_rounded),
                label: Text(loc.newNote),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotes,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: filteredNotes.length,
        itemBuilder: (context, index) {
          final note = filteredNotes[index] as Map<String, dynamic>;
          return NoteCard(
            title: note['title'] ?? loc.noTitle,
            content: note['content'] ?? 'Không có nội dung',
            backgroundColor: _getNoteColor(index),
            hasAttachment: note['attachments'] != null && 
                          (note['attachments'] as List).isNotEmpty,
            onTap: () => _navigateToEditScreen(note: note),
            onEdit: () => _navigateToEditScreen(note: note),
            onDelete: () => _deleteNote(note['_id']),
            onShare: () => _showShareDialog(note),
          );
        },
      ),
    );
  }
}

class _NotesSearchDelegate extends SearchDelegate<String> {
  final List notes;
  final Function(Map<String, dynamic>) onNoteSelected;

  _NotesSearchDelegate({
    required this.notes,
    required this.onNoteSelected,
  });

  @override
  String get searchFieldLabel => 'Tìm kiếm ghi chú...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final results = notes.where((note) {
      final title = (note['title'] ?? '').toString().toLowerCase();
      final content = (note['content'] ?? '').toString().toLowerCase();
      final searchQuery = query.toLowerCase();
      return title.contains(searchQuery) || content.contains(searchQuery);
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Không tìm thấy kết quả',
              style: AppTypography.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final note = results[index] as Map<String, dynamic>;
        return NoteCard(
          title: note['title'] ?? 'Không có tiêu đề',
          content: note['content'] ?? 'Không có nội dung',
          onTap: () {
            close(context, '');
            onNoteSelected(note);
          },
        );
      },
    );
  }
}
