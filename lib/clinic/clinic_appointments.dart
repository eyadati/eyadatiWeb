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
      debugPrint("Error fetching heatmap data: $e");
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

  const ClinicAppointments({super.key, required this.clinicId, this.showAppBar = true});

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
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
      appBar: widget.showAppBar ? AppBar(
        title: Image.asset('assets/logo.png', height: 120),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: StreamBuilder<QuerySnapshot>(
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
                return data['isRead'] == false || !data.containsKey('isRead');
              }).length;
            }

            return IconButton(
              onPressed: () {
                showMaterialModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: navProvider,
                    child: NotificationCenter(clinicUid: navProvider.clinicUid),
                  ),
                );
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    LucideIcons.bell,
                    color: Theme.of(context).colorScheme.primary,
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
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),                ],
              ),
            );
          },
        ),

        actions: [
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
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Card(
                  elevation: 10,
                  child: const _NormalCalendar(),
                ),
              ),
              const _AppointmentsPanel(),
            ],
          ),
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
      calendarFormat: CalendarFormat.month,
      selectedDayPredicate: (day) => isSameDay(provider.selectedDate, day),

      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(provider.selectedDate, selectedDay)) {
          provider.updateSelectedDate(selectedDay);
        }
      },
      onPageChanged: (focusedDay) {
        provider.updateFocusedDay(focusedDay);
      },
      onFormatChanged: (format) {
        provider.updateCalendarFormat(format);
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

      headerStyle: const HeaderStyle(titleCentered: true),
    );
  }
}

class _AppointmentsPanel extends StatelessWidget {
  const _AppointmentsPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicAppointmentProvider>();
    final bool isWeb = kIsWeb && MediaQuery.of(context).size.width > 900;

    if (provider.isInitialLoading && provider.appointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
        RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 100),
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: appointments.length + 1,
                  itemBuilder: (context, index) {
                    if (index == appointments.length) {
                      return const SizedBox(height: 100);
                    }
                    final doc = appointments[index];
                    final appointment = doc.data() as Map<String, dynamic>;
                    final appointmentId = doc.id;

                    final slot = Clinic.parseDateTime(appointment['date']);
                    final isPast = slot.isBefore(DateTime.now());
                    final timeFormatted = DateFormat(
                      'HH:mm',
                      context.locale.toString(),
                    ).format(slot);
                    final name = appointment['userName'] ?? 'Unknown';
                    final phone = appointment['phone'] ?? 'No phone';
                    final isManual = appointment['isManual'] == true;

                    return _buildAppointmentCard(
                      context: context,
                      appointment: appointment,
                      appointmentId: appointmentId,
                      slot: slot,
                      isPast: isPast,
                      timeFormatted: timeFormatted,
                      name: name,
                      phone: phone,
                      isManual: isManual,
                      isWeb: isWeb,
                      provider: provider,
                    );
                  },
                ),
          ),
      ],
    );
  }

  Widget _buildAppointmentCard({
    required BuildContext context,
    required Map<String, dynamic> appointment,
    required String appointmentId,
    required DateTime slot,
    required bool isPast,
    required String timeFormatted,
    required String name,
    required String phone,
    required bool isManual,
    required bool isWeb,
    required ClinicAppointmentProvider provider,
  }) {
    final cardContent = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      color: isPast
                        ? Theme.of(context).colorScheme.onSurface.withAlpha(150)
                        : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, indent: 20, endIndent: 20),
            Expanded(
              child: ListTile(
                trailing: isWeb
                  ? _buildWebActions(context, phone, isManual, appointmentId, provider)
                  : Icon(
                      LucideIcons.chevronLeft,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                    ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                subtitle: Text(phone, style: const TextStyle(fontWeight: FontWeight.w500)),
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
                final Uri launchUri = Uri(scheme: 'tel', path: phone);
                if (await canLaunchUrl(launchUri)) {
                  await launchUrl(launchUri);
                }
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: LucideIcons.phone,
              label: 'call'.tr(),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            if (!isManual)
              SlidableAction(
                onPressed: (context) => _markNoShow(context, appointmentId, provider),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                icon: LucideIcons.userX,
                label: 'no_show'.tr(),
              ),
            SlidableAction(
              onPressed: (context) => _cancelAppointment(context, appointment, appointmentId, provider),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              icon: LucideIcons.xCircle,
              label: 'cancel'.tr(),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ],
        ),
        child: cardContent,
      ),
    );
  }

  Widget _buildWebActions(BuildContext context, String phone, bool isManual, String appointmentId, ClinicAppointmentProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.phone, color: Colors.green),
          onPressed: () async {
            final Uri launchUri = Uri(scheme: 'tel', path: phone);
            if (await canLaunchUrl(launchUri)) {
              await launchUrl(launchUri);
            }
          },
        ),
        if (!isManual)
          IconButton(
            icon: const Icon(LucideIcons.userX, color: Colors.orange),
            onPressed: () => _markNoShow(context, appointmentId, provider),
          ),
        IconButton(
          icon: Icon(LucideIcons.xCircle, color: Theme.of(context).colorScheme.error),
          onPressed: () => _showCancelDialog(context, appointmentId, provider),
        ),
      ],
    );
  }

  Future<void> _markNoShow(BuildContext context, String appointmentId, ClinicAppointmentProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('mark_as_no_show'.tr()),
        content: Text('mark_as_no_show_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('no'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('yes'.tr())),
        ],
      ),
    );
    if (confirmed == true) {
      await ClinicFirestore().updateNoShow(appointmentId, provider.clinicId);
    }
  }

  Future<void> _showCancelDialog(BuildContext context, String appointmentId, ClinicAppointmentProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('cancel_appointment'.tr()),
        content: Text('are_you_sure_to_cancel_appointment'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('no'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('yes'.tr())),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final doc = provider.appointments.firstWhere((doc) => doc.id == appointmentId);
        final appointment = doc.data() as Map<String, dynamic>;
        await provider.cancelAppointment(appointmentId, appointment);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('appointment_cancelled_success'.tr())),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _cancelAppointment(BuildContext context, Map<String, dynamic> appointment, String appointmentId, ClinicAppointmentProvider provider) async {
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
            child: Text('yes'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.cancelAppointment(appointmentId, appointment);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('appointment_cancelled_success'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
