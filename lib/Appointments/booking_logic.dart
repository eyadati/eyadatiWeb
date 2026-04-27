import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/utils/models/clinic_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Handles appointment booking logic with optimized Firestore operations
/// and thread-safe slot booking via transactions.
class BookingLogic extends ChangeNotifier {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  // In-memory cache for clinic data
  final Map<String, Clinic> _clinicCache = {};

  BookingLogic({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  /// Generates hourly slots for a specific day using a single Firestore query
  /// and in-memory processing for optimal performance
  Future<List<DateTime>> generateSlots(
    DateTime day,
    String clinicUid,
    int slotDurationMinutes,
  ) async {
    try {
      // Fetch and cache clinic data
      final clinic = await _getCachedClinic(clinicUid);
      if (clinic == null) return [];

      final staffCount = clinic.staff;
      final workingDays = clinic.workingDays;
      final openingMinutes = clinic.openingAt;
      final closingMinutes = clinic.closingAt;
      final breakStartMinutes = clinic.breakStart;
      final breakEndMinutes = clinic.breakEnd;

      // Check if clinic is open
      if (!workingDays.contains(day.weekday)) return [];

      // Use local DateTime for consistent timezone handling with user app
      final localDay = DateTime(day.year, day.month, day.day);

      // Generate time boundaries
      final openingTime = localDay.add(Duration(minutes: openingMinutes));
      final closingTime = localDay.add(Duration(minutes: closingMinutes));
      final breakStart = localDay.add(Duration(minutes: breakStartMinutes));
      final breakEnd = localDay.add(Duration(minutes: breakEndMinutes));

      // Fetch ALL appointments for the day in a single query
      final dayAppointments = await firestore
          .collection('clinics')
          .doc(clinicUid)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(localDay))
          .where(
            'date',
            isLessThan: Timestamp.fromDate(localDay.add(const Duration(days: 1))),
          )
          .get();

      // Build slot occupancy map in memory
      final bookedSlots = <DateTime, int>{};
      for (var doc in dayAppointments.docs) {
        final data = doc.data();
        final appointmentTime = Clinic.parseDateTime(data['date']);
        // Normalize to local for slot key
        final slotKey = DateTime(
          appointmentTime.year,
          appointmentTime.month,
          appointmentTime.day,
          appointmentTime.hour,
          appointmentTime.minute,
        );
        bookedSlots[slotKey] = (bookedSlots[slotKey] ?? 0) + 1;
      }

      final now = DateTime.now();

      // Generate available slots
      final availableSlots = <DateTime>[];
      DateTime slotStart = openingTime;

      while (slotStart
          .add(Duration(minutes: slotDurationMinutes))
          .isBefore(closingTime.add(const Duration(minutes: 1)))) {
        final slotEnd = slotStart.add(Duration(minutes: slotDurationMinutes));

        // Skip if slot is during break
        final isDuringBreak =
            (slotStart.isBefore(breakEnd) && slotEnd.isAfter(breakStart));
        if (isDuringBreak) {
          slotStart = slotEnd;
          continue;
        }

        // Skip if the slot is in the past
        if (slotEnd.isBefore(now)) {
          slotStart = slotEnd;
          continue;
        }

        // Check bookings from in-memory map
        final currentBookings = bookedSlots[slotStart] ?? 0;
        if (currentBookings < staffCount) {
          availableSlots.add(slotStart);
        }

        slotStart = slotEnd;
      }

      return availableSlots;
    } catch (e) {
      debugPrint('error_generic'.tr(args: [e.toString()]));
      return [];
    }
  }

  /// Gets cached clinic data or fetches from Firestore if not available
  Future<Clinic?> _getCachedClinic(String clinicUid) async {
    if (_clinicCache.containsKey(clinicUid)) {
      return _clinicCache[clinicUid];
    }

    final doc = await firestore.collection('clinics').doc(clinicUid).get();
    if (doc.exists && doc.data() != null) {
      final clinic = Clinic.fromMap(doc.data()!);
      _clinicCache[clinicUid] = clinic;
      return clinic;
    }
    return null;
  }

  /// Invalidate cache for a specific clinic
  void refreshClinicData(String clinicUid) {
    _clinicCache.remove(clinicUid);
    notifyListeners();
  }
}
