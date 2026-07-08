import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'video_circle_recorder.dart';
import '../widgets/circle_video_player.dart';
import '../widgets/voice_message_player.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final AppUser receiver;
  const ChatScreen({super.key, required this.receiver});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _service = FirebaseService();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  
  ChatMessage? _replyingTo;
  late Stream<List<ChatMessage>> _messageStream;
  late String _chatId;
  bool _isUploading = false;
  bool _isRecordingVoice = false;
  int _limit = 45;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _chatId = _service.getChatId(_service.currentUserUid, widget.receiver.uid);
    _updateStream();
    _service.markMessagesAsRead(widget.receiver.uid);
    _scrollCtrl.addListener(_scrollListener);
  }

  void _updateStream() {
    setState(() {
      _messageStream = _service.getMessages(widget.receiver.uid, limit: _limit);
    });
  }

  void _scrollListener() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isFetching) return;
    _isFetching = true;
    setState(() {
      _limit += 45;
      _updateStream();
    });
    Future.delayed(const Duration(milliseconds: 500), () => _isFetching = false);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _sendText() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();
    final replyData = _replyingTo != null ? {'text': _replyingTo!.text, 'senderName': _replyingTo!.senderName} : null;
    setState(() => _replyingTo = null);
    await _service.sendMessage(widget.receiver.uid, text, replyTo: replyData);
  }

  void _uploadAndSendMedia(File file, String type) async {
    setState(() => _isUploading = true);
    final url = await _service.uploadMedia(file, type);
    if (url != null) {
      await _service.sendMessage(widget.receiver.uid, '', type: type, mediaUrl: url);
    }
    if (mounted) setState(() => _isUploading = false);
  }

  void _startVoiceRecord() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecordingVoice = true);
    }
  }

  void _stopVoiceRecord() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecordingVoice = false);
    if (path != null) _uploadAndSendMedia(File(path), 'voice');
  }

  Future<void> _downloadFile(String url, String type) async {
    if (Platform.isAndroid) await Permission.storage.request();
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final String ext = type == 'image' ? 'jpg' : (type == 'video' || type == 'circle' ? 'mp4' : 'file');
      final savePath = "${dir!.path}/UVZ_Chat_${DateTime.now().millisecondsSinceEpoch}.$ext";
      await Dio().download(url, savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Platform.isIOS ? 'Сохранено в Файлы' : 'Сохранено: $savePath'), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка скачивания')));
    }
  }

  void _startCall(bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          receiverId: widget.receiver.uid,
          isVideo: isVideo,
          isIncoming: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: StreamBuilder<AppUser>(
          stream: _service.getUserStream(widget.receiver.uid),
          initialData: widget.receiver,
          builder: (context, snapshot) {
            final user = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(user.status == 'online' ? 'в сети' : 'не в сети', 
                  style: TextStyle(fontSize: 12, color: user.status == 'online' ? Colors.greenAccent : Colors.white70)),
              ],
            );
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone), onPressed: () => _startCall(false)),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () => _startCall(true)),
        ],
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(color: Colors.orange),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessageItem(messages[index]),
                );
              },
            ),
          ),
          _buildInputPanel(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final bool isMe = msg.senderId == _service.currentUserUid;
    final String decryptedText = _service.decryptMessage(msg.text, _chatId);
    final String time = DateFormat('HH:mm').format(msg.createdAt.toDate());

    return Dismissible(
      key: Key(msg.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async { setState(() => _replyingTo = msg); return false; },
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.reply, color: Colors.blueGrey)),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.circular(12).copyWith(
              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
              bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(12),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.replyTo != null) _buildReplyBadge(msg.replyTo!, _chatId),
              _buildMediaContent(msg),
              if (decryptedText.isNotEmpty) SelectableText(decryptedText, style: const TextStyle(color: Colors.black, fontSize: 15)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  if (msg.type != 'text' && msg.type != 'voice') 
                    IconButton(
                      icon: const Icon(Icons.download, size: 16), 
                      onPressed: () => _downloadFile(msg.mediaUrl!, msg.type), 
                      padding: EdgeInsets.zero, 
                      constraints: const BoxConstraints()
                    ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(msg.isRead ? Icons.done_all : Icons.done, size: 14, color: msg.isRead ? Colors.blue : Colors.grey),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(ChatMessage msg) {
    if (msg.type == 'image') return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(msg.mediaUrl!));
    if (msg.type == 'circle') return CircleVideoPlayer(url: msg.mediaUrl!);
    if (msg.type == 'voice') return VoiceMessagePlayer(url: msg.mediaUrl!);
    return const SizedBox.shrink();
  }

  Widget _buildReplyBadge(Map<String, dynamic> reply, String key) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: const Border(left: BorderSide(color: Colors.blueGrey, width: 3))),
      child: Text(_service.decryptMessage(reply['text'] ?? '', key), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_service.decryptMessage(_replyingTo!.text, _chatId), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyingTo = null)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey), onPressed: _showMediaMenu),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFFF5F6F7), borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageCtrl,
                        keyboardType: TextInputType.multiline,
                        maxLines: 5, minLines: 1,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(hintText: 'Сообщение...', border: InputBorder.none),
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.blueGrey), onPressed: () async {
                    final file = await Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoCircleRecorder()));
                    if (file != null) _uploadAndSendMedia(file, 'circle');
                  }),
                  GestureDetector(
                    onLongPress: _startVoiceRecord,
                    onLongPressUp: _stopVoiceRecord,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.mic, color: _isRecordingVoice ? Colors.red : Colors.blueGrey),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: Colors.blueGrey), onPressed: _sendText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaMenu() {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.image), title: const Text('Фото'), onTap: () async { Navigator.pop(context); final img = await _picker.pickImage(source: ImageSource.gallery); if (img != null) _uploadAndSendMedia(File(img.path), 'image'); }),
      ListTile(leading: const Icon(Icons.videocam), title: const Text('Видео'), onTap: () async { Navigator.pop(context); final vid = await _picker.pickVideo(source: ImageSource.gallery); if (vid != null) _uploadAndSendMedia(File(vid.path), 'video'); }),
      ListTile(leading: const Icon(Icons.file_present), title: const Text('Файл'), onTap: () async { Navigator.pop(context); final res = await FilePicker.pickFiles(); if (res != null) _uploadAndSendMedia(File(res.files.single.path!), 'file'); }),
    ])));
  }
}
