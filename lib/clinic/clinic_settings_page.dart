import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eyadati/chargili/paiment.dart';
import 'package:eyadati/clinic/clinic_edit_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:eyadati/utils/markdown_viewer_screen.dart'; 
import 'package:eyadati/utils/connectivity_service.dart'; 
import 'package:eyadati/utils/firestore_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eyadati/intro.dart';
import 'package:eyadati/Themes/ThemeProvider.dart' as theme_provider;

class ClinicsettingProvider extends ChangeNotifier {
  bool _isPaused = false;
  final ClinicFirestore _clinicFirestore;
  final String? _clinicUid = FirebaseAuth.instance.currentUser?.uid;

  ClinicsettingProvider(ConnectivityService connectivityService)
    : _clinicFirestore = ClinicFirestore(
        connectivityService: connectivityService,
      ) {
    _loadPauseStatus();
  }

  bool get isPaused => _isPaused;

  Future<void> _loadPauseStatus() async {
    if (_clinicUid != null) {
      final clinicData = await _clinicFirestore.getClinicData(_clinicUid);
      if (clinicData != null && clinicData['paused'] != null) {
        _isPaused = clinicData['paused'];
        notifyListeners();
      }
    }
  }

  Future<void> togglePauseStatus(bool newValue) async {
    if (_clinicUid != null) {
      _isPaused = newValue;
      notifyListeners();
      await _clinicFirestore.updateClinicPauseStatus(_clinicUid, newValue);
    }
  }
}

class Clinicsettings extends StatefulWidget {
  const Clinicsettings({super.key});

  @override
  State<Clinicsettings> createState() => _ClinicsettingsState();
}

class _ClinicsettingsState extends State<Clinicsettings> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? clinicUid = FirebaseAuth.instance.currentUser?.uid;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ClinicsettingProvider(
            Provider.of<ConnectivityService>(context, listen: false),
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        body: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Builder(
              builder: (context) {
                final clinicSettingProvider = context.watch<ClinicsettingProvider>();

                return Column(
                  children: [
                    const SizedBox(height: 20),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: clinicUid != null
                          ? clinicSettingProvider._clinicFirestore.getClinicData(clinicUid)
                          : Future.value(null),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return const CircleAvatar(
                            radius: 50,
                            child: Icon(LucideIcons.alertCircle),
                          );
                        } else if (snapshot.hasData && snapshot.data!['picUrl'] != null) {
                          return CircleAvatar(
                            radius: 50,
                            backgroundImage: CachedNetworkImageProvider(snapshot.data!['picUrl']),
                          );
                        } else {
                          return const CircleAvatar(
                            radius: 50,
                            child: Icon(LucideIcons.user),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    SettingsList(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      lightTheme: SettingsThemeData(
                        settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      darkTheme: SettingsThemeData(
                        settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      sections: [
                        SettingsSection(
                          title: Text('appearance'.tr()),
                          tiles: [
                            SettingsTile.switchTile(
                              onToggle: (value) {
                                Provider.of<theme_provider.ThemeProvider>(context, listen: false).toggleTheme();
                              },
                              initialValue: Provider.of<theme_provider.ThemeProvider>(context).isDarkMode,
                              leading: const Icon(LucideIcons.moon),
                              title: Text('dark_mode'.tr()),
                            ),
                          ],
                        ),
                        SettingsSection(
                          tiles: [
                            SettingsTile.navigation(
                              title: Text('edit_profile'.tr()),
                              leading: const Icon(LucideIcons.user),
                              onPressed: (_) => showMaterialModalBottomSheet(
                                expand: true,
                                context: context,
                                builder: (_) => ClinicEditProfilePage(),
                              ),
                            ),
                            SettingsTile.navigation(
                              title: Text('language'.tr()),
                              leading: const Icon(LucideIcons.globe),
                              onPressed: (_) => _showLanguageDialog(context),
                            ),
                            SettingsTile.navigation(
                              title: Text('payment'.tr()),
                              leading: const Icon(LucideIcons.creditCard),
                              onPressed: (_) => showMaterialModalBottomSheet(
                                expand: true,
                                context: context,
                                builder: (_) => SubscribeScreen(),
                              ),
                            ),
                            SettingsTile.navigation(
                              title: Text('reset_password'.tr()),
                              leading: const Icon(LucideIcons.lock),
                              onPressed: (context) => _handlePasswordReset(context),
                            ),
                            SettingsTile.switchTile(
                              onToggle: (value) {
                                clinicSettingProvider.togglePauseStatus(value);
                              },
                              initialValue: clinicSettingProvider.isPaused,
                              title: Text('pause_profile'.tr()),
                              leading: const Icon(LucideIcons.pauseCircle),
                            ),
                            SettingsTile.navigation(
                              title: Text('qr_code'.tr()),
                              leading: const Icon(LucideIcons.qrCode),
                              onPressed: (_) => _showQrDialog(context, clinicUid),
                            ),
                            SettingsTile.navigation(
                              title: Text('log_out'.tr()),
                              leading: const Icon(LucideIcons.logOut),
                              onPressed: (_) async {
                                await FirestoreHelper.signOutWithPendingWrites();
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('role');
                                await prefs.remove('patient_phone');
                                if (!context.mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (ctx) => const IntroScreen()),
                                  (route) => false,
                                );
                              },
                            ),
                            SettingsTile.navigation(
                              title: Text('terms_of_service'.tr()),
                              leading: const Icon(LucideIcons.fileText),
                              onPressed: (context) => _navigateToMarkdown(context, 'terms_of_service'.tr(), 'terms_of_service.md'),
                            ),
                            SettingsTile.navigation(
                              title: Text('privacy_policy'.tr()),
                              leading: const Icon(LucideIcons.fileLock),
                              onPressed: (context) => _navigateToMarkdown(context, 'privacy_policy'.tr(), 'privacy_policy.md'),
                            ),
                            SettingsTile.navigation(
                              title: Text('delete_account'.tr(), style: const TextStyle(color: Colors.red)),
                              leading: const Icon(LucideIcons.trash2, color: Colors.red),
                              onPressed: (_) => _showDeleteAccountDialog(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
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

  void _showQrDialog(BuildContext context, String? clinicUid) {
    if (clinicUid == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('qr_code'.tr()),
        content: SizedBox(
          width: 250,
          height: 250,
          child: Center(
            child: QrImageView(
              data: clinicUid,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _navigateToMarkdown(BuildContext context, String title, String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MarkdownViewerScreen(
          title: title,
          markdownAssetPath: path,
        ),
      ),
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
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_account_confirmation_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('delete_account_confirmation_message'.tr()),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ClinicFirestore().deleteClinicAccount(passwordController.text);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (ctx) => const IntroScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('error_deleting_account'.tr(args: [e.toString()]))),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }
}
