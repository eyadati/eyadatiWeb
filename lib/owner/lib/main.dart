import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'owner/owner_clinic_registration.dart';
// import 'firebase_options.dart'; // Uncomment after running 'flutterfire configure'

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // Uncomment after running 'flutterfire configure'
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinic Registration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const OwnerClinicRegistration(),
    );
  }
}
