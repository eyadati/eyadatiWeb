import 'package:eyadati/utils/colors.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ClinicRequestRegistrationScreen extends StatelessWidget {
  const ClinicRequestRegistrationScreen({super.key});

  final String whatsappNumber =
      "213562025180"; // Replace with your actual number (format: CCXXXXXXXXX)

  Future<void> _launchWhatsApp() async {
    final message = "whatsapp_message".tr();
    // Using wa.me as recommended by WhatsApp
    final url = "https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);

    try {
      // On some platforms canLaunchUrl might return false even if it can be launched
      // especially if queries are not perfectly set up, so we try anyway in a try-catch
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some android versions/browsers
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint("Could not launch WhatsApp: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('join_eyadati'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shieldCheck, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'verified_clinic_program'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'registration_instruction_text'.tr() ==
                        'registration_instruction_text'
                    ? "To maintain the highest quality and trust, Eyadati registrations are now handled directly. Contact us on WhatsApp to schedule a verification visit and set up your account."
                    : 'registration_instruction_text'.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _launchWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsappGreen, // WhatsApp Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.messageCircle),
                label: Text(
                  'contact_on_whatsapp'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('back_to_login'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
