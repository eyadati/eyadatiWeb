import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String phone;
  final String name;
  final DateTime? createdAt;
  final DateTime? lastBookingAt;

  Patient({
    required this.phone,
    required this.name,
    this.createdAt,
    this.lastBookingAt,
  });

  factory Patient.fromMap(Map<String, dynamic> data) {
    return Patient(
      phone: data['phone'] ?? '',
      name: data['name'] ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      lastBookingAt: _parseDateTime(data['lastBookingAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'name': name,
      'createdAt': createdAt,
      'lastBookingAt': lastBookingAt,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}