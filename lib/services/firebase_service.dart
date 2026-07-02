import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/app_models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _projectId = 'cars-9aa2a'; 

  final String _cloudName = 'drjgshmqw';
  final String _uploadPreset = 'uvz_preset';

  String get currentUserUid => _auth.currentUser?.uid ?? '';

  // --- СТАТУС ПОЛЬЗОВАТЕЛЯ ---

  Future<void> updateUserStatus(String status) async {
    if (_auth.currentUser != null) {
      await _db.collection('users').doc(_auth.currentUser!.uid).update({
        'status': status,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- МЕССЕНДЖЕР И ШИФРОВАНИЕ ---

  String encryptMessage(String plainText, String keySeed) {
    if (plainText.isEmpty) return "";
    final key = encrypt.Key.fromUtf8(keySeed.padRight(32).substring(0, 32));
    final iv = encrypt.IV.fromUtf8(keySeed.padRight(16).substring(0, 16)); 
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.encrypt(plainText, iv: iv).base64;
  }

  String decryptMessage(String encryptedBase64, String keySeed) {
    if (encryptedBase64.isEmpty || encryptedBase64 == '[Медиа]' || !encryptedBase64.contains('==') && encryptedBase64.length < 15) {
      return encryptedBase64;
    }
    try {
      final key = encrypt.Key.fromUtf8(keySeed.padRight(32).substring(0, 32));
      final iv = encrypt.IV.fromUtf8(keySeed.padRight(16).substring(0, 16)); 
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt64(encryptedBase64, iv: iv);
    } catch (e) { return encryptedBase64; }
  }

  String getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  // Личные сообщения
  Future<void> sendMessage(String receiverId, String text, {String type = 'text', String? mediaUrl, Map<String, dynamic>? replyTo}) async {
    final String senderId = currentUserUid;
    final String chatId = getChatId(senderId, receiverId);
    
    final senderDoc = await _db.collection('users').doc(senderId).get();
    final String senderName = senderDoc.get('fullName') ?? 'Сотрудник';
    
    final String encryptedText = encryptMessage(text, chatId);

    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'text': encryptedText,
      'type': type,
      'mediaUrl': mediaUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'replyTo': replyTo,
    });

    await _db.collection('chats').doc(chatId).set({
      'lastMessage': type == 'text' ? encryptedText : '[Медиа]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [senderId, receiverId],
    }, SetOptions(merge: true));

    _sendNotificationToUser(receiverId, senderId, type);
  }

  Future<void> markMessagesAsRead(String receiverId) async {
    final String chatId = getChatId(currentUserUid, receiverId);
    final messages = await _db.collection('chats').doc(chatId).collection('messages')
        .where('senderId', isEqualTo: receiverId)
        .where('isRead', isEqualTo: false).get();
    for (var doc in messages.docs) { await doc.reference.update({'isRead': true}); }
  }

  Stream<List<ChatMessage>> getMessages(String receiverId, {int limit = 45}) {
    final String chatId = getChatId(currentUserUid, receiverId);
    return _db.collection('chats').doc(chatId).collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((sn) => sn.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  // Групповые сообщения
  Future<void> createGroup(String groupName, List<String> memberIds) async {
    if (!memberIds.contains(currentUserUid)) {
      memberIds.add(currentUserUid);
    }

    await _db.collection('groups').add({
      'name': groupName,
      'members': memberIds,
      'createdBy': currentUserUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Группа создана',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendGroupMessage(String groupId, String text, {String type = 'text', String? mediaUrl, Map<String, dynamic>? replyTo}) async {
    final senderDoc = await _db.collection('users').doc(currentUserUid).get();
    final String senderName = senderDoc.get('fullName') ?? 'Сотрудник';
    
    final String encryptedText = encryptMessage(text, groupId);

    await _db.collection('groups').doc(groupId).collection('messages').add({
      'senderId': currentUserUid,
      'senderName': senderName,
      'text': encryptedText,
      'type': type,
      'mediaUrl': mediaUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'replyTo': replyTo,
    });
    
    await _db.collection('groups').doc(groupId).update({
      'lastMessage': type == 'text' ? encryptedText : '[Медиа]', 
      'lastMessageTime': FieldValue.serverTimestamp()
    });

    _sendNotificationToGroup(groupId, currentUserUid, senderName, type);
  }

  void _sendNotificationToGroup(String groupId, String senderId, String senderName, String type) async {
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final String groupName = groupDoc.get('name') ?? 'Группа';
    final List<dynamic> members = groupDoc.get('members') ?? [];

    for (var memberId in members) {
      if (memberId == senderId) continue;
      final memberDoc = await _db.collection('users').doc(memberId.toString()).get();
      if (memberDoc.exists) {
        final token = memberDoc.data()?['fcmToken'];
        if (token != null) {
          String actionText = type == 'text' ? 'отправил(а) сообщение' : 'отправил(а) медиафайл';
          await _sendPushV1(token, groupName, "$senderName $actionText в $groupName");
        }
      }
    }
  }

  Stream<List<ChatMessage>> getGroupMessages(String groupId, {int limit = 45}) {
    return _db.collection('groups').doc(groupId).collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((sn) => sn.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  // --- МЕДИА ---

  Future<String?> uploadMedia(File file, String type) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/upload');
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        var json = jsonDecode(responseData);
        return json['secure_url'];
      }
      return null;
    } catch (e) { return null; }
  }

  // --- АВТОРИЗАЦИЯ И ПОЛЬЗОВАТЕЛИ ---

  Future<UserCredential?> signIn(String email, String password) async {
    UserCredential res = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await updateUserStatus('online');
    return res;
  }

  Future<UserCredential?> signUp(String email, String password, String fullName, String department, String role) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (res.user != null) {
        await _db.collection('users').doc(res.user!.uid).set({
          'email': email,
          'fullName': fullName,
          'department': department,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'online',
        });
      }
      return res;
    } catch (e) { rethrow; }
  }

  Future<void> signOut() async {
    await updateUserStatus('offline');
    await _auth.signOut();
  }

  Stream<AppUser> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => AppUser.fromFirestore(doc));
  }

  Stream<List<AppUser>> getAllUsers() {
    return _db.collection('users').snapshots().map((sn) => 
      sn.docs.where((doc) => doc.id != _auth.currentUser?.uid)
      .map((doc) => AppUser.fromFirestore(doc)).toList()
    );
  }

  Stream<List<ChatGroup>> getMyGroups() {
    return _db.collection('groups').where('members', arrayContains: currentUserUid).snapshots().map((sn) => sn.docs.map((doc) => ChatGroup.fromFirestore(doc)).toList());
  }

  Future<AppUser?> getCurrentAppUser() async {
    if (_auth.currentUser == null) return null;
    DocumentSnapshot doc = await _db.collection('users').doc(_auth.currentUser!.uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  // --- СИСТЕМНОЕ И ЗАЯВКИ ---

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    String? token = await messaging.getToken();
    if (token != null) {
      await _db.collection('users').doc(currentUserUid).set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  Future<String> _getAccessToken() async {
    final serviceAccountJson = await rootBundle.loadString('assets/service-account.json');
    final accountCredentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
    return (await auth.clientViaServiceAccount(accountCredentials, ['https://www.googleapis.com/auth/firebase.messaging'])).credentials.accessToken.data;
  }

  Future<void> _sendPushV1(String token, String title, String body) async {
    try {
      final String accessToken = await _getAccessToken();
      await http.post(Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode({'message': {'token': token, 'notification': {'title': title, 'body': body}}}),
      );
    } catch (e) {}
  }

  void _sendNotificationToUser(String receiverId, String senderId, String type) async {
    final receiverDoc = await _db.collection('users').doc(receiverId).get();
    final senderDoc = await _db.collection('users').doc(senderId).get();
    if (receiverDoc.exists && senderDoc.exists) {
      final token = receiverDoc.data()?['fcmToken'];
      if (token != null) await _sendPushV1(token, senderDoc.get('fullName'), type == 'text' ? 'Новое сообщение' : 'Медиафайл');
    }
  }

  Future<void> createRequest(TransportRequest request) async {
    await _db.collection('requests').add(request.toMap());
  }

  Stream<List<TransportRequest>> getUserRequests() {
    if (_auth.currentUser == null) return Stream.value([]);
    return _db.collection('requests').where('userId', isEqualTo: currentUserUid).orderBy('createdAt', descending: true).snapshots().map((sn) => sn.docs.map((doc) => TransportRequest.fromFirestore(doc)).toList());
  }

  Stream<List<TransportRequest>> getAllRequests() {
    return _db.collection('requests').orderBy('createdAt', descending: true).snapshots().map((sn) => sn.docs.map((doc) => TransportRequest.fromFirestore(doc)).toList());
  }

  Future<void> updateRequestStatus(TransportRequest request, String status) async {
    await _db.collection('requests').doc(request.id).update({'status': status});
  }

  Future<bool> verifySignature(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
        return true;
      }
      return false;
    } catch (e) { return false; }
  }
}
