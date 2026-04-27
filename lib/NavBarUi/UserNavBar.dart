import 'package:eyadati/user/userAppointments.dart';
import 'package:eyadati/user/userQrScannerPage.dart';
import 'package:eyadati/utils/connectivity_service.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:deferred_indexed_stack/deferred_indexed_stack.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:eyadati/utils/skeletons.dart';
import 'package:eyadati/NavBarUi/user_nav_bar_provider.dart';
import 'package:eyadati/utils/widgets.dart';

// ✅ Simplified: Expects Provider from above
class UserFloatingBottomNavBar extends StatelessWidget {
  const UserFloatingBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BottomNavContent();
  }
}

class _BottomNavContent extends StatelessWidget {
  const _BottomNavContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserNavBarProvider>();
    final connectivity = context.watch<ConnectivityService>();
    final selectedIndex = int.parse(provider.selected) - 1;

    return BottomBar(
      borderRadius: BorderRadius.circular(25),
      duration: const Duration(milliseconds: 500),
      curve: Curves.decelerate,
      width: MediaQuery.of(context).size.width * 0.9, // Floating effect
      barColor: Theme.of(context).colorScheme.onSecondary,
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
                  DeferredTab(id: '1', child: const UserAppointments()),
                  DeferredTab(id: '2', child: const FavoritScreen()),
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
            _buildNavItem(context, LucideIcons.home, 'home'.tr(), '1'),
            _buildNavItem(context, LucideIcons.heart, 'favorites'.tr(), '2'),
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
    final provider = context.watch<UserNavBarProvider>();
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
            Icon(
              value == '1'
                  ? LucideIcons.home
                  : value == '2'
                  ? LucideIcons.heart
                  : LucideIcons.mail,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(label.tr(), style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
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

class FavoritScreen extends StatelessWidget {
  const FavoritScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserNavBarProvider>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.qrCode),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserQrScannerPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (provider.isLoadingFavorites) {
              return ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) => const ClinicCardSkeleton(),
              );
            }
            if (provider.favorites.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.heart,
                      size: 70,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'no_favorite_clinics'.tr(),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'add_clinics_to_see_them_here'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            final favClinics = provider.favorites;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: favClinics.length + 1, // Add 1 for the SizedBox
              itemBuilder: (context, index) {
                if (index == favClinics.length) {
                  return SizedBox(
                    height: 92 + MediaQuery.of(context).padding.bottom,
                  ); // Adjust height to account for floating nav bar
                }
                final clinic = favClinics[index];

                return ClinicCard(clinic: clinic, showFavoriteButton: true);
              },
            );
          },
        ),
      ),
    );
  }
}
