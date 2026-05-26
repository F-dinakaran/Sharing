import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class PrivateChatScreen extends StatefulWidget {
  final String token;
  final String userId;
  final String fullName;
  final dynamic otherUser; // {_id, fullName, role, isOnline, speciality}

  const PrivateChatScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.fullName,
    required this.otherUser,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _socket = SocketService();
  List<dynamic> _messages = [];
  String? _typingUser;
  bool _loading = true;
  late ApiService _api;
  late String _otherId;

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.token);
    _otherId = widget.otherUser['_id'];
    _init();
  }

  Future<void> _init() async {
    final messages = await _api.getPrivateMessages(_otherId);
    setState(() {
      _messages = messages;
      _loading = false;
    });

    _socket.joinPrivateChat(widget.userId, _otherId);

    _socket.on('receivePrivateMessage', (data) {
      // Only show messages for this conversation
      final senderId = data['sender']?['_id'];
      final receiverId = data['receiver']?['_id'];
      final isThisConvo = (senderId == widget.userId && receiverId == _otherId) ||
          (senderId == _otherId && receiverId == widget.userId);
      if (isThisConvo) {
        setState(() => _messages.add(data));
        _scrollToBottom();
        // Mark as seen
        _socket.markSeen(data['_id'], widget.userId);
      }
    });

    _socket.on('messageEdited', (data) {
      setState(() {
        final idx = _messages.indexWhere((m) => m['_id'] == data['_id']);
        if (idx != -1) _messages[idx] = data;
      });
    });

    _socket.on('messageDeleted', (data) {
      setState(() {
        final idx = _messages.indexWhere((m) => m['_id'] == data['_id']);
        if (idx != -1) _messages[idx] = data;
      });
    });

    _socket.on('typing', (data) {
      if (data['fullName'] != widget.fullName) {
        setState(() => _typingUser = data['fullName']);
      }
    });

    _socket.on('stopTyping', (_) => setState(() => _typingUser = null));

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _socket.sendPrivateMessage(widget.userId, _otherId, text);
    _socket.emitStopTyping(
        chatType: 'private', userId: widget.userId, receiverId: _otherId);
    _controller.clear();
  }

  @override
  void dispose() {
    _socket.off('receivePrivateMessage');
    _socket.off('messageEdited');
    _socket.off('messageDeleted');
    _socket.off('typing');
    _socket.off('stopTyping');
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherName = widget.otherUser['fullName'] ?? 'User';
    final isOnline = widget.otherUser['isOnline'] == true;
    final role = widget.otherUser['role'] ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                otherName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role == 'doctor' ? 'Dr. $otherName' : otherName,
                    style: const TextStyle(fontSize: 15)),
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: isOnline ? Colors.greenAccent : Colors.white38),
                    const SizedBox(width: 4),
                    Text(isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
                ),
                if (_typingUser != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$_typingUser is typing...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ),
                _buildInput(),
              ],
            ),
    );
  }

  Widget _buildBubble(dynamic msg) {
    final isMe = msg['sender']?['_id'] == widget.userId;
    final isDeleted = msg['deleted'] == true;
    final text = msg['text'] ?? '';
    final seenBy = List.from(msg['seenBy'] ?? []);
    final seenByOther = seenBy.any((id) => id == _otherId || id['_id'] == _otherId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFE53935) : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg['edited'] == true && !isDeleted)
                    Text('edited · ',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  Icon(
                    seenByOther ? Icons.done_all : Icons.done,
                    size: 13,
                    color: seenByOther ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (_) {
                _socket.emitTyping(
                  chatType: 'private',
                  userId: widget.userId,
                  fullName: widget.fullName,
                  receiverId: _otherId,
                );
              },
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Message...',
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFFE53935),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
