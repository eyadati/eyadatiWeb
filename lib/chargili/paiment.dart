import 'package:chargily_pay/chargily_pay.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  int _doctorCount = 1;
  double _price = 4000;
  final client = ChargilyClient(
    ChargilyConfig.test(
      apiKey: 'test_sk_kMrjDHPewHDyW4CMkPEPl1viQN0ieJp5IKY9vrPB',
    ),
  );

  void _calculatePrice() {
    setState(() {
      if (_doctorCount == 1) {
        _price = 4000;
      } else if (_doctorCount == 2) {
        _price = 7000;
      } else {
        _price = _doctorCount * 3000.0;
      }
    });
  }

  void _incrementDoctors() {
    setState(() {
      _doctorCount++;
      _calculatePrice();
    });
  }

  void _decrementDoctors() {
    setState(() {
      if (_doctorCount > 1) {
        _doctorCount--;
        _calculatePrice();
      }
    });
  }

  Future<void> _startSubscription(double amount, int doctorCount) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final request = CreateCheckoutRequest(
        amount: amount,
        currency: 'dzd',
        successUrl: 'https://eyadati.page.link/payment_status',
        failureUrl: 'https://eyadati.page.link/payment_status',
        description: 'Subscription for $doctorCount doctors',
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
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('subscribe'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'choose_your_plan'.tr(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'unlock_all_features'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _SubscriptionCalculator(
                doctorCount: _doctorCount,
                price: _price,
                onDecrement: _decrementDoctors,
                onIncrement: _incrementDoctors,
                onSubscribe: () => _startSubscription(_price, _doctorCount),
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCalculator extends StatelessWidget {
  final int doctorCount;
  final double price;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onSubscribe;
  final bool isLoading;

  const _SubscriptionCalculator({
    required this.doctorCount,
    required this.price,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSubscribe,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'select_number_of_doctors'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: onDecrement,
                ),
                Text(
                  '$doctorCount',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onIncrement,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '${price.toStringAsFixed(2)} DZD',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubscribe,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: isLoading
                    ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                      )
                    : Text('subscribe'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
