import 'package:cloud_firestore/cloud_firestore.dart';

class Clinic {
  final String uid;
  final String email;
  final String name;
  final String clinicName;
  final String? fcm;
  final String mapsLink;
  final List<int> workingDays;
  final DateTime subscriptionStartDate;
  final DateTime subscriptionEndDate;
  final String subscriptionType;
  final int appointmentsThisMonth;
  final double multiplierValue;
  final bool paidThisMonth;
  final int noShowTotal;
  final bool paused;
  final bool test;
  final String phone;
  final String address;
  final String city;
  final String picUrl;
  final int openingAt;
  final int closingAt;
  final int breakStart;
  final int breakEnd;
  final String specialty;
  final int duration;
  final int staff;
  final Map<String, dynamic>? position;

  Clinic({
    required this.uid,
    required this.email,
    required this.name,
    required this.clinicName,
    this.fcm,
    required this.mapsLink,
    required this.workingDays,
    required this.subscriptionStartDate,
    required this.subscriptionEndDate,
    required this.subscriptionType,
    required this.appointmentsThisMonth,
    required this.multiplierValue,
    required this.paidThisMonth,
    required this.noShowTotal,
    required this.paused,
    required this.test,
    required this.phone,
    required this.address,
    required this.city,
    required this.picUrl,
    required this.openingAt,
    required this.closingAt,
    required this.breakStart,
    required this.breakEnd,
    required this.specialty,
    required this.duration,
    required this.staff,
    this.position,
  });

  factory Clinic.fromMap(Map<String, dynamic> data) {
    int parseInt(dynamic value, int defaultValue) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    double parseDouble(dynamic value, double defaultValue) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return Clinic(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      clinicName: data['clinicName'] ?? '',
      fcm: data['fcm'],
      mapsLink: data['mapsLink'] ?? '',
      workingDays: (data['workingDays'] as List?)?.map((e) => parseInt(e, 0)).toList() ?? [],
      subscriptionStartDate: parseDateTime(data['subscriptionStartDate']),
      subscriptionEndDate: parseDateTime(data['subscriptionEndDate']),
      subscriptionType: data['subscriptionType'] ?? 'pay_per_appointment',
      appointmentsThisMonth: parseInt(data['appointments_this_month'], 0),
      multiplierValue: parseDouble(data['multiplier_value'], 100.0),
      paidThisMonth: data['paid_this_month'] ?? true,
      noShowTotal: parseInt(data['no_show_total'], 0),
      paused: data['paused'] ?? false,
      test: data['test'] ?? false,
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      picUrl: data['picUrl'] ?? '',
      openingAt: parseInt(data['openingAt'], 0),
      closingAt: parseInt(data['closingAt'], 0),
      breakStart: parseInt(data['breakStart'], 0),
      breakEnd: parseInt(data['breakEnd'], 0),
      specialty: data['specialty'] ?? '',
      duration: parseInt(data['duration'], 60),
      staff: parseInt(data['staff'], 1),
      position: data['position'],
    );
  }

  static DateTime parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'clinicName': clinicName,
      'fcm': fcm,
      'mapsLink': mapsLink,
      'workingDays': workingDays,
      'subscriptionStartDate': subscriptionStartDate,
      'subscriptionEndDate': subscriptionEndDate,
      'subscriptionType': subscriptionType,
      'appointments_this_month': appointmentsThisMonth,
      'multiplier_value': multiplierValue,
      'paid_this_month': paidThisMonth,
      'no_show_total': noShowTotal,
      'paused': paused,
      'test': test,
      'phone': phone,
      'address': address,
      'city': city,
      'picUrl': picUrl,
      'openingAt': openingAt,
      'closingAt': closingAt,
      'breakStart': breakStart,
      'breakEnd': breakEnd,
      'specialty': specialty,
      'duration': duration,
      'staff': staff,
      'position': position,
    };
  }
}
