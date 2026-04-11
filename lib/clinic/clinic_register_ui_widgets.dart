import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/clinic/clinic_registration_provider.dart';
import 'package:eyadati/clinic/clinic_home.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UI Helper Widgets and Functions
// ─────────────────────────────────────────────────────────────────────────────

class ClinicOnboardingPages extends StatelessWidget {
  const ClinicOnboardingPages({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ClinicOnboardingProvider(),
      child: const _ClinicOnboardingView(),
    );
  }
}

class _ClinicOnboardingView extends StatelessWidget {
  const _ClinicOnboardingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: _FormPage()),
    );
  }
}

class _FormPage extends StatelessWidget {
  const _FormPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicOnboardingProvider>();

    return Form(
      key: provider.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, "account_information".tr()),
            _buildTextFormField(
              context,
              controller: provider.nameController,
              label: "Full Name".tr(),
              validator: provider.validateRequired,
              focusNode: provider.focusNodes[0],
              nextNode: provider.focusNodes[1],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.emailController,
              label: "Email".tr(),
              validator: provider.validateEmail,
              focusNode: provider.focusNodes[1],
              nextNode: provider.focusNodes[2],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.passwordController,
              label: "Password".tr(),
              obscureText: true,
              validator: provider.validatePassword,
              focusNode: provider.focusNodes[2],
              nextNode: provider.focusNodes[3],
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(context, "business_information".tr()),
            _buildTextFormField(
              context,
              controller: provider.clinicNameController,
              label: "Business Name".tr(),
              validator: provider.validateRequired,
              focusNode: provider.focusNodes[3],
              nextNode: provider.focusNodes[4],
            ),
            const SizedBox(height: 16),
            _buildSpecialtyDropdown(context, provider),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.durationController,
              label: 'appointment_duration_minutes'.tr(),
              inputType: TextInputType.number,
              focusNode: provider.focusNodes[4],
              nextNode: provider.focusNodes[5],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.doctorsController,
              label: 'number_of_doctors'.tr(),
              inputType: TextInputType.number,
              focusNode: provider.focusNodes[5],
              nextNode: provider.focusNodes[6],
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(context, "address_and_contact".tr()),
            _buildCityDropdown(context, provider),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.addressController,
              label: "Address".tr(),
              validator: provider.validateRequired,
              focusNode: provider.focusNodes[6],
              nextNode: provider.focusNodes[7],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.mapsLinkController,
              label: 'Google Maps link'.tr(),
              focusNode: provider.focusNodes[7],
              nextNode: provider.focusNodes[8],
            ),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://www.google.com/maps ');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(LucideIcons.mapPin),
                label: Text("open_google_maps".tr()),
              ),
            ),
            _buildTextFormField(
              context,
              controller: provider.phoneController,
              label: "Phone Number".tr(),
              inputType: TextInputType.phone,
              validator: provider.validatePhone,
              focusNode: provider.focusNodes[8],
              onFieldSubmitted: () => provider.validateAndSubmit(context),
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(context, "working_hours".tr()),
            _buildTimePickerRow(context, "Opening", 'opening', provider),
            const SizedBox(height: 12),
            _buildTimePickerRow(context, "Closing", 'closing', provider),
            const SizedBox(height: 12),
            _buildTimePickerRow(context, "Break Start", 'breakStart', provider),
            const SizedBox(height: 12),
            _buildTimePickerRow(context, "Break End", 'breakEnd', provider),
            const SizedBox(height: 24),
            _buildSectionTitle(context, "opening_days".tr(), isSmall: true),
            _buildWorkingDaysChips(context, provider),
            const SizedBox(height: 32),

            _buildSectionTitle(context, "clinic_image".tr()),
            Center(child: _buildAvatarPicker(context, provider)),
            const SizedBox(height: 32),

            // Terms and Conditions Checkbox
            CheckboxListTile(
              value: provider.agreeToTerms,
              onChanged: provider.toggleAgreeToTerms,
              title: Text.rich(
                TextSpan(
                  text: 'i_agree_to'.tr(),
                  children: [
                    TextSpan(
                      text: 'privacy_policy'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          // TODO: Navigate to Privacy Policy
                          debugPrint('Clinic Privacy Policy tapped!');
                        },
                    ),
                    TextSpan(text: 'and'.tr()),
                    TextSpan(
                      text: 'terms_of_service'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          // TODO: Navigate to Terms of Service
                          debugPrint('Clinic Terms of Service tapped!');
                        },
                    ),
                  ],
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isSubmitting || !provider.agreeToTerms
                    ? null
                    : () async {
                        final success = await provider.validateAndSubmit(
                          context,
                        );
                        if (success && context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Clinichome(),
                            ),
                          );
                        }
                      },
                child: provider.isSubmitting
                    ? _buildButtonProgress()
                    : Text("complete_setup".tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildTextFormField(
  BuildContext context, {
  required TextEditingController controller,
  required String label,
  bool obscureText = false,
  TextInputType? inputType,
  String? Function(String?)? validator,
  FocusNode? focusNode,
  FocusNode? nextNode,
  VoidCallback? onFieldSubmitted,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: inputType ?? TextInputType.text,
    focusNode: focusNode,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    validator: validator,
    onFieldSubmitted: (_) {
      if (nextNode != null) {
        FocusScope.of(context).requestFocus(nextNode);
      } else if (onFieldSubmitted != null) {
        onFieldSubmitted();
      }
    },
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
          : Theme.of(context).textTheme.titleLarge,
    ),
  );
}

Widget _buildButtonProgress() {
  return const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

Widget _buildCityDropdown(
  BuildContext context,
  ClinicOnboardingProvider provider,
) {
  return DropdownButtonFormField<String>(
    initialValue: provider.algerianCities[0],
    decoration: InputDecoration(
      labelText: "City".tr(),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    hint: Text("select_city".tr()),
    onChanged: provider.selectCity,
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'please_select_a_city'.tr();
      }
      return null;
    },
    items: provider.algerianCities.map((city) {
      return DropdownMenuItem(value: city, child: Text(city));
    }).toList(),
    menuMaxHeight: 300,
  );
}

Widget _buildSpecialtyDropdown(
  BuildContext context,
  ClinicOnboardingProvider provider,
) {
  return DropdownButtonFormField<String>(
    initialValue: provider.selectedSpecialty,
    decoration: InputDecoration(
      labelText: "specialty".tr(),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: Text("select_specialty".tr()),

    onChanged: provider.selectSpecialty,
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'please_select_a_specialty'.tr();
      }
      return null;
    },
    items: provider.specialties.map((s) {
      return DropdownMenuItem(value: s, child: Text(s.tr()));
    }).toList(),
    menuMaxHeight: 250,
  );
}

Widget _buildWorkingDaysChips(
  BuildContext context,
  ClinicOnboardingProvider provider,
) {
  final dayNames = [
    "Monday".tr(),
    "Tuesday".tr(),
    "Wednesday".tr(),
    "Thursday".tr(),
    "Friday".tr(),
    "Saturday".tr(),
    "Sunday".tr(),
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

Widget _buildTimePickerRow(
  BuildContext context,
  String label,
  String type,
  ClinicOnboardingProvider provider,
) {
  String? timeText;
  switch (type) {
    case 'opening':
      timeText = provider.openingMinutes != null
          ? "${provider.openingMinutes! ~/ 60}:${(provider.openingMinutes! % 60).toString().padLeft(2, '0')}"
          : null;
      break;
    case 'closing':
      timeText = provider.closingMinutes != null
          ? "${provider.closingMinutes! ~/ 60}:${(provider.closingMinutes! % 60).toString().padLeft(2, '0')}"
          : null;
      break;
    case 'breakStart':
      timeText = provider.breakStartMinutes != null
          ? "${provider.breakStartMinutes! ~/ 60}:${(provider.breakStartMinutes! % 60).toString().padLeft(2, '0')}"
          : null;
      break;
    case 'breakEnd':
      timeText = provider.breakEndMinutes != null
          ? "${provider.breakEndMinutes! ~/ 60}:${(provider.breakEndMinutes! % 60).toString().padLeft(2, '0')}"
          : null;
      break;
  }

  return Row(
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
      TextButton.icon(
        icon: const Icon(LucideIcons.clock),
        label: Text(timeText ?? "select_time".tr()),
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

Widget _buildAvatarPicker(
  BuildContext context,
  ClinicOnboardingProvider provider,
) {
  return SizedBox(
    height: MediaQuery.of(context).size.height * 0.2,
    width: MediaQuery.of(context).size.width * 0.3,
    child: GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 1,
      itemBuilder: (cntx, i) {
        return GestureDetector(
          onTap: () {
            provider.pickImage();
          },
          child: CircleAvatar(
            radius: 11,
            backgroundColor: provider.pickedImage != null
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            child: provider.pickedImage == null
                ? const Icon(Icons.add_a_photo, size: 30)
                : Image.file(provider.pickedImage!),
          ),
        );
      },
    ),
  );
}
