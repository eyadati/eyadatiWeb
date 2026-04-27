import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerClinicModel {
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

  OwnerClinicModel({
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

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "email": email,
      "name": name,
      "clinicName": clinicName,
      "fcm": fcm,
      "mapsLink": mapsLink,
      "workingDays": workingDays,
      "subscriptionStartDate": Timestamp.fromDate(subscriptionStartDate),
      "subscriptionEndDate": Timestamp.fromDate(subscriptionEndDate),
      "subscriptionType": subscriptionType,
      "appointments_this_month": appointmentsThisMonth,
      "multiplier_value": multiplierValue,
      "paid_this_month": paidThisMonth,
      "no_show_total": noShowTotal,
      "paused": paused,
      "phone": phone,
      "address": address,
      "city": city,
      'picUrl': picUrl,
      "openingAt": openingAt,
      'closingAt': closingAt,
      'breakStart': breakStart,
      "breakEnd": breakEnd,
      "specialty": specialty,
      'duration': duration,
      'staff': staff,
      "position": position,
    };
  }
}
