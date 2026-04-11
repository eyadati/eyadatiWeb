import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eyadati/user/user_firestore.dart';

class UserNavBarProvider extends ChangeNotifier {
  String _selected = "1";
  String get selected => _selected;
  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  StreamSubscription? _favoritesSubscription;
  Set<String> _favoriteIds = {};
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoadingFavorites = true;

  Set<String> get favoriteIds => _favoriteIds;
  List<Map<String, dynamic>> get favorites => _favorites;
  bool get isLoadingFavorites => _isLoadingFavorites;

  UserNavBarProvider() {
    _initFavorites();
  }

  void _initFavorites() {
    final user = auth.currentUser;
    if (user == null) {
      _favorites = [];
      _favoriteIds = {};
      _isLoadingFavorites = false;
      notifyListeners();
      return;
    }

    _favoritesSubscription?.cancel();
    _favoritesSubscription = firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .listen((snapshot) {
          final clinics = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
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

          // Sort by favorited timestamp
          clinics.sort((a, b) {
            final Timestamp? timestampA = a['favoritedTimestamp'];
            final Timestamp? timestampB = b['favoritedTimestamp'];

            if (timestampA == null && timestampB == null) return 0;
            if (timestampA == null) return 1;
            if (timestampB == null) return -1;

            return timestampB.compareTo(timestampA); // Newest first
          });

          _favorites = clinics;
          _favoriteIds = clinics.map((c) => (c['uid'] ?? c['id']).toString()).toSet();
          _isLoadingFavorites = false;
          notifyListeners();
        }, onError: (e) {
          debugPrint("Error in favorites subscription: $e");
          _isLoadingFavorites = false;
          notifyListeners();
        });
  }

  bool isFavorite(String clinicUid) {
    return _favoriteIds.contains(clinicUid);
  }

  Future<void> toggleFavorite(String clinicUid) async {
    final userFirestore = UserFirestore();
    await userFirestore.toggleFavorite(clinicUid);
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
