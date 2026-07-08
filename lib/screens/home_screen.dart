import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'my_requests_screen.dart';
import 'dispatcher_requests_screen.dart';
import 'login_screen.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseService _service = FirebaseService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialStatus();
    _setupCallListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkInitialStatus() {
    if (FirebaseAuth.instance.currentUser != null) {
      _service.updateUserStatus('online');
    }
  }

  // --- СЛУШАТЕЛЬ ВХОДЯЩИХ ЗВОНКОВ ---
  void _setupCallListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _db.collection('calls')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'dialing')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _showIncomingCallDialog(change.doc);
        }
      }
    });
  }

  void _showIncomingCallDialog(DocumentSnapshot callDoc) {
    final data = callDoc.data() as Map<String, dynamic>;
    final String callerName = data['callerName'] ?? 'Сотрудник';
    final bool isVideo = data['isVideo'] ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Column(
            children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 50)),
              const SizedBox(height: 16),
              Text(callerName, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text(isVideo ? 'Видеовызов...' : 'Аудиовызов...', 
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          FloatingActionButton(
            heroTag: 'reject',
            backgroundColor: Colors.red,
            onPressed: () {
              callDoc.reference.update({'status': 'rejected'});
              Navigator.pop(context);
            },
            child: const Icon(Icons.call_end, color: Colors.white),
          ),
          FloatingActionButton(
            heroTag: 'accept',
            backgroundColor: Colors.green,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    roomId: callDoc.id,
                    isVideo: isVideo,
                    isIncoming: true,
                  ),
                ),
              );
            },
            child: const Icon(Icons.call, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service.updateUserStatus('online');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _service.updateUserStatus('offline');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        return FutureBuilder<AppUser?>(
          future: _service.getCurrentAppUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final user = userSnapshot.data;
            if (user == null) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => _service.signOut(),
                    child: const Text("Ошибка профиля. Выйти"),
                  ),
                ),
              );
            }

            _service.updateUserStatus('online');
            _service.setupPushNotifications();

            if (user.role == 'dispatcher') {
              return DispatcherRequestsScreen(currentUser: user);
            } else {
              return MyRequestsScreen(currentUser: user);
            }
          },
        );
      },
    );
  }
}
