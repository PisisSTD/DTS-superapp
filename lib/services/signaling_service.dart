import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'firebase_service.dart';

class SignalingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  String? currentRoomId;
  Function(MediaStream stream)? onAddRemoteStream;
  Function()? onCallEnded;

  // ТВОЙ КОНФИГ VPS (БЕЗ GOOGLE)
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:161.104.45.232:3478',
          'turn:161.104.45.232:3478'
        ],
        'username': '***',
        'credential': '***'
      },
    ],
    'sdpSemantics': 'unified-plan'
  };

  Future<String> createRoom(String receiverId, bool isVideo) async {
    peerConnection = await createPeerConnection(configuration);
    registerPeerConnectionListeners();

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {
        'facingMode': 'user',
        'width': 1280,
        'height': 720,
      } : false,
    });

    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    var callDoc = _db.collection('calls').doc();
    currentRoomId = callDoc.id;

    peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      callDoc.collection('callerCandidates').add(candidate.toMap());
    };

    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    await callDoc.set({
      'offer': offer.toMap(),
      'callerId': _firebaseService.currentUserUid,
      'callerName': (await _firebaseService.getCurrentAppUser())?.fullName ?? 'Сотрудник',
      'receiverId': receiverId,
      'isVideo': isVideo,
      'status': 'dialing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    callDoc.snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (peerConnection?.getRemoteDescription() == null && data['answer'] != null) {
          var answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
          await peerConnection?.setRemoteDescription(answer);
        }
        if (data['status'] == 'ended' || data['status'] == 'rejected') {
          if (onCallEnded != null) onCallEnded!();
        }
      }
    });

    // ИСПРАВЛЕНО: Добавлена проверка на null для receiverCandidates
    callDoc.collection('receiverCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            peerConnection?.addCandidate(RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex']
            ));
          }
        }
      }
    });

    return callDoc.id;
  }

  Future<void> joinRoom(String roomId) async {
    currentRoomId = roomId;
    var callDoc = _db.collection('calls').doc(roomId);
    var callSnapshot = await callDoc.get();
    if (!callSnapshot.exists) return;
    var callData = callSnapshot.data()!;

    peerConnection = await createPeerConnection(configuration);
    registerPeerConnectionListeners();

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': callData['isVideo'] ? {'facingMode': 'user'} : false
    });

    localStream!.getTracks().forEach((track) => peerConnection!.addTrack(track, localStream!));

    peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      callDoc.collection('receiverCandidates').add(candidate.toMap());
    };

    // ИСПРАВЛЕНО: Добавлена проверка на null для callerCandidates
    callDoc.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            peerConnection?.addCandidate(RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex']
            ));
          }
        }
      }
    });

    callDoc.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'ended' || data['status'] == 'rejected') {
          if (onCallEnded != null) onCallEnded!();
        }
      }
    });

    var offer = callData['offer'];
    await peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
    var answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    await callDoc.update({'answer': answer.toMap(), 'status': 'active'});
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        if (onAddRemoteStream != null) onAddRemoteStream!(remoteStream!);
      }
    };

    peerConnection?.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (onCallEnded != null) onCallEnded!();
      }
    };
  }

  Future<void> hangUp() async {
    if (localStream != null) {
      localStream!.getTracks().forEach((track) => track.stop());
      await localStream!.dispose();
    }
    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
      await remoteStream!.dispose();
    }
    if (peerConnection != null) await peerConnection!.close();

    if (currentRoomId != null) {
      try {
        await _db.collection('calls').doc(currentRoomId).update({'status': 'ended'});
      } catch (e) {}
    }

    localStream = null;
    remoteStream = null;
    peerConnection = null;
    currentRoomId = null;
  }
}