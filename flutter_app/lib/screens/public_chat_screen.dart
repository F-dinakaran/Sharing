import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'private_chat_screen.dart';

class PublicChatScreen extends StatefulWidget {
  final String token;
  final String userId;
  final String fullName;
  final String role;

  const PublicChatScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.fullName,
    required this.role,
  });

  @override
  State<PublicChatScreen> createState() => _PublicChatScreenState();
}

class _PublicChatScreenState extends State<PublicChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _socket = SocketService();
  List<dynamic> _messages = [];
  List<dynamic> _users = [];
  String? _typingUser;
  bool _loading = true;
  late ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.token);
    _init();
  }

  Future<void> _init() async {
    final messages = await _api.getPublicMessages();
    final users = await _api.getUsers();

    setState(() {
      _messages = messages;
      _users = users;
      _loading = false;
    });

    _socket.connect(widget.userId);
    _socket.joinPublicChat();

    _socket.on('receivePublicMessage', (data) {
      setState(() => _messages.add(data));
      _scrollToBottom();
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
    _socket.sendPublicMessage(widget.userId, text);
    _socket.emitStopTyping(chatType: 'public', userId: widget.userId);
    _controller.clear();
  }

  void _openPrivateChat(dynamic user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          token: widget.token,
          userId: widget.userId,
          fullName: widget.fullName,
          otherUser: user,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socket.off('receivePublicMessage');
    _socket.off('typing');
    _socket.off('stopTyping');
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Chat'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Message someone',
            onPressed: () => _showUsersSheet(),
          ),
        ],
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
    final senderName = msg['sender']?['fullName'] ?? 'Unknown';
    final role = msg['sender']?['role'] ?? '';
    final text = msg['text'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(senderName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: role == 'doctor'
                          ? const Color(0xFFE53935).withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 10,
                        color: role == 'doctor' ? const Color(0xFFE53935) : Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
          if (msg['edited'] == true && !isDeleted)
            Padding(
              padding: EdgeInsets.only(
                  left: isMe ? 0 : 12, right: isMe ? 12 : 0, top: 2),
              child: Text('edited',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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
                  chatType: 'public',
                  userId: widget.userId,
                  fullName: widget.fullName,
                );
              },
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Share with the community...',
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

  void _showUsersSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Message Someone',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i];
                final role = u['role'] ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: role == 'doctor'
                        ? const Color(0xFFE53935)
                        : Colors.blue,
                    child: Text(
                      (u['fullName'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(u['fullName'] ?? ''),
                  subtitle: Text(role == 'doctor'
                      ? 'Dr · ${u['speciality'] ?? ''}'
                      : 'Patient'),
                  trailing: Icon(
                    u['isOnline'] == true
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 10,
                    color: u['isOnline'] == true ? Colors.green : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openPrivateChat(u);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
