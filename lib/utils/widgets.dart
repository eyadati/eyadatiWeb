import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/Appointments/slotsUi.dart';
import 'package:eyadati/NavBarUi/user_nav_bar_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

class ClinicCard extends StatelessWidget {
  final Map<String, dynamic> clinic;
  final double? distance;
  final bool showFavoriteButton;

  const ClinicCard({
    super.key,
    required this.clinic,
    this.distance,
    this.showFavoriteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<UserNavBarProvider>();
    final picUrl = clinic['picUrl'] as String?;

    ImageProvider? image;
    if (picUrl != null) {
      if (picUrl.startsWith('http')) {
        image = CachedNetworkImageProvider(picUrl);
      } else {
        image = AssetImage(picUrl);
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: image,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha((255 * 0.1).round()),
                        child: picUrl == null
                            ? const Icon(LucideIcons.home)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMarqueeRow(
                              clinic['clinicName'] ?? 'unnamed_clinic'.tr(),
                              TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              height: 25,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (clinic['specialty'] as String?)?.tr() ??
                                    'general'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (clinic['openingAt'] != null &&
                                clinic['closingAt'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  '${_formatTime(clinic['openingAt'] as int)} - ${_formatTime(clinic['closingAt'] as int)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.mapPin,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _buildMarqueeRow(
                                    "${clinic['address'] ?? ''}${clinic['address'] != null && clinic['city'] != null ? ', ' : ''}${clinic['city'] ?? ''}",
                                    TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    height: 20,
                                  ),
                                ),
                              ],
                            ),
                            if (distance != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  '${(distance! / 1000).toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      SlotsUi.showModalSheet(context, clinic);
                    },
                    child: Text('book_appointment'.tr()),
                  ),
                ],
              ),
            ),
            if (showFavoriteButton)
              Positioned(
                top: 4,
                right: 4,
                child: Builder(
                  builder: (context) {
                    final clinicId = (clinic['id'] ?? clinic['uid']).toString();
                    final isFav = navProvider.isFavorite(clinicId);

                    return IconButton(
                      icon: Icon(
                        Icons.favorite,
                        color: isFav ? Colors.red : Colors.grey.withAlpha(100),
                      ),
                      onPressed: () async {
                        try {
                          HapticFeedback.mediumImpact();
                          await navProvider.toggleFavorite(clinicId);
                          if (!context.mounted) return;

                          // After toggle, isFav reflects the OLD state because it's captured in this closure
                          // or if we use isFav directly, it's what was current during build.
                          // Actually, the provider will notify and the widget will rebuild,
                          // but for the snackbar, we should use the state we just transitioned FROM.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFav
                                    ? 'removed_from_favorites'.tr()
                                    : 'added_to_favorites'.tr(),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'error_generic'.tr(args: [e.toString()]),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarqueeRow(String text, TextStyle style, {double height = 25}) {
    return SizedBox(
      height: height,
      child: Marquee(
        text: text,
        style: style,
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        blankSpace: 20.0,
        velocity: 30.0,
        pauseAfterRound: const Duration(seconds: 2),
        startPadding: 0.0,
        accelerationDuration: const Duration(seconds: 1),
        accelerationCurve: Curves.linear,
        decelerationDuration: const Duration(milliseconds: 500),
        decelerationCurve: Curves.easeOut,
      ),
    );
  }

  String _formatTime(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }
}
