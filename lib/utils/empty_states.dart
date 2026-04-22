import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  final bool large;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = LucideIcons.inbox,
    this.action,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = large ? 80.0 : 60.0;
    final iconSize = large ? 32.0 : 24.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size * 1.5,
              height: size * 1.5,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyClinicsState extends StatelessWidget {
  final VoidCallback? onSearch;

  const EmptyClinicsState({super.key, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.searchX,
      title: 'no_clinics_found'.tr(),
      subtitle: 'try_different_search'.tr(),
      action: onSearch != null
          ? ElevatedButton.icon(
              onPressed: onSearch,
              icon: const Icon(LucideIcons.search, size: 18),
              label: Text('search'.tr()),
            )
          : null,
    );
  }
}

class EmptyAppointmentsState extends StatelessWidget {
  final bool isClinic;

  const EmptyAppointmentsState({super.key, this.isClinic = false});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.calendarX,
      title: isClinic ? 'no_clinic_appointments'.tr() : 'no_appointments'.tr(),
      subtitle: isClinic ? 'no_clinic_appointments_desc'.tr() : 'no_appointments_desc'.tr(),
    );
  }
}

class EmptyFavoritesState extends StatelessWidget {
  final VoidCallback? onBrowse;

  const EmptyFavoritesState({super.key, this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.heart,
      title: 'no_favorite_clinics'.tr(),
      subtitle: 'add_clinics_to_see_them_here'.tr(),
      action: onBrowse != null
          ? ElevatedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(LucideIcons.search, size: 18),
              label: Text('find_clinics'.tr()),
            )
          : null,
    );
  }
}

class OfflineState extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.wifiOff,
      title: 'no_internet_connection'.tr(),
      subtitle: 'check_your_connection'.tr(),
      action: onRetry != null
          ? OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text('retry'.tr()),
            )
          : null,
    );
  }
}