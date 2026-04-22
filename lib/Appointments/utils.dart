import 'package:eyadati/utils/models/clinic_model.dart';
import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class AppStartupService {
  static final AppStartupService _instance = AppStartupService._internal();
  factory AppStartupService() => _instance;
  AppStartupService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _userId;
  String? get userId => _userId;

  Map<String, dynamic> _userData = {};
  Map<String, dynamic> get userData => _userData;

  final BehaviorSubject<Clinic?> _clinicSubject = BehaviorSubject<Clinic?>();
  Stream<Clinic?> get clinicStream => _clinicSubject.stream;
  Clinic? get currentClinic => _clinicSubject.valueOrNull;

  /// Initialize app with role-aware data fetching
  Future<void> initialize(bool isClinic) async {
    if (_isInitialized) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isInitialized = true;
      return;
    }

    _userId = user.uid;

    try {
      if (isClinic) {
        await ClinicFirestore().ensureClinicProfileIntegrity(_userId!);
      }
      await Future.wait([
        if (isClinic) _setupClinicStream() else _cacheUserData(),
      ]);
    } catch (e) {
      debugPrint("Startup error: $e");
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> _setupClinicStream() async {
    FirebaseFirestore.instance
        .collection('clinics')
        .doc(_userId)
        .snapshots()
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            debugPrint("⚠️ Clinic stream timed out.");
            _clinicSubject.add(null); // Signal no clinic data
          },
        )
        .map((snapshot) => snapshot.exists && snapshot.data() != null
            ? Clinic.fromMap(snapshot.data()!)
            : null)
        .listen((clinic) {
          _clinicSubject.add(clinic);
        });
  }

  Future<void> _cacheUserData() async {
    await _fetchDocument(
      FirebaseFirestore.instance.collection('users').doc(_userId),
      (data) => _userData = data,
    );
  }

  Future<void> _fetchDocument(
    DocumentReference ref,
    Function(Map<String, dynamic>) onSuccess,
  ) async {
    try {
      final doc = await ref.get(GetOptions(source: Source.server));
      if (doc.exists) {
        onSuccess(doc.data() as Map<String, dynamic>);
        debugPrint("✅ Data loaded from server and cache: ${ref.path}");
      }
    } catch (e) {
      debugPrint("❌ Failed to load ${ref.path}: $e");
    }
  }

  /// Force refresh data (useful after profile update)
  Future<void> refreshData(bool isClinic) async {
    _isInitialized = false;
    await initialize(isClinic);
  }

  void dispose() {
    _clinicSubject.close();
  }
}
