import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:eyadati/utils/skeletons.dart';
import 'package:eyadati/FCM/notifications_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pwa_install/pwa_install.dart' as pwa;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// For web functionality
// For web functionality - using package:web instead of deprecated dart:html
import 'package:web/web.dart' as html;

// ================ PROVIDER ================
class SlotInfo {
  final DateTime time;
  final bool isAvailable;
  final int currentBookings;
  final int duration;

  SlotInfo({
    required this.duration,
    required this.time,
    required this.isAvailable,
    required this.currentBookings,
  });
}

class SlotsUiProvider extends ChangeNotifier {
  final Map<String, dynamic> clinic;
  final FirebaseFirestore firestore;
  late final int duration;

  String _patientName = '';
  String _patientPhone = '';

  late Map<String, dynamic> _fullClinicData;
  Map<String, dynamic> get clinicData => _fullClinicData;

  SlotsUiProvider({
    required this.clinic,
    required this.firestore,
  }) {
    _fullClinicData = Map<String, dynamic>.from(clinic);
    if (!_fullClinicData.containsKey('uid') &&
        _fullClinicData.containsKey('id')) {
      _fullClinicData['uid'] = _fullClinicData['id'];
    }
    _initializeData();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _patientName = prefs.getString('patient_name') ?? '';
      _patientPhone = prefs.getString('patient_phone') ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading patient data: $e');
    }
  }

  // Calendar state moved to provider
  DateTime focusedDay = DateTime.now();
  // State
  DateTime selectedDate = DateTime.now();
  List<SlotInfo> allSlots = [];
  DateTime? selectedSlot;
  bool isLoading = false;
  String errorMessage = '';
  int staffCount = 1;

  // Slot info with availability status

  Future<void> _initializeData() async {
    isLoading = true;
    notifyListeners();

    try {
      // Ensure UID is present
      final String? clinicUid = _fullClinicData['uid'] ?? _fullClinicData['id'];
      if (clinicUid == null) throw Exception('clinic_not_found'.tr());

      // If clinic data is incomplete (e.g. from favorites snapshot), fetch the full doc
      if (!_fullClinicData.containsKey('openingAt') ||
          !_fullClinicData.containsKey('duration')) {
        final doc = await firestore
            .collection('clinics')
            .doc(clinicUid)
            .get(const GetOptions(source: Source.serverAndCache));

        if (doc.exists) {
          _fullClinicData = doc.data()!;
          _fullClinicData['uid'] = doc.id; // Ensure UID is present
        } else {
          throw Exception('clinic_not_found'.tr());
        }
      } else {
        // Just ensure UID is set if we skipped fetch
        _fullClinicData['uid'] = clinicUid;
      }

      await _loadSlots();
    } catch (e) {
      errorMessage = 'failed_load_slots'.tr(args: [e.toString()]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateSelectedDate(DateTime date) {
    selectedDate = date;
    focusedDay = date;
    debugPrint(selectedDate.toString());
    debugPrint(focusedDay.toString());
    notifyListeners();
  }

  /// Updates calendar focus day
  void updateFocusedDay(DateTime day) {
    focusedDay = day;
    notifyListeners();
  }

  Future<void> nextWeek() async {
    selectedDate = selectedDate.add(const Duration(days: 7));
    focusedDay = focusedDay.add(const Duration(days: 7));
    selectedSlot = null;
    allSlots = [];
    await _loadSlots();
    notifyListeners();
  }

  Future<void> previousWeek() async {
    selectedDate = selectedDate.subtract(const Duration(days: 7));
    focusedDay = focusedDay.subtract(const Duration(days: 7));
    selectedSlot = null;
    allSlots = [];
    await _loadSlots();
    notifyListeners();
  }

  Future<void> _loadSlots() async {
    allSlots = []; // Clear first

    // Get appointments for the day
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await firestore
        .collection('clinics')
        .doc(clinicData['uid'])
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get(const GetOptions(source: Source.server));

    // Count bookings per EXACT slot start time
    final bookingCounts = <DateTime, int>{};
    for (var doc in snapshot.docs) {
      final appointmentTime = (doc.data()['date'] as Timestamp).toDate();
      // ✅ Use the exact appointment time as key
      final slotKey = DateTime(
        appointmentTime.year,
        appointmentTime.month,
        appointmentTime.day,
        appointmentTime.hour,
        appointmentTime.minute,
      );
      bookingCounts[slotKey] = (bookingCounts[slotKey] ?? 0) + 1;
    }

    // Use clinic configuration from provider's field
    final data = clinicData;

    // SAFE PARSING HELPER
    int parseInt(dynamic value, int defaultValue) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    final opening = parseInt(data['openingAt'], 480); // Default 8:00
    final closing = parseInt(data['closingAt'], 1080); // Default 18:00
    final breakStart = data['breakStart'] != null
        ? parseInt(data['breakStart'], 720)
        : null;
    final breakEnd = (data['breakEnd'] ?? data['break']) != null
        ? parseInt(data['breakEnd'] ?? data['break'], 840)
        : null;
    final duration = parseInt(data['duration'] ?? data['Duration'], 60);
    final workingDaysList =
        (data['workingDays'] as List?)?.map((e) => parseInt(e, 0)).toList() ??
        [];

    // Check if clinic is open
    if (!workingDaysList.contains(selectedDate.weekday)) {
      allSlots = []; // Ensure old slots are cleared
      return;
    }

    DateTime currentSlot = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      opening ~/ 60,
      opening % 60,
    );

    final closingTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      closing ~/ 60,
      closing % 60,
    );

    final slotDuration = duration;

    // Generate all possible slots
    List<SlotInfo> generatedSlots = [];
    final staffCountValue = parseInt(data['staff'], 1);
    final now = DateTime.now();

    while (currentSlot.isBefore(closingTime)) {
      // Skip if the slot is in the past (for today)
      if (currentSlot.isBefore(now)) {
        currentSlot = currentSlot.add(Duration(minutes: slotDuration));
        continue;
      }

      final bookings = bookingCounts[currentSlot] ?? 0;
      final isAvailable = bookings < staffCountValue;

      generatedSlots.add(
        SlotInfo(
          time: currentSlot,
          duration: slotDuration,
          isAvailable: isAvailable,
          currentBookings: bookings,
        ),
      );
      currentSlot = currentSlot.add(Duration(minutes: slotDuration));
    }

    // Filter out slots that overlap with breaks
    if (breakStart != null && breakEnd != null) {
      final breakStartTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        breakStart ~/ 60,
        breakStart % 60,
      );
      final breakEndTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        breakEnd ~/ 60,
        breakEnd % 60,
      );

      allSlots = generatedSlots.where((slot) {
        final slotEnd = slot.time.add(Duration(minutes: slot.duration));
        // Keep slot if it does NOT overlap with the break
        return !(slot.time.isBefore(breakEndTime) &&
            slotEnd.isAfter(breakStartTime));
      }).toList();
    } else {
      allSlots = generatedSlots;
    }
  }

  Future<void> changeDate(DateTime picked) async {
    selectedDate = DateTime(picked.year, picked.month, picked.day);
    selectedSlot = null;
    focusedDay = DateTime(picked.year, picked.month, picked.day);
    allSlots = []; // Clear old slots
    await _loadSlots(); // Regenerate for new date
    notifyListeners();
  }

  void selectSlot(DateTime slot) {
    // Only allow selecting available slots
    final slotInfo = allSlots.firstWhere(
      (s) => s.time == slot,
      orElse: () => SlotInfo(
        time: slot,
        isAvailable: false,
        currentBookings: 0,
        duration: duration,
      ),
    );

    if (slotInfo.isAvailable) {
      selectedSlot = slot;
      notifyListeners();
    }
  }

  Future<bool> confirmBooking() async {
    if (selectedSlot == null) return false;
    return true;
  }

  String _generateIcsContent(
    DateTime start,
    DateTime end,
    String title,
    String location,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Eyadati//Appointment//EN');
    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('UID:${DateTime.now().millisecondsSinceEpoch}@eyadati');
    buffer.writeln('DTSTART:${_formatIcsDate(start)}');
    buffer.writeln('DTEND:${_formatIcsDate(end)}');
    buffer.writeln('SUMMARY:$title');
    buffer.writeln('LOCATION:$location');
    buffer.writeln('END:VEVENT');
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _formatIcsDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}00';
  }

  Future<void> _addAppointmentToCalendar() async {
    if (selectedSlot == null) return;

    try {
      final slotInfo = allSlots.firstWhere((s) => s.time == selectedSlot);
      final endTime = selectedSlot!.add(Duration(minutes: slotInfo.duration));
      final title = 'Appointment at ${clinicData['clinicName']}';
      final location = clinicData['address'] ?? '';

      final icsContent = _generateIcsContent(
        selectedSlot!,
        endTime,
        title,
        location,
      );
      final encoded = base64Encode(utf8.encode(icsContent));
      final url = 'data:text/calendar;charset=utf-8;base64,$encoded';

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error adding to calendar: $e');
    }
  }

  Future<bool> bookSelectedSlot({
    required String patientName,
    required String patientPhone,
    bool addToCalendar = true,
  }) async {
    debugPrint('Booking started: $patientName, $patientPhone');
    if (selectedSlot == null) {
      debugPrint('Booking failed: No slot selected');
      return false;
    }

    try {
      if (addToCalendar) {
        try {
          await _addAppointmentToCalendar();
        } catch (e) {
          debugPrint('Error adding to calendar: $e');
        }
      }

      final slotInfo = allSlots.firstWhere((s) => s.time == selectedSlot);
      final slotStart = Timestamp.fromDate(selectedSlot!);
      final slotEnd = Timestamp.fromDate(
        selectedSlot!.add(Duration(minutes: slotInfo.duration)),
      );

      final String? clinicUid = clinicData['uid'];
      if (clinicUid == null) {
        throw Exception('Clinic UID is missing');
      }

      debugPrint('Checking occupancy for clinic: $clinicUid');
      final querySnapshot = await firestore
          .collection('clinics')
          .doc(clinicUid)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: slotStart)
          .where('date', isLessThan: slotEnd)
          .get(const GetOptions(source: Source.server));

      final staffCount = clinicData['staff'] as int? ?? 1;
      debugPrint(
        'Current bookings: ${querySnapshot.docs.length}, Staff: $staffCount',
      );
      if (querySnapshot.docs.length >= staffCount) {
        throw Exception('slot_is_full'.tr());
      }

      final appointmentId =
          '${clinicUid}_${patientPhone}_${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('Running transaction for patient: $patientPhone');

      // Save patient to patients collection
      final patientRef = firestore.collection('patients').doc(patientPhone);
      
      await firestore.runTransaction((transaction) async {
        final appointmentData = {
          'clinicUid': clinicUid,
          'patientName': patientName,
          'phone': patientPhone,
          'date': slotStart,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'status': 'upcoming',
        };

        transaction.set(
          firestore
              .collection('clinics')
              .doc(clinicUid)
              .collection('appointments')
              .doc(appointmentId),
          appointmentData,
        );

        transaction.set(
          patientRef,
          {
            'phone': patientPhone,
            'name': patientName,
            'lastBookingAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.update(firestore.collection('clinics').doc(clinicUid), {
          'appointments_this_month': FieldValue.increment(1),
        });
      });

      // Save to localStorage for auto-fill
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('patient_name', patientName);
        await prefs.setString('patient_phone', patientPhone);
      } catch (e) {
        debugPrint('Error saving to localStorage: $e');
      }

      debugPrint('Booking transaction successful');

      if (clinicData['fcm'] != null) {
        try {
          await NotificationService().sendDirectNotification(
            fcmToken: clinicData['fcm'],
            title: 'new_appointment_booked'.tr(),
            body: 'patient_booked_appointment_at'.tr(
              args: [patientName, DateFormat('HH:mm').format(selectedSlot!)],
            ),
            data: {
              'type': 'new_appointment',
              'appointmentId': appointmentId,
            },
          );
        } catch (e) {
          debugPrint('Error sending booking notification: $e');
        }
      }

      await _loadSlots();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('BOOKING ERROR: $e');
      errorMessage = 'booking_failed'.tr(args: [e.toString()]);
      notifyListeners();
      return false;
    }
  }
}

// ================ UI DIALOG ================

class SlotsUi {
  static Future<bool?> showModalSheet(
    BuildContext context,
    Map<String, dynamic> clinic,
  ) {
    if (kIsWeb && MediaQuery.of(context).size.width > 900) {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
            child: ChangeNotifierProvider(
              create: (_) => SlotsUiProvider(
                clinic: clinic,
                firestore: FirebaseFirestore.instance,
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                child: _SlotsDialog(),
              ),
            ),
          ),
        ),
      );
    }
    return showMaterialModalBottomSheet(
      expand: true,
      context: context,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => SlotsUiProvider(
          clinic: clinic,
          firestore: FirebaseFirestore.instance,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: const _SlotsDialog(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotsDialog extends StatelessWidget {
  const _SlotsDialog();

  // Helper method to build a confirmation row for the dialog
  Widget _buildConfirmationRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlotsUiProvider>();
    final clinic = provider.clinicData;

    Future<void> handleBookAppointment() async {
      if (provider.selectedSlot == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('select_a_slot_first'.tr())));
        return;
      }

      bool addToCalendar = true;

      // Create controllers and initialize them
      final nameController = TextEditingController(text: provider._patientName);
      final phoneController = TextEditingController(text: provider._patientPhone);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (stfContext, setState) => AlertDialog(
            title: Text('confirm_appointment'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmationRow(
                    stfContext,
                    'clinic'.tr(),
                    provider.clinicData['clinicName'],
                  ),
                  const SizedBox(height: 8),
                  _buildConfirmationRow(
                    stfContext,
                    'date'.tr(),
                    DateFormat(
                      'yyyy-MM-dd',
                      context.locale.toString(),
                    ).format(provider.selectedDate),
                  ),
                  const SizedBox(height: 8),
                  _buildConfirmationRow(
                    stfContext,
                    'time'.tr(),
                    DateFormat(
                      'HH:mm',
                      context.locale.toString(),
                    ).format(provider.selectedSlot!),
                  ),
                  const Divider(height: 24),
                  // Editable TextFields for user info
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'full_name'.tr(),
                      icon: const Icon(LucideIcons.user),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'phone_number'.tr(),
                      icon: const Icon(LucideIcons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  if (!kIsWeb)
                    CheckboxListTile(
                      title: Text('add_to_calendar'.tr()),
                      value: addToCalendar,
                      onChanged: (newValue) {
                        setState(() {
                          addToCalendar = newValue!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.camera,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'take_photo_note'.tr(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withAlpha(100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'appointment_fee_note'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('confirm'.tr()),
              ),
            ],
          ),
        ),
      );

      // Dispose controllers
      final name = nameController.text;
      final phone = phoneController.text;
      nameController.dispose();
      phoneController.dispose();

      if (!context.mounted) return;
      if (confirmed ?? false) {
        final bookingSuccess = await provider.bookSelectedSlot(
          patientName: name,
          patientPhone: phone,
          addToCalendar: addToCalendar,
        );
        if (!context.mounted) return;

        if (bookingSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('booking_success'.tr())));

          Navigator.of(context).pop(); // Close modal

          // Check if PWA is installed before showing dialog
          final bool isPwaInstalled =
              kIsWeb &&
              ((html.window.navigator as dynamic).standalone == true ||
                  html.window.matchMedia('(display-mode: standalone)').matches);

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                isPwaInstalled
                    ? 'open_app_title'.tr()
                    : 'install_app_title'.tr(),
              ),
              content: Text(
                isPwaInstalled
                    ? 'open_app_message'.tr()
                    : 'install_app_message'.tr(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('later'.tr()),
                ),
                if (!isPwaInstalled) ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Trigger PWA installation
                      pwa.PWAInstall().promptInstall_();
                    },
                    child: Text('install'.tr()),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Trigger opening the app (this is more of a suggestion since we can't directly open it)
                      // In a PWA context, this would typically just dismiss the dialog
                      // as the app is already running
                    },
                    child: Text('open'.tr()),
                  ),
                ],
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(provider.errorMessage)));
        }
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ClinicInfoCard(clinic: clinic),
              const SizedBox(height: 10),
              _DatePickerRow(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: _SlotsGrid(),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.all(12),
                width: MediaQuery.of(context).size.width * 0.7,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  onPressed: handleBookAppointment,
                  child: Text(
                    'book_appointment'.tr(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/*TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: provider.selectedSlot == null
              ? null
              : () => provider.bookSelectedSlot(context),
          child: Text('book'.tr()),
        ),*/
class _ClinicInfoCard extends StatelessWidget {
  final Map<String, dynamic> clinic;

  const _ClinicInfoCard({required this.clinic});

  @override
  Widget build(BuildContext context) {
    final workingDays = List<int>.from(clinic['workingDays'] ?? []);
    final dayNames = [
      'monday'.tr(),
      'tuesday'.tr(),
      'wednesday'.tr(),
      'thursday'.tr(),
      'friday'.tr(),
      'saturday'.tr(),
      'sunday'.tr(),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 45,
                backgroundImage:
                    (clinic['picUrl'] != null &&
                        clinic['picUrl'].startsWith('http'))
                    ? CachedNetworkImageProvider(clinic['picUrl'])
                    : (clinic['picUrl'] != null
                              ? AssetImage(clinic['picUrl'])
                              : null)
                          as ImageProvider?,
                child: clinic['picUrl'] == null
                    ? const Icon(Icons.business) // Placeholder icon
                    : null,
              ),
            ),
            SizedBox(height: 20),
            Text(
              clinic['clinicName'] ?? 'clinic_unnamed'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Text(
                  '  ${clinic['specialty']}  ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text('${clinic['address'] ?? ""}'),
            const SizedBox(height: 4),
            Text(
              workingDays
                  .where((d) => d >= 1 && d <= 7)
                  .map((d) => dayNames[d - 1])
                  .join(', '),
            ),

            const SizedBox(height: 4),
            Text(
              '${_formatTime(clinic['openingAt'])} - ${_formatTime(clinic['closingAt'])}   ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int? minutes) {
    if (minutes == null) return '--:--';
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlotsUiProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => provider.previousWeek(),
              ),
              Text(
                DateFormat(
                  'MMM d, yyyy',
                  context.locale.toString(),
                ).format(provider.focusedDay),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => provider.nextWeek(),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 90, // Adjusted height to accommodate new header and calendar
          child: TableCalendar(
            locale: context.locale.toString(),
            selectedDayPredicate: (day) =>
                isSameDay(provider.selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(provider.selectedDate, selectedDay)) {
                provider.changeDate(selectedDay);
              }
            },
            headerVisible: false, // Hide default header as we have a custom one
            calendarStyle: CalendarStyle(
              markersMaxCount: 5,
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              defaultTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              weekendTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              outsideDaysVisible: false,
            ),
            focusedDay: provider.focusedDay,
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(
              Duration(days: 90),
            ), // Extend last day to allow further navigation
            calendarFormat: CalendarFormat.week,
          ),
        ),
      ],
    );
  }
}

class _SlotsGrid extends StatelessWidget {
  const _SlotsGrid();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlotsUiProvider>();

    if (provider.isLoading) {
      return const SlotGridSkeleton();
    }

    if (provider.errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          provider.errorMessage,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (provider.allSlots.isEmpty) {
      return Center(child: Text('no_slots_available'.tr()));
    }

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: provider.allSlots.length,
      itemBuilder: (context, index) {
        final slotInfo = provider.allSlots[index];
        final isSelected = provider.selectedSlot == slotInfo.time;

        return _SlotTile(
          slotInfo: slotInfo,
          isSelected: isSelected,
          onTap: () => provider.selectSlot(slotInfo.time),
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  final SlotInfo slotInfo;
  final bool isSelected;
  final VoidCallback onTap;

  const _SlotTile({
    required this.slotInfo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeString = DateFormat(
      'HH:mm',
      context.locale.toString(),
    ).format(slotInfo.time);
    final isFull = !slotInfo.isAvailable;

    return GestureDetector(
      onTap: isFull ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: 1,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : isFull
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isFull
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
            if (isFull) ...[] else if (!isSelected) ...[],
          ],
        ),
      ),
    );
  }
}
