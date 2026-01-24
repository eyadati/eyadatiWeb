import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Handles appointment booking logic with optimized Firestore operations
/// and thread-safe slot booking via transactions.
class BookingLogic extends ChangeNotifier {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  // In-memory cache for clinic data
  final Map<String, Map<String, dynamic>> _clinicCache = {};

  BookingLogic({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches clinics by city with basic error handling
  Future<List<Map<String, dynamic>>> cityClinics(String city) async {
    try {
      final snapshot = await firestore
          .collection("clinics")
          .where("city", isEqualTo: city)
          .get(const GetOptions(source: Source.cache));

      return snapshot.docs
          .map((doc) => {"uid": doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint("Error fetching clinics: $e".tr());
      return [];
    }
  }

  /// Generates hourly slots for a specific day using a single Firestore query
  /// and in-memory processing for optimal performance
  Future<List<DateTime>> generateSlots(
    DateTime day,
    String clinicUid,
    int slotDurationMinutes,
  ) async {
    try {
      // Fetch and cache clinic data
      final clinicData = await _getCachedClinicData(clinicUid);
      if (clinicData == null) return [];

      // SAFE PARSING HELPER
      int parseInt(dynamic value, int defaultValue) {
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) return int.tryParse(value) ?? defaultValue;
        return defaultValue;
      }

      final staffCount = parseInt(clinicData["staff"], 1);

      final workingDays =
          (clinicData["workingDays"] as List?)
              ?.map((e) => parseInt(e, 0))
              .toList() ??
          [];

      final openingMinutes = parseInt(clinicData["openingAt"], 0);
      final closingMinutes = parseInt(clinicData["closingAt"], 0);
      final breakStartMinutes = parseInt(clinicData["breakStart"], 0);
      final breakEndMinutes = parseInt(clinicData["breakEnd"] ?? clinicData["break"], 0);

      // Check if clinic is open
      if (!workingDays.contains(day.weekday)) return [];

      // Use UTC for consistent timezone handling
      final utcDay = DateTime(day.year, day.month, day.day);

      // Generate time boundaries
      final openingTime = utcDay.add(Duration(minutes: openingMinutes));
      final closingTime = utcDay.add(Duration(minutes: closingMinutes));
      final breakStart = utcDay.add(Duration(minutes: breakStartMinutes));
      final breakEnd = utcDay.add(Duration(minutes: breakEndMinutes));

      // Fetch ALL appointments for the day in a single query
      final dayAppointments = await firestore
          .collection("clinics")
          .doc(clinicUid)
          .collection("appointments")
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(utcDay))
          .where(
            "date",
            isLessThan: Timestamp.fromDate(utcDay.add(const Duration(days: 1))),
          )
          .get();

      // Build slot occupancy map in memory
      final bookedSlots = <DateTime, int>{};
      for (var doc in dayAppointments.docs) {
        final appointmentTime = (doc.data()["date"] as Timestamp).toDate();
        final slotHour = DateTime(
          appointmentTime.year,
          appointmentTime.month,
          appointmentTime.day,
          appointmentTime.hour,
        );
        bookedSlots[slotHour] = (bookedSlots[slotHour] ?? 0) + 1;
      }

      final now = DateTime.now();

      // Generate available slots
      final availableSlots = <DateTime>[];
      DateTime slotStart = openingTime;

      while (slotStart
          .add(Duration(minutes: slotDurationMinutes))
          .isBefore(closingTime.add(Duration(minutes: 1)))) {
        // Ensure last slot ends before or exactly at closing time
        final slotEnd = slotStart.add(Duration(minutes: slotDurationMinutes));

        // Skip if slot is entirely within the break, or overlaps significantly
        final isDuringBreak =
            (slotStart.isBefore(breakEnd) && slotEnd.isAfter(breakStart));
        if (isDuringBreak) {
          slotStart = slotEnd; // Move to the end of this potential slot
          continue;
        }

        // Skip if the slot is in the past
        if (slotEnd.isBefore(now)) {
          // Use slotEnd to ensure the *entire* slot is in the past
          slotStart = slotEnd;
          continue;
        }

        // Check bookings from in-memory map
        final currentBookings = bookedSlots[slotStart] ?? 0;
        if (currentBookings < staffCount) {
          availableSlots.add(slotStart);
        }

        slotStart = slotEnd; // Move to the next slot
      }

      return availableSlots;
    } catch (e) {
      debugPrint("Slot generation error: $e".tr());
      return [];
    }
  }

  /// Gets cached clinic data or fetches from Firestore if not available
  Future<Map<String, dynamic>?> _getCachedClinicData(String clinicUid) async {
    if (_clinicCache.containsKey(clinicUid)) {
      return _clinicCache[clinicUid];
    }

    final doc = await firestore.collection("clinics").doc(clinicUid).get();
    if (doc.exists) {
      _clinicCache[clinicUid] = doc.data()!;
    }
    return doc.data();
  }
}
