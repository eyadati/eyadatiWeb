import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eyadati/chargili/paiment.dart';
import 'package:eyadati/clinic/clinicEditeProfile.dart';
import 'package:eyadati/flow.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:eyadati/Themes/ThemeProvider.dart';
import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:eyadati/utils/markdown_viewer_screen.dart'; // Import the MarkdownViewerScreen
import 'package:eyadati/utils/connectivity_service.dart'; // Import ConnectivityService

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

class Clinicsettings extends StatelessWidget {
  const Clinicsettings({super.key});

  @override
  Widget build(BuildContext context) {
    final String? clinicUid = FirebaseAuth.instance.currentUser?.uid;
    // ClinicFirestore _clinicFirestore = ClinicFirestore(); // This instance is now provided via ClinicsettingProvider

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
        
          centerTitle: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: Consumer<ClinicsettingProvider>(
          builder: (context, clinicSettingProvider, child) {
            return Column(
              children: [
                SizedBox(height: 20),
                FutureBuilder<Map<String, dynamic>?>(
                  
                  future: clinicUid != null
                      ? clinicSettingProvider._clinicFirestore.getClinicData(
                          clinicUid,
                        )
                      : Future.value(null),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return CircleAvatar(
                        radius: 50,
                        child: Icon(LucideIcons.alertCircle), // Error icon
                      );
                    } else if (snapshot.hasData &&
                        snapshot.data!['picUrl'] != null) {
                      return CircleAvatar(
                        radius: 50,
                        backgroundImage: CachedNetworkImageProvider(snapshot.data!['picUrl']),
                      );
                    } else {
                      return CircleAvatar(
                        radius: 50,
                        child: Icon(LucideIcons.user), // Default icon
                      );
                    }
                  },
                ),
                SizedBox(height: 20),
                Expanded(
                  child: SettingsList(
                    sections: [
                      SettingsSection(
                        tiles: [
                          SettingsTile.navigation(
                            title: Text("edit_profile".tr()),
                            leading: Icon(LucideIcons.user),
                            onPressed: (_) => showModalBottomSheet(
                              context: context,
                              builder: (_) {
                                return ClinicEditProfilePage();
                              },
                            ),
                          ),
                          SettingsTile.navigation(
                            title: Text("language".tr()),
                            leading: Icon(LucideIcons.globe),
                            onPressed: (_) {
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
                                            // ignore: deprecated_member_use
                                            RadioListTile<Locale>(
                                              title: const Text('English'),
                                              value: const Locale('en'),
                                              // ignore: deprecated_member_use
                                              groupValue: selectedLocale,
                                              // ignore: deprecated_member_use
                                              onChanged: (Locale? value) async {
                                                if (value != null) {
                                                  setState(() {
                                                    selectedLocale = value;
                                                  });
                                                  await context.setLocale(value);
                                                  if (!context.mounted) return;
                                                  Navigator.pop(context);
                                                }
                                              },
                                            ),
                                            // ignore: deprecated_member_use
                                            RadioListTile<Locale>(
                                              title: const Text('Français'),
                                              value: const Locale('fr'),
                                              // ignore: deprecated_member_use
                                              groupValue: selectedLocale,
                                              // ignore: deprecated_member_use
                                              onChanged: (Locale? value) async {
                                                if (value != null) {
                                                  setState(() {
                                                    selectedLocale = value;
                                                  });
                                                  await context.setLocale(value);
                                                  if (!context.mounted) return;
                                                  Navigator.pop(context);
                                                }
                                              },
                                            ),
                                            // ignore: deprecated_member_use
                                            RadioListTile<Locale>(
                                              title: const Text('العربية'),
                                              value: const Locale('ar'),
                                              // ignore: deprecated_member_use
                                              groupValue: selectedLocale,
                                              // ignore: deprecated_member_use
                                              onChanged: (Locale? value) async {
                                                if (value != null) {
                                                  setState(() {
                                                    selectedLocale = value;
                                                  });
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
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text('close'.tr()),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          SettingsTile.navigation(
                            title: Text("subscription".tr()),
                            leading: Icon(LucideIcons.user),
                            onPressed: (_) => showModalBottomSheet(
                              context: context,
                              builder: (_) {
                                return SubscribeScreen();
                              },
                            ),
                          ),
                          SettingsTile.switchTile(
                            onToggle: (value) {
                              clinicSettingProvider.togglePauseStatus(value);
                            },
                            initialValue: clinicSettingProvider.isPaused,
                            title: Text("pause_profile".tr()),
                            leading: Icon(LucideIcons.pauseCircle),
                          ),
                          SettingsTile.switchTile(
                            onToggle: (value) {
                              Provider.of<ThemeProvider>(
                                context,
                                listen: false,
                              ).toggleTheme();
                            },
                            initialValue: Provider.of<ThemeProvider>(
                              context,
                            ).isDarkMode,
                            title: Text("dark_mode".tr()),
                            leading: Icon(LucideIcons.moon),
                          ),
                          SettingsTile.navigation(
                            title: Text("qr_code".tr()),
                            leading: Icon(LucideIcons.qrCode),
                            onPressed: (_) {
                              final clinicUid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (clinicUid != null) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text("qr_code".tr()),
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
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('close'.tr()),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                          SettingsTile.navigation(
                            title: Text("log_out".tr()),
                            leading: Icon(LucideIcons.globe),
                            onPressed: (_) {
                              FirebaseAuth.instance.signOut();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (ctx) => intro(ctx)),
                              );
                            },
                          ),
                          SettingsTile.navigation(
                            title: Text("terms_of_service".tr()),
                            leading: Icon(LucideIcons.fileText),
                            onPressed: (context) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MarkdownViewerScreen(
                                    title: "terms_of_service".tr(),
                                    markdownAssetPath: "terms_of_service.md",
                                  ),
                                ),
                              );
                            },
                          ),
                          SettingsTile.navigation(
                            title: Text("privacy_policy".tr()),
                            leading: Icon(LucideIcons.fileLock),
                            onPressed: (context) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MarkdownViewerScreen(
                                    title: "privacy_policy".tr(),
                                    markdownAssetPath: "privacy_policy.md",
                                  ),
                                ),
                              );
                            },
                          ),
                          SettingsTile.navigation(
                            title: Text("delete_account".tr()),
                            leading: Icon(
                              LucideIcons.trash2,
                              color: Colors.red,
                            ),
                            onPressed: (_) {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final TextEditingController
                                  passwordController =
                                      TextEditingController(); // Renamed
                                  return AlertDialog(
                                    title: Text(
                                      "delete_account_confirmation_title".tr(),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "delete_account_confirmation_message"
                                              .tr(),
                                        ),
                                        SizedBox(height: 16),
                                        TextField(
                                          controller:
                                              passwordController, // Renamed
                                          obscureText: true,
                                          decoration: InputDecoration(
                                            labelText: "password".tr(),
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text("cancel".tr()),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            await ClinicFirestore()
                                                .deleteClinicAccount(
                                                  context,
                                                  passwordController
                                                      .text, // Renamed
                                                );
                                            if (!context.mounted) return;
                                            Navigator.of(
                                              context,
                                            ).pop(); // Close dialog
                                            if (!context.mounted) return;
                                            // Navigate to login/intro screen after successful deletion
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                builder: (ctx) => intro(ctx),
                                              ),
                                              (route) => false,
                                            );
                                          } catch (e) {
                                            // Error handling is already in deleteClinicAccount
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Text("delete".tr()),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
