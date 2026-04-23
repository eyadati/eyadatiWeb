import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/Appointments/utils.dart';
import 'package:eyadati/chargili/paiment.dart';
import 'package:eyadati/utils/models/clinic_model.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart'; // flutter pub add flutter_floating_bottom_bar
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/NavBarUi/appointments_management.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:eyadati/clinic/clinic_appointments.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:deferred_indexed_stack/deferred_indexed_stack.dart'; // flutter pub add deferred_indexed_stack
import 'package:lucide_icons/lucide_icons.dart';

import 'package:eyadati/utils/appointment_simulator.dart';
import 'dart:async';

class CliniNavBarProvider extends ChangeNotifier {
  final String clinicUid;
  String _selected = "1";
  String get selected => _selected;
  List<QueryDocumentSnapshot> _notifications = [];
  List<QueryDocumentSnapshot> get notifications => _notifications;
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _clinicSubscription;
  StreamSubscription? _feesSubscription;

  Clinic? _clinic;
  bool _isLoadingClinic = true;
  bool get isLoadingClinic => _isLoadingClinic;
  Clinic? get clinic => _clinic;

  CliniNavBarProvider(this.clinicUid) {
    _listenForNotifications(clinicUid);
    _listenToClinicStream();
  }

  void _listenToClinicStream() {
    _clinicSubscription = AppStartupService().clinicStream.listen((clinic) {
      _clinic = clinic;
      if (_clinic != null) {
        // Stop old fee listener if exists
        _feesSubscription?.cancel();
        
        // Start reactive fee counter
        _feesSubscription = PaymentService.listenAndSync(
          clinicUid: clinicUid,
          startDate: _clinic!.subscriptionStartDate,
          endDate: _clinic!.subscriptionEndDate,
        );
        
        _syncAppointmentCountIfNeeded();
      }
      _isLoadingClinic = false;
      notifyListeners();
    });
  }

  int _lastSyncedCount = -1;

  Future<void> _syncAppointmentCountIfNeeded() async {
    if (_clinic == null) return;
    final newCount = await PaymentService.syncAppointmentCountIfNeeded(
      clinicUid: clinicUid,
      clinicData: _clinic!.toMap(),
      lastSyncedCount: _lastSyncedCount,
    );
    if (newCount != null) {
      _lastSyncedCount = newCount;
    }
  }

  void _listenForNotifications(String clinicUid) {
    _notifSubscription = FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicUid)
        .collection('appointments')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          _notifications = snapshot.docs;
          _unreadCount = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['isRead'] == false || !data.containsKey('isRead');
          }).length;
          notifyListeners();
        });
  }

  void select(String value) {
    _selected = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _clinicSubscription?.cancel();
    _feesSubscription?.cancel();
    AppointmentSimulator.stopSimulation();
    super.dispose();
  }
}

// ✅ Simplified: Expects Provider from above
class FloatingBottomNavBar extends StatelessWidget {
  const FloatingBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final clinicUid = FirebaseAuth.instance.currentUser!.uid;
    return _BottomNavContent(clinicUid: clinicUid);
  }
}

class _BottomNavContent extends StatelessWidget {
  final String clinicUid;
  const _BottomNavContent({required this.clinicUid});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CliniNavBarProvider>();
    final connectivity = context.watch<ConnectivityService>();
    final selectedIndex = int.parse(provider.selected) - 1;

    if (provider.isLoadingClinic) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('loading'.tr()),
            ],
          ),
        ),
      );
    }

    // Wait for auth and clinic data before showing "not found"
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('please_wait'.tr()),
            ],
          ),
        ),
      );
    }

    if (provider.clinic == null) {
      // Try to reload clinic data
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('loading_clinic_data'.tr()),
            ],
          ),
        ),
      );
    }

    final clinic = provider.clinic!;
    final status = PaymentService.checkSubscriptionStatus(clinic.toMap());

    if (status['isPaused'] ||
        status['needsPayment'] ||
        status['isSubscriptionEnded']) {
      return PaymentOverlay(
        title: status['overlayTitle'],
        message: status['overlayMessage'],
        icon: status['icon'] ?? LucideIcons.alertCircle,
        initialAmount:
            status['needsPayment'] ? (status['totalFees'] as double) : null,
      );
    }

    return BottomBar(
      borderRadius: BorderRadius.circular(25),
      duration: const Duration(milliseconds: 500),
      curve: Curves.decelerate,
      showIcon: false, // Hide center icon for cleaner nav bar
      width: MediaQuery.of(context).size.width * 0.9, // Floating effect
      barColor: Theme.of(context).cardColor,
      barAlignment: Alignment.bottomCenter,

      // Main content area with lazy loading
      body: (context, controller) {
        return Column(
          children: [
            if (!connectivity.isOnline) const _OfflineBanner(),
            Expanded(
              child: DeferredIndexedStack(
                index: selectedIndex,
                children: [
                  DeferredTab(
                    id: "1",
                    child: ClinicAppointments(clinicId: clinicUid),
                  ),
                  DeferredTab(
                    id: "2",
                    child: ManagementScreen(clinicUid: clinicUid),
                  ),
                ],
              ),
            ),
          ],
        );
      },

      // Floating navigation bar items
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, LucideIcons.home, "home".tr(), "1"),
            _buildNavItem(context, LucideIcons.calendar, "managment".tr(), "2"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final provider = context.watch<CliniNavBarProvider>();
    final isSelected = provider.selected == value;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: () => provider.select(value),
      customBorder: const CircleBorder(), // Circular ripple effect
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Larger tap area
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label.tr(), style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class NotificationCenter extends StatelessWidget {
  final String clinicUid;
  const NotificationCenter({super.key, required this.clinicUid});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'notifications'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => _markAllAsRead(context),
                      child: Text('mark_all_read'.tr()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<CliniNavBarProvider>(
                  builder: (context, provider, child) {
                    final docs = provider.notifications;
                    if (docs.isEmpty) {
                      return Center(child: Text('no_notifications'.tr()));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isRead = data['isRead'] ?? false;
                        final dateValue = data['date'];
                        final DateTime date;
                        if (dateValue is Timestamp) {
                          date = dateValue.toDate();
                        } else if (dateValue is String) {
                          date = DateTime.parse(dateValue);
                        } else {
                          date = DateTime.now();
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRead
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              LucideIcons.calendar,
                              color: isRead
                                  ? Theme.of(context).colorScheme.onSurface.withAlpha(150)
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            data['userName'] ?? 'unknown_patient'.tr(),
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${'appointment'.tr()}: ${DateFormat.yMMMd(context.locale.toString()).add_Hm().format(date)}',
                          ),
                          trailing: !isRead
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: () {
                             FirebaseFirestore.instance
                                .collection('clinics')
                                .doc(clinicUid)
                                .collection('appointments')
                                .doc(docs[index].id)
                                .update({'isRead': true});
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _markAllAsRead(BuildContext context) async {
     final provider = context.read<CliniNavBarProvider>();
     final unread = provider.notifications.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isRead'] == false || !data.containsKey('isRead');
     });

     final batch = FirebaseFirestore.instance.batch();
     for (var doc in unread) {
        batch.update(doc.reference, {'isRead': true});
     }
     await batch.commit();
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.error,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        'you_are_currently_offline'.tr(),
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onError),
      ),
    );
  }
}
