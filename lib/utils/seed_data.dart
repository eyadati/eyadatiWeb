import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:eyadati/utils/constants.dart';

class DataSeeder {
  static final _random = Random();

  static const List<String> _doctorNames = [
    'Benali',
    'Brahimi',
    'Kacimi',
    'Mansouri',
    'Hamidi',
    'Ziane',
    'Belkaid',
    'Yahi',
    'Amrani',
    'Saidani',
    'Mebarki',
    'Bouzidi',
    'Guenifi',
    'Larbi',
    'Taleb',
    'Hadid',
    'Slimani',
    'Ouali',
    'Ferhat',
    'Djebbar',
  ];

  static const List<String> _neighborhoods = [
    'Boudjlida',
    'Kiffane',
    'Imama',
    'Mansourah',
    'Downtown',
    'Hennaya',
    'Chetouane',
    'El Koudia',
    'Bir El Djir',
    'Saf Saf',
    'Oujlida',
  ];

  static Future<void> seedClinics() async {
    debugPrint('Starting clinic seeding for Tlemcen...');

    final supabase = Supabase.instance.client;
    final firestore = FirebaseFirestore.instance;
    final specialties = AppConstants.specialties;

    // 1. Upload/Prepare Avatar URLs
    List<String> avatarUrls = [];
    for (int i = 1; i <= 10; i++) {
      try {
        final ByteData data = await rootBundle.load('assets/avatars/$i.png');
        final Uint8List bytes = data.buffer.asUint8List();
        final fileName = 'seed_avatar_$i.png';

        await supabase.storage
            .from('eyadati')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        final url = supabase.storage.from('eyadati').getPublicUrl(fileName);
        avatarUrls.add(url);
      } catch (e) {
        debugPrint('Error uploading avatar $i: $e');
      }
    }

    if (avatarUrls.isEmpty) {
      debugPrint('Failed to upload avatars. Aborting.');
      return;
    }

    // 2. Generate 50 Clinics
    final batch = firestore.batch();

    for (int i = 0; i < 50; i++) {
      final docName = _doctorNames[_random.nextInt(_doctorNames.length)];
      final neighborhood =
          _neighborhoods[_random.nextInt(_neighborhoods.length)];
      final specialty = specialties[_random.nextInt(specialties.length)];
      final clinicId = 'seed_clinic_tlemcen_$i';

      double lat = 34.85 + (_random.nextDouble() * 0.07);
      double lon = -1.35 + (_random.nextDouble() * 0.07);

      final geoFirePoint = GeoFirePoint(GeoPoint(lat, lon));

      final clinicData = {
        "uid": clinicId,
        "email": "doctor_${i}_tlemcen@eyadati.com",
        "name": "Dr. $docName",
        "clinicName": "Clinique $neighborhood ${specialty.tr()}",
        "FCM": "",
        "mapsLink": "https://www.google.com/maps/search/?api=1&query=$lat,$lon",
        "workingDays": [1, 2, 3, 4, 7],
        "subscriptionStartDate": DateTime.now(),
        "subscriptionEndDate": DateTime.now().add(const Duration(days: 365)),
        "paused": false,
        "phone": "043${100000 + _random.nextInt(899999)}",
        "address": "$neighborhood, Rue ${_random.nextInt(100) + 1}, Tlemcen",
        "city": "Tlemcen",
        'picUrl': avatarUrls[_random.nextInt(avatarUrls.length)],
        "openingAt": 480,
        'closingAt': 1020,
        'breakStart': 720,
        "breakEnd": 780,
        "specialty": specialty, // Storing raw key
        'duration': 30,
        'staff': _random.nextInt(3) + 1,
        "position": geoFirePoint.data,
      };

      batch.set(firestore.collection("clinics").doc(clinicId), clinicData);
    }

    await batch.commit();
    debugPrint('Successfully seeded 50 clinics in Tlemcen!');
  }

  /// Fixes existing seed clinics by mapping their translated specialty back to the key.
  static Future<void> fixSeedData() async {
    final firestore = FirebaseFirestore.instance;
    final specialties = AppConstants.specialties;

    final snapshot = await firestore.collection("clinics").get();
    final batch = firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final currentSpecialty = data['specialty'] as String?;
      if (currentSpecialty == null) continue;

      // Find which key this translated specialty belongs to
      String? foundKey;

      // Check if it's already a key
      if (specialties.contains(currentSpecialty)) continue;

      // Heuristic: check against all possible translations
      for (var key in specialties) {
        if (currentSpecialty.toLowerCase() == key.toLowerCase()) {
          foundKey = key;
          break;
        }
        // Add more manual mappings based on user feedback
        if (key == 'radiology' &&
            (currentSpecialty == 'Radiologist' ||
                currentSpecialty == 'Radiology')) {
          foundKey = 'radiology';
        }
        if (key == 'surgery' &&
            (currentSpecialty == 'Surgeon' || currentSpecialty == 'Surgery')) {
          foundKey = 'surgery';
        }
        // ... add others as discovered
      }

      if (foundKey != null) {
        batch.update(doc.reference, {'specialty': foundKey});
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('Fixed $count clinics specialties.');
    }
  }
}
