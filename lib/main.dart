import 'package:eyadati/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:eyadati/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/flow.dart';
import 'package:eyadati/intro.dart';
import 'package:eyadati/Themes/ThemeProvider.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pwa_install/pwa_install.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      debugPrint("FLUTTER ERROR: ${details.exception}");
      debugPrint("STACK TRACE: ${details.stack}");
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("ASYNC ERROR: $error");
    return true;
  };

  PWAInstall().setup();
  await EasyLocalization.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FlutterError.onError = (errorDetails) {
      debugPrint(errorDetails.toString());
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint(error.toString());
      return true;
    };

    await Supabase.initialize(
      url: "https://erkldarqweehvwgpncrg.supabase.co",
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVya2xkYXJxd2VlaHZ3Z3BuY3JnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5MTIyMDgsImV4cCI6MjA3NzQ4ODIwOH0.rQPh6hFnn6sz78rLa8_AWU3NV__-EgX8wDOTXbyeQ7o",
    );

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          child: const EyadatiApp(),
        ),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.alertTriangle,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'initialization_error'.tr(),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EyadatiApp extends StatefulWidget {
  const EyadatiApp({super.key});

  @override
  State<EyadatiApp> createState() => _EyadatiAppState();
}

class _EyadatiAppState extends State<EyadatiApp> {
  late Future<Widget> _navigationFuture;

  @override
  void initState() {
    super.initState();
    _navigationFuture = _initializeAndDecide();
  }

  Future<Widget> _initializeAndDecide() async {
    try {
      final Widget homePage = await decidePage(context);
      return homePage;
    } catch (e) {
      debugPrint("Initialization error: $e");
      if (!mounted) return const SizedBox.shrink();
      return intro();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown
        },
      ),
      theme: themeProvider.themeData.copyWith(
        textTheme: themeProvider.themeData.textTheme.copyWith(
          bodyLarge: themeProvider.themeData.textTheme.bodyLarge?.copyWith(
            fontWeight: kIsWeb ? FontWeight.w500 : null,
          ),
          bodyMedium: themeProvider.themeData.textTheme.bodyMedium?.copyWith(
            fontWeight: kIsWeb ? FontWeight.w500 : null,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: PWAInstallWrapper(
        child: FutureBuilder<Widget>(
          future: _navigationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            } else if (snapshot.hasError) {
              debugPrint("Error loading initial page: ${snapshot.error}");
              return intro();
            } else if (snapshot.hasData) {
              return snapshot.data!;
            }
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}

class PWAInstallWrapper extends StatefulWidget {
  final Widget child;
  const PWAInstallWrapper({super.key, required this.child});

  @override
  State<PWAInstallWrapper> createState() => _PWAInstallWrapperState();
}

class _PWAInstallWrapperState extends State<PWAInstallWrapper> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (PWAInstall().installPromptEnabled && !_dismissed)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(LucideIcons.download, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "install_eyadati".tr() == "install_eyadati" ? "Install Eyadati" : "install_eyadati".tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "install_for_better_experience".tr(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        PWAInstall().promptInstall_();
                      },
                      child: Text("install".tr()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _dismissed = true),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
