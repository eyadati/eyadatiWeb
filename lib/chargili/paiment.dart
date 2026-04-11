import 'package:chargily_pay/chargily_pay.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/utils/models/clinic_model.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  static const double fixedMonthlyFee = 3000.0;
  static const double feePerAppointment = 100.0;
  static const int trialDays = 14;

  /// Logic to sync appointment count for clinics
  static Future<int?> syncAppointmentCountIfNeeded({
    required String clinicUid,
    required Map<String, dynamic> clinicData,
    required int lastSyncedCount,
  }) async {
    final clinic = Clinic.fromMap(clinicData);
    final startDate = clinic.subscriptionStartDate;
    final now = DateTime.now();

    // Calculate current cycle start (every 30 days)
    DateTime cycleStart = startDate;
    while (cycleStart.add(const Duration(days: 30)).isBefore(now)) {
      cycleStart = cycleStart.add(const Duration(days: 30));
    }

    // Reset if we just entered a new cycle
    final dynamic lastCycleStartRaw = clinicData['lastCycleStart'];
    DateTime? lastCycleStart;
    if (lastCycleStartRaw is Timestamp) {
      lastCycleStart = lastCycleStartRaw.toDate();
    } else if (lastCycleStartRaw is DateTime) {
      lastCycleStart = lastCycleStartRaw;
    }

    if (lastCycleStart == null || lastCycleStart.isBefore(cycleStart)) {
      await FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicUid)
          .update({
        'lastCycleStart': Timestamp.fromDate(cycleStart),
        'appointments_this_month': 0,
        'paid_this_month': false,
      });
      return 0;
    }

    try {
      final aggregateQuery = FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicUid)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cycleStart))
          .where('isManual', isNotEqualTo: true) // Only count online appointments
          .count();

      final res = await aggregateQuery.get();
      final count = res.count ?? 0;

      if (lastSyncedCount == -1 || (count - lastSyncedCount).abs() >= 1) {
        await FirebaseFirestore.instance
            .collection('clinics')
            .doc(clinicUid)
            .update({
          'appointments_this_month': count,
        });
        return count;
      }
    } catch (e) {
      debugPrint("Error syncing appointment count: $e");
    }
    return null;
  }

  static Map<String, dynamic> checkSubscriptionStatus(
      Map<String, dynamic> clinicData) {
    final clinic = Clinic.fromMap(clinicData);
    final now = DateTime.now();
    final startDate = clinic.subscriptionStartDate;
    
    // Check for free trial
    final trialEndDate = startDate.add(const Duration(days: trialDays));
    final isTrial = now.isBefore(trialEndDate);

    if (isTrial) {
      return {
        'isPaused': false,
        'needsPayment': false,
        'isSubscriptionEnded': false,
        'overlayTitle': '',
        'overlayMessage': '',
        'totalFees': 0.0,
        'isTrial': true,
        'daysLeftInTrial': trialEndDate.difference(now).inDays,
      };
    }

    // Calculate cycle
    DateTime cycleStart = startDate;
    while (cycleStart.add(const Duration(days: 30)).isBefore(now)) {
      cycleStart = cycleStart.add(const Duration(days: 30));
    }
    final cycleEnd = cycleStart.add(const Duration(days: 30));

    final int appointmentsCount = clinic.appointmentsThisMonth;
    final double totalFees = fixedMonthlyFee + (appointmentsCount * feePerAppointment);
    
    bool needsPayment = false;
    // If previous month wasn't paid and we are in new month
    if (!clinic.paidThisMonth && now.isAfter(cycleEnd.subtract(const Duration(days: 1)))) {
       needsPayment = true;
    }

    return {
      'isPaused': clinic.paused,
      'needsPayment': needsPayment,
      'isSubscriptionEnded': false,
      'overlayTitle': needsPayment ? 'clinic_invisible_pay_fees'.tr() : '',
      'overlayMessage': needsPayment ? 'your_clinic_is_invisible_pay_fees_message'.tr(args: [totalFees.toStringAsFixed(0)]) : '',
      'totalFees': totalFees,
      'cycleEnd': cycleEnd,
    };
  }
}

class PaymentOverlay extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final double? initialAmount;

  const PaymentOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.initialAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 80,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const FractionallySizedBox(
                        heightFactor: 0.9,
                        child: SubscribeScreen(),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.refreshCcw),
                  label: Text('take_action'.tr()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final client = ChargilyClient(ChargilyConfig.test(apiKey: ""));
  Clinic? _clinic;
  bool _isFetchingData = false;

  @override
  void initState() {
    super.initState();
    _fetchClinicData();
  }

  Future<void> _fetchClinicData() async {
    setState(() => _isFetchingData = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('clinics')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          setState(() => _clinic = Clinic.fromMap(doc.data()!));
        }
      }
    } catch (e) {
      debugPrint("Error fetching clinic data: $e");
    } finally {
      setState(() => _isFetchingData = false);
    }
  }

  Future<void> _startSubscription(double amount) async {
    if (amount <= 0) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final request = CreateCheckoutRequest(
        amount: amount,
        currency: 'dzd',
        successUrl: 'https://eyadati.page.link/payment_status',
        failureUrl: 'https://eyadati.page.link/payment_status',
        description: 'Payment for Monthly Subscription',
        metadata: {'clinic_id': user.uid, 'subscription_type': 'pay_per_appointment'},
      );
      final checkout = await client.createCheckout(request);
      if (mounted) {
        await launchUrl(Uri.parse(checkout.checkoutUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_clinic == null) {
      return Center(child: Text('clinic_data_not_found'.tr()));
    }

    final now = DateTime.now();
    final startDate = _clinic!.subscriptionStartDate;
    
    // Trial check
    final trialEndDate = startDate.add(const Duration(days: PaymentService.trialDays));
    final isTrial = now.isBefore(trialEndDate);
    
    // Cycle check
    DateTime cycleStart = startDate;
    while (cycleStart.add(const Duration(days: 30)).isBefore(now)) {
      cycleStart = cycleStart.add(const Duration(days: 30));
    }
    final cycleEnd = cycleStart.add(const Duration(days: 30));
    final daysLeft = cycleEnd.difference(now).inDays;
    
    final appointments = _clinic!.appointmentsThisMonth;
    final apptFees = appointments * PaymentService.feePerAppointment;
    final totalAmount = PaymentService.fixedMonthlyFee + apptFees;

    final canPay = now.isAfter(cycleEnd) || now.isAtSameMomentAs(cycleEnd);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('receipt'.tr(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (isTrial)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                 child: Text('trial_ends_in'.tr(args: [trialEndDate.difference(now).inDays.toString()]), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
               ),
            const SizedBox(height: 32),
            _buildReceipt(context, appointments, apptFees, totalAmount, daysLeft, cycleEnd),
            const SizedBox(height: 32),
            if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (canPay && !_isLoading) ? () => _startSubscription(totalAmount) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(canPay ? 'pay_now'.tr() : 'payment_available_on'.tr(args: [DateFormat.yMMMd().format(cycleEnd)])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceipt(BuildContext context, int count, double apptFees, double total, int daysLeft, DateTime cycleEnd) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _receiptRow('monthly_fee'.tr(), '${PaymentService.fixedMonthlyFee.toStringAsFixed(0)} DA'),
          const SizedBox(height: 16),
          _receiptRow('${'appointments_fee'.tr()} ($count)', '${apptFees.toStringAsFixed(0)} DA'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
          _receiptRow('total_to_pay'.tr(), '${total.toStringAsFixed(0)} DA', isBold: true),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('days_left'.tr(args: [daysLeft.toString()]), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: isBold ? null : Colors.grey[600], fontWeight: isBold ? FontWeight.bold : null)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
