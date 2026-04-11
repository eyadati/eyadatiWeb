import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/clinic/clinic_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eyadati/utils/network_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Clinicauth {
  final auth = FirebaseAuth.instance;
  Future<void> clinicAccount(String email, String password) async {
    if (!await NetworkHelper.checkInternetConnectivity()) {
      return;
    }
    await auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> clinicLoginIn(BuildContext context) async {
    final TextEditingController loginEmail = TextEditingController();
    final TextEditingController loginPassword = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("login".tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: loginEmail,
                decoration: InputDecoration(labelText: "email".tr()),
              ),
              SizedBox(height: 12),
              TextField(
                controller: loginPassword,
                obscureText: true,
                decoration: InputDecoration(labelText: "password".tr()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("cancel".tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final dialogNavigator = Navigator.of(ctx);

                if (!await NetworkHelper.checkInternetConnectivity()) {
                  return;
                }
                try {
                  final cred = await FirebaseAuth.instance
                      .signInWithEmailAndPassword(
                        email: loginEmail.text.trim(),
                        password: loginPassword.text.trim(),
                      );

                  if (cred.user != null) {
                    // VERIFY ROLE
                    final clinicDoc = await FirebaseFirestore.instance
                        .collection('clinics')
                        .doc(cred.user!.uid)
                        .get();

                    if (!clinicDoc.exists) {
                      await FirebaseAuth.instance.signOut();
                      throw FirebaseAuthException(
                        code: 'invalid-role',
                        message: 'not_a_clinic_account'.tr(),
                      );
                    }

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('role', 'clinic');

                    dialogNavigator.pop(); // close modal
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const Clinichome()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  debugPrint("Login error: $e");
                  String message = "login_failed".tr();
                  if (e is FirebaseAuthException) {
                    message = e.message ?? message;
                  }
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              },
              child: Text("login".tr()),
            ),
          ],
        );
      },
    );
  }
}
