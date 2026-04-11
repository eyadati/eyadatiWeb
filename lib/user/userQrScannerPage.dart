import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/NavBarUi/user_nav_bar_provider.dart';

class UserQrScannerPage extends StatefulWidget {
  const UserQrScannerPage({super.key});

  @override
  State<UserQrScannerPage> createState() => _UserQrScannerPageState();
}

class _UserQrScannerPageState extends State<UserQrScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _screenOpened = false;
  bool _isTorchOn = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    // The MobileScanner widget will handle starting the camera.
    // Explicitly stopping it here prevents it from working.
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: (capture) {
            if (!_screenOpened) {
              _screenOpened = true;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? clinicUid = barcodes.first.rawValue;
                if (clinicUid != null) {
                  _foundBarcode(clinicUid);
                }
              }
            }
          },
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            color: Colors.white,
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              cameraController.toggleTorch();
            },
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: IconButton(
            color: Colors.white,
            icon: Icon(_isFrontCamera ? Icons.camera_front : Icons.camera_rear),
            onPressed: () {
              setState(() {
                _isFrontCamera = !_isFrontCamera;
              });
              cameraController.switchCamera();
            },
          ),
        ),
      ],
    );
  }

  void _foundBarcode(String clinicUid) async {
    debugPrint('Scanned clinic UID: $clinicUid');
    // For now, we assume the scanned QR code is a clinic UID
    // In a real app, you might want to validate this UID or fetch clinic data first

    try {
      final provider = Provider.of<UserNavBarProvider>(context, listen: false);
      // First, check if the clinic exists and is valid before adding to favorites
      // For this example, we'll assume it's valid.
      // In a real application, you would query Firestore for the clinic's existence.

      // Simulate fetching clinic data from Firestore
      final clinicDoc = await Provider.of<UserNavBarProvider>(
        context,
        listen: false,
      ).firestore.collection('clinics').doc(clinicUid).get();

      if (!clinicDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('clinic_not_found'.tr())));
        Navigator.of(context).pop(); // Go back to favorites screen
        return;
      }

      await provider.toggleFavorite(clinicUid);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('added_to_favorites'.tr())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_adding_to_favorites'.tr())));
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Go back to favorites screen
      }
    }
  }
}
