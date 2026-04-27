import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/intro.dart';
import 'package:eyadati/user/userEditProfile.dart';
import 'package:eyadati/utils/markdown_viewer_screen.dart';
import 'package:eyadati/utils/firestore_helper.dart';
import 'package:eyadati/Themes/ThemeProvider.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DocumentSnapshot> _getPatientData() async {
  final prefs = await SharedPreferences.getInstance();
  final phone = prefs.getString('patient_phone');
  if (phone == null || phone.isEmpty) {
    return FirebaseFirestore.instance.collection('patients').doc('__placeholder__').get();
  }
  return FirebaseFirestore.instance.collection('patients').doc(phone).get();
}

class UserSettings extends StatelessWidget {
  const UserSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          FutureBuilder<DocumentSnapshot>(
            future: _getPatientData(),
            builder: (context, snapshot) {
              String name = 'User';
              if (snapshot.hasData && snapshot.data!.exists) {
                name = snapshot.data!.get('name') ?? 'User';
              }
              return Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      LucideIcons.user,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SettingsList(
                lightTheme: SettingsThemeData(
                  settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
                ),
                darkTheme: SettingsThemeData(
                  settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
                ),
                sections: [
                  SettingsSection(
                    title: Text('account_settings'.tr()),
                    tiles: [
                      SettingsTile.navigation(
                        title: Text('edit_profile'.tr()),
                        leading: const Icon(LucideIcons.user),
                        onPressed: (_) => showMaterialModalBottomSheet(
                          expand: true,
                          context: context,
                          builder: (_) => const UserEditProfilePage(),
                        ),
                      ),
                      SettingsTile.navigation(
                        title: Text('language'.tr()),
                        leading: const Icon(LucideIcons.globe),
                        onPressed: (_) => _showLanguageDialog(context),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: Text('appearance'.tr()),
                    tiles: [
                      SettingsTile.switchTile(
                        onToggle: (value) {
                          Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                        },
                        initialValue: themeProvider.isDarkMode,
                        leading: const Icon(LucideIcons.moon),
                        title: Text('dark_mode'.tr()),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: Text('legal'.tr()),
                    tiles: [
                      SettingsTile.navigation(
                        title: Text('privacy_policy'.tr()),
                        leading: const Icon(LucideIcons.shieldCheck),
                        onPressed: (context) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MarkdownViewerScreen(
                              title: 'privacy_policy'.tr(),
                              markdownAssetPath: 'privacy_policy.md',
                            ),
                          ),
                        ),
                      ),
                      SettingsTile.navigation(
                        title: Text('terms_of_use'.tr()),
                        leading: const Icon(LucideIcons.fileText),
                        onPressed: (context) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MarkdownViewerScreen(
                              title: 'terms_of_use'.tr(),
                              markdownAssetPath: 'terms_of_service.md',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: Text('session'.tr()),
                    tiles: [
                      SettingsTile.navigation(
                        title: Text('log_out'.tr()),
                        leading: const Icon(LucideIcons.logOut),
                        onPressed: (context) async {
                          await FirestoreHelper.signOutWithPendingWrites();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('patient_phone');
                          await prefs.remove('role');
                          await prefs.remove('patient_name');
                          await prefs.remove('patient_city');
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (ctx) => const IntroScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('language'.tr()),
          content: StatefulBuilder(
            builder: (context, setState) {
              Locale selectedLocale = context.locale;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<Locale>(
                    title: Text('english'.tr()),
                    value: const Locale('en'),
                    groupValue: selectedLocale,
                    onChanged: (Locale? value) async {
                      if (value != null) {
                        await context.setLocale(value);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<Locale>(
                    title: Text('french'.tr()),
                    value: const Locale('fr'),
                    groupValue: selectedLocale,
                    onChanged: (Locale? value) async {
                      if (value != null) {
                        await context.setLocale(value);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<Locale>(
                    title: Text('arabic'.tr()),
                    value: const Locale('ar'),
                    groupValue: selectedLocale,
                    onChanged: (Locale? value) async {
                      if (value != null) {
                        await context.setLocale(value);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}