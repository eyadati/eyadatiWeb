// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';

import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_url_extractor/url_extractor.dart';
import 'package:eyadati/utils/network_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // Add Provider import
import 'package:eyadati/utils/connectivity_service.dart'; // Add ConnectivityService import

import 'package:eyadati/utils/constants.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ClinicOnboardingProvider extends ChangeNotifier {
  // Form key

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Focus nodes for keyboard navigation

  final focusNodes = List.generate(9, (_) => FocusNode());

  // Controllers

  final nameController = TextEditingController();

  final mapsLinkController = TextEditingController();

  final durationController = TextEditingController();

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final clinicNameController = TextEditingController();

  final addressController = TextEditingController();

  final phoneController = TextEditingController();

  final doctorsController = TextEditingController(text: "1");

  // State

  File? pickedImage;

  String? picUrl;

  double? extractedLatitude;

  int avatarNumber = 1;

  double? extractedLongitude;

  int? openingMinutes;

  int? closingMinutes;

  int? breakStartMinutes;

  int? breakEndMinutes;

  List<int> workingDays = [];

  String? selectedSpecialty;

  String? _selectedCity;

  String? get selectedCity => _selectedCity;

  int currentPage = 0;

  bool isSubmitting = false;

  bool _agreeToTerms = false; // New property

  bool get agreeToTerms => _agreeToTerms;

  void toggleAgreeToTerms(bool? newValue) {
    _agreeToTerms = newValue ?? false;

    notifyListeners();
  }

  // Specialties from constants

  List<String> get specialties => AppConstants.specialties;

  // Algerian cities from constants

  List<String> get algerianCities => AppConstants.algerianCities;

  // ──────────────────────────────────────────────────────────────────────────

  // Public methods

  // ──────────────────────────────────────────────────────────────────────────
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      pickedImage = File(image.path);
      avatarNumber = -1; // Deselect default avatars
      notifyListeners();
    }
  }

  void selectAvatar(int i) {
    avatarNumber = i;
    pickedImage = null; // Deselect picked image
    notifyListeners();
  }

  void selectCity(String? city) {
    _selectedCity = city;
    notifyListeners();
  }

  void goToFormPage() {
    currentPage = 1;
    notifyListeners();
  }

  void selectSpecialty(String? value) {
    selectedSpecialty = value;
    notifyListeners();
  }

  void toggleWorkingDay(int dayIndex, bool selected) {
    selected ? workingDays.add(dayIndex) : workingDays.remove(dayIndex);
    notifyListeners();
  }

  void setTime(String type, TimeOfDay pickedTime) {
    final minutes = pickedTime.hour * 60 + pickedTime.minute;
    switch (type) {
      case 'opening':
        openingMinutes = minutes;
        break;
      case 'closing':
        closingMinutes = minutes;
        break;
      case 'breakStart':
        breakStartMinutes = minutes;
        break;
      case 'breakEnd':
        breakEndMinutes = minutes;
        break;
    }
    notifyListeners();
  }

  void extractCoordinates() {
    if (mapsLinkController.text.isNotEmpty) {
      final coordinates = GoogleMapsUrlExtractor.extractCoordinates(
        mapsLinkController.text,
      );
      if (coordinates != null) {
        extractedLatitude = coordinates['latitude'];
        extractedLongitude = coordinates['longitude'];
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Validation
  // ──────────────────────────────────────────────────────────────────────────
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required'.tr();
    final pattern = RegExp(r'^\S+@\S+\.\S+$');
    if (!pattern.hasMatch(value.trim())) return 'Invalid email'.tr();
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Required'.tr();
    if (value.length < 6) return 'Password too short'.tr();
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required'.tr();
    final pattern = RegExp(r'^[0-9]+$');
    if (!pattern.hasMatch(value.trim())) return 'Invalid number'.tr();
    return null;
  }

  String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required'.tr();
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Submission with safety checks - Returns success/failure
  // ──────────────────────────────────────────────────────────────────────────
  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 800,
      minHeight: 800,
      format: CompressFormat.jpeg,
    );

    return result != null ? File(result.path) : null;
  }

  Future<String?> _uploadImage() async {
    if (pickedImage == null) return null;

    final compressedFile = await _compressImage(pickedImage!);
    if (compressedFile == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await Supabase.instance.client.storage
          .from('eyadati')
          .upload(fileName, compressedFile);
      final urlResponse = Supabase.instance.client.storage
          .from('eyadati')
          .getPublicUrl(fileName);
      return urlResponse;
    } catch (e) {
      return null;
    }
  }

  final FirebaseAuth auth;

  ClinicOnboardingProvider() : auth = FirebaseAuth.instance;

  // ... (rest of the provider properties) ...

  Future<bool> validateAndSubmit(BuildContext context) async {
    // ... (all the validation checks remain the same) ...
    if (!formKey.currentState!.validate()) {
      if (!context.mounted) return false;
      _showSnackBar(context, "Please fill all required fields".tr());
      return false;
    }

    // Check internet connectivity
    if (!await NetworkHelper.checkInternetConnectivity()) {
      if (!context.mounted) return false;
      _showSnackBar(context, 'no_internet_connection'.tr());
      isSubmitting = false; // Ensure submitting state is reset
      notifyListeners();
      return false;
    }

    // Validate time logic
    if (openingMinutes == null || closingMinutes == null) {
      if (!context.mounted) return false;
      _showSnackBar(context, "please_select_opening_and_closing_times".tr());
      return false;
    }
    if (openingMinutes! >= closingMinutes!) {
      if (!context.mounted) return false;
      _showSnackBar(context, "opening_time_error".tr());
      return false;
    }
    if (breakStartMinutes != null && breakEndMinutes != null) {
      if (breakStartMinutes! >= breakEndMinutes!) {
        if (!context.mounted) return false;
        _showSnackBar(context, "break_time_error".tr());
        return false;
      }
      if (breakStartMinutes! < openingMinutes! ||
          breakEndMinutes! > closingMinutes!) {
        if (!context.mounted) return false;
        _showSnackBar(context, "break_within_working_hours".tr());
        return false;
      }
    }

    // Validate duration
    final duration = int.tryParse(durationController.text);
    if (duration == null || duration <= 0) {
      if (!context.mounted) return false;
      _showSnackBar(context, "duration_positive_error".tr());
      return false;
    }

    if (_selectedCity == null) {
      if (!context.mounted) return false;
      _showSnackBar(context, "please_select_city".tr());
      return false;
    }
    if (selectedSpecialty == null) {
      if (!context.mounted) return false;
      _showSnackBar(context, "please_select_specialty".tr());
      return false;
    }
    if (workingDays.isEmpty) {
      if (!context.mounted) return false;
      _showSnackBar(context, "please_select_working_days".tr());
      return false;
    }

    if (!agreeToTerms) {
      // New validation for agreeToTerms
      if (!context.mounted) return false;
      _showSnackBar(
        context,
        "please_agree_to_terms".tr(),
      );
      return false;
    }

    isSubmitting = true;
    notifyListeners();

    UserCredential? userCredential;
    try {
      String? imageUrl;
      if (pickedImage != null) {
        imageUrl = await _uploadImage();
      } else {
        imageUrl = 'assets/avatars/${avatarNumber + 1}.png';
      }

      if (imageUrl == null) {
        throw Exception("Image upload failed or no image selected.");
      }

      // Step 1: Create Auth User
      userCredential = await auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception("user_creation_failed".tr());
      }

      // Step 2: Create Firestore Document
      // Get ConnectivityService before any async calls that might invalidate context
      if (!context.mounted) {
        return false; // Ensure context is mounted before accessing provider
      }
      final connectivityService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );
      // Sort working days before saving
      workingDays.sort();

      try {
        await ClinicFirestore(
          connectivityService: connectivityService,
        ).addClinic(
          nameController.text.trim(),
          mapsLinkController.text.trim(),
          clinicNameController.text.trim(),
          imageUrl,
          _selectedCity!,
          workingDays,
          phoneController.text.trim(),
          selectedSpecialty!,
          int.tryParse(durationController.text) ?? 60,
          openingMinutes!,
          closingMinutes!,
          breakStartMinutes ?? 0,
          breakEndMinutes ?? 0,
          addressController.text.trim(),
          extractedLatitude,
          extractedLongitude,
          int.tryParse(doctorsController.text) ?? 1,
        );
      } catch (e) {
        await user.delete();
        throw Exception("failed_to_save_clinic_data".tr());
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', 'clinic');

      isSubmitting = false;
      notifyListeners();
      return true; // ✅ Success
    } catch (e) {
      isSubmitting = false;
      notifyListeners();
      if (!context.mounted) return false;
      _showSnackBar(context, "Error: ${e.toString()}");
      return false; // ✅ Failure
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Cleanup
  // ──────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    for (var node in focusNodes) {
      node.dispose();
    }
    nameController.dispose();
    mapsLinkController.dispose();
    durationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    clinicNameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
