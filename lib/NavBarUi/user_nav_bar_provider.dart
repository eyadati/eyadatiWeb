import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:eyadati/user/patient_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserNavBarProvider extends ChangeNotifier {
  String _selected = '1';
  String get selected => _selected;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  StreamSubscription? _favoritesSubscription;
  Set<String> _favoriteIds = {};
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoadingFavorites = true;
  String _currentPhone = '';

  Set<String> get favoriteIds => _favoriteIds;
  List<Map<String, dynamic>> get favorites => _favorites;
  bool get isLoadingFavorites => _isLoadingFavorites;

  UserNavBarProvider() {
    _initPhone();
  }

  Future<void> _initPhone() async {
    final prefs = await SharedPreferences.getInstance();
    _currentPhone = prefs.getString('patient_phone') ?? '';
    _initFavorites();
  }

  void _initFavorites() {
    if (_currentPhone.isEmpty) {
      _favorites = [];
      _favoriteIds = {};
      _isLoadingFavorites = false;
      notifyListeners();
      return;
    }

    _favoritesSubscription?.cancel();
    _favoritesSubscription = firestore
        .collection('patients')
        .doc(_currentPhone)
        .collection('favorites')
        .snapshots()
        .listen((snapshot) {
          final clinics = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'id': doc.id,
              'clinicName': data['clinicName'],
              'address': data['address'],
              'specialty': data['specialty'],
              'picUrl': data['picUrl'],
              'openingAt': data['openingAt'],
              'closingAt': data['closingAt'],
              'workingDays': data['workingDays'],
              'favoritedTimestamp': data['timestamp'],
            };
          }).toList();

          clinics.sort((a, b) {
            final Timestamp? timestampA = a['favoritedTimestamp'];
            final Timestamp? timestampB = b['favoritedTimestamp'];

            if (timestampA == null && timestampB == null) return 0;
            if (timestampA == null) return 1;
            if (timestampB == null) return -1;

            return timestampB.compareTo(timestampA);
          });

          _favorites = clinics;
          _favoriteIds = clinics.map((c) => (c['uid'] ?? c['id']).toString()).toSet();
          _isLoadingFavorites = false;
          notifyListeners();
        }, onError: (e) {
          debugPrint('Error in favorites subscription: $e');
          _isLoadingFavorites = false;
          notifyListeners();
        });
  }

  bool isFavorite(String clinicUid) {
    return _favoriteIds.contains(clinicUid);
  }

  Future<void> toggleFavorite(String clinicUid) async {
    if (_currentPhone.isEmpty) {
      // Try to get phone from prefs
      final prefs = await SharedPreferences.getInstance();
      _currentPhone = prefs.getString('patient_phone') ?? '';
    }
    
    if (_currentPhone.isEmpty) {
      debugPrint('Cannot toggle favorite: no phone found');
      return;
    }

    final patientFirestore = PatientFirestore(phone: _currentPhone);
    await patientFirestore.toggleFavorite(clinicUid);
  }

  void refreshPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final newPhone = prefs.getString('patient_phone') ?? '';
    if (newPhone != _currentPhone) {
      _currentPhone = newPhone;
      _initFavorites();
    }
  }

  void select(String value) {
    _selected = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}