import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/constants.dart';
import 'package:eyadati/utils/network_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_url_extractor/url_extractor.dart';
import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:eyadati/utils/shimmer_loading.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

// ================ PROVIDER ================

class ClinicEditProfileProvider extends ChangeNotifier {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  ClinicEditProfileProvider({required this.auth, required this.firestore}) {
    _loadClinicData();
  }

  // Form key
  final formKey = GlobalKey<FormState>();

  // Controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final clinicNameController = TextEditingController();
  final specialtyController = TextEditingController();
  final durationController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final mapsLinkController = TextEditingController();
  final doctorsController = TextEditingController();

  // State
  String? selectedCity;
  List<int> workingDays = [];
  int? openingMinutes;
  int? closingMinutes;
  int? breakStartMinutes;
  int? breakEndMinutes;
  File? pickedImage;
  String? picUrl;
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  // Dropdown data from constants
  List<String> get algerianCities => AppConstants.algerianCities;
  List<String> get specialties => AppConstants.specialties;

  void onSpecialtyChange(String? value) {
    specialtyController.text = value ?? '';
    notifyListeners();
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      pickedImage = File(image.path);
      notifyListeners();
    }
  }

  Future<void> _loadClinicData() async {
    try {
      final user = auth.currentUser;
      if (user == null) {
        error = 'no_user_found'.tr();
        isLoading = false;
        notifyListeners();
        return;
      }

      final doc = await firestore
          .collection('clinics')
          .doc(user.uid)
          .get(GetOptions(source: Source.cache));
      if (doc.exists) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? '';
        emailController.text = data['email'] ?? '';
        clinicNameController.text = data['clinicName'] ?? '';
        specialtyController.text = data['specialty'] ?? '';
        // Handle variable name mismatch: duration vs Duration
        durationController.text =
            (data['duration'] ?? data['Duration'])?.toString() ?? '';
        addressController.text = data['address'] ?? '';
        phoneController.text = data['phone'] ?? '';
        mapsLinkController.text = data['mapsLink'] ?? '';
        doctorsController.text = (data['staff'] ?? 1).toString();
        picUrl = data['picUrl'];

        selectedCity = data['city'] != null
            ? algerianCities.firstWhere(
                (c) => c.toLowerCase() == data['city'].toString().toLowerCase(),
                orElse: () => algerianCities[0],
              )
            : null;

        workingDays = List<int>.from(data['workingDays'] ?? []);
        openingMinutes = data['openingAt'];
        closingMinutes = data['closingAt'];
        breakStartMinutes = data['breakStart'];
        // Handle break vs breakEnd
        breakEndMinutes = data['breakEnd'] ?? data['break'];
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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

  Future<void> saveProfile(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;
    if (selectedCity == null) {
      error = 'city_required'.tr();
      notifyListeners();
      return;
    }

    if (!await NetworkHelper.checkInternetConnectivity()) {
      isSaving = false; // Reset saving state
      notifyListeners();
      return;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      final user = auth.currentUser;
      if (user == null) throw Exception('no user found'.tr());

      String? newPicUrl;
      if (pickedImage != null) {
        newPicUrl = await _uploadImage();
      }

      // Sort working days before saving
      workingDays.sort();

      // Extract coordinates if maps link changed
      double? lat;
      double? lon;
      if (mapsLinkController.text.isNotEmpty) {
        final coordinates = GoogleMapsUrlExtractor.extractCoordinates(
          mapsLinkController.text.trim(),
        );
        lat = coordinates?['latitude'];
        lon = coordinates?['longitude'];
      }

      if (!context.mounted) return;
      final connService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );

      await ClinicFirestore(connectivityService: connService).updateClinic(
        name: nameController.text.trim(),
        clinicName: clinicNameController.text.trim(),
        specialty: specialtyController.text,
        sessionDuration: int.tryParse(durationController.text) ?? 60,
        city: selectedCity!,
        address: addressController.text.trim(),
        phone: phoneController.text.trim(),
        mapsLink: mapsLinkController.text.trim(),
        workingDays: workingDays,
        openingAt: openingMinutes!,
        closingAt: closingMinutes!,
        breakStart: breakStartMinutes ?? 0,
        breakEnd: breakEndMinutes ?? 0,
        picUrl: newPicUrl ?? picUrl ?? '',
        paused: false,
        staff: int.tryParse(doctorsController.text) ?? 1,
        latitude: lat,
        longitude: lon,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('profile_updated_success'.tr())));
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void selectCity(String? city) {
    selectedCity = city;
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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    clinicNameController.dispose();
    specialtyController.dispose();
    durationController.dispose();
    addressController.dispose();
    phoneController.dispose();
    mapsLinkController.dispose();
    super.dispose();
  }
}

// ================ UI PAGE ================

class ClinicEditProfilePage extends StatelessWidget {
  const ClinicEditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ClinicEditProfileProvider(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      ),
      child: const _ClinicEditProfileContent(),
    );
  }
}

class _ClinicEditProfileContent extends StatelessWidget {
  const _ClinicEditProfileContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicEditProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('edit_clinic_profile'.tr()),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: provider.isLoading
            ? _buildShimmerLoading(context)
            : provider.error != null
            ? _buildErrorState(context, provider)
            : Form(
                key: provider.formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, 'clinic_information'.tr()),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.clinicNameController,
                        'clinic_name'.tr(),
                        provider,
                      ),
                      const SizedBox(height: 16),
                      _buildSpecialtyDropdown(context, provider),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.durationController,
                        'appointment_duration_minutes'.tr(),
                        provider,
                        inputType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.doctorsController,
                        'number_of_doctors'.tr(),
                        provider,
                        inputType: TextInputType.number,
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle(context, 'owner_information'.tr()),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.nameController,
                        'owner_name'.tr(),
                        provider,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.emailController,
                        'email'.tr(),
                        provider,
                        readOnly: true,
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle(context, 'contact_details'.tr()),
                      const SizedBox(height: 16),
                      _buildCityDropdown(context, provider),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.addressController,
                        'address'.tr(),
                        provider,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.mapsLinkController,
                        'maps_link'.tr(),
                        provider,
                        isOptional: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        provider.phoneController,
                        'phone_number'.tr(),
                        provider,
                        inputType: TextInputType.phone,
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle(context, 'working_hours'.tr()),
                      const SizedBox(height: 16),
                      _buildTimePickerRow(
                        context,
                        'opening'.tr(),
                        'opening',
                        provider,
                      ),
                      const SizedBox(height: 12),
                      _buildTimePickerRow(
                        context,
                        'closing'.tr(),
                        'closing',
                        provider,
                      ),
                      const SizedBox(height: 12),
                      _buildTimePickerRow(
                        context,
                        'break_start'.tr(),
                        'breakStart',
                        provider,
                      ),
                      const SizedBox(height: 12),
                      _buildTimePickerRow(
                        context,
                        'break_end'.tr(),
                        'breakEnd',
                        provider,
                      ),
                      const SizedBox(height: 24),

                      _buildSectionTitle(
                        context,
                        'working_days'.tr(),
                        isSmall: true,
                      ),
                      _buildWorkingDaysChips(context, provider),
                      const SizedBox(height: 32),

                      _buildSectionTitle(context, 'clinic_avatar'.tr()),
                      _buildAvatarPicker(context, provider),
                      const SizedBox(height: 32),

                      if (provider.error != null) ...[
                        Text(
                          provider.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: provider.isSaving
                              ? null
                              : () => provider.saveProfile(context),
                          child: provider.isSaving
                              ? const ShimmerLoading.rectangular(
                                  width: 100,
                                  height: 20,
                                )
                              : Text(
                                  'save_changes'.tr(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading.rectangular(width: 150, height: 24),
          const SizedBox(height: 16),
          const ShimmerLoading.rectangular(height: 56),
          const SizedBox(height: 16),
          const ShimmerLoading.rectangular(height: 56),
          const SizedBox(height: 32),
          const ShimmerLoading.rectangular(width: 150, height: 24),
          const SizedBox(height: 16),
          const ShimmerLoading.rectangular(height: 56),
          const SizedBox(height: 16),
          const ShimmerLoading.rectangular(height: 56),
          const SizedBox(height: 32),
          const ShimmerLoading.rectangular(width: 150, height: 24),
          const SizedBox(height: 16),
          const ShimmerLoading.rectangular(height: 56),
          const SizedBox(height: 16),
          const ShimmerLoading.rectangular(height: 56),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ClinicEditProfileProvider provider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.alertTriangle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            provider.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => provider._loadClinicData(),
            icon: const Icon(LucideIcons.refreshCcw),
            label: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    bool isSmall = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: isSmall
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    ClinicEditProfileProvider provider, {
    bool obscureText = false,
    TextInputType? inputType,
    bool readOnly = false,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: inputType ?? TextInputType.text,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      validator: (value) {
        if (!isOptional && (value == null || value.trim().isEmpty)) {
          return 'required_field'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildCityDropdown(
    BuildContext context,
    ClinicEditProfileProvider provider,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: provider.selectedCity,
      decoration: InputDecoration(
        labelText: 'city'.tr(),
        prefixIcon: const Icon(LucideIcons.mapPin),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      hint: Text('select city'.tr()),
      items: provider.algerianCities.map((city) {
        return DropdownMenuItem(value: city, child: Text(city));
      }).toList(),
      onChanged: provider.selectCity,
      validator: (value) {
        if (value == null) {
          return 'city required'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildSpecialtyDropdown(
    BuildContext context,
    ClinicEditProfileProvider provider,
  ) {
    return DropdownButtonFormField<String>(
      initialValue:
          provider.specialties.contains(provider.specialtyController.text)
          ? provider.specialtyController.text
          : null,
      decoration: InputDecoration(
        labelText: 'specialty'.tr(),
        prefixIcon: const Icon(LucideIcons.stethoscope),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      hint: Text('select specialty'.tr()),
      items: provider.specialties.map((specialty) {
        return DropdownMenuItem(value: specialty, child: Text(specialty.tr()));
      }).toList(),
      onChanged: (value) {
        provider.onSpecialtyChange(value);
      },
      validator: (value) {
        if (value == null) {
          return 'specialty required'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildTimePickerRow(
    BuildContext context,
    String label,
    String type,
    ClinicEditProfileProvider provider,
  ) {
    String? timeText;
    int? minutes;

    switch (type) {
      case 'opening':
        minutes = provider.openingMinutes;
        break;
      case 'closing':
        minutes = provider.closingMinutes;
        break;
      case 'breakStart':
        minutes = provider.breakStartMinutes;
        break;
      case 'breakEnd':
        minutes = provider.breakEndMinutes;
        break;
    }

    if (minutes != null) {
      timeText =
          "${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}";
    }

    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton.icon(
          icon: const Icon(LucideIcons.clock),
          label: Text(timeText ?? 'select time'.tr()),
          onPressed: () async {
            TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              provider.setTime(type, picked);
            }
          },
        ),
      ],
    );
  }

  Widget _buildWorkingDaysChips(
    BuildContext context,
    ClinicEditProfileProvider provider,
  ) {
    final dayNames = [
      'monday'.tr(),
      'tuesday'.tr(),
      'wednesday'.tr(),
      'thursday'.tr(),
      'friday'.tr(),
      'saturday'.tr(),
      'sunday'.tr(),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        return FilterChip(
          label: Text(dayNames[i]),
          selected: provider.workingDays.contains(i),
          onSelected: (val) => provider.toggleWorkingDay(i, val),
        );
      }),
    );
  }

  Widget _buildAvatarPicker(
    BuildContext context,
    ClinicEditProfileProvider provider,
  ) {
    return Center(
      child: GestureDetector(
        onTap: () {
          provider.pickImage();
        },
        child: CircleAvatar(
          radius: 60,
          backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          backgroundImage: provider.pickedImage != null
              ? FileImage(provider.pickedImage!)
              : (provider.picUrl != null && provider.picUrl!.startsWith('http')
                        ? CachedNetworkImageProvider(provider.picUrl!)
                        : (provider.picUrl != null
                              ? AssetImage(provider.picUrl!)
                              : null))
                    as ImageProvider?,
          child: provider.pickedImage == null && provider.picUrl == null
              ? const Icon(Icons.add_a_photo, size: 50)
              : null,
        ),
      ),
    );
  }
}
