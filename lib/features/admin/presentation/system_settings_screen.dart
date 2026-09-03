import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/company_settings.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/widgets/web_layout.dart';
import '../../auth/domain/auth_provider.dart';

class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() =>
      _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _companyController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _secretController;
  late TextEditingController _adminApiController;
  late TextEditingController _mobileAppUrlController;
  late TextEditingController _mobileAppVersionController;
  late TextEditingController _mobileAppNotesController;

  double _radiusMeters = 500;
  int _rotationInterval = 15;
  bool _allowRemoteClockIn = false;
  bool _mobileAppEnabled = true;

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _secretController = TextEditingController();
    _adminApiController = TextEditingController();
    _mobileAppUrlController = TextEditingController();
    _mobileAppVersionController = TextEditingController();
    _mobileAppNotesController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _secretController.dispose();
    _adminApiController.dispose();
    _mobileAppUrlController.dispose();
    _mobileAppVersionController.dispose();
    _mobileAppNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('settings').doc('company').get();
      CompanySettings settings = CompanySettings.defaultSettings;
      if (doc.exists && doc.data() != null) {
        settings = CompanySettings.fromJson(doc.data()!);
      }

      final currentUser = ref.read(currentUserModelProvider).valueOrNull;

      if (currentUser != null && currentUser.isManager) {
        _companyController.text =
            currentUser.assignedCompanyName ?? settings.companyName;
        _latController.text = currentUser.assignedLocationLat?.toString() ??
            settings.latitude.toString();
        _lngController.text = currentUser.assignedLocationLng?.toString() ??
            settings.longitude.toString();
        _radiusMeters =
            currentUser.assignedLocationRadius ?? settings.radiusMeters;

        _secretController.text =
            currentUser.assignedQrSecret ?? settings.qrSecret;
        _rotationInterval = currentUser.assignedQrRotateIntervalSeconds ??
            settings.qrRotateIntervalSeconds;
        _allowRemoteClockIn = currentUser.assignedAllowRemoteClockIn ??
            settings.allowRemoteClockIn;
      } else {
        _companyController.text = settings.companyName;
        _latController.text = settings.latitude.toString();
        _lngController.text = settings.longitude.toString();
        _radiusMeters = settings.radiusMeters;

        _secretController.text = settings.qrSecret;
        _rotationInterval = settings.qrRotateIntervalSeconds;
        _allowRemoteClockIn = settings.allowRemoteClockIn;
      }

      _adminApiController.text = settings.adminApiBaseUrl;
      _mobileAppUrlController.text = settings.mobileAppUrl;
      _mobileAppVersionController.text = settings.mobileAppVersion;
      _mobileAppNotesController.text = settings.mobileAppNotes;
      _mobileAppEnabled = settings.mobileAppEnabled;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.tr('errorLoadingSettings')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.tr('locationServicesDisabled'))),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.tr('locationPermissionRequired'))),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latController.text = pos.latitude.toString();
          _lngController.text = pos.longitude.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr('gpsPositionCaptured')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.tr('errorLoadingSettings')}: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final currentUser = ref.read(currentUserModelProvider).valueOrNull;
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final companyName = _companyController.text.trim();
    final secret = _secretController.text.trim();

    if (lat == null || lng == null || companyName.isEmpty || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.tr('fillAllFields'))),
      );
      return;
    }

    if (currentUser != null && currentUser.isManager) {
      setState(() => _saving = true);
      try {
        final batch = _db.batch();
        final managerRef = _db.collection('users').doc(currentUser.uid);
        batch.update(managerRef, {
          'assignedLocationLat': lat,
          'assignedLocationLng': lng,
          'assignedLocationRadius': _radiusMeters,
          'locationAssignedBy': currentUser.uid,
          'assignedQrSecret': secret,
          'assignedQrRotateIntervalSeconds': _rotationInterval,
          'assignedAllowRemoteClockIn': _allowRemoteClockIn,
          'assignedCompanyName': companyName,
        });

        final usersSnap = await _db
            .collection('users')
            .where('managerId', isEqualTo: currentUser.uid)
            .get();
        for (final doc in usersSnap.docs) {
          batch.update(doc.reference, {
            'assignedLocationLat': lat,
            'assignedLocationLng': lng,
            'assignedLocationRadius': _radiusMeters,
            'locationAssignedBy': currentUser.uid,
            'assignedQrSecret': secret,
            'assignedQrRotateIntervalSeconds': _rotationInterval,
            'assignedAllowRemoteClockIn': _allowRemoteClockIn,
            'assignedCompanyName': companyName,
          });
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.tr('locationAssigned')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ref.tr('errorSavingSettings')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    bool locationChanged = false;
    try {
      final existing = await _db.collection('settings').doc('company').get();
      if (existing.exists && existing.data() != null) {
        final data = existing.data()!;
        final savedLat = (data['latitude'] as num?)?.toDouble();
        final savedLng = (data['longitude'] as num?)?.toDouble();
        locationChanged = savedLat == null ||
            savedLng == null ||
            savedLat != lat ||
            savedLng != lng;
      } else {
        locationChanged = true;
      }
    } catch (_) {
      locationChanged = false;
    }

    if (locationChanged && mounted) {
      final choice = await _showLocationApplyDialog();
      if (choice == null) return;
      setState(() => _saving = true);
      await _persistSettings(lat, lng, companyName, secret);
      await _applyAdminLocationToUsers(lat, lng, _radiusMeters, scope: choice);
    } else {
      setState(() => _saving = true);
      await _persistSettings(lat, lng, companyName, secret);
    }
  }

  Future<String?> _showLocationApplyDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(ref.tr('applyNewLocation'))),
          ],
        ),
        content: Text(
          ref.tr('locationChangedDesc'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(ref.tr('cancel')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'without_manager'),
            child: Text(ref.tr('onlyUsersWithoutManager')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: Text(ref.tr('applyToAllUsers')),
          ),
        ],
      ),
    );
  }

  Future<void> _persistSettings(
    double lat,
    double lng,
    String companyName,
    String secret,
  ) async {
    try {
      final updated = CompanySettings(
        latitude: lat,
        longitude: lng,
        radiusMeters: _radiusMeters,
        qrSecret: secret,
        qrRotateIntervalSeconds: _rotationInterval,
        companyName: companyName,
        allowRemoteClockIn: _allowRemoteClockIn,
        adminApiBaseUrl: _adminApiController.text.trim(),
        mobileAppUrl: _mobileAppUrlController.text.trim(),
        mobileAppVersion: _mobileAppVersionController.text.trim(),
        mobileAppNotes: _mobileAppNotesController.text.trim(),
        mobileAppEnabled: _mobileAppEnabled,
      );
      await _db.collection('settings').doc('company').set(updated.toJson());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr('settingsSaved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr('errorSavingSettings')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyAdminLocationToUsers(
    double lat,
    double lng,
    double radius, {
    required String scope,
  }) async {
    try {
      final usersSnap = await _db.collection('users').get();
      final batch = _db.batch();
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final assignedBy = data['locationAssignedBy'] as String?;
        final hasManagerLocation = assignedBy != null &&
            assignedBy.isNotEmpty &&
            assignedBy != 'admin';

        if (scope == 'all' || !hasManagerLocation) {
          batch.update(doc.reference, {
            'assignedLocationLat': FieldValue.delete(),
            'assignedLocationLng': FieldValue.delete(),
            'assignedLocationRadius': FieldValue.delete(),
            'locationAssignedBy': FieldValue.delete(),
            'assignedQrSecret': FieldValue.delete(),
            'assignedQrRotateIntervalSeconds': FieldValue.delete(),
            'assignedAllowRemoteClockIn': FieldValue.delete(),
            'assignedCompanyName': FieldValue.delete(),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr('errorSavingSettings')}: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    final showAdminApiSettings = currentUser?.isAdmin == true;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.tr('systemSettings'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('systemSettings')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
          ),
        ],
      ),
      body: WebLayout(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business, color: Colors.blue),
                        const SizedBox(width: 10),
                        Text(
                          ref.tr('companyDetails'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _companyController,
                      decoration: InputDecoration(
                        labelText: ref.tr('companyName'),
                        prefixIcon: const Icon(Icons.business_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ref.tr('geofenceLocation'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _useCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 16),
                          label: Text(ref.tr('setCurrentGps')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration:
                                InputDecoration(labelText: ref.tr('latitude')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration:
                                InputDecoration(labelText: ref.tr('longitude')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ref.tr('geofenceRadius'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Chip(
                          label: Text(
                            '${_radiusMeters.toInt()} ${ref.tr('radiusMeters')}',
                          ),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radiusMeters,
                      min: 50,
                      max: 5000,
                      divisions: 99,
                      label: '${_radiusMeters.toInt()} m',
                      onChanged: (val) => setState(() => _radiusMeters = val),
                    ),
                    SwitchListTile(
                      title: Text(ref.tr('allowRemoteClockIn')),
                      subtitle: Text(ref.tr('allowRemoteClockInSub')),
                      value: _allowRemoteClockIn,
                      onChanged: (val) =>
                          setState(() => _allowRemoteClockIn = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2, color: Colors.purple),
                        const SizedBox(width: 10),
                        Text(
                          ref.tr('qrSecurity'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _secretController,
                      decoration: InputDecoration(
                        labelText: ref.tr('hmacSecretKey'),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.autorenew),
                          tooltip: ref.tr('generateNewKey'),
                          onPressed: () {
                            setState(() {
                              _secretController.text =
                                  'sec_${const Uuid().v4().replaceAll('-', '')}';
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      initialValue: _rotationInterval,
                      decoration: InputDecoration(
                        labelText: ref.tr('qrRotationInterval'),
                      ),
                      items: [
                        DropdownMenuItem(value: 5, child: Text(ref.tr('qr5s'))),
                        DropdownMenuItem(
                          value: 10,
                          child: Text(ref.tr('qr10s')),
                        ),
                        DropdownMenuItem(
                          value: 15,
                          child: Text(ref.tr('qr15s')),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text(ref.tr('qr30s')),
                        ),
                        DropdownMenuItem(
                          value: 60,
                          child: Text(ref.tr('qr60s')),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _rotationInterval = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (showAdminApiSettings) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.api, color: Colors.orange),
                          const SizedBox(width: 10),
                          Text(
                            ref.tr('adminBackendApi'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ref.tr('adminApiDesc'),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _adminApiController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: ref.tr('adminApiBaseUrl'),
                          prefixIcon: const Icon(Icons.link),
                          hintText: 'https://your-backend.example.com',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSettings,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _saving ? ref.tr('saving') : ref.tr('saveConfiguration'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
