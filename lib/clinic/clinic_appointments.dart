import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/FCM/notificationsService.dart';
import 'package:eyadati/clinic/clinicSettingsPage.dart';
import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Manages clinic appointment state with optimized Firestore queries
/// and proper lifecycle management to prevent memory leaks.
class ClinicAppointmentProvider extends ChangeNotifier {
  final String clinicId;
  DateTime selectedDate;
  final ClinicFirestore _clinicFirestore; // Add this field

  // Calendar state moved to provider
  DateTime focusedDay = DateTime.now();
  CalendarFormat calendarFormat;

  late Stream<QuerySnapshot> _appointmentsStream;
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;
  DocumentSnapshot<Map<String, dynamic>>? _clinicData;
  DocumentSnapshot<Map<String, dynamic>>? get clinicData => _clinicData;
  final ConnectivityService? _connectivityService; // Add this field

  // Implement lastSyncTimestamp getter
  Future<DateTime?> get lastSyncTimestamp =>
      _clinicFirestore.getLastSyncTimestamp(clinicId);

  ClinicAppointmentProvider({
    required this.clinicId,
    DateTime? initialDate,
    ClinicFirestore? clinicFirestore,
    ConnectivityService? connectivityService,
  })  : selectedDate = (initialDate ?? DateTime.now()),
        focusedDay = (initialDate ?? DateTime.now()),
        calendarFormat = CalendarFormat.month,
        _clinicFirestore = clinicFirestore ?? ClinicFirestore(),
        _connectivityService = connectivityService {
    _appointmentsStream = _createAppointmentsStream();
    _listenToAppointmentsStream();

    _connectivityService?.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    if (_connectivityService?.isOnline == true) {
      // If reconnected and data might be stale (e.g., from cache), refresh
      _checkAndRefreshDataOnReconnect();
    }
  }

  Future<void> _checkAndRefreshDataOnReconnect() async {
    final lastSync = await lastSyncTimestamp;
    if (lastSync != null &&
        DateTime.now().difference(lastSync).inMinutes > 5) {
      refresh();
    }
  }

  void _listenToAppointmentsStream() {
    _appointmentsSubscription?.cancel(); // Cancel previous subscription
    _appointmentsSubscription = _appointmentsStream.listen((snapshot) {
      // No specific logic needed here for now, as the StreamBuilder in the UI
      // directly consumes the stream. This primarily ensures the subscription
      // is active and managed by the provider for proper disposal.
    });
  }

  Stream<QuerySnapshot> _createAppointmentsStream() {
    final dayStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('date', isLessThan: Timestamp.fromDate(dayEnd))
        .where('date', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('date')
        .snapshots(includeMetadataChanges: true);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getClinicData() async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore
        .collection('clinics')
        .doc(clinicId)
        .get(GetOptions(source: Source.cache));
    _clinicData = doc;
    return doc;
  }

  /// Fetches monthly appointment data for calendar markers
  Future<Map<DateTime, int>> getHeatMapData() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final snapshot = await FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .get();

    final heatMapData = <DateTime, int>{};
    for (var doc in snapshot.docs) {
      final appointmentDate = (doc.data()['date'] as Timestamp).toDate();
      final dateKey = DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
      );
      heatMapData[dateKey] = (heatMapData[dateKey] ?? 0) + 1;
    }
    return heatMapData;
  }

  /// Updates the selected date and refreshes appointment stream
  void updateSelectedDate(DateTime date) {
    selectedDate = date;
    focusedDay = date;
    _appointmentsStream = _createAppointmentsStream();
    _listenToAppointmentsStream(); // Re-subscribe to the new stream
    notifyListeners();
  }

  /// Updates calendar focus day
  void updateFocusedDay(DateTime day) {
    focusedDay = day;
    notifyListeners();
  }

  /// Updates calendar format (month/week)
  void updateCalendarFormat(CalendarFormat format) {
    calendarFormat = format;
    notifyListeners();
  }

  Future<void> refresh() async {
    _appointmentsStream = _createAppointmentsStream();
    _listenToAppointmentsStream();
    notifyListeners();
  }

  /// Cancels an appointment and sends notification
  Future<void> cancelAppointment(
    String appointmentId,
    Map<String, dynamic> appointmentData,
    BuildContext context,
  ) async {
    await ClinicFirestore().cancelAppointment(appointmentId, clinicId, context);

    if (appointmentData['FCM'] != null) {
      await NotificationService().sendDirectNotification(
        fcmToken: appointmentData['FCM'],
        title: 'appointment_cancelled'.tr(),
        body: 'your_appointment_got_cancelled'.tr(),
      );
    }
  }

  /// Cleans up stream subscription to prevent memory leaks
  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _connectivityService?.removeListener(_onConnectivityChange); // Remove listener
    super.dispose();
  }

  // Getter for stream access
  Stream<QuerySnapshot> get appointmentsStream => _appointmentsStream;

  /// Utility to parse integers safely
  int _parseInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Gets the clinic's default appointment duration
  int getClinicDuration() {
    return _parseInt(
      _clinicData?.data()?['duration'],
      60,
    ); // Default to 60 minutes
  }
}

/// Main widget that provides the appointment management state
class ClinicAppointments extends StatelessWidget {
  final String clinicId;

  const ClinicAppointments({super.key, required this.clinicId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
        return ClinicAppointmentProvider(
          clinicId: clinicId,
          clinicFirestore: ClinicFirestore(connectivityService: connectivityService),
          connectivityService: connectivityService, // Pass connectivityService here
        );
      },
      child: const _ClinicAppointmentsView(),
    );
  }
}

class _ClinicAppointmentsView extends StatefulWidget {
  const _ClinicAppointmentsView();

  @override
  State<_ClinicAppointmentsView> createState() =>
      _ClinicAppointmentsViewState();
}

class _ClinicAppointmentsViewState extends State<_ClinicAppointmentsView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshData();
    }
  }

  Future<void> _checkAndRefreshData() async {
    final provider = context.read<ClinicAppointmentProvider>();
    final lastSync = await provider.lastSyncTimestamp;
    if (lastSync != null &&
        DateTime.now().difference(lastSync).inMinutes > 5) {
      provider.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Image.asset('assets/logo.png', height: 120),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        actions: [
          IconButton(
            onPressed: () => showModalBottomSheet(
              isScrollControlled: true,
              context: context,
              builder: (context) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: Clinicsettings(),
                );
              },
            ),
            icon: Icon(
              LucideIcons.settings,
              
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Card(
                color: Theme.of(context).colorScheme.onPrimary,
                child: const _NormalCalendar(),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            // Appointments list below calendar
            const Expanded(child: _AppointmentsPanel()),
          ],
        ),
      ),
    );
  }
}

/// Normal calendar widget with appointment markers
class _NormalCalendar extends StatelessWidget {
  const _NormalCalendar();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ClinicAppointmentProvider>();

    return FutureBuilder<Map<DateTime, int>>(
      future: provider.getHeatMapData(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Calendar error: ${snapshot.error}');
          return Center(
            child: Icon(
              LucideIcons.alertTriangle,
              color: Theme.of(context).colorScheme.error,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return _CalendarContent(appointmentCounts: snapshot.data!);
      },
    );
  }
}

/// Provider-based calendar content (StatelessWidget)
class _CalendarContent extends StatelessWidget {
  final Map<DateTime, int> appointmentCounts;

  const _CalendarContent({required this.appointmentCounts});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicAppointmentProvider>();

    return TableCalendar(
      locale: context.locale.toString(),
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      focusedDay: provider.focusedDay,
      calendarFormat: CalendarFormat.month,
      selectedDayPredicate: (day) => isSameDay(provider.selectedDate, day),

      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(provider.selectedDate, selectedDay)) {
          provider.updateSelectedDate(selectedDay);
          provider.updateFocusedDay(focusedDay);
        }
      },

      eventLoader: (day) {
        final count = appointmentCounts[day] ?? 0;
        return List.generate(count, (index) => 'Appointment ${index + 1}');
      },

      calendarStyle: CalendarStyle(
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 5,
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),

      headerStyle: HeaderStyle(titleCentered: true),
    );
  }
}

/// Daily appointments list with swipe-to-cancel
class _AppointmentsPanel extends StatelessWidget {
  const _AppointmentsPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicAppointmentProvider>();

    return StreamBuilder<QuerySnapshot>(
      stream: provider.appointmentsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Appointments error: ${snapshot.error}');
          return Center(
            child: Text(
              'error_loading_appointments'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  'no_appointments_for_this_day'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
                // Display last sync timestamp here
                FutureBuilder<DateTime?>(
                  future: provider.lastSyncTimestamp,
                  builder: (context, timestampSnapshot) {
                    if (timestampSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (timestampSnapshot.hasData && timestampSnapshot.data != null) {
                      final formattedTime = DateFormat.yMd(context.locale.toString()).add_Hms().format(timestampSnapshot.data!);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'last_synced_at'.tr(args: [formattedTime]),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        }

        final appointments = snapshot.data!.docs;
        final metadata = snapshot.data!.metadata;

        return Column(
          children: [
            if (metadata.isFromCache || metadata.hasPendingWrites)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (metadata.isFromCache)
                      Tooltip(
                        message: 'offline_mode_data_from_cache'.tr(),
                        child: Icon(
                          LucideIcons.cloudOff,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    if (metadata.hasPendingWrites) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'local_changes_pending_sync'.tr(),
                        child: Icon(
                          LucideIcons.rotateCcw,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded( // Use Expanded to give RefreshIndicator flexible height
              child: RefreshIndicator(
                onRefresh: provider.refresh, // Connect to the refresh method
                child: Container(
                  padding: EdgeInsets.only(top: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(13),
                      topRight: Radius.circular(13),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    // Remove NeverScrollableScrollPhysics when RefreshIndicator is used
                    // physics: const NeverScrollableScrollPhysics(),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final doc = appointments[index];
                      final appointment = doc.data() as Map<String, dynamic>;
                      final appointmentId = doc.id;

                  final clinicDuration = provider
                      .getClinicDuration(); // Get duration from provider
                  final slot = (appointment['date'] as Timestamp).toDate();
                  final slotEnd = slot.add(Duration(minutes: clinicDuration));
                  final timeFormatted = DateFormat('HH:mm', context.locale.toString()).format(slot);
                  final timeEndFormatter = DateFormat('HH:mm', context.locale.toString()).format(slotEnd);
                  final name = appointment['userName'] ?? 'Unknown';
                  final phone = appointment['phone'] ?? 'No phone';

                  return Slidable(
                    key: ValueKey(appointmentId),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      extentRatio: 0.2,
                      children: [
                        IconButton(
                          onPressed: () async {
                            await provider.cancelAppointment(
                              appointmentId,
                              appointment,
                              context,
                            );
                          },
                          icon: Icon(
                            LucideIcons.xCircle,
                            color: Theme.of(context).colorScheme.error,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 130,
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),

                        child: Row(
                          children: [
                            SizedBox(
                              width: 50,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Center(child: Text("$timeFormatted")),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                trailing: Icon(
                                  LucideIcons.chevronLeft,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                title: Text(name),
                                subtitle: Text(phone),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
          ],
        );
      },
    );
  }
}
