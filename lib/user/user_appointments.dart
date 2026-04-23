import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/FCM/notifications_service.dart';
import 'package:eyadati/user/user_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:marquee/marquee.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:eyadati/utils/skeletons.dart';

class AppointmentWithClinic {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> clinic;
  AppointmentWithClinic({required this.appointment, required this.clinic});
}

class UserAppointmentsProvider extends ChangeNotifier {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final UserFirestore _userFirestore;
  final NotificationService _notificationService;
  final ConnectivityService? _connectivityService;

  StreamSubscription? _appointmentsSubscription;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  List<AppointmentWithClinic> _appointments = [];
  List<AppointmentWithClinic> get appointments => _appointments;

  final Map<String, Map<String, dynamic>> _clinicCache = {};
  bool _isLoading = true;
  bool get isLoading => _isLoading;

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
  }) : auth = auth ?? FirebaseAuth.instance,
       firestore = firestore ?? FirebaseFirestore.instance,
       _userFirestore = userFirestore ?? UserFirestore(connectivityService: connectivityService),
       _notificationService = notificationService ?? NotificationService(),
       _connectivityService = connectivityService {
    _initAppointmentsStream();
    _connectivityService?.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (_connectivityService?.isOnline == true) _checkAndRefreshDataOnReconnect();
  }

  Future<void> _checkAndRefreshDataOnReconnect() async {
    final lastSync = await lastSyncTimestamp;
    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes > 5) refresh();
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
    final stream = firestore.collection("users").doc(userId).collection("appointments")
        .where("date", isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy("date").limit(15).snapshots(includeMetadataChanges: true);

    _appointmentsSubscription = stream.listen((snapshot) async {
      final appointmentDocs = snapshot.docs;
      if (appointmentDocs.isEmpty) {
        _appointments = [];
        _isLoading = false;
        notifyListeners();
        return;
      }
      final clinicUids = appointmentDocs.map((doc) => doc.data()['clinicUid'] as String).toSet();
      final uidsToFetch = clinicUids.where((uid) => !_clinicCache.containsKey(uid)).toList();
      if (uidsToFetch.isNotEmpty) {
        for (var i = 0; i < uidsToFetch.length; i += 30) {
          final batchUids = uidsToFetch.skip(i).take(30).toList();
          final clinicsSnapshot = await firestore.collection('clinics')
              .where(FieldPath.documentId, whereIn: batchUids)
              .get(const GetOptions(source: Source.serverAndCache));
          for (var doc in clinicsSnapshot.docs) {
            _clinicCache[doc.id] = doc.data();
          }
        }
      }
      if (_disposed) return;
      final newAppointments = <AppointmentWithClinic>[];
      for (var doc in appointmentDocs) {
        final appointmentData = doc.data();
        appointmentData['id'] = doc.id;
        final clinicData = _clinicCache[appointmentData['clinicUid']];
        if (clinicData != null) {
          newAppointments.add(AppointmentWithClinic(appointment: appointmentData, clinic: clinicData));
        }
      }
      _appointments = newAppointments;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> cancelAppointment(String appointmentId, String clinicUid, Map<String, dynamic> clinicData) async {
    final userId = auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _userFirestore.cancelAppointment(appointmentId, userId);
      if (clinicData['fcm'] != null) {
        await _notificationService.sendDirectNotification(
          fcmToken: clinicData['fcm'],
          title: 'appointment_cancelled'.tr(),
          body: 'the_appointment_got_cancelled'.tr(),
        );
      }
    } catch (e) { rethrow; }
  }

  Future<void> refresh() async { _initAppointmentsStream(); }

  @override
  void dispose() {
    _disposed = true;
    _appointmentsSubscription?.cancel();
    _connectivityService?.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}

class Appointmentslistview extends StatelessWidget {
  final ScrollController? scrollController;
  const Appointmentslistview({super.key, this.scrollController});
  @override
  Widget build(BuildContext context) { return _AppointmentsListView(scrollController: scrollController); }
}

class _AppointmentsListView extends StatefulWidget {
  final ScrollController? scrollController;
  const _AppointmentsListView({this.scrollController});
  @override
  State<_AppointmentsListView> createState() => _AppointmentsListViewState();
}

class _AppointmentsListViewState extends State<_AppointmentsListView> with WidgetsBindingObserver {
  late ScrollController _scrollController;

  @override
  void initState() { 
    super.initState(); 
    _scrollController = widget.scrollController ?? ScrollController();
    WidgetsBinding.instance.addObserver(this); 
  }

  @override
  void dispose() { 
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    WidgetsBinding.instance.removeObserver(this); 
    super.dispose(); 
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _checkAndRefreshData(); }
  Future<void> _checkAndRefreshData() async {
    final provider = context.read<UserAppointmentsProvider>();
    final lastSync = await provider.lastSyncTimestamp;
    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes > 5) provider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserAppointmentsProvider>();
    if (provider.isLoading) return ListView.builder(itemCount: 5, itemBuilder: (context, index) => const AppointmentCardSkeleton());
    if (provider.appointments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('no_appointments'.tr()),
        FutureBuilder<DateTime?>(future: provider.lastSyncTimestamp, builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final formattedTime = DateFormat.yMd(context.locale.toString()).add_Hms().format(snapshot.data!);
            return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('last_synced_at'.tr(args: [formattedTime]), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)));
          }
          return const SizedBox.shrink();
        }),
      ]));
    }
    final appointments = provider.appointments;
    return RefreshIndicator(onRefresh: provider.refresh, child: ListView.builder(
      controller: _scrollController,
      itemCount: appointments.length + 1,
      itemBuilder: (context, index) {
        if (index == appointments.length) return SizedBox(height: 92 + MediaQuery.of(context).padding.bottom);
        final item = appointments[index];
        final slot = item.appointment["date"] as Timestamp?;
        if (slot == null) return const SizedBox.shrink();
        return _AppointmentCard(appointment: item.appointment, clinicData: item.clinic, slot: slot);
      },
    ));
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> clinicData;
  final Timestamp slot;

  const _AppointmentCard({required this.appointment, required this.clinicData, required this.slot});

  @override
  Widget build(BuildContext context) {
    final appointmentId = appointment["id"] as String;
    final clinicUid = appointment["clinicUid"] as String;
    final shopName = clinicData["clinicName"] ?? "unknown_shop".tr();
    final address = clinicData["address"] ?? "unknown_address".tr();
    final mapsLink = clinicData["mapsLink"] as String?;
    final bool isLargeScreen = MediaQuery.of(context).size.width > 900;

    final content = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    shopName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mapsLink != null && mapsLink.isNotEmpty)
                      IconButton(
                        onPressed: () => launchUrl(Uri.parse(mapsLink), mode: LaunchMode.platformDefault),
                        icon: const Icon(LucideIcons.mapPin, color: Colors.green),
                      ),
                    if (isLargeScreen)
                      IconButton(
                        onPressed: () => _handleCancel(context, appointmentId, clinicUid),
                        icon: Icon(LucideIcons.xCircle, color: Theme.of(context).colorScheme.error),
                        tooltip: 'cancel_appointment'.tr(),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.mapPin, size: 18, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.calendar, size: 18, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMMM d', context.locale.toString()).format(slot.toDate()),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.clock, size: 18, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('hh:mm a', context.locale.toString()).format(slot.toDate()),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (kIsWeb || isLargeScreen) return content;
    return Slidable(
      key: ValueKey(appointmentId),
      endActionPane: ActionPane(motion: const ScrollMotion(), extentRatio: 0.2, children: [
        IconButton(onPressed: () => _handleCancel(context, appointmentId, clinicUid), icon: Icon(LucideIcons.xCircle, color: Theme.of(context).colorScheme.error, size: 40)),
      ]),
      child: content,
    );
  }

  Future<void> _handleCancel(BuildContext context, String appointmentId, String clinicUid) async {
    HapticFeedback.warningNotification();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('cancel_appointment'.tr()),
      content: Text('are_you_sure_to_cancel_appointment'.tr()),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('no'.tr())),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('yes'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ],
    ));
    if (confirmed != true) return;
    try {
      await context.read<UserAppointmentsProvider>().cancelAppointment(appointmentId, clinicUid, clinicData);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('appointment_cancelled_success'.tr())));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildMarqueeRow(String label, String value, {bool isTitle = false}) {
    return SizedBox(height: isTitle ? 35 : 30, child: Row(children: [
      Text("${label.tr()}: "),
      Expanded(child: Marquee(text: value, style: TextStyle(fontWeight: isTitle ? FontWeight.bold : FontWeight.normal, fontSize: isTitle ? 16 : 14), velocity: isTitle ? 25 : 15, blankSpace: isTitle ? 50 : 40, pauseAfterRound: const Duration(seconds: 1))),
    ]));
  }
}
