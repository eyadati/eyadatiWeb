import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/NavBarUi/user_nav_bar_provider.dart';
import 'package:eyadati/utils/constants.dart';
import 'package:eyadati/utils/location_helper.dart';
import 'package:eyadati/utils/skeletons.dart';
import 'package:eyadati/utils/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class ClinicSearchProvider extends ChangeNotifier {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  List<Map<String, dynamic>> _currentClinics = [];
  bool _isLoading = false;
  String? _error;
  String? _userCity;
  Position? _currentLocation;

  // Filter states
  String _searchQuery = '';
  String? _selectedCity;
  String? _selectedSpecialty;

  // Pagination
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  static const int _limit = 15;

  Timer? _debounceTimer;
  bool _isLocationLoading = false;

  ClinicSearchProvider({required this.firestore, required this.auth}) {
    _initialize();
  }

  // Getters
  List<Map<String, dynamic>> get currentClinics => _currentClinics;
  bool get isLoading => _isLoading;
  bool get isLocationLoading => _isLocationLoading;
  bool get isLocationEnabled => _currentLocation != null;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get userCity => _userCity;
  String? get selectedCity => _selectedCity;
  String? get selectedSpecialty => _selectedSpecialty;
  String get searchQuery => _searchQuery;
  List<String> get specialtiesList => AppConstants.specialties;
  List<String> get algerianCitiesList => AppConstants.algerianCities;

  Future<void> _initialize() async {
    try {
      final user = auth.currentUser;
      if (user == null) return;

      // Proactively request location on init to show distance
      await requestLocation(silent: true);

      final doc = await firestore.collection("users").doc(user.uid).get();
      _userCity = doc.data()?["city"]?.toString();
      notifyListeners();
    } catch (e) {
      debugPrint("Init error: $e");
    }
  }

  Future<void> requestLocation({bool silent = false}) async {
    if (!silent) {
      _isLocationLoading = true;
      notifyListeners();
    }

    try {
      _currentLocation = await LocationHelper.getCurrentLocation();
      if (_currentLocation != null && !silent) {
        // Refresh clinics with distance if requested manually
        fetchClinics();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint("Location error: $e");
    } finally {
      if (!silent) {
        _isLocationLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchClinics({bool isNextPage = false}) async {
    // If it's a fresh search, we allow it even if something is loading
    // to prevent the "stuck" feeling.
    if (isNextPage && (_isLoading || !_hasMore)) return;

    final cityToQuery = _selectedCity ?? _userCity;

    // We need either a city OR a location to search
    if (cityToQuery == null && _currentLocation == null) return;

    _isLoading = true;
    _error = null;
    if (!isNextPage) {
      _currentClinics = []; // Clear for fresh search
      _lastDocument = null;
      _hasMore = true;
    }
    notifyListeners();

    try {
      List<Map<String, dynamic>> fetchedClinics = [];

      // Logic: If 'Nearby First' is active AND we don't have a specific city override,
      // or if we just want to prioritize proximity.
      if (_currentLocation != null && _selectedCity == null) {
        // GEO-QUERY: Find anything within 100km of the user
        final center = GeoFirePoint(
          GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
        );
        final GeoCollectionReference<Map<String, dynamic>> geoRef =
            GeoCollectionReference<Map<String, dynamic>>(
              firestore.collection('clinics'),
            );

        // GeoQuery fetches everything in range, we'll filter specialty manually
        final geoDocs = await geoRef.fetchWithin(
          center: center,
          radiusInKm: 100, // Increased radius
          field: 'position',
          geopointFrom: (data) =>
              (data['position'] as Map<String, dynamic>)['geopoint']
                  as GeoPoint,
          strictMode: true,
        );

        fetchedClinics = geoDocs
            .cast<GeoDocumentSnapshot<Map<String, dynamic>>>()
            .map((doc) {
              final data = doc.documentSnapshot.data()!;
              return {
                'id': doc.documentSnapshot.id,
                ...data,
                'distance': doc.distanceFromCenterInKm * 1000,
              };
            })
            .toList();

        // Filter by specialty if selected
        if (_selectedSpecialty != null) {
          fetchedClinics = fetchedClinics
              .where((c) => c['specialty'] == _selectedSpecialty)
              .toList();
        }

        // Distance is already sorted by fetchWithin
        _hasMore = false;
      } else {
        // STANDARD QUERY: Search by City (with client-side distance calc)
        Query<Map<String, dynamic>> query = firestore
            .collection("clinics")
            .where("city", isEqualTo: cityToQuery);

        if (_selectedSpecialty != null) {
          query = query.where("specialty", isEqualTo: _selectedSpecialty);
        }

        if (isNextPage && _lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }

        final snapshot = await query.limit(_limit).get(const GetOptions(source: Source.serverAndCache));
        if (snapshot.docs.length < _limit) _hasMore = false;
        if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;

        fetchedClinics = snapshot.docs.map((doc) {
          final data = doc.data();
          double? dist;
          if (_currentLocation != null && data['position'] != null) {
            final geoPoint =
                (data['position'] as Map<String, dynamic>)['geopoint']
                    as GeoPoint?;
            if (geoPoint != null) {
              dist = Geolocator.distanceBetween(
                _currentLocation!.latitude,
                _currentLocation!.longitude,
                geoPoint.latitude,
                geoPoint.longitude,
              );
            }
          }
          return {'id': doc.id, ...data, if (dist != null) 'distance': dist};
        }).toList();

        // If we have location, sort the city results by distance
        if (_currentLocation != null) {
          fetchedClinics.sort(
            (a, b) =>
                (a['distance'] ?? 999999).compareTo(b['distance'] ?? 999999),
          );
        }
      }

      // Final Search Text Filter
      if (_searchQuery.isNotEmpty) {
        fetchedClinics = fetchedClinics
            .where(
              (c) => (c['clinicName'] as String).toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
            )
            .toList();
      }

      if (isNextPage) {
        _currentClinics.addAll(fetchedClinics);
      } else {
        _currentClinics = fetchedClinics;
      }
    } catch (e) {
      _error = "error_fetching_clinics".tr(args: [e.toString()]);
      debugPrint("Fetch error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void applyFilters({String? city, String? specialty}) {
    _selectedCity = city;
    _selectedSpecialty = specialty;
    _lastDocument = null;
    _hasMore = true;
    fetchClinics();
  }

  void updateSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = query;
      _lastDocument = null;
      _hasMore = true;
      fetchClinics();
    });
  }

  void clearFilters() {
    _selectedCity = null;
    _selectedSpecialty = null;
    _searchQuery = '';
    _lastDocument = null;
    _hasMore = true;
    fetchClinics();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ================ UI COMPONENTS ================

class ClinicFilterBottomSheet extends StatelessWidget {
  static Future<bool?> show(
    BuildContext context,
    UserNavBarProvider userNavBarProvider,
  ) async {
    final provider = ClinicSearchProvider(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    );

    final bool? shouldShowList = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: userNavBarProvider),
        ],
        child: _InitialFilterDialog(provider: provider),
      ),
    );

    if (shouldShowList == true && context.mounted) {
      return showMaterialModalBottomSheet<bool>(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: userNavBarProvider),
          ],
          child: const _ClinicBottomSheetContent(),
        ),
      );
    }
    return false;
  }

  const ClinicFilterBottomSheet({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _InitialFilterDialog extends StatefulWidget {
  final ClinicSearchProvider provider;
  const _InitialFilterDialog({required this.provider});

  @override
  State<_InitialFilterDialog> createState() => _InitialFilterDialogState();
}

class _InitialFilterDialogState extends State<_InitialFilterDialog> {
  String? _tempCity;
  String? _tempSpecialty;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicSearchProvider>();
    if (_tempCity == null && provider.userCity != null) {
      _tempCity = provider.userCity;
    }

    return AlertDialog(
      title: Text('find_clinics'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('please_select_filters_to_find_clinics'.tr()),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tempCity,
            decoration: InputDecoration(
              labelText: "city".tr(),
              prefixIcon: const Icon(LucideIcons.mapPin),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: provider.algerianCitiesList
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) => setState(() => _tempCity = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tempSpecialty,
            decoration: InputDecoration(
              labelText: "specialty".tr(),
              prefixIcon: const Icon(LucideIcons.stethoscope),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: provider.specialtiesList
                .map((s) => DropdownMenuItem(value: s, child: Text(s.tr())))
                .toList(),
            onChanged: (val) => setState(() => _tempSpecialty = val),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: (_tempCity != null && _tempSpecialty != null)
              ? () {
                  provider.applyFilters(
                    city: _tempCity,
                    specialty: _tempSpecialty,
                  );
                  Navigator.pop(context, true);
                }
              : null,
          child: Text('search'.tr()),
        ),
      ],
    );
  }
}

class _ClinicBottomSheetContent extends StatelessWidget {
  const _ClinicBottomSheetContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicSearchProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              _buildHeader(context, provider),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent * 0.9) {
                      provider.fetchClinics(isNextPage: true);
                    }
                    return false;
                  },
                  child: _buildClinicList(context, provider, scrollController),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ClinicSearchProvider provider) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _showFilterDialog(context, provider),
                icon: const Icon(LucideIcons.slidersHorizontal),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (provider.selectedSpecialty != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(provider.selectedSpecialty!.tr()),
                          ),
                        ),
                      if (provider.selectedCity != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(label: Text(provider.selectedCity!)),
                        ),
                      ActionChip(
                        avatar: provider.isLocationLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                LucideIcons.mapPin,
                                size: 16,
                                color: provider.isLocationEnabled
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                        label: Text(
                          provider.isLocationEnabled
                              ? 'nearby_sorted'.tr()
                              : 'sort_by_distance'.tr(),
                        ),
                        onPressed: () => provider.requestLocation(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (provider.isLocationEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'showing_closest_clinics_first'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClinicList(
    BuildContext context,
    ClinicSearchProvider provider,
    ScrollController controller,
  ) {
    if (provider.isLoading && provider.currentClinics.isEmpty) {
      return ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const ClinicCardSkeleton(),
      );
    }

    if (provider.currentClinics.isEmpty) {
      return Center(child: Text('no_clinics_found'.tr()));
    }

    return ListView.builder(
      controller: controller,
      itemCount: provider.currentClinics.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == provider.currentClinics.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final clinic = provider.currentClinics[index];
        return ClinicCard(
          clinic: clinic,
          distance: clinic['distance'] as double?,
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context, ClinicSearchProvider provider) {
    String? tCity = provider.selectedCity;
    String? tSpec = provider.selectedSpecialty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('select_filters'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: tCity,
                items: provider.algerianCitiesList
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => tCity = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: tSpec,
                items: provider.specialtiesList
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.tr())))
                    .toList(),
                onChanged: (v) => setState(() => tSpec = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: (tCity != null && tSpec != null)
                  ? () {
                      provider.applyFilters(city: tCity, specialty: tSpec);
                      Navigator.pop(ctx);
                    }
                  : null,
              child: Text('apply'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}


