import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/utils/models/clinic_model.dart';
import 'package:eyadati/utils/exceptions.dart';
import 'package:eyadati/utils/network_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb_flutter;
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class ClinicFirestore {
  final sb_flutter.SupabaseClient client = sb_flutter.Supabase.instance.client;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final CollectionReference<Map<String, dynamic>> collection;
  final User? clinic;
  final ConnectivityService? _connectivityService; // Add ConnectivityService

  ClinicFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    ConnectivityService? connectivityService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       collection = (firestore ?? FirebaseFirestore.instance).collection(
         'clinics',
       ),
       clinic = (firebaseAuth ?? FirebaseAuth.instance).currentUser,
       _connectivityService = connectivityService; // Initialize it
  Future<void> addClinic(
    String name,
    String mapsLink,
    String clinicName,
    String picUrl,
    String city,
    List workingDays,
    String phone,
    String specialty,
    int sessionDuration,
    int openingAt,
    int closingAt,
    int breakStart,
    int breakEnd,
    String adress,
    double? latitude,
    double? longitude,
    int staff,
  ) async {
    try {
      final fcm = null;

      GeoFirePoint? geoFirePoint;
      if (latitude != null && longitude != null) {
        geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));
      }

    final newClinic = Clinic(
      uid: clinic!.uid,
      email: clinic!.email ?? '',
      name: name,
      clinicName: clinicName,
      fcm: fcm,
      mapsLink: mapsLink,
      workingDays: workingDays.cast<int>(),
      subscriptionStartDate: DateTime.now(),
      subscriptionEndDate: DateTime.now().add(const Duration(days: 31)),
      subscriptionType: 'pay_per_appointment',
      appointmentsThisMonth: 0,
      multiplierValue: 100.0,
      paidThisMonth: true,
      noShowTotal: 0,
      paused: false,
      test: false,
      phone: phone,
      address: adress,
      city: city,
      picUrl: picUrl,
      openingAt: openingAt,
      closingAt: closingAt,
      breakStart: breakStart,
      breakEnd: breakEnd,
      specialty: specialty,
      duration: sessionDuration,
      staff: staff,
      position: geoFirePoint?.data,
    );

      await collection.doc(clinic?.uid).set(newClinic.toMap());
    } catch (e) {
      debugPrint('Clinic creation error : $e');
      throw DatabaseException('failed_to_save_clinic_data');
    }
  }

  Future<void> ensureClinicProfileIntegrity(String clinicUid) async {
    try {
      final doc = await collection.doc(clinicUid).get(const GetOptions(source: Source.server));
      if (!doc.exists) return;

      final data = doc.data()!;
      final updates = <String, dynamic>{};

      if (!data.containsKey('subscriptionStartDate')) {
        updates['subscriptionStartDate'] = FieldValue.serverTimestamp();
      }
      if (!data.containsKey('subscriptionEndDate')) {
        updates['subscriptionEndDate'] = Timestamp.fromDate(DateTime.now().add(const Duration(days: 31)));
      }
      if (!data.containsKey('subscriptionType')) {
        updates['subscriptionType'] = 'pay_per_appointment';
      }
      if (!data.containsKey('appointments_this_month')) {
        updates['appointments_this_month'] = 0;
      }
      if (!data.containsKey('paid_this_month')) {
        updates['paid_this_month'] = true;
      }
      if (!data.containsKey('multiplierValue')) {
        updates['multiplierValue'] = 100.0;
      }
      if (!data.containsKey('staff')) {
        updates['staff'] = 1;
      }
      if (!data.containsKey('paused')) {
        updates['paused'] = false;
      }

      if (updates.isNotEmpty) {
        await collection.doc(clinicUid).update(updates);
        debugPrint("✅ Fixed clinic profile integrity for $clinicUid: ${updates.keys.join(', ')}");
      }
    } catch (e) {
      debugPrint('Error ensuring clinic profile integrity: $e');
    }
  }

  Future<void> updateClinic({
    required String name,
    required String clinicName,
    required String mapsLink,
    required String picUrl,
    required String city,
    required List workingDays,
    required String phone,
    required String specialty,
    required int sessionDuration,
    required int openingAt,
    required int closingAt,
    required int breakStart,
    required int breakEnd,
    required String address,
    required bool paused,
    required int staff,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final fcm = null;

      GeoFirePoint? geoFirePoint;
      if (latitude != null && longitude != null) {
        geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));
      }

      final updateData = {
        'uid': clinic!.uid,
        'email': clinic!.email,
        'name': name,
        'clinicName': clinicName,
        'fcm': fcm,
        'mapsLink': mapsLink,
        'workingDays': workingDays,
        'phone': phone,
        'address': address,
        'city': city,
        'picUrl': picUrl,
        'openingAt': openingAt,
        'closingAt': closingAt,
        'breakStart': breakStart,
        'breakEnd': breakEnd,
        'specialty': specialty,
        'duration': sessionDuration,
        'staff': staff,
        'paused': paused,
      };

      if (geoFirePoint != null) {
        updateData['position'] = geoFirePoint.data;
      }

      await collection.doc(clinic?.uid).update(updateData);
    } catch (e) {
      debugPrint('Clinic update error : $e');
      throw DatabaseException('failed_to_update_clinic_data');
    }
  }

  Future<void> _saveLastSyncTimestamp(String clinicUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_sync_clinic_$clinicUid',
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getLastSyncTimestamp(String clinicUid) async {
    final prefs = await SharedPreferences.getInstance();
    final timestampString = prefs.getString('last_sync_clinic_$clinicUid');
    if (timestampString != null) {
      return DateTime.parse(timestampString);
    }
    return null;
  }

  Future<Clinic?> getClinic(String clinicUid) async {
    final data = await getClinicData(clinicUid);
    if (data == null) return null;
    return Clinic.fromMap(data);
  }

  Future<Map<String, dynamic>?> getClinicData(String clinicUid) async {
    try {
      // First, try to get data from cache
      DocumentSnapshot doc = await collection
          .doc(clinicUid)
          .get(GetOptions(source: Source.cache));

      // If data is not in cache AND device is online, try to get from server (and cache)
      if (!doc.exists && (_connectivityService?.isOnline == true)) {
        doc = await collection
            .doc(clinicUid)
            .get(GetOptions(source: Source.serverAndCache));
        if (doc.exists) {
          await _saveLastSyncTimestamp(
            clinicUid,
          ); // Save timestamp after successful server fetch
        }
      } else if (!doc.exists && (_connectivityService?.isOnline == false)) {
        // If offline and not in cache, we still don't have data, return null
        debugPrint('Clinic data not in cache and device is offline.');
        return null;
      }

      // If after all attempts, the document still doesn't exist, return null
      if (!doc.exists) {
        return null;
      }

      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting clinic data: $e');
      return null;
    }
  }

  Future<void> updateClinicPauseStatus(String clinicUid, bool isPaused) async {
    try {
      await collection.doc(clinicUid).update({'paused': isPaused});
    } catch (e) {
      debugPrint('Error updating clinic pause status: $e');
      throw DatabaseException('failed_to_update_pause_status');
    }
  }

  Stream<List<Map<String, dynamic>>> getAvailableClinics() {
    return collection
        .where('paused', isEqualTo: false)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          // Implement checks for metadata changes
          if (snapshot.metadata.isFromCache) {
            debugPrint('getAvailableClinics: Data from cache.');
          }
          if (snapshot.metadata.hasPendingWrites) {
            debugPrint(
              'getAvailableClinics: Data has pending writes (local changes).',
            );
          }
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  Future<void> deleteClinicAccount(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException('no_user_logged_in');
      }

      // Reauthenticate user
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Best-effort client-side cleanup for orphaned data
      try {
        final appointmentsSnapshot = await collection
            .doc(user.uid)
            .collection('appointments')
            .get();

        final batch = _firestore.batch();
        for (var doc in appointmentsSnapshot.docs) {
          // Delete from clinic subcollection
          batch.delete(doc.reference);

          // Attempt to delete from user subcollection (requires knowing userUid)
          final data = doc.data();
          if (data['userUid'] != null) {
            batch.delete(
              _firestore
                  .collection('users')
                  .doc(data['userUid'])
                  .collection('appointments')
                  .doc(doc.id),
            );
          }
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Error performing client-side cleanup: $e');
      }

      // 1. Delete clinic document from Firestore
      await collection.doc(user.uid).delete();

      // 2. Delete the Firebase Authentication user
      await user.delete();

      // Sign out after deletion
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'failed_to_delete_account');
    } catch (e) {
      throw DatabaseException('failed_to_delete_account');
    }
  }

  Future<void> cancelAppointment(String appointmentId, String clinicId) async {
    try {
      // Check network connectivity before forcing server read
      bool isOnline =
          _connectivityService?.isOnline ??
          await NetworkHelper.checkInternetConnectivity();
      if (!isOnline) {
        throw NetworkException();
      }

      // Get appointment to find user UID - FORCE SERVER READ
      final appointmentDoc = await _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('appointments')
          .doc(appointmentId)
          .get(GetOptions(source: Source.server));

      if (!appointmentDoc.exists) {
        throw DatabaseException('appointment_not_found');
      }

      final appointmentData = appointmentDoc.data()!;
      final userUid = appointmentData['userUid'] as String;

      // Delete from both collections
      final batch = _firestore.batch();

      // Update status instead of deleting
      batch.update(
        _firestore
            .collection('clinics')
            .doc(clinicId)
            .collection('appointments')
            .doc(appointmentId),
        {'status': 'cancelled'},
      );

      batch.update(
        _firestore
            .collection('users')
            .doc(userUid)
            .collection('appointments')
            .doc(appointmentId),
        {'status': 'cancelled'},
      );

      await batch.commit();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('failed_to_cancel_appointment');
    }
  }

  Future<void> updateNoShow(String appointmentId, String clinicId) async {
    try {
      final batch = _firestore.batch();
      final clinicRef = collection.doc(clinicId);
      final appointmentRef = clinicRef.collection('appointments').doc(appointmentId);

      // Get current data to know userUid
      final appointmentDoc = await appointmentRef.get();
      if (!appointmentDoc.exists) throw DatabaseException('appointment_not_found');
      final data = appointmentDoc.data()!;
      final userUid = data['userUid'];
      
      batch.delete(appointmentRef);
      if (userUid != null) {
        batch.delete(_firestore.collection('users').doc(userUid).collection('appointments').doc(appointmentId));
      }

      batch.update(clinicRef, {
        'no_show_total': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('failed_to_update_no_show');
    }
  }

  Future<void> incrementAppointmentCount(String clinicId) async {
    try {
      final docRef = collection.doc(clinicId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data.containsKey('appointments_this_month')) {
            transaction.update(docRef, {
              'appointments_this_month': FieldValue.increment(1),
            });
          } else {
            transaction.update(docRef, {
              'appointments_this_month': 1,
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error incrementing appointment count: $e');
    }
  }

  Future<void> addManualAppointment({
    required String clinicId,
    required String name,
    required String phone,
    required DateTime date,
  }) async {
    try {
      // 1. First check occupancy OUTSIDE transaction because queries are not allowed inside client-side transactions
      final slotStart = Timestamp.fromDate(date);
      // We need clinic data for duration to calculate slot end
      final clinicDoc = await collection.doc(clinicId).get();
      if (!clinicDoc.exists) throw DatabaseException('clinic_not_found');
      
      final clinic = Clinic.fromMap(clinicDoc.data()!);
      final staffCount = clinic.staff;
      final duration = clinic.duration;
      final slotEnd = Timestamp.fromDate(date.add(Duration(minutes: duration)));

      final appointmentsSnapshot = await collection
          .doc(clinicId)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: slotStart)
          .where('date', isLessThan: slotEnd)
          .get(const GetOptions(source: Source.server));

      if (appointmentsSnapshot.docs.length >= staffCount) {
        throw AppException('slot_is_full');
      }

      // 2. Perform the write in a transaction or batch if needed, 
      // but since we already checked occupancy above and it's a manual appointment,
      // a simple write is often sufficient for manual clinic operations.
      // However, to keep it consistent with the intention of being safe:
      final appointmentRef = collection.doc(clinicId).collection('appointments').doc();
      
      await _firestore.runTransaction((transaction) async {
        // Re-verify clinic still exists and get latest data if needed
        final txClinicDoc = await transaction.get(collection.doc(clinicId));
        if (!txClinicDoc.exists) throw DatabaseException('clinic_not_found');

        transaction.set(appointmentRef, {
          'id': appointmentRef.id,
          'userName': name,
          'phone': phone,
          'date': slotStart,
          'createdAt': FieldValue.serverTimestamp(),
          'isManual': true,
          'isRead': true,
        });
      });
    } catch (e) {
      debugPrint('Error adding manual appointment: $e');
      if (e is AppException) rethrow;
      throw DatabaseException('failed_to_add_manual_appointment');
    }
  }
}
