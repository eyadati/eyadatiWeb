import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

class PatientFirestore {
  final String phone;
  final CollectionReference<Map<String, dynamic>> _patientsCollection;

  PatientFirestore({required this.phone})
      : _patientsCollection = FirebaseFirestore.instance.collection('patients');

  CollectionReference<Map<String, dynamic>> get _favoritesCollection =>
      _patientsCollection.doc(phone).collection('favorites');

  Future<void> toggleFavorite(String clinicUid) async {
    if (phone.isEmpty) {
      throw Exception('patient_phone_required'.tr());
    }

    final favoriteDoc = _favoritesCollection.doc(clinicUid);
    final docSnapshot = await favoriteDoc.get();

    if (docSnapshot.exists) {
      await favoriteDoc.delete();
    } else {
      final clinicDoc = await FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicUid)
          .get();
      
      if (clinicDoc.exists) {
        final clinicData = clinicDoc.data()!;
        await favoriteDoc.set({
          'timestamp': FieldValue.serverTimestamp(),
          'clinicName': clinicData['clinicName'] ?? 'Unknown',
          'address': clinicData['address'] ?? '',
          'specialty': clinicData['specialty'] ?? '',
          'picUrl': clinicData['picUrl'] ?? '',
          'openingAt': clinicData['openingAt'] ?? 0,
          'closingAt': clinicData['closingAt'] ?? 0,
          'workingDays': clinicData['workingDays'] ?? [],
          'id': clinicUid,
          'phone': phone,
        });
      } else {
        throw Exception('clinic_not_found'.tr());
      }
    }
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    if (phone.isEmpty) return [];

    final snapshot = await _favoritesCollection.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<bool> isFavorite(String clinicUid) async {
    if (phone.isEmpty) return false;
    
    final doc = await _favoritesCollection.doc(clinicUid).get();
    return doc.exists;
  }
}