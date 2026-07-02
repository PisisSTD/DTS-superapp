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

class GroupChatScreen extends StatefulWidget {
  final ChatGroup group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _service = FirebaseService();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  
  ChatMessage? _replyingTo;
  late Stream<List<ChatMessage>> _messageStream;
  bool _isUploading = false;
  bool _isRecordingVoice = false;
  int _limit = 45;

  @override
  void initState() {
    super.initState();
    _updateStream();
    _scrollCtrl.addListener(_scrollListener);
  }

  void _updateStream() {
    setState(() {
      _messageStream = _service.getGroupMessages(widget.group.id, limit: _limit);
    });
  }

  void _scrollListener() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() {
      _limit += 45;
      _messageStream = _service.getGroupMessages(widget.group.id, limit: _limit);
    });
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- ЛОГИКА ОТПРАВКИ ---

  void _sendText() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();
    final replyData = _replyingTo != null ? {'text': _replyingTo!.text, 'senderName': _replyingTo!.senderName} : null;
    setState(() => _replyingTo = null);
    await _service.sendGroupMessage(widget.group.id, text, replyTo: replyData);
  }

  void _uploadAndSendMedia(File file, String type) async {
    setState(() => _isUploading = true);
    final url = await _service.uploadMedia(file, type);
    if (url != null) {
      await _service.sendGroupMessage(widget.group.id, '', type: type, mediaUrl: url);
    }
    if (mounted) setState(() => _isUploading = false);
  }

  // --- ГОЛОСОВЫЕ ---

  void _startVoiceRecord() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/group_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecordingVoice = true);
    }
  }

  void _stopVoiceRecord() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecordingVoice = false);
    if (path != null) _uploadAndSendMedia(File(path), 'voice');
  }

  // --- СКАЧИВАНИЕ ---

  Future<void> _downloadFile(String url, String type) async {
    await Permission.storage.request();
    try {
      final dir = await getExternalStorageDirectory();
      final String ext = type == 'image' ? 'jpg' : (type == 'video' || type == 'circle' ? 'mp4' : 'file');
      final savePath = "${dir!.path}/UVZ_Group_${DateTime.now().millisecondsSinceEpoch}.$ext";
      await Dio().download(url, savePath);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Сохранено: $savePath'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка скачивания')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${widget.group.members.length} участников', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
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
    final String decryptedText = _service.decryptMessage(msg.text, widget.group.id);
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
              if (!isMe) Text(msg.senderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              if (msg.replyTo != null) _buildReplyBadge(msg.replyTo!),
              _buildMediaContent(msg),
              if (decryptedText.isNotEmpty) SelectableText(decryptedText, style: const TextStyle(color: Colors.black, fontSize: 15)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  if (msg.type != 'text' && msg.type != 'voice') IconButton(icon: const Icon(Icons.download, size: 16), onPressed: () => _downloadFile(msg.mediaUrl!, msg.type), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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
    if (msg.type == 'video') return Container(height: 150, width: double.infinity, color: Colors.black12, child: const Icon(Icons.videocam, color: Colors.white));
    return const SizedBox.shrink();
  }

  Widget _buildReplyBadge(Map<String, dynamic> reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: const Border(left: BorderSide(color: Colors.blueGrey, width: 3))),
      child: Text(_service.decryptMessage(reply['text'] ?? '', widget.group.id), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _buildReplyPreview(),
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
                        decoration: const InputDecoration(hintText: 'Сообщение в группу...', border: InputBorder.none),
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

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_service.decryptMessage(_replyingTo!.text, widget.group.id), maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyingTo = null)),
        ],
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
