import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Не забудь добавить intl в pubspec.yaml
import '../models/app_models.dart';

class RequestDetailScreen extends StatelessWidget {
  final TransportRequest request;

  const RequestDetailScreen({super.key, required this.request});

  // Вспомогательный метод для форматирования даты и времени из Timestamp
  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Нет данных';
    DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  // Метод для определения цвета статуса
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'отправлено': return Colors.blue;
      case 'принято': return Colors.green;
      case 'отклонено': return Colors.red;
      case 'транспорт выделен': return Colors.orange;
      case 'выполнено': return Colors.grey;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали заявки'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Секция статуса
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(request.status)),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(request.status),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Основная информация'),
            _buildDetailCard([
              _buildInfoRow(Icons.person, 'Заявитель', request.userEmail),
              _buildInfoRow(Icons.business, 'Подразделение', request.department),
              _buildInfoRow(Icons.directions_car, 'Транспорт', request.transportType),
            ]),

            const SizedBox(height: 16),
            _buildSectionTitle('Детали поездки'),
            _buildDetailCard([
              _buildInfoRow(Icons.calendar_today, 'Дата', request.date),
              _buildInfoRow(Icons.access_time, 'Время начала', request.timeStart),
              _buildInfoRow(Icons.timer, 'Длительность', request.duration),
              _buildInfoRow(Icons.flag, 'Цель', request.purpose),
              _buildInfoRow(Icons.map, 'Маршрут', request.route),
            ]),

            const SizedBox(height: 16),
            _buildSectionTitle('Дополнительно'),
            _buildDetailCard([
              _buildInfoRow(Icons.comment, 'Комментарий', request.comment ?? '—'),
              _buildInfoRow(Icons.history, 'Создана', _formatDateTime(request.createdAt)),
              _buildInfoRow(Icons.verified_user, 'ЭЦП подписана', _formatDateTime(request.signatureTimestamp)),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Виджет заголовка секции
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  // Общая карточка для группы полей
  Widget _buildDetailCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: children),
      ),
    );
  }

  // Строка с иконкой, заголовком и значением
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}