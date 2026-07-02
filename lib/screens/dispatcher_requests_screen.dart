import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'login_screen.dart';
import 'request_detail_screen.dart';
import 'profile_screen.dart';
import 'users_list_screen.dart';

class DispatcherRequestsScreen extends StatefulWidget {
  final AppUser currentUser;

  const DispatcherRequestsScreen({super.key, required this.currentUser});

  @override
  _DispatcherRequestsScreenState createState() => _DispatcherRequestsScreenState();
}

class _DispatcherRequestsScreenState extends State<DispatcherRequestsScreen> {
  final FirebaseService _service = FirebaseService();
  String _statusFilter = 'Все';

  final List<String> _filterOptions = [
    'Все', 'отправлено', 'принято', 'транспорт выделен', 'отклонено', 'выполнено'
  ];

  Future<void> _confirmSignOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из панели диспетчера?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.signOut();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  void _changeStatus(TransportRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сменить статус'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _filterOptions.where((s) => s != 'Все').map((status) {
              bool isCurrent = request.status == status;
              return ListTile(
                title: Text(status, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                trailing: isCurrent ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _service.updateRequestStatus(request, status);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Статус изменен на "$status"'),
                          backgroundColor: TransportRequest.getStatusColor(status),
                        )
                    );
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Панель диспетчера'),
        leading: IconButton(
          icon: const Icon(Icons.people_outline, color: Colors.blueGrey),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UsersListScreen()),
            );
          },
          tooltip: 'Заводская сеть',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(currentUser: widget.currentUser)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _confirmSignOut,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue[50],
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Фильтр по статусу',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              items: _filterOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _statusFilter = val!),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TransportRequest>>(
              stream: _service.getAllRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 80),
                          const SizedBox(height: 20),
                          const Text(
                            'ТРЕБУЕТСЯ НАСТРОЙКА FIRESTORE',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Зажмите и выделите ссылку в рамке ниже, чтобы скопировать её и открыть в браузере:',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.red, width: 2),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                              ],
                            ),
                            child: SelectableText(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black, 
                                fontSize: 13, 
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                var requests = snapshot.data ?? [];
                if (_statusFilter != 'Все') {
                  requests = requests.where((r) => r.status == _statusFilter).toList();
                }

                if (requests.isEmpty) {
                  return const Center(child: Text('Заявок не найдено', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(req.transportType, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('От: ${req.userEmail}\nДата: ${req.date}'),
                        isThreeLine: true,
                        trailing: IntrinsicWidth(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => _changeStatus(req),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TransportRequest.getStatusColor(req.status),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: const Size(80, 36),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(req.status, style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(request: req))),
                      ),
                    );
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
