class CompanySettings {
  const CompanySettings({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.qrSecret,
    this.qrRotateIntervalSeconds = 15,
    this.companyName = 'Chez Le Pointage HQ',
    this.allowRemoteClockIn = false,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String qrSecret;
  final int qrRotateIntervalSeconds;
  final String companyName;
  final bool allowRemoteClockIn;

  static const CompanySettings defaultSettings = CompanySettings(
    latitude: 37.4219983,
    longitude: -122.0840000,
    radiusMeters: 500,
    qrSecret: 'pointage_secure_secret_2026_key',
    qrRotateIntervalSeconds: 15,
    companyName: 'Chez Le Pointage HQ',
    allowRemoteClockIn: false,
  );

  factory CompanySettings.fromJson(Map<String, dynamic> json) =>
      CompanySettings(
        latitude: (json['latitude'] as num? ?? defaultSettings.latitude).toDouble(),
        longitude: (json['longitude'] as num? ?? defaultSettings.longitude).toDouble(),
        radiusMeters: (json['radiusMeters'] as num? ?? defaultSettings.radiusMeters).toDouble(),
        qrSecret: json['qrSecret'] as String? ?? defaultSettings.qrSecret,
        qrRotateIntervalSeconds:
            (json['qrRotateIntervalSeconds'] as num? ?? defaultSettings.qrRotateIntervalSeconds).toInt(),
        companyName: json['companyName'] as String? ?? defaultSettings.companyName,
        allowRemoteClockIn: json['allowRemoteClockIn'] as bool? ?? defaultSettings.allowRemoteClockIn,
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'qrSecret': qrSecret,
        'qrRotateIntervalSeconds': qrRotateIntervalSeconds,
        'companyName': companyName,
        'allowRemoteClockIn': allowRemoteClockIn,
      };

  CompanySettings copyWith({
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? qrSecret,
    int? qrRotateIntervalSeconds,
    String? companyName,
    bool? allowRemoteClockIn,
  }) {
    return CompanySettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      qrSecret: qrSecret ?? this.qrSecret,
      qrRotateIntervalSeconds: qrRotateIntervalSeconds ?? this.qrRotateIntervalSeconds,
      companyName: companyName ?? this.companyName,
      allowRemoteClockIn: allowRemoteClockIn ?? this.allowRemoteClockIn,
    );
  }
}
