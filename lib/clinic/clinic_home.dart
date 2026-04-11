import 'package:eyadati/NavBarUi/clinic_nav_bar.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Clinichome extends StatefulWidget {
  const Clinichome({super.key});

  @override
  State<Clinichome> createState() => _ClinichomeState();
}

class _ClinichomeState extends State<Clinichome> {
  final clinicUid = FirebaseAuth.instance.currentUser!.uid;
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: FloatingBottomNavBar());
  }
}
