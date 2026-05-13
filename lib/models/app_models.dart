import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppUser {
  final String uid;
  final String email;
  final String role;
  final String department;
  final String fullName;

  AppUser({required this.uid, required this.email, required this.role, required this.department, required this.fullName});

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      department: data['department'] ?? '',
      fullName: data['fullName'] ?? '',
    );
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

  // Хелпер для получения цвета статуса
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
