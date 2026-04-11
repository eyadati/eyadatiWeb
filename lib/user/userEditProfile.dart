import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/utils/constants.dart'; // Import constants
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/network_helper.dart';
import 'package:eyadati/utils/connectivity_service.dart'; // Add ConnectivityService import
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

// ================ PROVIDER ================

class UserEditProfileProvider extends ChangeNotifier {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final ConnectivityService? _connectivityService; // Add this field

  UserEditProfileProvider({
    required this.auth,
    required this.firestore,
    ConnectivityService? connectivityService, // Add this parameter
  }) : _connectivityService = connectivityService {
    _initializeData();
  }

  // Form key
  final formKey = GlobalKey<FormState>();

  // Controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  // State
  String? selectedCity;
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  // Algerian cities list (matching registration)
  final List<String> algerianCities = AppConstants.algerianCities;

  Future<void> _initializeData() async {
    isLoading = true;
    notifyListeners();

    try {
      await _loadUserData();
    } catch (e) {
      error = 'fetch_user_data_error'.tr();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveLastSyncTimestamp(String userUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_sync_user_$userUid',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _loadUserData() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('no_user_found'.tr());

    // Fetch data ONLY from server
    DocumentSnapshot doc = await firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    if (!doc.exists) {
      throw Exception('user_document_not_found'.tr());
    }

    await _saveLastSyncTimestamp(
      user.uid,
    ); // Save timestamp after successful server fetch

    final data = doc.data()! as Map<String, dynamic>;
    nameController.text = data['name'] ?? '';
    emailController.text = data['email'] ?? '';
    phoneController.text = data['phone'] ?? '';

    // Match city case-insensitively
    final cityFromDb = data['city']?.toString();
    if (cityFromDb != null) {
      selectedCity = algerianCities.firstWhere(
        (c) => c == cityFromDb,
        orElse: () => algerianCities[0],
      );
    }
  }

  Future<void> updateProfile(BuildContext context) async {
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
      if (user == null) throw Exception('no_user_found'.tr());

      await firestore.collection('users').doc(user.uid).update({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'city': selectedCity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('profile_updated_success'.tr())));
        Navigator.of(context).pop();
      }
    } catch (e) {
      error = 'error_updating_profile'.tr(args: [e.toString()]);
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void selectCity(String? city) {
    selectedCity = city;
    notifyListeners();
  }

  // Validation methods
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'required_field'.tr();
    final pattern = RegExp(r'^\S+@\S+\.\S+$');
    if (!pattern.hasMatch(value.trim())) return 'invalid_email_format'.tr();
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'required_field'.tr();
    final pattern = RegExp(r'^[0-9]+$');
    if (!pattern.hasMatch(value.trim())) return 'invalid_phone'.tr();
    return null;
  }

  String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'required_field'.tr();
    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

// ================ UI PAGE ================

class UserEditProfilePage extends StatelessWidget {
  const UserEditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UserEditProfileProvider(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        connectivityService: Provider.of<ConnectivityService>(
          context,
          listen: false,
        ),
      ),
      child: const UserEditProfileView(),
    );
  }
}

class UserEditProfileView extends StatelessWidget {
  const UserEditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserEditProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('edit_profile'.tr()),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null
            ? _buildErrorState(context, provider)
            : Form(
                key: provider.formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, 'personal_information'.tr()),
                      const SizedBox(height: 16),
                      _buildTextField(
                        provider.nameController,
                        'full_name'.tr(),
                        provider.validateRequired,
                      ),
                      const SizedBox(height: 24),

                      _buildSectionTitle(context, 'contact_information'.tr()),
                      const SizedBox(height: 16),
                      _buildTextField(
                        provider.phoneController,
                        'phone_number'.tr(),
                        provider.validatePhone,
                        inputType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildCityDropdown(context, provider),
                      const SizedBox(height: 24),

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
                              : () => provider.updateProfile(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: provider.isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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

  Widget _buildErrorState(
    BuildContext context,
    UserEditProfileProvider provider,
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => provider._initializeData(),
            icon: const Icon(LucideIcons.refreshCcw),
            label: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String? Function(String?) validator, {
    TextInputType? inputType,
    bool readOnly = false,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      validator: validator,
    );
  }

  Widget _buildCityDropdown(
    BuildContext context,
    UserEditProfileProvider provider,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: provider.selectedCity,
      decoration: InputDecoration(
        labelText: 'city'.tr(),
        prefixIcon: const Icon(LucideIcons.mapPin),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      hint: Text('select_city'.tr()),
      items: provider.algerianCities.map((city) {
        return DropdownMenuItem(value: city, child: Text(city));
      }).toList(),
      onChanged: (value) {
        provider.selectCity(value);
      },
      validator: (value) => value == null ? 'city_required'.tr() : null,
    );
  }
}
