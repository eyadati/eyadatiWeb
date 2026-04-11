import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/intro.dart';
import 'package:eyadati/user/userEditProfile.dart';
import 'package:eyadati/utils/markdown_viewer_screen.dart';
import 'package:eyadati/Themes/ThemeProvider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class UserSettings extends StatelessWidget {
  const UserSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // User Profile Header
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
            builder: (context, snapshot) {
              String name = "User";
              if (snapshot.hasData && snapshot.data!.exists) {
                name = snapshot.data!.get('name') ?? "User";
              }
              return Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(LucideIcons.user, size: 50, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? "",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SettingsList(
              lightTheme: SettingsThemeData(
                settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
              ),
              darkTheme: SettingsThemeData(
                settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
              ),
              sections: [
                SettingsSection(
                  title: Text("account_settings".tr()),
                  tiles: [
                    SettingsTile.navigation(
                      title: Text("edit_profile".tr()),
                      leading: const Icon(LucideIcons.user),
                      onPressed: (_) => showMaterialModalBottomSheet(
                        expand: true,
                        context: context,
                        builder: (_) => const UserEditProfilePage(),
                      ),
                    ),
                    SettingsTile.navigation(
                      title: Text("language".tr()),
                      leading: const Icon(LucideIcons.globe),
                      onPressed: (_) => _showLanguageDialog(context),
                    ),
                    SettingsTile.navigation(
                      title: Text("reset_password".tr()),
                      leading: const Icon(LucideIcons.lock),
                      onPressed: (context) => _handlePasswordReset(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: Text("appearance".tr()),
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) {
                        Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                      },
                      initialValue: themeProvider.isDarkMode,
                      leading: const Icon(LucideIcons.moon),
                      title: Text("dark_mode".tr()),
                    ),
                  ],
                ),
                SettingsSection(
                  title: Text("contact_us".tr()),
                  tiles: [
                    SettingsTile(
                      title: Text("email".tr()),
                      leading: const Icon(LucideIcons.mail),
                      description: const Text("eyadati.dz@gmail.com"),
                    ),
                    SettingsTile(
                      title: Text("whatsapp".tr()),
                      leading: const Icon(LucideIcons.phone),
                      description: const Text("+213562025180"),
                    ),
                  ],
                ),
                SettingsSection(
                  title: Text("legal".tr()),
                  tiles: [
                    SettingsTile.navigation(
                      title: Text("privacy_policy".tr()),
                      leading: const Icon(LucideIcons.shieldCheck),
                      onPressed: (context) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarkdownViewerScreen(
                            title: "privacy_policy".tr(),
                            markdownAssetPath: "privacy_policy.md",
                          ),
                        ),
                      ),
                    ),
                    SettingsTile.navigation(
                      title: Text("terms_of_use".tr()),
                      leading: const Icon(LucideIcons.fileText),
                      onPressed: (context) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarkdownViewerScreen(
                            title: "terms_of_use".tr(),
                            markdownAssetPath: "terms_of_service.md",
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: Text("session".tr()),
                  tiles: [
                    SettingsTile.navigation(
                      title: Text("log_out".tr()),
                      leading: const Icon(LucideIcons.logOut),
                      onPressed: (context) async {
                        await FirebaseAuth.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (ctx) => const IntroScreen()),
                          (route) => false,
                        );
                      },
                    ),
                    SettingsTile.navigation(
                      title: Text(
                        "delete_account".tr(),
                        style: const TextStyle(color: Colors.red),
                      ),
                      leading: const Icon(LucideIcons.trash2, color: Colors.red),
                      onPressed: (context) => _showDeleteAccountDialog(context),
                    ),
                  ],
                ),
              ],
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
          title: Text("language".tr()),
          content: StatefulBuilder(
            builder: (context, setState) {
              Locale selectedLocale = context.locale;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<Locale>(
                    title: const Text('English'),
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
                    title: const Text('Français'),
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
                    title: const Text('العربية'),
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

  Future<void> _handlePasswordReset(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('password_reset_email_sent'.tr())),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generic'.tr())),
        );
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("delete_account".tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("are_you_sure_to_delete_account".tr()),
              const SizedBox(height: 8),
              Text(
                "this_action_is_irreversible".tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr()),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.delete();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (ctx) => const IntroScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("error_deleting_account".tr(args: [e.toString()]))),
                  );
                  Navigator.pop(context);
                }
              },
              child: Text("yes".tr(), style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
