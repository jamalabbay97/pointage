class CompanySettings {
  const CompanySettings({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.qrSecret,
    this.qrRotateIntervalSeconds = 15,
    this.companyName = 'Pointage HQ',
    this.allowRemoteClockIn = false,
    this.adminApiBaseUrl = '',
    this.mobileAppUrl = '',
    this.mobileAppVersion = 'v1.0.0',
    this.mobileAppNotes = '',
    this.mobileAppEnabled = true,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String qrSecret;
  final int qrRotateIntervalSeconds;
  final String companyName;
  final bool allowRemoteClockIn;
  final String adminApiBaseUrl;
  final String mobileAppUrl;
  final String mobileAppVersion;
  final String mobileAppNotes;
  final bool mobileAppEnabled;

  static const CompanySettings defaultSettings = CompanySettings(
    latitude: 37.4219983,
    longitude: -122.0840000,
    radiusMeters: 500,
    qrSecret: 'pointage_secure_secret_2026_key',
    qrRotateIntervalSeconds: 15,
    companyName: 'Pointage HQ',
    allowRemoteClockIn: false,
    mobileAppUrl: '',
    mobileAppVersion: 'v1.0.0',
    mobileAppNotes: '',
    mobileAppEnabled: true,
  );

  factory CompanySettings.fromJson(Map<String, dynamic> json) =>
      CompanySettings(
        latitude:
            (json['latitude'] as num? ?? defaultSettings.latitude).toDouble(),
        longitude:
            (json['longitude'] as num? ?? defaultSettings.longitude).toDouble(),
        radiusMeters:
            (json['radiusMeters'] as num? ?? defaultSettings.radiusMeters)
                .toDouble(),
        qrSecret: json['qrSecret'] as String? ?? defaultSettings.qrSecret,
        qrRotateIntervalSeconds: (json['qrRotateIntervalSeconds'] as num? ??
                defaultSettings.qrRotateIntervalSeconds)
            .toInt(),
        companyName:
            json['companyName'] as String? ?? defaultSettings.companyName,
        allowRemoteClockIn: json['allowRemoteClockIn'] as bool? ??
            defaultSettings.allowRemoteClockIn,
        adminApiBaseUrl: json['adminApiBaseUrl'] as String? ??
            defaultSettings.adminApiBaseUrl,
        mobileAppUrl:
            json['mobileAppUrl'] as String? ?? defaultSettings.mobileAppUrl,
        mobileAppVersion: json['mobileAppVersion'] as String? ??
            defaultSettings.mobileAppVersion,
        mobileAppNotes:
            json['mobileAppNotes'] as String? ?? defaultSettings.mobileAppNotes,
        mobileAppEnabled: json['mobileAppEnabled'] as bool? ??
            defaultSettings.mobileAppEnabled,
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'qrSecret': qrSecret,
        'qrRotateIntervalSeconds': qrRotateIntervalSeconds,
        'companyName': companyName,
        'allowRemoteClockIn': allowRemoteClockIn,
        if (adminApiBaseUrl.trim().isNotEmpty)
          'adminApiBaseUrl': adminApiBaseUrl.trim(),
        'mobileAppUrl': mobileAppUrl.trim(),
        'mobileAppVersion': mobileAppVersion.trim(),
        'mobileAppNotes': mobileAppNotes.trim(),
        'mobileAppEnabled': mobileAppEnabled,
      };

  CompanySettings copyWith({
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? qrSecret,
    int? qrRotateIntervalSeconds,
    String? companyName,
    bool? allowRemoteClockIn,
    String? adminApiBaseUrl,
    String? mobileAppUrl,
    String? mobileAppVersion,
    String? mobileAppNotes,
    bool? mobileAppEnabled,
  }) {
    return CompanySettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      qrSecret: qrSecret ?? this.qrSecret,
      qrRotateIntervalSeconds:
          qrRotateIntervalSeconds ?? this.qrRotateIntervalSeconds,
      companyName: companyName ?? this.companyName,
      allowRemoteClockIn: allowRemoteClockIn ?? this.allowRemoteClockIn,
      adminApiBaseUrl: adminApiBaseUrl ?? this.adminApiBaseUrl,
      mobileAppUrl: mobileAppUrl ?? this.mobileAppUrl,
      mobileAppVersion: mobileAppVersion ?? this.mobileAppVersion,
      mobileAppNotes: mobileAppNotes ?? this.mobileAppNotes,
      mobileAppEnabled: mobileAppEnabled ?? this.mobileAppEnabled,
    );
  }
}
