import 'package:chargily_pay/chargily_pay.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eyadati/utils/models/clinic_model.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  static const double fixedMonthlyFee = 3000.0;
  static const double feePerAppointment = 100.0;
  static const int trialDays = 14;

  /// Reactive stream to listen for appointment changes and sync count
  static StreamSubscription<QuerySnapshot> listenAndSync({
    required String clinicUid,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicUid)
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThan: Timestamp.fromDate(endDate))
        .where('isManual', isNotEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final count = snapshot.docs.length;
      FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicUid)
          .update({'appointments_this_month': count});
    });
  }

  /// Logic to sync appointment count for clinics
  static Future<int?> syncAppointmentCountIfNeeded({
    required String clinicUid,
    required Map<String, dynamic> clinicData,
    required int lastSyncedCount,
  }) async {
    final clinic = Clinic.fromMap(clinicData);
    final startDate = clinic.subscriptionStartDate;
    final endDate = clinic.subscriptionEndDate;

    try {
      final aggregateQuery = FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicUid)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .where(
            'isManual',
            isNotEqualTo: true,
          ) // Only count online appointments
          .count();

      final res = await aggregateQuery.get();
      final count = res.count ?? 0;

      if (lastSyncedCount == -1 || (count - lastSyncedCount).abs() >= 1) {
        await FirebaseFirestore.instance
            .collection('clinics')
            .doc(clinicUid)
            .update({'appointments_this_month': count});
        return count;
      }
    } catch (e) {
      debugPrint("Error syncing appointment count: $e");
    }
    return null;
  }

  static Map<String, dynamic> checkSubscriptionStatus(
    Map<String, dynamic> clinicData,
  ) {
    final clinic = Clinic.fromMap(clinicData);
    final now = DateTime.now();
    final endDate = clinic.subscriptionEndDate;

    final bool isSubscriptionEnded = now.isAfter(endDate);
    final int appointmentsCount = clinic.appointmentsThisMonth;
    final double totalFees =
        fixedMonthlyFee + (appointmentsCount * feePerAppointment);

    bool needsPayment = isSubscriptionEnded;

    return {
      'isPaused': clinic.paused || isSubscriptionEnded,
      'needsPayment': needsPayment,
      'isSubscriptionEnded': isSubscriptionEnded,
      'overlayTitle': needsPayment ? 'subscription_ended_pay_fees'.tr() : '',
      'overlayMessage': needsPayment
          ? 'your_subscription_has_ended_pay_fees_message'.tr(
              args: [totalFees.toStringAsFixed(0)],
            )
          : '',
      'totalFees': totalFees,
      'endDate': endDate,
      'icon': isSubscriptionEnded
          ? LucideIcons.creditCard
          : LucideIcons.pauseCircle,
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
    this.icon = LucideIcons.alertCircle,
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
  final client = ChargilyClient(
    ChargilyConfig.test(
      apiKey: "test_sk_cCDBJ3lBdjpzoWKiOwdbW7O6KsVHJf0MRFPXb1Ld",
    ),
  );

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startSubscription(double amount) async {
    if (amount <= 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Check if API key is missing
      if (client.config.apiKey == null) {
        // SIMULATION MODE
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Simulation Mode"),
              content: const Text(
                "The Chargily API Key is missing in lib/chargili/paiment.dart. \n\nIn a real build, this would open the payment gateway. For testing, we'll simulate a successful payment trigger.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
        return;
      }

      final request = CreateCheckoutRequest(
        amount: amount,
        currency: 'dzd',
        successUrl: 'https://eyadati.page.link/payment_status',
        failureUrl: 'https://eyadati.page.link/payment_status',
        description: 'Payment for Monthly Subscription',
        metadata: {
          'clinic_id': user.uid,
          'subscription_type': 'pay_per_appointment',
        },
      );
      final checkout = await client.createCheckout(request);
      if (mounted) {
        await launchUrl(
          Uri.parse(checkout.checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Center(child: Text('please_login'.tr()));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('clinics')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('something_went_wrong'.tr()));
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return Center(child: Text('clinic_data_not_found'.tr()));
        }

        final clinic = Clinic.fromMap(data);
        final now = DateTime.now();
        final startDate = clinic.subscriptionStartDate;
        final dbEndDate = clinic.subscriptionEndDate;

        // Use database endDate if valid (subscription already active), otherwise calculate cycle
        DateTime effectiveEndDate;
        if (dbEndDate.isAfter(now)) {
          // Use real subscription end date from database (active subscription)
          effectiveEndDate = dbEndDate;
        } else {
          // Calculate cycle from start date (for new/renewal)
          DateTime cycleStart = startDate;
          while (cycleStart.add(const Duration(days: 30)).isBefore(now)) {
            cycleStart = cycleStart.add(const Duration(days: 30));
          }
          effectiveEndDate = cycleStart.add(const Duration(days: 30));
        }
        
        final daysLeft = effectiveEndDate.difference(now).inDays;

final appointments = clinic.appointmentsThisMonth;
        final apptFees = appointments * PaymentService.feePerAppointment;
        final totalAmount = PaymentService.fixedMonthlyFee + apptFees;

        final isExpired = now.isAfter(effectiveEndDate);
        final canRenew = isExpired || daysLeft <= 7;
        final canPay = canRenew;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'subscription_renewal'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _receiptRow(
                  'clinic_id'.tr(),
                  clinic.clinicName,
                  isBold: true,
                ),
                const SizedBox(height: 24),
                if (!canRenew)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'subscription_active_days_left'.tr(args: [daysLeft.toString()]),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'receipt'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                _buildReceipt(
                  context,
                  appointments,
                  apptFees,
                  totalAmount,
                  daysLeft,
                  effectiveEndDate,
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (canPay && !_isLoading)
                        ? () => _startSubscription(totalAmount)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            canPay
                                ? 'pay_now'.tr()
                                : 'payment_available_on'.tr(
                                    args: [DateFormat.yMMMd().format(effectiveEndDate)],
                                  ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceipt(
    BuildContext context,
    int count,
    double apptFees,
    double total,
    int daysLeft,
    DateTime cycleEnd,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _receiptRow(
            'monthly_fee'.tr(),
            '${PaymentService.fixedMonthlyFee.toStringAsFixed(0)} DA',
          ),
          const SizedBox(height: 16),
          _receiptRow(
            '${'appointments_fee'.tr()} ($count)',
            '${apptFees.toStringAsFixed(0)} DA',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
          ),
          _receiptRow(
            'total_to_pay'.tr(),
            '${total.toStringAsFixed(0)} DA',
            isBold: true,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'days_left'.tr(args: [daysLeft.toString()]),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: isBold ? null : Colors.grey[600],
            fontWeight: isBold ? FontWeight.bold : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
