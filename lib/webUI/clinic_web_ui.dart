import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eyadati/clinic/clinic_appointments.dart';
import 'package:eyadati/NavBarUi/appointments_management.dart';
import 'package:eyadati/NavBarUi/clinic_nav_bar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:eyadati/clinic/clinic_settings_page.dart';

class ClinicWebUI extends StatelessWidget {
  const ClinicWebUI({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<CliniNavBarProvider>();
    final clinicUid = navProvider.clinicUid;
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // Left Side: Online Appointment (Home UI in phone version)
          Expanded(
            flex: 1,
            child: ClinicAppointments(clinicId: clinicUid),
          ),
          // Right Side: Management Side (Management UI in phone version)
          Expanded(flex: 1, child: ManagementScreen(clinicUid: clinicUid)),
        ],
      ),
    );
  }
}
