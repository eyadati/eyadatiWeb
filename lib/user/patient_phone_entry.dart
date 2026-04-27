import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/user/UserHome.dart';
import 'package:eyadati/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PatientPhoneEntry extends StatefulWidget {
  const PatientPhoneEntry({super.key});

  @override
  State<PatientPhoneEntry> createState() => _PatientPhoneEntryState();
}

class _PatientPhoneEntryState extends State<PatientPhoneEntry> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('patient_phone') ?? '';
    final savedCity = prefs.getString('patient_city');
    if (savedPhone.isNotEmpty) {
      _phoneController.text = savedPhone;
    }
    if (savedCity != null && savedCity.isNotEmpty) {
      setState(() {
        _selectedCity = savedCity;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final city = _selectedCity ?? AppConstants.algerianCities.first;
      final firestore = FirebaseFirestore.instance;

      // Check if patient exists
      final patientDoc = await firestore
          .collection('patients')
          .doc(phone)
          .get();

      if (!patientDoc.exists) {
        // Create new patient document
        await firestore.collection('patients').doc(phone).set({
          'phone': phone,
          'name': '',
          'city': city,
          'createdAt': FieldValue.serverTimestamp(),
          'lastBookingAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last booking time and city
        await firestore.collection('patients').doc(phone).update({
          'lastBookingAt': FieldValue.serverTimestamp(),
          'city': city,
        });
      }

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('patient_phone', phone);
      await prefs.setString('patient_city', city);
      await prefs.setString('patient_name', patientDoc.data()?['name'] ?? '');

      if (!mounted) return;
      
      // Navigate to UserHome
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Userhome()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_occurred'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('welcome_back'.tr()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 100,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'enter_phone_to_continue'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'phone_help_text'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'city'.tr(),
                    prefixIcon: const Icon(LucideIcons.mapPin),
                    border: const OutlineInputBorder(),
                  ),
                  items: AppConstants.algerianCities.map((city) {
                    return DropdownMenuItem(value: city, child: Text(city));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCity = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'please_select_city'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'phone_number'.tr(),
                    prefixIcon: const Icon(LucideIcons.phone),
                    border: const OutlineInputBorder(),
                    hintText: '05xxxxxxxx',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'please_enter_phone'.tr();
                    }
                    if (value.length < 10) {
                      return 'invalid_phone'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _handleSubmit,
                      icon: const Icon(LucideIcons.arrowRight),
                      label: Text('continue'.tr()),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'no_account_needed'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}