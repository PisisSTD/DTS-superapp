import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppUser currentUser;
  final FirebaseService _service = FirebaseService();

  ProfileScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Аватар-заглушка с инициалами
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  currentUser.fullName.isNotEmpty ? currentUser.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 40,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                currentUser.fullName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                currentUser.role == 'dispatcher' ? 'Диспетчер' : 'Сотрудник',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Карточка с информацией (Material 3 Card)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildProfileItem(
                        context,
                        Icons.email_outlined,
                        'Электронная почта',
                        currentUser.email
                    ),
                    const Divider(height: 1, indent: 50),
                    _buildProfileItem(
                        context,
                        Icons.business_outlined,
                        'Подразделение',
                        currentUser.department
                    ),
                    const Divider(height: 1, indent: 50),
                    _buildProfileItem(
                        context,
                        Icons.admin_panel_settings_outlined,
                        'Роль в системе',
                        currentUser.role
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Кнопка выхода (Tonal Button в стиле M3)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    await _service.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                            (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти из системы'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
}