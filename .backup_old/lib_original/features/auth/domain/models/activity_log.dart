import 'package:flutter/material.dart';

/// Bản ghi nhật ký hoạt động người dùng (Security & Activity Audit)
class UserActivity {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final String? ipAddress;
  final String? device;

  const UserActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    this.ipAddress,
    this.device,
  });

  String get timeFormatted {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      final d = timestamp.day.toString().padLeft(2, '0');
      final m = timestamp.month.toString().padLeft(2, '0');
      final y = timestamp.year;
      final h = timestamp.hour.toString().padLeft(2, '0');
      final min = timestamp.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $h:$min';
    }
  }
}
