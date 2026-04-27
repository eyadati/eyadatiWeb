import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/FCM/notifications_service.dart';
import 'package:flutter/foundation.dart';
import 'package:eyadati/NavBarUi/clinic_nav_bar.dart';
import 'package:eyadati/clinic/clinic_settings_page.dart';
import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:eyadati/utils/models/clinic_model.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/skeletons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Manages clinic appointment state with optimized Firestore queries
/// and proper lifecycle management to prevent memory leaks.
class ClinicAppointmentProvider extends ChangeNotifier {
  final String clinicId;
  DateTime selectedDate;
  final ClinicFirestore _clinicFirestore;

  // Calendar state moved to provider
  DateTime focusedDay = DateTime.now();
  CalendarFormat calendarFormat;

  late Stream<QuerySnapshot> _appointmentsStream;
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;
  DocumentSnapshot<Map<String, dynamic>>? _clinicData;
  DocumentSnapshot<Map<String, dynamic>>? get clinicData => _clinicData;
  final ConnectivityService? _connectivityService;

  String _filter = 'online';
  String get filter => _filter;

  List<QueryDocumentSnapshot> _appointments = [];

  List<QueryDocumentSnapshot> get appointments {
    // Only return online appointments
    return _appointments.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['isManual'] != true;
    }).toList();
  }

  List<QueryDocumentSnapshot> get manualAppointments {
    return _appointments.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['isManual'] == true;
    }).toList();
  }

  void setFilter(String value) {
    // No-op as we only show online appointments now
    _filter = 'online';
    notifyListeners();
  }

  bool _isInitialLoading = true;
  bool get isInitialLoading => _isInitialLoading;
  SnapshotMetadata? _lastMetadata;
  SnapshotMetadata? get lastMetadata => _lastMetadata;

  // Implement lastSyncTimestamp getter
  Future<DateTime?> get lastSyncTimestamp =>
      _clinicFirestore.getLastSyncTimestamp(clinicId);

  ClinicAppointmentProvider({
    required this.clinicId,
    DateTime? initialDate,
    ClinicFirestore? clinicFirestore,
    ConnectivityService? connectivityService,
  }) : selectedDate = (initialDate ?? DateTime.now()),
       focusedDay = (initialDate ?? DateTime.now()),
       calendarFormat = CalendarFormat.month,
       _clinicFirestore = clinicFirestore ?? ClinicFirestore(),
       _connectivityService = connectivityService {
    _appointmentsStream = _createAppointmentsStream();
    _listenToAppointmentsStream();
    fetchHeatMapData(); // Initialize heatmap data

    _connectivityService?.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    if (_connectivityService?.isOnline == true) {
      _checkAndRefreshDataOnReconnect();
    }
  }

  Future<void> _checkAndRefreshDataOnReconnect() async {
    final lastSync = await lastSyncTimestamp;
    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes > 5) {
      refresh();
    }
  }

  void _listenToAppointmentsStream() {
    _appointmentsSubscription?.cancel();
    _appointmentsSubscription = _appointmentsStream.listen((snapshot) {
      _appointments = snapshot.docs;
      _lastMetadata = snapshot.metadata;
      _isInitialLoading = false;

      // Update heatmap automatically when appointments change (smooth refresh)
      fetchHeatMapData(silent: true);

      notifyListeners();
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

  Map<DateTime, int> _heatMapData = {};
  Map<DateTime, int> get heatMapData => _heatMapData;
  bool _isLoadingHeatMap = false;

  /// Fetches appointment counts for the visible calendar range
  Future<void> fetchHeatMapData({bool silent = false}) async {
    if (_isLoadingHeatMap) return;
    _isLoadingHeatMap = true;
    if (!silent) notifyListeners();

    final startOfWeek = focusedDay.subtract(
      Duration(days: focusedDay.weekday - 1),
    );
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final start = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final end = DateTime(
      endOfWeek.year,
      endOfWeek.month,
      endOfWeek.day,
      23,
      59,
      59,
    );

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final newData = <DateTime, int>{};
      for (var doc in snapshot.docs) {
        final appointmentDate = Clinic.parseDateTime(doc.data()['date']);
        final dateKey = DateTime(
          appointmentDate.year,
          appointmentDate.month,
          appointmentDate.day,
        );
        newData[dateKey] = (newData[dateKey] ?? 0) + 1;
      }

      _heatMapData = newData;
    } catch (e) {
      debugPrint('Error fetching heatmap data: $e');
    } finally {
      _isLoadingHeatMap = false;
      notifyListeners();
    }
  }

  /// Updates the selected date and refreshes appointment stream
  void updateSelectedDate(DateTime date) {
    selectedDate = date;
    focusedDay = date;

    // Smooth transition: keep old data until new stream emits
    // We don't set _isInitialLoading = true here to avoid the full-page spinner

    _appointmentsStream = _createAppointmentsStream();
    _listenToAppointmentsStream();
    fetchHeatMapData(silent: true);
    notifyListeners();
  }

  /// Updates calendar focus day (e.g. on swipe)
  void updateFocusedDay(DateTime day) {
    focusedDay = day;
    fetchHeatMapData(silent: true);
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
    // We don't clear data immediately to allow "smooth" transition
    notifyListeners();
  }

  /// Cancels an appointment and sends notification
  Future<void> cancelAppointment(
    String appointmentId,
    Map<String, dynamic> appointmentData,
  ) async {
    await ClinicFirestore().cancelAppointment(appointmentId, clinicId);

    if (appointmentData['fcm'] != null) {
      await NotificationService().sendDirectNotification(
        fcmToken: appointmentData['fcm'],
        title: 'appointment_cancelled'.tr(),
        body: 'your_appointment_got_cancelled'.tr(),
      );
    }
  }

  /// Cleans up stream subscription to prevent memory leaks
  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _connectivityService?.removeListener(
      _onConnectivityChange,
    ); // Remove listener
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
  final bool showAppBar;

  const ClinicAppointments({
    super.key,
    required this.clinicId,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final connectivityService = Provider.of<ConnectivityService>(
          context,
          listen: false,
        );
        return ClinicAppointmentProvider(
          clinicId: clinicId,
          clinicFirestore: ClinicFirestore(
            connectivityService: connectivityService,
          ),
          connectivityService:
              connectivityService, // Pass connectivityService here
        );
      },
      child: _ClinicAppointmentsView(showAppBar: showAppBar),
    );
  }
}

class _ClinicAppointmentsView extends StatefulWidget {
  final bool showAppBar;
  const _ClinicAppointmentsView({this.showAppBar = true});

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
    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes > 5) {
      provider.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<CliniNavBarProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clinics')
                        .doc(navProvider.clinicUid)
                        .collection('appointments')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int unreadCount = 0;
                      if (snapshot.hasData) {
                        unreadCount = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['isRead'] == false ||
                              !data.containsKey('isRead');
                        }).length;
                      }

                      return IconButton(
                        onPressed: () {
                          showMaterialModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ChangeNotifierProvider.value(
                              value: navProvider,
                              child: NotificationCenter(
                                clinicUid: navProvider.clinicUid,
                              ),
                            ),
                          );
                        },
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              LucideIcons.bell,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 25,
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () => showMaterialModalBottomSheet(
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Card(
                color: Theme.of(context).colorScheme.surface,
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
    // Just pass through, the _CalendarContent will consume the data from provider
    return const _CalendarContent();
  }
}

/// Provider-based calendar content (StatelessWidget)
class _CalendarContent extends StatelessWidget {
  const _CalendarContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicAppointmentProvider>();
    final appointmentCounts = provider.heatMapData;

    return TableCalendar(
      locale: context.locale.toString(),
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      focusedDay: provider.focusedDay,

      calendarFormat: provider.calendarFormat,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Month',
        CalendarFormat.week: 'Week',
      },
      onFormatChanged: (format) {
        provider.updateCalendarFormat(format);
      },
      selectedDayPredicate: (day) => isSameDay(provider.selectedDate, day),

      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(provider.selectedDate, selectedDay)) {
          provider.updateSelectedDate(selectedDay);
          // provider.updateFocusedDay(focusedDay); // Already handled in updateSelectedDate
        }
      },
      onPageChanged: (focusedDay) {
        provider.updateFocusedDay(focusedDay);
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
        holidayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          shape: BoxShape.circle,
        ),
        holidayTextStyle: TextStyle(color: Theme.of(context).colorScheme.error),
      ),

      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: true,
        titleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
        weekendStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Daily appointments list with swipe-to-cancel
class _AppointmentsPanel extends StatelessWidget {
  const _AppointmentsPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicAppointmentProvider>();
    final bool isWeb = kIsWeb && MediaQuery.of(context).size.width > 900;
    final ScrollController scrollController = ScrollController();

    if (provider.isInitialLoading && provider.appointments.isEmpty) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: AppointmentCardSkeleton(),
        ),
      );
    }

    if (provider.appointments.isEmpty) {
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
                if (timestampSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (timestampSnapshot.hasData &&
                    timestampSnapshot.data != null) {
                  final formattedTime = DateFormat.yMd(
                    context.locale.toString(),
                  ).add_Hms().format(timestampSnapshot.data!);
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

    final appointments = provider.appointments;
    final metadata = provider.lastMetadata;

    return Column(
      children: [
        if (metadata != null &&
            (metadata.isFromCache || metadata.hasPendingWrites))
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: Container(
              padding: const EdgeInsets.only(top: 13),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: isWeb,
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: appointments.length + 1,
                  itemExtent: 120, // Fixed height for performance
                  itemBuilder: (context, index) {
                    if (index == appointments.length) {
                      return const SizedBox(
                        height: 100,
                      ); // Space for Floating NavBar
                    }
                    final doc = appointments[index];
                    final appointment = doc.data() as Map<String, dynamic>;
                    final appointmentId = doc.id;

                    final slot = Clinic.parseDateTime(appointment['date']);
                    final now = DateTime.now();
                    final isPast = slot.isBefore(now);
                    final appointmentStatus =
                        appointment['status'] as String? ?? 'upcoming';
                    final isCancelled = appointmentStatus == 'cancelled';

                    // Determine effective status (cancelled from firestore, passed calculated locally)
                    final displayStatus = isCancelled
                        ? 'cancelled'
                        : (isPast ? 'passed' : 'upcoming');

                    final timeFormatted = DateFormat(
                      'HH:mm',
                      context.locale.toString(),
                    ).format(slot);
                    final name = appointment['patientName'] ?? 'unknown_patient'.tr();
                    final phone = appointment['phone'] ?? 'no_phone'.tr();
                    final isManual = appointment['isManual'] == true;

                    // Get status indicator color only (badge, not tile)
                    Color statusIndicatorColor;
                    String statusLabel;

                    switch (displayStatus) {
                      case 'cancelled':
                        statusIndicatorColor = Theme.of(context).colorScheme.error;
                        statusLabel = 'cancelled'.tr();
                        break;
                      case 'passed':
                        statusIndicatorColor = Theme.of(context).colorScheme.outline;
                        statusLabel = 'passed'.tr();
                        break;
                      default: // upcoming
                        statusIndicatorColor = Theme.of(context).colorScheme.primary;
                        statusLabel = 'upcoming'.tr();
                    }

                    Widget cardContent = Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: isWeb ? 2 : 1,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SizedBox(
                        height: 120,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Center(
                                  child: Text(
                                    timeFormatted,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              indent: 20,
                              endIndent: 20,
                            ),
                            Expanded(
                              child: ListTile(
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusIndicatorColor.withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          color: statusIndicatorColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isWeb) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(
                                          LucideIcons.phone,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        onPressed: () async {
                                          final Uri launchUri = Uri(
                                            scheme: 'tel',
                                            path: phone,
                                          );
                                          if (await canLaunchUrl(launchUri)) {
                                            await launchUrl(launchUri);
                                          }
                                        },
                                      ),
                                      if (!isManual)
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.userX,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('the_patient_did_not_show_up'.tr()),
                                                content: Text('mark_as_absence_confirm'.tr()),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(false),
                                                    child: Text('no'.tr()),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(true),
                                                    child: Text('yes'.tr()),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true) {
                                              await ClinicFirestore().updateNoShow(appointmentId, provider.clinicId);
                                            }
                                          },
                                        ),
                                      IconButton(
                                        icon: Icon(
                                          LucideIcons.xCircle,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('cancel_appointment'.tr()),
                                              content: Text('are_you_sure_to_cancel_appointment'.tr()),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text('no'.tr()),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text('yes'.tr()),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await provider.cancelAppointment(appointmentId, appointment);
                                          }
                                        },
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        LucideIcons.chevronLeft,
                                        color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                                      ),
                                    ],
                                  ],
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  phone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isWeb) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: cardContent,
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Slidable(
                        key: ValueKey(appointmentId),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          extentRatio: isManual ? 0.5 : 0.7,
                          children: [
                            SlidableAction(
                              onPressed: (context) async {
                                final Uri launchUri = Uri(
                                  scheme: 'tel',
                                  path: phone,
                                );
                                if (await canLaunchUrl(launchUri)) {
                                  await launchUrl(launchUri);
                                }
                              },
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              icon: LucideIcons.phone,
                              label: 'call'.tr(),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12),
                              ),
                            ),
                            if (!isManual)
                              SlidableAction(
                                onPressed: (context) async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('cancelled'.tr()),
                                      content: Text(
                                        'mark_as_no_show_confirm'.tr(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text('no'.tr()),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text('yes'.tr()),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    try {
                                      await ClinicFirestore().updateNoShow(
                                        appointmentId,
                                        provider.clinicId,
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'no_show_marked_success'.tr(),
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                icon: LucideIcons.userX,
                                label: 'cancelled'.tr(),
                              ),
                            SlidableAction(
                              onPressed: (context) async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('cancel_appointment'.tr()),
                                    content: Text(
                                      'are_you_sure_to_cancel_appointment'.tr(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text('no'.tr()),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(
                                          'yes'.tr(),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed != true) return;

                                try {
                                  await provider.cancelAppointment(
                                    appointmentId,
                                    appointment,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'appointment_cancelled_success'.tr(),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Colors.white,
                              icon: LucideIcons.xCircle,
                              label: 'cancel'.tr(),
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(12),
                              ),
                            ),
                          ],
                        ),
                        child: cardContent,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
