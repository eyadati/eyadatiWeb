import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/Appointments/clinicsList.dart';
import 'package:eyadati/user/user_appointments.dart';
import 'package:eyadati/utils/widgets.dart';
import 'package:eyadati/utils/skeletons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:eyadati/user/userSettingsPage.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:eyadati/NavBarUi/user_nav_bar_provider.dart';

class PatientWebUI extends StatelessWidget {
  const PatientWebUI({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surfaceContainerHighest;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ClinicSearchProvider(
            firestore: FirebaseFirestore.instance,
            auth: FirebaseAuth.instance,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => UserAppointmentsProvider(
            connectivityService: Provider.of<ConnectivityService>(
              context,
              listen: false,
            ),
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Image.asset('assets/logo.png', height: 120),
          centerTitle: true,
          backgroundColor: bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(LucideIcons.settings),
              onPressed: () => showMaterialModalBottomSheet(
                enableDrag: false,
                context: context,
                builder: (context) => const UserSettings(),
              ),
            ),
          ),
        ),
        body: Row(
          children: [
            // Left Side: Filter & Clinic Search (40%)
            const Expanded(flex: 4, child: _WebClinicSearchSide()),
            // Right Side: Patient Appointments (60%)
            const Expanded(flex: 6, child: _PatientAppointmentsSide()),
          ],
        ),
      ),
    );
  }
}

class _WebClinicSearchSide extends StatefulWidget {
  const _WebClinicSearchSide();

  @override
  State<_WebClinicSearchSide> createState() => _WebClinicSearchSideState();
}

class _WebClinicSearchSideState extends State<_WebClinicSearchSide> {
  String? _tempCity;
  String? _tempSpec;
  bool _showFavoritesOnly = false;
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<ClinicSearchProvider>();
    final navProvider = context.watch<UserNavBarProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'find_clinics'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        // Filters Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _tempCity ?? searchProvider.userCity,
                    decoration: InputDecoration(
                      labelText: "city".tr(),
                      prefixIcon: const Icon(LucideIcons.mapPin, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: searchProvider.algerianCitiesList
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _tempCity = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _tempSpec,
                    decoration: InputDecoration(
                      labelText: "specialty".tr(),
                      prefixIcon: const Icon(LucideIcons.stethoscope, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: searchProvider.specialtiesList
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.tr())),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _tempSpec = v),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text("show_favorites".tr()),
                    secondary: const Icon(LucideIcons.heart),
                    value: _showFavoritesOnly,
                    onChanged: (v) {
                      setState(() => _showFavoritesOnly = v);
                      searchProvider.applyFilters(
                        city: _tempCity ?? searchProvider.userCity,
                        specialty: _tempSpec,
                        favoritesOnly: v,
                        favoriteIds: navProvider.favoriteIds,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        searchProvider.applyFilters(
                          city: _tempCity ?? searchProvider.userCity,
                          specialty: _tempSpec,
                          favoritesOnly: _showFavoritesOnly,
                          favoriteIds: navProvider.favoriteIds,
                        );
                      },
                      icon: const Icon(LucideIcons.search, size: 18),
                      label: Text('search'.tr()),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Results Section
        Expanded(
          child:
              searchProvider.isLoading && searchProvider.currentClinics.isEmpty
              ? ListView.builder(
                  itemCount: 5,
                  itemBuilder: (_, __) => const ClinicCardSkeleton(),
                )
              : searchProvider.currentClinics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.searchX,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'no_clinics_found'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: searchProvider.currentClinics.length,
                    itemBuilder: (context, index) {
                      final clinic = searchProvider.currentClinics[index];
                      return ClinicCard(clinic: clinic);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _PatientAppointmentsSide extends StatefulWidget {
  const _PatientAppointmentsSide();

  @override
  State<_PatientAppointmentsSide> createState() =>
      _PatientAppointmentsSideState();
}

class _PatientAppointmentsSideState extends State<_PatientAppointmentsSide> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'my_appointments'.tr() == 'my_appointments'
                ? 'My Appointments'
                : 'my_appointments'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: Appointmentslistview(scrollController: _scrollController),
          ),
        ),
      ],
    );
  }
}
