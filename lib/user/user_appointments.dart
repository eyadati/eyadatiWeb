import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/FCM/notifications_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/skeletons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppointmentWithClinic {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> clinic;
  AppointmentWithClinic({required this.appointment, required this.clinic});
}

class PatientAppointmentsProvider extends ChangeNotifier {
  final FirebaseFirestore firestore;
  final NotificationService _notificationService;

  StreamSubscription? _appointmentsSubscription;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  List<AppointmentWithClinic> _appointments = [];
  List<AppointmentWithClinic> get appointments => _appointments;

  final Map<String, Map<String, dynamic>> _clinicCache = {};
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _currentPhone = '';
  String get currentPhone => _currentPhone;

  PatientAppointmentsProvider({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = NotificationService() {
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentPhone = prefs.getString('patient_phone') ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved phone: $e');
    }
  }

  Future<void> loadAppointmentsByPhone(String phone) async {
    _isLoading = true;
    _currentPhone = phone;
    notifyListeners();

    _appointmentsSubscription?.cancel();
    _appointments = [];
    _clinicCache.clear();

    try {
      // Get all clinics first
      final clinicsSnapshot = await firestore.collection('clinics')
          .where('test', isEqualTo: false)
          .get(const GetOptions(source: Source.server));

      final allAppointments = <AppointmentWithClinic>[];
      
      for (var clinicDoc in clinicsSnapshot.docs) {
        final clinicData = clinicDoc.data();
        final clinicUid = clinicDoc.id;
        _clinicCache[clinicUid] = clinicData;

        // Query appointments for this clinic with this phone
        final appointmentsSnapshot = await firestore
            .collection('clinics')
            .doc(clinicUid)
            .collection('appointments')
            .where('phone', isEqualTo: phone)
            .where('status', isEqualTo: 'upcoming')
            .get(const GetOptions(source: Source.server));

        for (var aptDoc in appointmentsSnapshot.docs) {
          final aptData = aptDoc.data();
          final slotDate = (aptData['date'] as Timestamp?)?.toDate();
          if (slotDate != null && slotDate.isAfter(DateTime.now())) {
            aptData['id'] = aptDoc.id;
            aptData['clinicUid'] = clinicUid;
            allAppointments.add(AppointmentWithClinic(
              appointment: aptData,
              clinic: clinicData,
            ));
          }
        }
      }

      // Sort by date
      allAppointments.sort((a, b) {
        final aDate = (a.appointment['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b.appointment['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      _appointments = allAppointments;
    } catch (e) {
      debugPrint('Error loading appointments: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> cancelAppointment(String appointmentId, String clinicUid) async {
    try {
      await firestore
          .collection('clinics')
          .doc(clinicUid)
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': 'cancelled'});

      final clinicData = _clinicCache[clinicUid];
      if (clinicData?['fcm'] != null) {
        try {
          await _notificationService.sendDirectNotification(
            fcmToken: clinicData!['fcm'],
            title: 'appointment_cancelled'.tr(),
            body: 'the_appointment_got_cancelled'.tr(),
          );
        } catch (e) {
          debugPrint('Error sending notification: $e');
        }
      }

      // Refresh the list
      if (_currentPhone.isNotEmpty) {
        await loadAppointmentsByPhone(_currentPhone);
      }
      return true;
    } catch (e) {
      debugPrint('Error cancelling appointment: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    if (_currentPhone.isNotEmpty) {
      await loadAppointmentsByPhone(_currentPhone);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _appointmentsSubscription?.cancel();
    super.dispose();
  }
}

class Appointmentslistview extends StatelessWidget {
  final ScrollController? scrollController;
  const Appointmentslistview({super.key, this.scrollController});
  @override
  Widget build(BuildContext context) => _AppointmentsListView(scrollController: scrollController);
}

class _PhoneEntryScreen extends StatefulWidget {
  const _PhoneEntryScreen();
  @override
  State<_PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<_PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('patient_phone') ?? '';
    if (savedPhone.isNotEmpty) {
      _phoneController.text = savedPhone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.phone,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'enter_phone_to_view_appointments'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'phone_number'.tr(),
                prefixIcon: const Icon(LucideIcons.phone),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'please_enter_phone'.tr();
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  context.read<PatientAppointmentsProvider>()
                      .loadAppointmentsByPhone(_phoneController.text);
                }
              },
              icon: const Icon(LucideIcons.search),
              label: Text('search'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsListView extends StatefulWidget {
  final ScrollController? scrollController;
  const _AppointmentsListView({this.scrollController});
  @override
  State<_AppointmentsListView> createState() => _AppointmentsListViewState();
}

class _AppointmentsListViewState extends State<_AppointmentsListView> {
  late ScrollController _scrollController;

  @override
  void initState() { 
    super.initState(); 
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() { 
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientAppointmentsProvider>();
    
    if (provider.currentPhone.isEmpty || provider.isLoading) {
      return SingleChildScrollView(child: const _PhoneEntryScreen());
    }

    if (provider.isLoading) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: AppointmentCardSkeleton(),
        ),
      );
    }

    if (provider.appointments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.calendarX, size: 64, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text('no_appointments_found'.tr(), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () {
            provider.loadAppointmentsByPhone(provider.currentPhone);
          },
          icon: const Icon(Icons.refresh),
          label: Text('refresh'.tr()),
        ),
      ]));
    }

    final appointments = provider.appointments;
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: appointments.length + 1,
        itemBuilder: (context, index) {
          if (index == appointments.length) return SizedBox(height: 92 + MediaQuery.of(context).padding.bottom);
          final item = appointments[index];
          final slot = item.appointment['date'] as Timestamp?;
          if (slot == null) return const SizedBox.shrink();
          return _AppointmentCard(
            appointment: item.appointment, 
            clinicData: item.clinic, 
            slot: slot,
            onCancel: () => _handleCancel(context, item.appointment['id'] as String, item.appointment['clinicUid'] as String),
          );
        },
      ),
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
    if (!context.mounted) return;
    
    final success = await context.read<PatientAppointmentsProvider>()
        .cancelAppointment(appointmentId, clinicUid);
    
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('appointment_cancelled_success'.tr())));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('cancellation_failed'.tr())));
    }
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> clinicData;
  final Timestamp slot;
  final VoidCallback onCancel;

  const _AppointmentCard({
    required this.appointment, 
    required this.clinicData, 
    required this.slot,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final shopName = clinicData['clinicName'] ?? 'unknown_shop'.tr();
    final address = clinicData['address'] ?? 'unknown_address'.tr();
    final latitude = clinicData['latitude'] as double?;
    final longitude = clinicData['longitude'] as double?;
    final mapsLink = clinicData['mapsLink'] as String?;
    
    String getLocationUrl() {
      if (latitude != null && longitude != null) {
        return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      }
      return mapsLink ?? '';
    }
    final bool isLargeScreen = MediaQuery.of(context).size.width > 900;
    
    final cardColor = Theme.of(context).colorScheme.surface;

    final content = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 10,
      color: cardColor,
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
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(LucideIcons.xCircle, color: Theme.of(context).colorScheme.error),
                  tooltip: 'cancel_appointment'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (getLocationUrl().isNotEmpty)
                  IconButton(
                    onPressed: () => launchUrl(Uri.parse(getLocationUrl()), mode: LaunchMode.platformDefault),
                    icon: Icon(LucideIcons.mapPin, color: Theme.of(context).colorScheme.primary),
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
      key: ValueKey(appointment['id']),
      endActionPane: ActionPane(motion: const ScrollMotion(), extentRatio: 0.2, children: [
        IconButton(onPressed: onCancel, icon: Icon(LucideIcons.xCircle, color: Theme.of(context).colorScheme.error, size: 40)),
      ]),
      child: content,
    );
  }
}