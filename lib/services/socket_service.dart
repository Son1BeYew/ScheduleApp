import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:schedule_app/config/api_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  List<Function()> _connectCallbacks = [];

  bool get isConnected => _isConnected;

  void connect(String token) {
    if (_socket != null && _socket!.connected) {
      return;
    }

    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ Connected to socket server');
      _isConnected = true;
      
      // Call any waiting callbacks
      for (var callback in _connectCallbacks) {
        callback();
      }
      _connectCallbacks.clear();
    });

    _socket!.onDisconnect((_) {
      print('❌ Disconnected from socket server');
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      print('❌ Connection error: $error');
      _isConnected = false;
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });

    _socket!.connect();
  }

  Future<void> waitForConnection() async {
    if (_isConnected) {
      return;
    }
    
    await Future.delayed(Duration(milliseconds: 100));
    int attempts = 0;
    while (!_isConnected && attempts < 50) {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
    }
  }

  void disconnect() {
    if (_socket != null) {
      print('🔴 Disconnecting socket...');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _connectCallbacks.clear();
      print('✅ Socket disconnected');
    }
  }

  void reconnect(String token) {
    print('🔄 Reconnecting socket...');
    disconnect();
    Future.delayed(const Duration(milliseconds: 200), () {
      connect(token);
    });
  }

  void joinGroup(String groupId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('group:join', {'groupId': groupId});
      print('📥 Joined group: $groupId');
    }
  }

  void leaveGroup(String groupId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('group:leave', {'groupId': groupId});
      print('📤 Left group: $groupId');
    }
  }

  void onNoteCreated(Function(dynamic) callback) {
    _socket?.on('note-created', callback);
  }

  void onNoteUpdated(Function(dynamic) callback) {
    _socket?.on('note-updated', callback);
  }

  void onNoteDeleted(Function(dynamic) callback) {
    _socket?.on('note-deleted', callback);
  }

  void onUserJoined(Function(dynamic) callback) {
    _socket?.on('user-joined', callback);
  }

  void onUserLeft(Function(dynamic) callback) {
    _socket?.on('user-left', callback);
  }

  void offNoteCreated() {
    _socket?.off('note-created');
  }

  void offNoteUpdated() {
    _socket?.off('note-updated');
  }

  void offNoteDeleted() {
    _socket?.off('note-deleted');
  }

  void offUserJoined() {
    _socket?.off('user-joined');
  }

  void offUserLeft() {
    _socket?.off('user-left');
  }

  void sendMessage(String groupId, String content) {
    print('📤 sendMessage called: groupId=$groupId, content=$content');
    print('   Socket connected: ${_socket?.connected}');
    print('   Socket exists: ${_socket != null}');
    
    if (_socket != null && _socket!.connected) {
      final payload = {
        'groupId': groupId,
        'content': content,
        'attachments': [],
      };
      print('📤 Emitting group:message with payload: $payload');
      _socket!.emit('group:message', payload);
      print('✅ Message sent to group $groupId');
    } else {
      print('❌ Socket not connected - cannot send message');
    }
  }

  void onGroupMessage(Function(dynamic) callback) {
    _socket?.on('group:message', callback);
  }

  void offGroupMessage() {
    _socket?.off('group:message');
  }

  void onGroupError(Function(dynamic) callback) {
    _socket?.on('group:error', callback);
  }

  void offGroupError() {
    _socket?.off('group:error');
  }

  void onGroupJoined(Function(dynamic) callback) {
    _socket?.on('group:joined', callback);
  }

  void offGroupJoined() {
    _socket?.off('group:joined');
  }

  void onGroupLeft(Function(dynamic) callback) {
    _socket?.on('group:left', callback);
  }

  void offGroupLeft() {
    _socket?.off('group:left');
  }
}
