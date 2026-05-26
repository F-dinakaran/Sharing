import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket socket;
  bool _connected = false;

  void connect(String userId) {
    if (_connected) return;

    socket = IO.io(BASE_URL, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    socket.connect();

    socket.onConnect((_) {
      _connected = true;
      socket.emit('userOnline', {'userId': userId});
    });

    socket.onDisconnect((_) => _connected = false);
  }

  void joinPublicChat() => socket.emit('joinPublicChat');

  void joinPrivateChat(String userId, String otherUserId) {
    socket.emit('joinPrivateChat', {'userId': userId, 'otherUserId': otherUserId});
  }

  void sendPublicMessage(String senderId, String text) {
    socket.emit('sendPublicMessage', {'senderId': senderId, 'text': text});
  }

  void sendPrivateMessage(String senderId, String receiverId, String text) {
    socket.emit('sendPrivateMessage', {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
    });
  }

  void emitTyping({
    required String chatType,
    required String userId,
    required String fullName,
    String? receiverId,
  }) {
    socket.emit('typing', {
      'chatType': chatType,
      'userId': userId,
      'fullName': fullName,
      if (receiverId != null) 'receiverId': receiverId,
    });
  }

  void emitStopTyping({required String chatType, required String userId, String? receiverId}) {
    socket.emit('stopTyping', {
      'chatType': chatType,
      'userId': userId,
      if (receiverId != null) 'receiverId': receiverId,
    });
  }

  void markSeen(String messageId, String userId) {
    socket.emit('messageSeen', {'messageId': messageId, 'userId': userId});
  }

  void on(String event, Function(dynamic) handler) => socket.on(event, handler);
  void off(String event) => socket.off(event);

  void disconnect() {
    socket.disconnect();
    _connected = false;
  }
}
