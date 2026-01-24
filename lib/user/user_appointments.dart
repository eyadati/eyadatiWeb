import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/FCM/notificationsService.dart';
import 'package:eyadati/user/user_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:marquee/marquee.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/connectivity_service.dart'; // Import ConnectivityService

// Represents a combined appointment and its associated clinic data
class AppointmentWithClinic {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> clinic;

  AppointmentWithClinic({required this.appointment, required this.clinic});
}

/// Manages user appointments with batched clinic data fetching.
class UserAppointmentsProvider extends ChangeNotifier {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final UserFirestore _userFirestore;
  final NotificationService _notificationService;
  final ConnectivityService? _connectivityService;

  StreamSubscription? _appointmentsSubscription;

  List<AppointmentWithClinic> _appointments = [];
  List<AppointmentWithClinic> get appointments => _appointments;

  final Map<String, Map<String, dynamic>> _clinicCache = {};
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Implement lastSyncTimestamp getter
  Future<DateTime?> get lastSyncTimestamp {
    final userId = auth.currentUser?.uid;
    if (userId == null) return Future.value(null);
    return _userFirestore.getLastSyncTimestamp(userId);
  }

  UserAppointmentsProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    UserFirestore? userFirestore,
    NotificationService? notificationService,
    ConnectivityService? connectivityService,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        _userFirestore = userFirestore ?? UserFirestore(connectivityService: connectivityService),
        _notificationService = notificationService ?? NotificationService(),
        _connectivityService = connectivityService {
    _initAppointmentsStream();

    _connectivityService?.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
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

  void _initAppointmentsStream() {
    _isLoading = true;
    notifyListeners();

    _appointmentsSubscription?.cancel();

    final userId = auth.currentUser?.uid;
    if (userId == null) {
      _isLoading = false;
      _appointments = [];
      notifyListeners();
      return;
    }

    final stream = firestore
        .collection("users")
        .doc(userId)
        .collection("appointments")
        .where("date", isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy("date")
        .limit(15)
        .snapshots(includeMetadataChanges: true);

    _appointmentsSubscription = stream.listen((snapshot) async {
      // Implement checks for metadata changes
      if (snapshot.metadata.isFromCache) {
        debugPrint("UserAppointments: Data from cache.");
      }
      if (snapshot.metadata.hasPendingWrites) {
        debugPrint("UserAppointments: Data has pending writes (local changes).");
      }
      final appointmentDocs = snapshot.docs;
      if (appointmentDocs.isEmpty) {
        _appointments = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final clinicUids = appointmentDocs
          .map((doc) => doc.data()['clinicUid'] as String)
          .toSet();

      // Fetch clinic data for UIDs not already in cache
      final uidsToFetch =
          clinicUids.where((uid) => !_clinicCache.containsKey(uid)).toList();
      if (uidsToFetch.isNotEmpty) {
        // Firestore 'in' query is limited to 30 elements per query.
        for (var i = 0; i < uidsToFetch.length; i += 30) {
          final batchUids =
              uidsToFetch.skip(i).take(30).toList();
          final clinicsSnapshot = await firestore
              .collection('clinics')
              .where(FieldPath.documentId, whereIn: batchUids)
              .get();
          for (var doc in clinicsSnapshot.docs) {
            _clinicCache[doc.id] = doc.data();
          }
        }
      }

      // Combine appointments with cached clinic data
      final newAppointments = <AppointmentWithClinic>[];
      for (var doc in appointmentDocs) {
        final appointmentData = doc.data();
        appointmentData['id'] = doc.id; // Add document ID to map
        final clinicData = _clinicCache[appointmentData['clinicUid']];
        if (clinicData != null) {
          newAppointments.add(AppointmentWithClinic(
            appointment: appointmentData,
            clinic: clinicData,
          ));
        }
      }

      _appointments = newAppointments;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> cancelAppointment(
    String appointmentId,
    String clinicUid,
    Map<String, dynamic> clinicData,
    BuildContext context,
  ) async {
    final userId = auth.currentUser?.uid;
    if (userId == null) return;

    await _userFirestore.cancelAppointment(appointmentId, userId, context);

    if (clinicData['FCM'] != null) {
      await _notificationService.sendDirectNotification(
        fcmToken: clinicData['FCM'],
        title: 'appointment_cancelled'.tr(),
        body: 'the_appointment_got_cancelled'.tr(),
      );
    }
    // The stream will update the list automatically, no need for notifyListeners()
  }

  Future<void> refresh() async {
    _initAppointmentsStream();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _connectivityService?.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}

/// Main entry widget for user appointments list
class Appointmentslistview extends StatelessWidget {
  const Appointmentslistview({super.key});

  @override
  Widget build(BuildContext context) {
    // The provider is created in `userAppointments.dart`
    return ChangeNotifierProvider(
      create: (context) => UserAppointmentsProvider(
        connectivityService: Provider.of<ConnectivityService>(context, listen: false),
      ),
      child: const _AppointmentsListView(),
    );
  }
}

class _AppointmentsListView extends StatefulWidget {
  const _AppointmentsListView();

  @override
  State<_AppointmentsListView> createState() => _AppointmentsListViewState();
}

class _AppointmentsListViewState extends State<_AppointmentsListView>
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
    final provider = context.read<UserAppointmentsProvider>();
    final lastSync = await provider.lastSyncTimestamp;
    if (lastSync != null &&
        DateTime.now().difference(lastSync).inMinutes > 5) {
      provider.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserAppointmentsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('no_appointments'.tr()),
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

        final appointments = provider.appointments;

        return RefreshIndicator(
          onRefresh: provider.refresh, // Connect to the refresh method
          child: ListView.builder(
            itemCount: appointments.length + 1, // Add 1 for the SizedBox
            itemBuilder: (context, index) {
              if (index == appointments.length) {
                return SizedBox(
                  height: 92 + MediaQuery.of(context).padding.bottom,
                ); // Adjust height for floating nav bar
              }
              final appointmentWithClinic = appointments[index];
              final slot =
                  appointmentWithClinic.appointment["date"] as Timestamp?;

              if (slot == null) return const SizedBox.shrink();

              return _AppointmentCard(
                appointment: appointmentWithClinic.appointment,
                clinicData: appointmentWithClinic.clinic,
                slot: slot,
              );
            },
          ),
        );
      },
    );
  }
}
class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> clinicData;
  final Timestamp slot;

  const _AppointmentCard({
    required this.appointment,
    required this.clinicData,
    required this.slot,
  });

  String _formatDateWithContext(Timestamp ts, BuildContext context) {
    final date = ts.toDate();
    final weekday = DateFormat('EEEE', context.locale.toString()).format(date);
    final formatted = DateFormat('M/d/yyyy', context.locale.toString()).format(date);
    return "$weekday $formatted";
  }

  String _formatTimeWithContext(Timestamp ts, BuildContext context) {
    final date = ts.toDate();
    return DateFormat('hh:mm a', context.locale.toString()).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final appointmentId = appointment["id"] as String;
    final clinicUid = appointment["clinicUid"] as String;
    final shopName = clinicData["name"] ?? "unknown_shop".tr();
    final address = clinicData["address"] ?? "unknown_address".tr();
    final mapsLink = clinicData["mapsLink"] as String?;

    return Slidable(
      key: ValueKey(appointmentId),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.2,
        children: [
          IconButton(
            onPressed: () async {
              await context.read<UserAppointmentsProvider>().cancelAppointment(
                    appointmentId,
                    clinicUid,
                    clinicData,
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
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          title: _buildMarqueeRow("clinic".tr(), shopName, isTitle: true),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMarqueeRow("address".tr(), address),
              const SizedBox(height: 4),
              Text(_formatDateWithContext(slot, context), style: const TextStyle(fontSize: 14)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimeWithContext(slot, context),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (mapsLink != null && mapsLink.isNotEmpty)
                    IconButton(
                      onPressed: () async {
                        await launchUrl(
                          mode: LaunchMode.platformDefault,
                          Uri.parse(mapsLink),
                        );
                      },
                      icon: const Icon(
                        LucideIcons.mapPin,
                        size: 40,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarqueeRow(String label, String value, {bool isTitle = false}) {
    return SizedBox(
      height: isTitle ? 35 : 30,
      child: Row(
        children: [
          Text("$label: "),
          Expanded(
            child: Marquee(
              text: value,
              style: TextStyle(
                fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
                fontSize: isTitle ? 16 : 14,
              ),
              velocity: isTitle ? 25 : 15,
              blankSpace: isTitle ? 50 : 40,
              pauseAfterRound: const Duration(seconds: 1),
            ),
          ),
        ],
      ),
    );
  }
}
