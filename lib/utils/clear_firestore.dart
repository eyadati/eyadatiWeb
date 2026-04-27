import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> deleteAllFirestoreData() async {
  final firestore = FirebaseFirestore.instance;
  
  debugPrint('Starting to delete all Firestore data...');
  
  // Delete all clinics
  final clinics = await firestore.collection('clinics').get();
  for (var doc in clinics.docs) {
    // Delete all appointments in each clinic
    final appointments = await doc.reference.collection('appointments').get();
    for (var apt in appointments.docs) {
      await apt.reference.delete();
    }
    // Delete clinic document
    await doc.reference.delete();
    debugPrint('Deleted clinic: ${doc.id}');
  }
  
  // Delete all users
  final users = await firestore.collection('users').get();
  for (var doc in users.docs) {
    // Delete all appointments for each user
    final appointments = await doc.reference.collection('appointments').get();
    for (var apt in appointments.docs) {
      await apt.reference.delete();
    }
    // Delete user document
    await doc.reference.delete();
    debugPrint('Deleted user: ${doc.id}');
  }
  
  debugPrint('All Firestore data deleted successfully!');
}