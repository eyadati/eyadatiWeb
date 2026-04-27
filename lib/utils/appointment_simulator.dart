import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/Appointments/booking_logic.dart';
import 'package:flutter/material.dart';

class AppointmentSimulator {
  static final _random = Random();
  static Timer? _timer;
  static int _appointmentsCreated = 0;

  static const List<String> _patientNames = [
    'Ahmed Mansouri',
    'Sara Belkaid',
    'Mohamed Brahimi',
    'Lina Ziane',
    'Yacine Hamidi',
    'Amine Amrani',
    'Meriem Kacimi',
    'Rayan Taleb',
    'Imane Hadid',
    'Omar Slimani',
  ];

  static void startSimulation(String clinicUid) {
    if (_timer != null && _timer!.isActive) return;

    _appointmentsCreated = 0;
    debugPrint('Starting appointment simulation for clinic: $clinicUid');

    // Create one immediately
    _createSimulatedAppointment(clinicUid);

    // Then one every 30 to 90 seconds
    _timer = Timer.periodic(Duration(seconds: 30 + _random.nextInt(60)), (
      timer,
    ) {
      if (_appointmentsCreated >= 30) {
        timer.cancel();
        debugPrint('Simulation finished.');
        return;
      }
      _createSimulatedAppointment(clinicUid);
    });
  }

  static Future<void> _createSimulatedAppointment(String clinicUid) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Get clinic data for duration and slots
      final clinicDoc = await firestore
          .collection('clinics')
          .doc(clinicUid)
          .get();
      if (!clinicDoc.exists) return;

      final clinicData = clinicDoc.data()!;
      final duration = clinicData['duration'] ?? 30;

      // 2. Find a random working day in the next 7 days
      final bookingLogic = BookingLogic(firestore: firestore);
      DateTime? targetSlot;

      // Try up to 10 times to find an available slot
      for (int i = 0; i < 10; i++) {
        final randomDayOffset = _random.nextInt(7);
        final day = DateTime.now().add(Duration(days: randomDayOffset));
        final slots = await bookingLogic.generateSlots(
          day,
          clinicUid,
          duration,
        );

        if (slots.isNotEmpty) {
          targetSlot = slots[_random.nextInt(slots.length)];
          break;
        }
      }

      if (targetSlot == null) return;

      // 3. Create the appointment
      final patientName = _patientNames[_random.nextInt(_patientNames.length)];
      final patientPhone = '05${50000000 + _random.nextInt(40000000)}';
      final appointmentId =
          'sim_${clinicUid}_${DateTime.now().millisecondsSinceEpoch}';

      final appointmentData = {
        'clinicUid': clinicUid,
        'userUid': 'simulated_user',
        'date': Timestamp.fromDate(targetSlot),
        'userName': patientName,
        'phone': patientPhone,
        'createdAt': FieldValue.serverTimestamp(),
        'isSimulated': true,
        'isRead': false, // For notification center
      };

      final batch = firestore.batch();

      // Add to clinic's appointments
      batch.set(
        firestore
            .collection('clinics')
            .doc(clinicUid)
            .collection('appointments')
            .doc(appointmentId),
        appointmentData,
      );

      await batch.commit();
      _appointmentsCreated++;
      debugPrint(
        'Simulated appointment created ($_appointmentsCreated/30) for $patientName at $targetSlot',
      );
    } catch (e) {
      debugPrint('Error creating simulated appointment: $e');
    }
  }

  static void stopSimulation() {
    _timer?.cancel();
    _timer = null;
  }
}
