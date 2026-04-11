import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/clinic/clinic_auth_selection.dart';
import 'package:eyadati/user/user_auth_selection.dart';
import 'package:eyadati/utils/markdown_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

Widget intro() {
  return const IntroScreen();
}

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('language_selection'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Français'),
              onTap: () {
                context.setLocale(const Locale('fr'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('العربية'),
              onTap: () {
                context.setLocale(const Locale('ar'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              onTap: () {
                context.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.languages,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => _showLanguageDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Larger logo
              Image.asset('assets/logo.png', height: 180),
              const SizedBox(height: 32),
              Text(
                'intro_description'.tr() == 'intro_description'
                    ? "Your healthcare journey starts here."
                    : 'intro_description'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Patient Path
              _buildPathButton(
                context,
                title: 'patient_side'.tr() == 'patient_side'
                    ? "I am a Patient"
                    : 'patient_side'.tr(),
                icon: LucideIcons.user,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserAuthSelectionScreen(),
                    ),
                  );
                },
                isPrimary: true,
              ),
              const SizedBox(height: 16),
              // Clinic Path
              _buildPathButton(
                context,
                title: 'clinic_side'.tr() == 'patient_side'
                    ? "I am a Clinic"
                    : 'clinic_side'.tr(),
                icon: LucideIcons.stethoscope,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ClinicAuthSelectionScreen(),
                    ),
                  );
                },
                isPrimary: false,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarkdownViewerScreen(
                        title: "privacy_policy".tr(),
                        markdownAssetPath: "privacy_policy.md",
                      ),
                    ),
                  );
                },
                child: Text(
                  "privacy_policy".tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isPrimary
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: isPrimary
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isPrimary ? 2 : 0,
        ),
        icon: Icon(icon),
        label: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
