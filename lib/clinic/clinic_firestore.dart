import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb_flutter;
import 'package:eyadati/utils/connectivity_service.dart'; // Import ConnectivityService
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

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
         "clinics",
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
  ) async {
    try {
      final fcm = await FirebaseMessaging.instance.getToken();

      await collection.doc(clinic?.uid).set({
        "uid": clinic!.uid,
        "email": clinic!.email,
        "name": name,
        "clinicName": clinicName,
        "FCM": fcm,
        "mapsLink": mapsLink,
        "workingDays": workingDays,
        "subscriptionStartDate": DateTime.now(),
        "subscriptionEndDate": DateTime.now().add(Duration(days: 31)),
        "paused": false,
        "phone": phone,
        "address": adress,
        "city": city,
        'picUrl': picUrl,
        "openingAt": openingAt,
        'closingAt': closingAt,
        'breakStart': breakStart,
        "breakEnd": breakEnd,
        "specialty": specialty,
        'duration': sessionDuration,
        'staff': 1.toInt(),
      });
    } catch (e) {
      debugPrint("Clinic creation error : $e");
      rethrow;
    }
  }

  Future<void> updateClinic(
    String name,
    String clinicName,
    String mapsLink,
    String picUrl,
    String city,
    List workingDays,
    String phone,
    String specialty,
    String sessionDuration,
    int openingAt,
    int closingAt,
    int breakStart,
    int breakTime,
    String adress,
    bool paused,
  ) async {
    try {
      final fcm = await FirebaseMessaging.instance.getToken();

      await collection.doc(clinic?.uid).update({
        "uid": clinic!.uid,

        "email": clinic!.email,

        "name": name,

        "clinicName": clinicName,

        "FCM": fcm,

        "mapsLink": mapsLink,

        "workingDays": workingDays,

        "phone": phone,

        "address": adress,

        "city": city,

        'picUrl': picUrl,

        "openingAt": openingAt,

        'closingAt': closingAt,

        'breakStart': breakStart,

        "breakEnd": breakTime,

        "specialty": specialty,

        'duration': sessionDuration,

        'staff': 1.toInt(),

        "paused": paused,
      });
    } catch (e) {
      debugPrint("Clinic creation error : $e");

      rethrow;
    }
  }

  Future<void> _saveLastSyncTimestamp(String clinicUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_clinic_$clinicUid', DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncTimestamp(String clinicUid) async {
    final prefs = await SharedPreferences.getInstance();
    final timestampString = prefs.getString('last_sync_clinic_$clinicUid');
    if (timestampString != null) {
      return DateTime.parse(timestampString);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getClinicData(String clinicUid) async {
    try {
      // First, try to get data from cache
      DocumentSnapshot doc = await collection.doc(clinicUid).get(GetOptions(source: Source.cache));

      // If data is not in cache AND device is online, try to get from server (and cache)
      if (!doc.exists && (_connectivityService?.isOnline == true)) {
        doc = await collection.doc(clinicUid).get(GetOptions(source: Source.serverAndCache));
        if (doc.exists) {
          await _saveLastSyncTimestamp(clinicUid); // Save timestamp after successful server fetch
        }
      } else if (!doc.exists && (_connectivityService?.isOnline == false)) {
          // If offline and not in cache, we still don't have data, return null
          debugPrint("Clinic data not in cache and device is offline.");
          return null;
      }

      // If after all attempts, the document still doesn't exist, return null
      if (!doc.exists) {
        return null;
      }

      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint("Error getting clinic data: $e");
      return null;
    }
  }

  Future<void> updateClinicPauseStatus(String clinicUid, bool isPaused) async {
    try {
      await collection.doc(clinicUid).update({"paused": isPaused});
    } catch (e) {
      debugPrint("Error updating clinic pause status: $e");
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getAvailableClinics() {
    return collection.where('paused', isEqualTo: false).snapshots(includeMetadataChanges: true).map((
      snapshot,
    ) {
      // Implement checks for metadata changes
      if (snapshot.metadata.isFromCache) {
        debugPrint("getAvailableClinics: Data from cache.");
      }
      if (snapshot.metadata.hasPendingWrites) {
        debugPrint("getAvailableClinics: Data has pending writes (local changes).");
      }
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> deleteClinicAccount(
    BuildContext context,
    String password,
  ) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No user logged in.');
      }

      // Reauthenticate user
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // 1. Delete clinic document from Firestore
      await collection.doc(user.uid).delete();

      // 2. Remove clinic from user favorites (Placeholder - ideally a Cloud Function)
      // This would involve iterating through all user documents and removing the clinic's UID
      // from their favorites list. This can be very expensive and should ideally be done
      // via a Firebase Cloud Function or a batch job.
      debugPrint(
        "TODO: Implement removal from user favorites (Cloud Function recommended).",
      );

      // 3. Remove appointments made by users (Placeholder - ideally a Cloud Function)
      // This would involve querying all appointments related to this clinic and deleting them
      // from both the clinic's sub-collection and the users' sub-collections.
      debugPrint(
        "TODO: Implement removal of user appointments (Cloud Function recommended).",
      );

      // 4. Delete the Firebase Authentication user
      await user.delete();

      // Sign out after deletion
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}'.tr())));
      }
      rethrow;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'.tr())));
      }
      rethrow;
    }
  }

  Future<void> cancelAppointment(
    String appointmentId,
    String clinicId,
    BuildContext context,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('cancel_appointment'.tr()),
        content: Text('are_you_sure_to_cancel_appointment'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'yes'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Check network connectivity before forcing server read
      if (!(_connectivityService?.isOnline == true)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('no_internet_connection'.tr())),
        );
        return;
      }

      // Get appointment to find user UID - FORCE SERVER READ
      final appointmentDoc = await _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('appointments')
          .doc(appointmentId)
          .get(GetOptions(source: Source.server)); // Changed to Source.server

      if (!appointmentDoc.exists) {
        throw Exception('appointment_not_found'.tr());
      }

      final appointmentData = appointmentDoc.data()!;
      final userUid = appointmentData['userUid'] as String;

      // Delete from both collections
      final batch = _firestore.batch();

      batch.delete(
        _firestore
            .collection('clinics')
            .doc(clinicId)
            .collection('appointments')
            .doc(appointmentId),
      );

      batch.delete(
        _firestore
            .collection('users')
            .doc(userUid)
            .collection('appointments')
            .doc(appointmentId),
      );

      await batch.commit();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_generic'.tr())));
    }
  }
}
