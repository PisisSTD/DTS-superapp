import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppUser {
  final String uid;
  final String email;
  final String role;
  final String department;
  final String fullName;
  final String status;
  final Timestamp? lastSeen;
  final String? fcmToken;

  AppUser({
    required this.uid, 
    required this.email, 
    required this.role, 
    required this.department, 
    required this.fullName,
    this.status = 'offline',
    this.lastSeen,
    this.fcmToken,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      department: data['department'] ?? '',
      fullName: data['fullName'] ?? '',
      status: data['status'] ?? 'offline',
      lastSeen: data['lastSeen'],
      fcmToken: data['fcmToken'],
    );
  }
}

class ChatGroup {
  final String id;
  final String name;
  final String adminId;
  final List<String> members;
  final String? lastMessage;
  final Timestamp? lastMessageTime;

  ChatGroup({
    required this.id,
    required this.name,
    required this.adminId,
    required this.members,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory ChatGroup.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ChatGroup(
      id: doc.id,
      name: data['name'] ?? '',
      adminId: data['adminId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'],
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text; 
  final String type;
  final String? mediaUrl;
  final Timestamp createdAt;
  final bool isRead;
  final Map<String, dynamic>? replyTo;

  ChatMessage({
    required this.id, 
    required this.senderId, 
    required this.senderName,
    required this.text, 
    this.type = 'text',
    this.mediaUrl,
    required this.createdAt,
    this.isRead = false,
    this.replyTo,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Сотрудник',
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      mediaUrl: data['mediaUrl'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      replyTo: data['replyTo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'createdAt': createdAt,
      'isRead': isRead,
      'replyTo': replyTo,
    };
  }
}

class TransportRequest {
  final String id;
  final String userId;
  final String userEmail;
  final String transportType;
  final String date;
  final String timeStart;
  final String duration;
  final String purpose;
  final String route;
  final String department;
  final String? comment;
  final String status;
  final Timestamp? signatureTimestamp;
  final Timestamp? createdAt;

  TransportRequest({
    required this.id, required this.userId, required this.userEmail, required this.transportType,
    required this.date, required this.timeStart, required this.duration, required this.purpose,
    required this.route, required this.department, this.comment, required this.status,
    this.signatureTimestamp, this.createdAt
  });

  factory TransportRequest.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TransportRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      transportType: data['transportType'] ?? '',
      date: data['date'] ?? '',
      timeStart: data['timeStart'] ?? '',
      duration: data['duration'] ?? '',
      purpose: data['purpose'] ?? '',
      route: data['route'] ?? '',
      department: data['department'] ?? '',
      comment: data['comment'],
      status: data['status'] ?? 'отправлено',
      signatureTimestamp: data['signatureTimestamp'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId, 
      'userEmail': userEmail, 
      'transportType': transportType,
      'date': date, 
      'timeStart': timeStart, 
      'duration': duration,
      'purpose': purpose, 
      'route': route, 
      'department': department,
      'comment': comment, 
      'status': status,
      'signatureTimestamp': signatureTimestamp ?? FieldValue.serverTimestamp(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'отправлено': return Colors.blue;
      case 'принято': return Colors.green;
      case 'отклонено': return Colors.red;
      case 'транспорт выделен': return Colors.orange;
      case 'выполнено': return Colors.grey;
      default: return Colors.black;
    }
  }
}

enum CallStatus { dialing, ringing, active, rejected, missed, ended }

class CallSession {
  final String id;
  final String callerId;
  final String callerName;
  final String receiverId;
  final CallStatus status;
  final bool isVideo;
  final Timestamp createdAt;

  CallSession({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.status,
    this.isVideo = false,
    required this.createdAt,
  });

  factory CallSession.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return CallSession(
      id: doc.id,
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      receiverId: data['receiverId'] ?? '',
      status: CallStatus.values.firstWhere((e) => e.toString().split('.').last == data['status'], orElse: () => CallStatus.ended),
      isVideo: data['isVideo'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
