import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:table_calendar/table_calendar.dart';

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
  final FirebaseAuth auth;
  late final int duration;

  String _userName = '';
  String _userPhone = '';

  SlotsUiProvider({
    required this.clinic,
    required this.firestore,
    FirebaseAuth? auth,
  }) : auth = auth ?? FirebaseAuth.instance {
    _initializeData();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = auth.currentUser;
    if (user != null) {
      final userDoc = await firestore
          .collection('users')
          .doc(user.uid)
          .get(GetOptions(source: Source.cache));
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userName = data['name'] ?? '';
        _userPhone = data['phone'] ?? '';
        notifyListeners();
      }
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
        .doc(clinic['uid'])
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

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
    final data = clinic;
    final opening = data['openingAt'] as int;
    final closing = data['closingAt'] as int;
    final breakStart = data['breakStart'] as int?;
    final breakEnd = (data['breakEnd'] ?? data['break']) as int?;
    final duration = (data['duration'] ?? data['Duration']) as int?;
    final workingDays = List<int>.from(data['workingDays'] ?? []);

    // Check if clinic is open
    if (!workingDays.contains(selectedDate.weekday)) {
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

    final slotDuration = duration ?? 60;

    // Generate all possible slots
    List<SlotInfo> generatedSlots = [];
    while (currentSlot.isBefore(closingTime)) {
      final bookings = bookingCounts[currentSlot] ?? 0;
      final isAvailable = bookings < (data['staff'] as int? ?? 1);

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

  Future<void> _addAppointmentToCalendar() async {
    if (selectedSlot == null) return;

    final slotInfo = allSlots.firstWhere((s) => s.time == selectedSlot);

    final Event event = Event(
      title: 'Appointment at ${clinic['clinicName']}',
      startDate: selectedSlot!,
      endDate: selectedSlot!.add(Duration(minutes: slotInfo.duration)),
      location: clinic['address'],
    );

    await Add2Calendar.addEvent2Cal(event);
  }

  Future<bool> bookSelectedSlot({
    required String userName,
    required String userPhone,
    bool addToCalendar = true,
  }) async {
    if (selectedSlot == null) return false;

    try {
      if (addToCalendar) {
        try {
          await _addAppointmentToCalendar();
        } catch (e) {
          debugPrint("Error adding to calendar: $e");
          // Do not rethrow, just log and continue with booking
        }
      }

      await firestore.runTransaction((transaction) async {
        final slotInfo = allSlots.firstWhere((s) => s.time == selectedSlot);

        final slotStart = Timestamp.fromDate(selectedSlot!);
        final slotEnd = Timestamp.fromDate(
          selectedSlot!.add(Duration(minutes: slotInfo.duration)),
        );

        final querySnapshot = await firestore
            .collection('clinics')
            .doc(clinic['uid'])
            .collection('appointments')
            .where('date', isGreaterThanOrEqualTo: slotStart)
            .where('date', isLessThan: slotEnd)
            .get();

        final staffCount = clinic['staff'] as int? ?? 1;
        if (querySnapshot.docs.length >= staffCount) {
          throw Exception('slot is full'.tr());
        }

        final appointmentId =
            "${clinic['uid']}_${auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}";
        
        // Save the provided user name and phone directly into the appointment
        final appointmentData = {
          "clinicUid": clinic['uid'],
          "userUid": auth.currentUser!.uid,
          "date": slotStart,
          "userName": userName,
          "phone": userPhone,
          "createdAt": FieldValue.serverTimestamp(),
        };

        transaction.set(
          firestore
              .collection('clinics')
              .doc(clinic['uid'])
              .collection('appointments')
              .doc(appointmentId),
          appointmentData,
        );
        transaction.set(
          firestore
              .collection('users')
              .doc(auth.currentUser!.uid)
              .collection('appointments')
              .doc(appointmentId),
          appointmentData,
        );
      });

      await _loadSlots();
      notifyListeners();
      return true; // Booking successful
    } catch (e) {
      errorMessage = 'booking failed'.tr(args: [e.toString()]);
      notifyListeners();
      return false; // Booking failed
    }
  }
}

// ================ UI DIALOG ================

class SlotsUi {
  static Future<bool?> showModalSheet(
    BuildContext context,
    Map<String, dynamic> clinic,
  ) {
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
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: const _SlotsDialog(),
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
    final clinic = provider.clinic;

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
      final nameController = TextEditingController(text: provider._userName);
      final phoneController = TextEditingController(text: provider._userPhone);

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
                    clinic['clinicName'],
                  ),
                  const SizedBox(height: 8),
                  _buildConfirmationRow(
                    stfContext,
                    'date'.tr(),
                    DateFormat('yyyy-MM-dd', context.locale.toString()).format(provider.selectedDate),
                  ),
                  const SizedBox(height: 8),
                  _buildConfirmationRow(
                    stfContext,
                    'time'.tr(),
                    DateFormat('HH:mm', context.locale.toString()).format(provider.selectedSlot!),
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
          userName: name,
          userPhone: phone,
          addToCalendar: addToCalendar,
        );
        if (!context.mounted) return;

        if (bookingSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('booking_success'.tr())));
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(provider.errorMessage)));
        }
      }
    }

    return SafeArea(
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          children: [
            _ClinicInfoCard(clinic: clinic),
            const SizedBox(height: 10),
            _DatePickerRow(),
            Flexible(child: _SlotsGrid()),
            Container(
              margin: const EdgeInsets.all(12),
              width: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: handleBookAppointment,
                child: Text(
                  "book_appointment".tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
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
              clinic['clinicName'] ?? 'clinic unnamed'.tr(),
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
                  style: TextStyle(fontWeight: FontWeight.w500),
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
                  .join(', ')
                  .tr(),
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
                DateFormat('MMM d, yyyy', context.locale.toString()).format(provider.focusedDay),
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
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlotsUiProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
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
      return Center(child: Text('no slots available'.tr()));
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
    final timeString = DateFormat('HH:mm', context.locale.toString()).format(slotInfo.time);
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
