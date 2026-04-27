import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/user/UserHome.dart';
import 'package:eyadati/clinic/clinic_home.dart';
import 'package:eyadati/Appointments/utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<Widget> decidePage(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. Check if there's a Firebase Auth user (clinic) FIRST
  final currentUser = FirebaseAuth.instance.currentUser;
  
  if (currentUser != null) {
    // 2. Check connectivity
    final connectivityResult = await (Connectivity().checkConnectivity());
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    
    if (isOffline) {
      final role = prefs.getString('role');
      if (role == 'clinic') {
        await AppStartupService().initialize(true);
        return const Clinichome();
      }
    } else {
      // 3. Verify if user is a clinic in Firestore (online)
      try {
        final isClinic = await _isClinicRole(currentUser.uid);
        if (isClinic) {
          await prefs.setString('role', 'clinic');
          await AppStartupService().initialize(true);
          return const Clinichome();
        }
      } catch (e) {
        debugPrint('Role check error: $e');
        final role = prefs.getString('role');
        if (role == 'clinic') {
          await AppStartupService().initialize(true);
          return const Clinichome();
        }
      }
    }
  }

  // 4. Check if there's a logged in patient (via phone) - only if no clinic auth
  final patientPhone = prefs.getString('patient_phone');
  if (patientPhone != null && patientPhone.isNotEmpty) {
    return const Userhome();
  }

  // 5. No patient phone, no Firebase user - go to intro → Userhome
  return const Userhome();
}

Future<bool> _isClinicRole(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('clinics')
      .doc(uid)
      .get(const GetOptions(source: Source.serverAndCache));
  return doc.exists;
}