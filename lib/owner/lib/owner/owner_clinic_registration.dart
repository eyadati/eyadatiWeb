import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'owner_clinic_model.dart';

class OwnerClinicRegistration extends StatefulWidget {
  const OwnerClinicRegistration({super.key});

  @override
  State<OwnerClinicRegistration> createState() => _OwnerClinicRegistrationState();
}

class _OwnerClinicRegistrationState extends State<OwnerClinicRegistration> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for all required fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _mapsLinkController = TextEditingController();
  
  // Default values
  final int _openingAt = 480; // 08:00
  final int _closingAt = 1080; // 18:00
  final int _breakStart = 720; // 12:00
  final int _breakEnd = 780; // 13:00
  final int _duration = 30;
  final int _staff = 1;
  final List<int> _workingDays = [1, 2, 3, 4, 5]; // Mon-Fri

  bool _isLoading = false;

  Future<void> _registerClinic() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create Auth User
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // 2. Create Clinic Document
      final clinic = OwnerClinicModel(
        uid: uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        clinicName: _clinicNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        specialty: _specialtyController.text.trim(),
        mapsLink: _mapsLinkController.text.trim(),
        workingDays: _workingDays,
        openingAt: _openingAt,
        closingAt: _closingAt,
        breakStart: _breakStart,
        breakEnd: _breakEnd,
        duration: _duration,
        staff: _staff,
        subscriptionStartDate: DateTime.now(),
        subscriptionEndDate: DateTime.now().add(const Duration(days: 30)),
        subscriptionType: 'pay_per_appointment',
        appointmentsThisMonth: 0,
        multiplierValue: 100.0,
        paidThisMonth: true,
        noShowTotal: 0,
        paused: false,
        picUrl: 'assets/doctors.png', // Default placeholder
      );

      await FirebaseFirestore.instance.collection('clinics').doc(uid).set(clinic.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinic registered successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Register New Clinic'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Doctor Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _clinicNameController,
                    decoration: const InputDecoration(labelText: 'Clinic Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _specialtyController,
                    decoration: const InputDecoration(labelText: 'Specialty'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _mapsLinkController,
                    decoration: const InputDecoration(labelText: 'Google Maps Link'),
                  ),
                  const SizedBox(height: 20),
                  // Note: In a real app, you'd add pickers for time, days, etc.
                  // For this prototype, we'll use defaults or simple inputs.
                  const Text('Time configuration and staff count can be edited later by the clinic.'),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _registerClinic,
                    child: const Text('Register Clinic'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
