import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';

class CreateRequestScreen extends StatefulWidget {
  final AppUser currentUser;
  const CreateRequestScreen({super.key, required this.currentUser});

  @override
  _CreateRequestScreenState createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirebaseService();

  String _transportType = 'Легковой автомобиль';
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  final List<String> _transportTypes = ["Электрокар", "Грузовой автомобиль", "Автобус", "Легковой автомобиль"];

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    String? password = await _showSignatureDialog();
    if (password == null || password.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      bool isVerified = await _service.verifySignature(password);
      if (!mounted) return;
      Navigator.pop(context);

      if (!isVerified) {
        _showErrorDialog('Неверный пароль подписи! Пожалуйста, проверьте ввод.');
        return;
      }

      final req = TransportRequest(
        id: '',
        userId: widget.currentUser.uid,
        userEmail: widget.currentUser.email,
        department: widget.currentUser.department,
        transportType: _transportType,
        date: _dateCtrl.text,
        timeStart: _timeCtrl.text,
        duration: _durationCtrl.text,
        purpose: _purposeCtrl.text,
        route: _routeCtrl.text,
        comment: _commentCtrl.text,
        status: 'отправлено',
      );

      await _service.createRequest(req);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка успешно подписана и отправлена'),
            backgroundColor: Colors.green,
          )
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _showErrorDialog('Произошла ошибка при отправке: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<String?> _showSignatureDialog() {
    TextEditingController _passCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Электронная подпись',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Для подтверждения заявки введите ваш текущий пароль.'),
              const SizedBox(height: 15),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль от аккаунта',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _passCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Подписать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заявка'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionTitle('Транспорт и время'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _transportType,
                        items: _transportTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _transportType = val!),
                        decoration: const InputDecoration(
                          labelText: 'Тип транспорта',
                          prefixIcon: Icon(Icons.directions_car_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Дата (ДД.ММ.ГГГГ)',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (v) => v!.isEmpty ? 'Укажите дату' : null
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _timeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Время начала',
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              validator: (v) => v!.isEmpty ? 'Укажите время' : null
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _durationCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Длительность (ч)',
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                              validator: (v) => v!.isEmpty ? 'Укажите срок' : null,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Детали поездки'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _purposeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Цель поездки',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        validator: (v) => v!.isEmpty ? 'Опишите цель' : null
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _routeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Маршрут (Откуда - Куда)',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                        validator: (v) => v!.isEmpty ? 'Укажите маршрут' : null
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий',
                          prefixIcon: Icon(Icons.comment_outlined),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text('Подписать и отправить заявку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1),
      ),
    );
  }
}
