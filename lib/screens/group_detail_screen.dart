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
    _initializeData();
  }

  Future<void> _initializeData() async {
    print('🟦 _initializeData started');

    print('1️⃣ Fetching group details...');
    await _fetchGroupDetails();
    print('1️⃣ fetchGroupDetails complete');

    print('2️⃣ Calling setupSocketListeners...');
    await _setupSocketListeners();
    print('2️⃣ setupSocketListeners complete');

    print('3️⃣ Fetching messages...');
    await _fetchMessages();
    print('3️⃣ fetchMessages complete');

    print('🟩 _initializeData complete');
  }

  @override
  void dispose() {
    _socketService.offNoteCreated();
    _socketService.offNoteUpdated();
    _socketService.offNoteDeleted();
    _socketService.offGroupMessage();
    _socketService.offGroupError();
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
      print('🔵 Setting up socket listeners...');
      _socketService.connect(token);

      // Wait for socket to connect before joining group
      print('⏳ Waiting for socket connection...');
      await _socketService.waitForConnection();
      print('✅ Socket connected, joining group...');

      _socketService.joinGroup(widget.groupId);

      // Wait a bit for server to process joinGroup
      print('⏳ Waiting for joinGroup to be processed...');
      await Future.delayed(const Duration(milliseconds: 300));

      _socketService.onNoteCreated((data) {
        print('🔔 Note created: ${data['note']['title']}');
        _fetchGroupDetails();
      });

      _socketService.onGroupMessage((data) {
        print('💬 Realtime Message: $data');
        if (mounted) {
          final messageId = data['_id'] ?? '';
          final messageContent = data['content'] ?? '';
          final senderName = data['sender']?['fullname'] ?? 'Ẩn danh';

          setState(() {
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

            if (!foundMatch) {
              if (messageId.isNotEmpty && !_messageIds.contains(messageId)) {
                final newMessage = {
                  '_id': messageId,
                  'sender': senderName,
                  'message': messageContent,
                  'timestamp': data['createdAt'] ?? DateTime.now().toString(),
                };
                _messages.add(newMessage);
                _messageIds.add(messageId);
              }
            }
          });
          _scrollToBottom();
        }
      });

      _socketService.onGroupError((data) {
        print('❌ Group error: $data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${data['message'] ?? 'Unknown error'}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });

      print('✅ Socket listeners setup complete');
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

  Future<void> _fetchMessages() async {
    print('📨 _fetchMessages called, groupId: ${widget.groupId}');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      print('❌ Token not found');
      return;
    }

    print('✅ Token found: ${token.substring(0, 20)}...');

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
      print('📥 Response body length: ${response.body.length}');
      if (response.body.length < 500) {
        print('📥 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Decoded data type: ${data.runtimeType}');
        print(
          '📦 Data keys: ${data is Map ? data.keys.toList() : "not a map"}',
        );

        List messageList = [];

        if (data is Map) {
          print('  ℹ️ Data is a Map');
          if (data.containsKey('data')) {
            print('  ✅ Found "data" key, type: ${data['data'].runtimeType}');
            if (data['data'] is List) {
              messageList = data['data'];
            }
          } else if (data.containsKey('messages')) {
            print('  ✅ Found "messages" key');
            messageList = data['messages'];
          } else {
            print('  ⚠️ No "data" or "messages" key found!');
          }
        } else if (data is List) {
          print('  ℹ️ Data is a List');
          messageList = data;
        } else {
          print('  ❌ Unknown data type!');
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

        print('🔵 Setting messages via setState...');
        setState(() {
          _messages = msgs;
          print('   _messages count after assignment: ${_messages.length}');

          _messageIds.clear();
          for (var msg in _messages) {
            final id = msg['_id'] ?? '';
            if (id.isNotEmpty) {
              _messageIds.add(id);
            }
          }
          print('   _messageIds count: ${_messageIds.length}');
        });
        print('✅ Loaded ${_messages.length} messages (oldest first)');
        print('✅ Widget will rebuild now');
        _scrollToBottom();
        print('✅ Scroll completed');
      } else {
        print('⚠️ Fetch messages failed: ${response.statusCode}');
        print('📥 Response: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _fetchMessages: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

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
    print('🔵 _sendMessage called');

    if (_messageController.text.trim().isEmpty) {
      print('⚠️ Message is empty');
      return;
    }

    final msg = _messageController.text.trim();
    print('📝 Message text: $msg');
    print('🔌 Socket connected: ${_socketService.isConnected}');

    if (!_socketService.isConnected) {
      print('❌ Socket not connected, showing error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lỗi: Không kết nối đến server'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    print('✅ Socket connected, adding message to UI');
    setState(() {
      _messages.add({
        '_id': null,
        'sender': 'Bạn',
        'message': msg,
        'timestamp': DateTime.now().toString(),
      });
    });

    print('📤 Calling socketService.sendMessage');
    _socketService.sendMessage(widget.groupId, msg);
    _messageController.clear();
    _scrollToBottom();
    print('✅ Message processing complete');
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giải tán nhóm'),
        content: const Text(
          'Bạn có chắc muốn giải tán nhóm này? Tất cả tin nhắn sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroup();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Giải tán'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final url = Uri.parse('${ApiConfig.apiGroups}/${widget.groupId}');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nhóm đã được giải tán'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to delete group');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _showDeleteGroupDialog,
            tooltip: 'Giải tán nhóm',
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
        Container(
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
        ),
      ],
    );
  }

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
      final url = Uri.parse(
        '${ApiConfig.apiGroups}/${widget.groupId}/notes/$noteId',
      );
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
          _fetchGroupDetails();
        }
      } else {
        throw Exception('Failed to delete note');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
