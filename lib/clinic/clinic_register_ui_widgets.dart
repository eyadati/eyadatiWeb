import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/clinic/clinic_registration_provider.dart';
import 'package:eyadati/clinic/clinic_home.dart';
import 'package:eyadati/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

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

    if (!provider.phoneVerified) {
      return _EmailSignUpStep(provider: provider);
    }

    return _ClinicFormContent(provider: provider);
  }
}

class _EmailSignUpStep extends StatefulWidget {
  final ClinicOnboardingProvider provider;

  const _EmailSignUpStep({required this.provider});

  @override
  State<_EmailSignUpStep> createState() => _EmailSignUpStepState();
}

class _EmailSignUpStepState extends State<_EmailSignUpStep> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: provider.emailFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 80),
            const SizedBox(height: 32),
            Text(
              'register_clinic'.tr(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'create_account_to_continue'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: provider.emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'email'.tr(),
                prefixIcon: const Icon(LucideIcons.mail),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'please_enter_email'.tr();
                }
                if (!value.contains('@')) {
                  return 'invalid_email'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: provider.passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                prefixIcon: const Icon(LucideIcons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'please_enter_password'.tr();
                }
                if (value.length < 6) {
                  return 'password_too_short'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: provider.confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'confirm_password'.tr(),
                prefixIcon: const Icon(LucideIcons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? LucideIcons.eye
                        : LucideIcons.eyeOff,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'please_confirm_password'.tr();
                }
                if (value != provider.passwordController.text) {
                  return 'passwords_not_match'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await provider.signUpWithEmail(context);
                        setState(() => _isLoading = false);
                      },
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.userPlus),
                label: Text(
                  _isLoading ? 'creating_account'.tr() : 'register'.tr(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'already_have_account'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _LoginDialog(provider: provider),
                );
              },
              child: Text('login'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginDialog extends StatefulWidget {
  final ClinicOnboardingProvider provider;

  const _LoginDialog({required this.provider});

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('clinic_login'.tr()),
      content: Form(
        key: widget.provider.emailFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.provider.emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'email'.tr(),
                prefixIcon: const Icon(LucideIcons.mail),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.provider.passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                prefixIcon: const Icon(LucideIcons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  await widget.provider.signInWithEmail(context);
                  setState(() => _isLoading = false);
                  if (widget.provider.phoneVerified && context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('login'.tr()),
        ),
      ],
    );
  }
}

class _ClinicFormContent extends StatelessWidget {
  final ClinicOnboardingProvider provider;

  const _ClinicFormContent({required this.provider});

  Widget _buildTextFormField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    FocusNode? nextNode,
    bool obscureText = false,
    TextInputType? inputType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: inputType,
      onFieldSubmitted: (_) {
        if (nextNode != null) {
          nextNode.requestFocus();
        }
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: provider.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                provider.phoneVerified ? Icons.check_circle : Icons.phone,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (provider.phoneVerified)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.checkCircle,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'account_ready'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'account_information'.tr()),
            _buildTextFormField(
              context,
              controller: provider.nameController,
              label: 'Full Name'.tr(),
              validator: provider.validateRequired,
              focusNode: provider.focusNodes[0],
              nextNode: provider.focusNodes[1],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.clinicPhoneController,
              label: 'phone_number'.tr(),
              validator: provider.validatePhone,
              focusNode: provider.focusNodes[1],
              nextNode: provider.focusNodes[2],
              inputType: TextInputType.phone,
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(context, 'business_information'.tr()),
            _buildTextFormField(
              context,
              controller: provider.clinicNameController,
              label: 'Business Name'.tr(),
              validator: provider.validateRequired,
              focusNode: provider.focusNodes[2],
              nextNode: provider.focusNodes[3],
            ),
            const SizedBox(height: 16),
            _buildSpecialtyDropdown(context, provider),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.durationController,
              label: 'appointment_duration_minutes'.tr(),
              inputType: TextInputType.number,
              focusNode: provider.focusNodes[3],
              nextNode: provider.focusNodes[4],
            ),
            const SizedBox(height: 16),
            _buildDoctorsStepper(context, provider),
            const SizedBox(height: 32),

            _buildSectionTitle(context, 'address_and_contact'.tr()),
            _buildCityDropdown(context, provider),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.addressController,
              label: 'Address'.tr(),
              validator: provider.validateRequired,
              focusNode: provider.focusNodes[5],
              nextNode: provider.focusNodes[6],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              context,
              controller: provider.mapsLinkController,
              label: 'Google Maps link'.tr(),
              focusNode: provider.focusNodes[6],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('https://www.google.com/maps');
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(LucideIcons.mapPin),
                    label: Text('search_location'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(context, 'working_hours'.tr()),
            _buildWorkingDaysSelector(context, provider),
            const SizedBox(height: 16),
            _buildTimeRow(context, 'opening'.tr(), provider.openingMinutes, (
              value,
            ) {
              provider.openingMinutes = value;
              provider.notifyListeners();
            }),
            const SizedBox(height: 8),
            _buildTimeRow(context, 'closing'.tr(), provider.closingMinutes, (
              value,
            ) {
              provider.closingMinutes = value;
              provider.notifyListeners();
            }),
            const SizedBox(height: 8),
            _buildTimeRow(
              context,
              'break_start'.tr(),
              provider.breakStartMinutes,
              (value) {
                provider.breakStartMinutes = value;
                provider.notifyListeners();
              },
            ),
            const SizedBox(height: 8),
            _buildTimeRow(context, 'break_end'.tr(), provider.breakEndMinutes, (
              value,
            ) {
              provider.breakEndMinutes = value;
              provider.notifyListeners();
            }),
            const SizedBox(height: 16),
            _buildClinicImagePicker(context, provider),
            const SizedBox(height: 24),
            _buildTermsCheckbox(context, provider),
            const SizedBox(height: 24),
            _buildSubmitButton(context, provider),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialtyDropdown(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    return DropdownButtonFormField<String>(
      value: provider.selectedSpecialty,
      decoration: InputDecoration(
        labelText: 'specialty'.tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(LucideIcons.stethoscope),
      ),
      items: AppConstants.specialties.map((specialty) {
        return DropdownMenuItem(value: specialty, child: Text(specialty.tr()));
      }).toList(),
      onChanged: (value) {
        provider.selectedSpecialty = value;
        provider.notifyListeners();
      },
      validator: (value) =>
          value == null ? 'please_select_a_specialty'.tr() : null,
    );
  }

  Widget _buildCityDropdown(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    return DropdownButtonFormField<String>(
      value: provider.selectedCity,
      decoration: InputDecoration(
        labelText: 'city'.tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(LucideIcons.mapPin),
      ),
      items: AppConstants.algerianCities.map((city) {
        return DropdownMenuItem(value: city, child: Text(city));
      }).toList(),
      onChanged: (value) {
        provider.selectedCity = value;
        provider.notifyListeners();
      },
      validator: (value) => value == null ? 'city_required'.tr() : null,
    );
  }

  Widget _buildWorkingDaysSelector(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    final days = [
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
      children: List.generate(7, (index) {
        final isSelected = provider.workingDays.contains(index);
        return FilterChip(
          label: Text(days[index]),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              provider.workingDays.add(index);
            } else {
              provider.workingDays.remove(index);
            }
            provider.notifyListeners();
          },
        );
      }),
    );
  }

  Widget _buildTimeRow(
    BuildContext context,
    String label,
    int? minutes,
    void Function(int?) onChanged,
  ) {
    final time = minutes != null
        ? TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60)
        : null;

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) {
          onChanged(picked.hour * 60 + picked.minute);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.clock,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    minutes != null
                        ? '${time!.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                        : 'select_time'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: minutes != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronDown,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsStepper(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    final doctors = int.tryParse(provider.doctorsController.text) ?? 1;
    final clampedDoctors = doctors.clamp(1, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'number_of_doctors'.tr()),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: clampedDoctors > 1
                    ? () {
                        provider.doctorsController.text = (clampedDoctors - 1)
                            .toString();
                        provider.notifyListeners();
                      }
                    : null,
                icon: Icon(
                  LucideIcons.minus,
                  color: clampedDoctors > 1
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    clampedDoctors.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    clampedDoctors == 1 ? 'doctor' : 'doctors',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: clampedDoctors < 10
                    ? () {
                        provider.doctorsController.text = (clampedDoctors + 1)
                            .toString();
                        provider.notifyListeners();
                      }
                    : null,
                icon: Icon(
                  LucideIcons.plus,
                  color: clampedDoctors < 10
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClinicImagePicker(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'clinic_image'.tr()),
        InkWell(
          onTap: () => _showImagePickerDialog(context, provider),
          child: Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: provider.pickedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<List<int>>(
                      future: provider.pickedImage!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            Uint8List.fromList(snapshot.data!),
                            fit: BoxFit.cover,
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.camera,
                        size: 32,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'add_photo'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (provider.picUrl != null && provider.pickedImage == null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showImagePickerDialog(context, provider),
            icon: const Icon(LucideIcons.edit),
            label: Text('change_photo'.tr()),
          ),
        ],
      ],
    );
  }

  void _showImagePickerDialog(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: Text('take_photo'.tr()),
              onTap: () {
                Navigator.pop(context);
                provider.pickImage();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: Text('choose_from_gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                provider.pickImage();
              },
            ),
            if (provider.pickedImage != null)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.red),
                title: Text(
                  'remove_photo'.tr(),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  provider.selectAvatar(-1); // Clear picked image
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    return CheckboxListTile(
      value: provider.agreeToTerms,
      onChanged: (value) => provider.toggleAgreeToTerms(value),
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
            ),
            TextSpan(text: 'and'.tr()),
            TextSpan(
              text: 'terms_of_service'.tr(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    ClinicOnboardingProvider provider,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: provider.isSubmitting
            ? null
            : () async {
                if (await provider.validateAndSubmit(context)) {
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const Clinichome()),
                      (route) => false,
                    );
                  }
                }
              },
        child: provider.isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('complete_setup'.tr()),
      ),
    );
  }
}
