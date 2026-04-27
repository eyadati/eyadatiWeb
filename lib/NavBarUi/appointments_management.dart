import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/Appointments/booking_logic.dart';
import 'package:eyadati/clinic/clinic_firestore.dart';
import 'package:eyadati/utils/models/clinic_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/skeletons.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagementProvider extends ChangeNotifier {
  final String clinicUid;
  final FirebaseFirestore firestore;

  // In-memory manual appointments: key is "yyyy-MM-ddTHH:mm" in UTC
  final Map<String, List<Map<String, dynamic>>> _manualAppointments = {};

  // Online appointment counts from database
  final Map<String, int> _onlineAppointmentsCount = {};

  // Clinic configuration cache
  Map<String, dynamic>? _clinicData;

  // Slots for visible days only (excludes closed days)
  final List<List<DateTime>> _weekSlots = [];

  // The actual day DateTime objects for each page (in UTC)
  final List<DateTime> _visibleDays = [];

  bool _isLoading = true;
  String? _errorMessage;
  int _currentPageIndex = 0; // New: Current page index for PageView

  ManagementProvider({required this.clinicUid, FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance {
    _initializeData();
  }

  Stream<QuerySnapshot> get appointmentsStream => firestore
      .collection('clinics')
      .doc(clinicUid)
      .collection('appointments')
      .snapshots();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<List<DateTime>> get weekSlots => _weekSlots;
  List<DateTime> get visibleDays => _visibleDays;
  int get currentPageIndex => _currentPageIndex; // New getter

  void setCurrentPageIndex(int index) {
    _currentPageIndex = index;
    notifyListeners();
  }

  // Utility to parse integers safely
  int _parseInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // Checks if the clinic is open on a specific day (using UTC)
  bool isWorkingDay(DateTime day) {
    if (day.isUtc == false) day = day;
    if (_clinicData == null) return false;

    final workingDays =
        (_clinicData!['workingDays'] as List?)
            ?.map((e) => _parseInt(e, 0))
            .toList() ??
        [];

    return workingDays.contains(day.weekday);
  }

  Future<void> _initializeData() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _fetchClinicData();
      await _generateWeekSlots();
      if (_visibleDays.isNotEmpty) {
        await _fetchAllAppointments();
      }
    } catch (e) {
      debugPrint('ManagementProvider initialization error: $e');
      _errorMessage = 'Failed to load appointment data. Pull to retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchClinicData() async {
    final doc = await firestore
        .collection('clinics')
        .doc(clinicUid)
        .get(GetOptions(source: Source.cache));
    if (doc.exists) {
      _clinicData = doc.data();
    } else {
      throw Exception('Clinic not found');
    }
  }

  Future<void> _generateWeekSlots() async {
    if (_clinicData == null) return;

    final bookingLogic = BookingLogic(firestore: firestore);
    final now = DateTime.now();
    _weekSlots.clear();
    _visibleDays.clear();

    // Check next 7 days, but only add working days
    for (int i = 0; i < 7; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));

      // Skip non-working days entirely
      if (!isWorkingDay(day)) {
        debugPrint('Skipping non-working day: $day');
        continue;
      }

      final slotDurationMinutes = _parseInt(
        _clinicData!['duration'] ?? _clinicData!['Duration'],
        60,
      );
      final slots = await bookingLogic.generateSlots(
        day,
        clinicUid,
        slotDurationMinutes,
      );
      // Only show days that have at least one slot
      if (slots.isNotEmpty) {
        _weekSlots.add(slots);
        _visibleDays.add(day);
        debugPrint('Added day with ${slots.length} slots: $day');
      }
    }
  }

  Future<void> _fetchAllAppointments() async {
    if (_clinicData == null || _visibleDays.isEmpty) return;

    // Determine date range from first to last visible day
    final startDate = _visibleDays.first;
    final endDate = _visibleDays.last.add(const Duration(days: 1));

    final snapshot = await firestore
        .collection('clinics')
        .doc(clinicUid)
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThan: Timestamp.fromDate(endDate))
        .get();

    _onlineAppointmentsCount.clear();
    _manualAppointments.clear();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final appointmentTime = Clinic.parseDateTime(data['date']);
      final slotKey = _getSlotKey(appointmentTime);
      final isManual = data['isManual'] == true;

      if (isManual) {
        if (!_manualAppointments.containsKey(slotKey)) {
          _manualAppointments[slotKey] = [];
        }
        data['docId'] = doc.id;
        _manualAppointments[slotKey]!.add(data);
      } else {
        _onlineAppointmentsCount[slotKey] =
            (_onlineAppointmentsCount[slotKey] ?? 0) + 1;
      }
    }
  }

  String _getSlotKey(DateTime slotTime) {
    // Ensure local time consistency to match BookingLogic's slot generation
    return '${slotTime.year}-${_twoDigits(slotTime.month)}-${_twoDigits(slotTime.day)}T${_twoDigits(slotTime.hour)}:${_twoDigits(slotTime.minute)}Z';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  int getOnlineAppointmentsForSlot(DateTime slot) {
    return _onlineAppointmentsCount[_getSlotKey(slot)] ?? 0;
  }

  List<Map<String, dynamic>> getManualAppointmentsForSlot(DateTime slot) {
    return _manualAppointments[_getSlotKey(slot)] ?? [];
  }

  int getTotalAppointmentsForSlot(DateTime slot) {
    return getOnlineAppointmentsForSlot(slot) +
        getManualAppointmentsForSlot(slot).length;
  }

  int getStaffCount() {
    if (_clinicData == null) return 1;
    return _parseInt(_clinicData!['staff'], 1);
  }

  bool isSlotFull(DateTime slot) {
    return getTotalAppointmentsForSlot(slot) >= getStaffCount();
  }

  Future<void> addManualAppointment(DateTime slot, String name, String phone) async {
    if (isSlotFull(slot)) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ClinicFirestore().addManualAppointment(
        clinicId: clinicUid,
        name: name,
        phone: phone,
        date: slot,
      );
      await _fetchAllAppointments();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void removeManualAppointment(String docId) async {
    await firestore
        .collection('clinics')
        .doc(clinicUid)
        .collection('appointments')
        .doc(docId)
        .delete();
    await _fetchAllAppointments();
    notifyListeners();
  }

  String getSlotDisplayText(DateTime slot) {
    final localSlot = slot.toLocal(); // Display in local time for user
    final slotDurationMinutes = _parseInt(
      _clinicData!['Duration'] ?? _clinicData!['duration'],
      60,
    );
    final endTime = localSlot.add(Duration(minutes: slotDurationMinutes));
    return '${_twoDigits(localSlot.hour)}:${_twoDigits(localSlot.minute)} - ${_twoDigits(endTime.hour)}:${_twoDigits(endTime.minute)}';
  }

  Future<void> refreshData() async {
    await _initializeData();
  }
}

// ==================== UI SCREEN ====================

/// Main management screen with PageView for days and ListView for slots
class ManagementScreen extends StatefulWidget {
  final String clinicUid;

  const ManagementScreen({super.key, required this.clinicUid});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ManagementProvider(clinicUid: widget.clinicUid),
      child: Scaffold(
        body: SafeArea(
          child: Builder(
            builder: (context) {
              final provider = context.watch<ManagementProvider>();

              if (provider.isLoading) {
                return ListView.builder(
                  itemCount: 3,
                  itemBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: AppointmentCardSkeleton(),
                  ),
                );
              }

              if (provider.errorMessage != null) {
                return _buildErrorState(context, provider);
              }

              if (provider.visibleDays.isEmpty) {
                return _buildNoWorkingDaysState(context);
              }

              return Column(
                children: [
                  _buildDayHeaderWithNavigation(context, provider),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: provider.appointmentsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return ListView.builder(
                            itemCount: 3,
                            itemBuilder: (_, _) => const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: AppointmentCardSkeleton(),
                            ),
                          );
                        }

                        // The realAppointmentsCount is now managed internally by the provider
                        // and accessed via provider.getRealAppointmentsForSlot(slot).

                        return PageView.builder(
                          controller: _pageController,
                          itemCount: provider.visibleDays.length,
                          onPageChanged: (index) {
                            provider.setCurrentPageIndex(index);
                          },
                          itemBuilder: (context, dayIndex) {
                            final day = provider.visibleDays[dayIndex];
                            final slots = provider.weekSlots[dayIndex];

                            if (slots.isEmpty) {
                              return _buildEmptyState(context, day, provider);
                            }

                            return ManagementPage(
                              slots: slots,
                              provider: provider,
                              slotCardBuilder: _buildSlotCard,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeaderWithNavigation(
    BuildContext context,
    ManagementProvider provider,
  ) {
    final day = provider.visibleDays[provider.currentPageIndex];
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // UI Improvement: match scaffold
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              LucideIcons.arrowLeft,
              color: Theme.of(context).colorScheme.primary, // Contrast fix
            ),
            onPressed: provider.currentPageIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
          ),

          Text(
            DateFormat(
              'EEEE, MMM d, yyyy',
              context.locale.toString(),
            ).format(day.toLocal()),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary, // Contrast fix
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.arrowRight,
              color: Theme.of(context).colorScheme.primary, // Contrast fix
            ),
            onPressed:
                provider.currentPageIndex < provider.visibleDays.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ManagementProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.refreshData,
              icon: const Icon(LucideIcons.refreshCcw),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWorkingDaysState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.calendarOff,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 16),
          Text(
            'no_working_days_found'.tr(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    DateTime day,
    ManagementProvider provider,
  ) {
    final isWorkingDay = provider.isWorkingDay(day);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isWorkingDay ? LucideIcons.calendarOff : LucideIcons.store,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            isWorkingDay
                ? 'no_slots_available_today'.tr()
                : 'clinic_is_closed'.tr(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    ManagementProvider provider,
    DateTime slot,
  ) {
    final manualAppointments = provider.getManualAppointmentsForSlot(slot);
    final totalCount = provider.getTotalAppointmentsForSlot(slot);
    final staffCount = provider.getStaffCount();
    final isFull = provider.isSlotFull(slot);
    final displayText = provider.getSlotDisplayText(slot);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isFull
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary.withAlpha(150),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              LucideIcons.plusCircle,
              color: isFull 
                ? Theme.of(context).colorScheme.onSurface.withAlpha(150) 
                : Theme.of(context).colorScheme.primary,
            ),
            onPressed: isFull
                ? null
                : () => _showAddManualDialog(context, provider, slot),
          ),
        ),
        title: Text(
          displayText,
          style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: isFull
                    ? Theme.of(context).colorScheme.primary.withAlpha(200)
                    : Theme.of(context).colorScheme.primary,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "$totalCount / $staffCount ${'appointments'.tr()}\n(${provider.getOnlineAppointmentsForSlot(slot)} Online, ${manualAppointments.length} Manual)",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isFull
                  ? Theme.of(context).colorScheme.primary.withAlpha(180)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: const Icon(LucideIcons.chevronDown),
        children: [
          const Divider(indent: 16, endIndent: 16),
          if (manualAppointments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'no_manual_appointments'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...manualAppointments.asMap().entries.map((entry) {
              final index = entry.key;
              final app = entry.value;
              return _buildManualAppointmentTile(
                context,
                provider,
                slot,
                app,
                index,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildManualAppointmentTile(
    BuildContext context,
    ManagementProvider provider,
    DateTime slot,
    Map<String, dynamic> app,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          app['patientName'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          app['phone'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                LucideIcons.phone,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              onPressed: () async {
                final phoneNumber = app['phone'] ?? '';
                if (phoneNumber.isEmpty) return;
                
                final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
                if (await canLaunchUrl(launchUri)) {
                  await launchUrl(launchUri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('this_feature_works_only_on_phone'.tr()),
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: Icon(
                LucideIcons.trash2,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              onPressed: () => provider.removeManualAppointment(app['docId']),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddManualDialog(
    BuildContext context,
    ManagementProvider provider,
    DateTime slot,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_manual_appointment'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'full_name'.tr()),
                validator: (v) =>
                    v == null || v.isEmpty ? 'required'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'phone_number'.tr()),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? 'required'.tr() : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                provider.addManualAppointment(
                  slot,
                  nameController.text,
                  phoneController.text,
                );
                Navigator.pop(context);
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }
}

class ManagementPage extends StatefulWidget {
  final List<DateTime> slots;
  final ManagementProvider provider;
  final Widget Function(BuildContext, ManagementProvider, DateTime) slotCardBuilder;

  const ManagementPage({
    super.key,
    required this.slots,
    required this.provider,
    required this.slotCardBuilder,
  });

  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              itemCount: widget.slots.length + 1,
              itemBuilder: (context, slotIndex) {
                if (slotIndex == widget.slots.length) {
                  return SizedBox(
                    height: 92 + MediaQuery.of(context).padding.bottom,
                  );
                }
                return widget.slotCardBuilder(
                  context,
                  widget.provider,
                  widget.slots[slotIndex],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
