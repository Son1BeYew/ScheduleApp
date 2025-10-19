import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_typography.dart';
import 'package:schedule_app/widgets/cards/app_card.dart';
import 'package:schedule_app/widgets/cards/note_card.dart';
import 'package:schedule_app/services/socket_service.dart';
import 'package:schedule_app/config/api_config.dart';

import 'add_note_screen.dart';
import 'add_member_dialog.dart';
import 'edit_note_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _group = {};
  List _notes = [];
  List _members = [];
  List<Map<String, dynamic>> _messages = [];
  final Set<String> _messageIds = {};

  late TabController _tabController;
  final _socketService = SocketService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupSocketListeners();
    _fetchGroupDetails();
    _fetchMessages(); // ✅ tải tin nhắn thật từ backend khi mở nhóm
  }

  @override
  void dispose() {
    _socketService.leaveGroup(widget.groupId);
    _socketService.disconnect();
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ======================= SOCKET =======================
  Future<void> _setupSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      _socketService.connect(token);
      _socketService.joinGroup(widget.groupId);

      // 💬 Nhận tin nhắn realtime
      _socketService.onMessageReceived((data) {
        print('💬 Realtime Message: $data');
        if (mounted) {
          final messageId = data['_id'] ?? data['id'] ?? '';
          final messageContent = data['content'] ?? data['message'] ?? '';
          final senderName = data['sender']?['fullname'] ??
              data['senderName'] ??
              'Ẩn danh';

          setState(() {
            // Cố gắng match với tin nhắn pending (optimistic update)
            bool foundMatch = false;
            for (int i = _messages.length - 1; i >= 0; i--) {
              final msg = _messages[i];
              if (msg['_id'] == null &&
                  msg['sender'] == 'Bạn' &&
                  msg['message'] == messageContent) {
                _messages[i] = {
                  '_id': messageId,
                  'sender': senderName,
                  'message': messageContent,
                  'timestamp': data['createdAt'] ?? msg['timestamp'],
                };
                if (messageId.isNotEmpty) {
                  _messageIds.add(messageId);
                }
                foundMatch = true;
                break;
              }
            }

            // Nếu không match, thêm tin nhắn mới (từ người khác)
            if (!foundMatch) {
              if (messageId.isEmpty || !_messageIds.contains(messageId)) {
                final newMessage = {
                  '_id': messageId,
                  'sender': senderName,
                  'message': messageContent,
                  'timestamp': data['createdAt'] ?? DateTime.now().toString(),
                };
                _messages.add(newMessage);
                if (messageId.isNotEmpty) {
                  _messageIds.add(messageId);
                }
              }
            }
          });
          _scrollToBottom();
        }
      });
    }
  }

  // ======================= API CALL =======================
  Future<void> _fetchGroupDetails() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final url = Uri.parse('${ApiConfig.apiGroups}/${widget.groupId}');
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
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi khi tải dữ liệu nhóm: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  // ✅ Load tin nhắn thật từ DB
  Future<void> _fetchMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      print('❌ Token not found');
      return;
    }

    try {
      final url = Uri.parse(
        '${ApiConfig.apiGroups}/${widget.groupId}/messages',
      );
      print('📡 Fetching messages from: $url');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Decoded data: $data');

        List messageList = [];
        
        // Cố gắng các cách khác nhau để lấy messages
        if (data is Map) {
          if (data.containsKey('data') && data['data'] is List) {
            messageList = data['data'];
          } else if (data.containsKey('messages') && data['messages'] is List) {
            messageList = data['messages'];
          }
        } else if (data is List) {
          messageList = data;
        }

        print('📋 Message list length: ${messageList.length}');

        final msgs = messageList
            .map(
              (m) => {
                '_id': m['_id'] ?? m['id'] ?? '',
                'sender': m['sender']?['fullname'] ?? 'Ẩn danh',
                'message': m['content'] ?? '',
                'timestamp': m['createdAt'] ?? DateTime.now().toIso8601String(),
              },
            )
            .toList();

        setState(() {
          _messages = msgs.reversed.toList();
          _messageIds.clear();
          for (var msg in _messages) {
            final id = msg['_id'] ?? '';
            if (id.isNotEmpty) {
              _messageIds.add(id);
            }
          }
        });
        print('✅ Loaded ${_messages.length} messages');
        _scrollToBottom();
      } else {
        print('⚠️ Fetch messages failed: ${response.statusCode}');
        print('📥 Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Lỗi tải tin nhắn: $e');
    }
  }

  // ======================= CHAT UI =======================
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final msg = _messageController.text.trim();
    
    if (!_socketService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lỗi: Không kết nối đến server'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _messages.add({
        '_id': null,
        'sender': 'Bạn',
        'message': msg,
        'timestamp': DateTime.now().toString(),
      });
    });

    _socketService.sendMessage(widget.groupId, msg);
    _messageController.clear();
    _scrollToBottom();
  }

  // ======================= BUILD UI =======================
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final groupName = _group['name'] ?? 'Nhóm';

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
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _showAddMemberDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.note_alt_outlined), text: 'Ghi chú'),
            Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Thành viên'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotesTab(loc),
                _buildChatTab(),
                _buildMembersTab(),
              ],
            ),
    );
  }

  // ======================= TAB: GHI CHÚ =======================
  Widget _buildNotesTab(AppLocalizations loc) {
    if (_notes.isEmpty) {
      return _emptyState(
        icon: Icons.note_alt_outlined,
        title: 'Chưa có ghi chú nào',
        description: 'Thêm ghi chú đầu tiên cho nhóm của bạn',
        actionLabel: 'Thêm ghi chú',
        onPressed: _navigateToAddNote,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchGroupDetails,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index] as Map<String, dynamic>;
          return NoteCard(
            title: note['title'] ?? loc.noTitle,
            content: note['content'] ?? 'Không có nội dung',
            backgroundColor: _getNoteColor(index),
            groupName: _group['name'],
            hasAttachment: (note['attachments'] as List?)?.isNotEmpty ?? false,
            onTap: () async {
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

  // ======================= TAB: CHAT =======================
  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có tin nhắn',
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['sender'] == 'Bạn';
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primaryLight
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                msg['sender'],
                                style: AppTypography.textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              msg['message'],
                              style: AppTypography.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _sendMessage,
            child: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  // ======================= TAB: THÀNH VIÊN =======================
  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return _emptyState(
        icon: Icons.people_alt_outlined,
        title: 'Chưa có thành viên',
        description: 'Mời bạn bè tham gia nhóm',
        actionLabel: 'Thêm thành viên',
        onPressed: _showAddMemberDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchGroupDetails,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final m = _members[index];
          final name = m['fullname'] ?? 'Người dùng';
          final email = m['email'] ?? '';

          return AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight.withValues(
                    alpha: 0.2,
                  ),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.cardTitle),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ======================= HELPER =======================
  Widget _emptyState({
    required IconData icon,
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(title, style: AppTypography.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
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

  void _navigateToAddNote() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddNoteScreen(groupId: widget.groupId),
      ),
    );
    if (result == true) _fetchGroupDetails();
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMemberDialog(
        groupId: widget.groupId,
        onMemberAdded: _fetchGroupDetails,
      ),
    );
  }

  Future<void> _deleteNote(String noteId) async {
    // same as before
  }
}
