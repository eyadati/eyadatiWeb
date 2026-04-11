import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/user/UserHome.dart';
import 'package:eyadati/clinic/clinic_home.dart';
import 'package:eyadati/Appointments/utils.dart'; // For AppStartupService
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eyadati/intro.dart';

Future<Widget> decidePage(BuildContext context) async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return intro();
  } else {
    final connectivityResult = await (Connectivity().checkConnectivity());
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    
    if (isOffline) {
      // Offline: trust stored role
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      if (role == 'user') {
        return const Userhome();
      } else if (role == 'clinic') {
        await AppStartupService().initialize(true);
        return const Clinichome();
      } else {
        // No role stored? Try to show something or intro
        return intro();
      }
    } else {
      // Online: verify role
      try {
        // 1. Check if User
        final isUser = await _isUserRole(currentUser.uid);
        if (isUser) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', 'user');
          return const Userhome();
        }
        
        // 2. Check if Clinic
        final isClinic = await _isClinicRole(currentUser.uid);
        if (isClinic) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', 'clinic');
          await AppStartupService().initialize(true);
          return const Clinichome();
        }

        // 3. Neither? Sign out.
        await FirebaseAuth.instance.signOut();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('role');
        return intro();
      } catch (e) {
        debugPrint("Role check error: $e");
        // Fallback to stored role if error
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('role');
        if (role == 'user') return const Userhome();
        if (role == 'clinic') {
          await AppStartupService().initialize(true);
          return const Clinichome();
        }
        return intro();
      }
    }
  }
}

Future<bool> _isUserRole(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get(const GetOptions(source: Source.serverAndCache));
  return doc.exists;
}

Future<bool> _isClinicRole(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('clinics')
      .doc(uid)
      .get(const GetOptions(source: Source.serverAndCache));
  return doc.exists;
}
