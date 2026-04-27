import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:eyadati/NavBarUi/user_nav_bar_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

class UserQrScannerPage extends StatefulWidget {
  const UserQrScannerPage({super.key});

  @override
  State<UserQrScannerPage> createState() => _UserQrScannerPageState();
}

class _UserQrScannerPageState extends State<UserQrScannerPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showManualInput = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _processCode(String code) async {
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clinicDoc = await FirebaseFirestore.instance
          .collection('clinics')
          .doc(code.trim())
          .get();

      if (!clinicDoc.exists) {
        setState(() {
          _error = 'clinic_not_found'.tr();
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      final provider = Provider.of<UserNavBarProvider>(context, listen: false);
      await provider.toggleFavorite(code.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('added_to_favorites'.tr())),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('qr_scanner'.tr()),
        actions: [
          IconButton(
            icon: Icon(_showManualInput ? Icons.qr_code : Icons.edit),
            onPressed: () {
              setState(() {
                _showManualInput = !_showManualInput;
              });
            },
            tooltip: _showManualInput ? 'scan_from_qr'.tr() : 'enter_manually'.tr(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_showManualInput) ...[
              Icon(
                Icons.link,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'enter_clinic_code'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'clinic_code_description'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'clinic_code'.tr(),
                  hintText: 'xxxxxxxx-xxxx-xxxx',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(LucideIcons.hash),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => _processCode(value),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () => _processCode(_codeController.text),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('add_to_favorites'.tr()),
                ),
              ),
            ] else ...[
              Icon(
                Icons.qr_code_2,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'scan_qr_code'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'qr_scanner_web_description'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showManualInput = true;
                  });
                },
                icon: const Icon(LucideIcons.edit3),
                label: Text('enter_code_manually'.tr()),
              ),
              const SizedBox(height: 16),
              Text(
                'or'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'ask_clinic_for_code'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}