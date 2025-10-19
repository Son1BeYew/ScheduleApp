import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:schedule_app/config/api_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

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

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }

  void joinGroup(String groupId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join-group', groupId);
      print('📥 Joined group: $groupId');
    }
  }

  void leaveGroup(String groupId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave-group', groupId);
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

  void sendMessage(String groupId, String message) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('send-message', {
        'groupId': groupId,
        'message': message,
      });
      print('📨 Message sent to group $groupId');
    }
  }

  void onMessageReceived(Function(dynamic) callback) {
    _socket?.on('message-received', callback);
  }

  void offMessageReceived() {
    _socket?.off('message-received');
  }

  void onMessageSent(Function(dynamic) callback) {
    _socket?.on('message-sent', callback);
  }

  void offMessageSent() {
    _socket?.off('message-sent');
  }

  void onMessageError(Function(dynamic) callback) {
    _socket?.on('message-error', callback);
  }

  void offMessageError() {
    _socket?.off('message-error');
  }
}
