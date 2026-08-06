import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/company_settings.dart';
import '../../../core/widgets/web_layout.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _companyController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _secretController;
  late TextEditingController _adminApiController;

  double _radiusMeters = 500;
  int _rotationInterval = 15;
  bool _allowRemoteClockIn = false;

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _secretController = TextEditingController();
    _adminApiController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _secretController.dispose();
    _adminApiController.dispose();
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

      _companyController.text = settings.companyName;
      _latController.text = settings.latitude.toString();
      _lngController.text = settings.longitude.toString();
      _secretController.text = settings.qrSecret;
      _adminApiController.text = settings.adminApiBaseUrl;
      _radiusMeters = settings.radiusMeters;
      _rotationInterval = settings.qrRotateIntervalSeconds;
      _allowRemoteClockIn = settings.allowRemoteClockIn;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
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
            const SnackBar(content: Text('Location services are disabled on device')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _latController.text = pos.latitude.toString();
          _lngController.text = pos.longitude.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Captured current GPS position as HQ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final companyName = _companyController.text.trim();
    final secret = _secretController.text.trim();

    if (lat == null || lng == null || companyName.isEmpty || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid coordinates, company name, and secret key')),
      );
      return;
    }

    setState(() => _saving = true);
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
      );

      await _db.collection('settings').doc('company').set(updated.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System Settings updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('System Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
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
                  const Row(
                    children: [
                      Icon(Icons.business, color: Colors.blue),
                      SizedBox(width: 10),
                      Text(
                        'Company Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company / Location Name',
                      prefixIcon: Icon(Icons.business_outlined),
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
                      const Icon(Icons.location_on_outlined, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Geofence & Location Limits',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('Set Current GPS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Latitude'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Longitude'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Geofence Radius:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text('${_radiusMeters.toInt()} meters'),
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
                    title: const Text('Allow Remote Clock-In'),
                    subtitle: const Text('Bypass geofence restriction for remote work'),
                    value: _allowRemoteClockIn,
                    onChanged: (val) => setState(() => _allowRemoteClockIn = val),
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
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2, color: Colors.purple),
                      SizedBox(width: 10),
                      Text(
                        'QR & Anti-Spoofing Security',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _secretController,
                    decoration: InputDecoration(
                      labelText: 'HMAC Secret Key',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.autorenew),
                        tooltip: 'Generate New Key',
                        onPressed: () {
                          setState(() {
                            _secretController.text = 'sec_${const Uuid().v4().replaceAll('-', '')}';
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    initialValue: _rotationInterval,
                    decoration: const InputDecoration(labelText: 'QR Rotation Interval'),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 Seconds (High Security)')),
                      DropdownMenuItem(value: 10, child: Text('10 Seconds')),
                      DropdownMenuItem(value: 15, child: Text('15 Seconds (Recommended)')),
                      DropdownMenuItem(value: 30, child: Text('30 Seconds')),
                      DropdownMenuItem(value: 60, child: Text('60 Seconds')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _rotationInterval = val);
                    },
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
                  const Row(
                    children: [
                      Icon(Icons.api, color: Colors.orange),
                      SizedBox(width: 10),
                      Text(
                        'Admin Backend API',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Required for creating and deleting user accounts. '
                    'Example: https://your-backend.example.com',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _adminApiController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Admin API Base URL',
                      prefixIcon: Icon(Icons.link),
                      hintText: 'https://your-backend.example.com',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveSettings,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Save Configuration'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
