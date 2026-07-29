class CompanySettings {
  const CompanySettings({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.qrSecret,
  });
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String qrSecret;

  factory CompanySettings.fromJson(Map<String, dynamic> json) =>
      CompanySettings(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters: (json['radiusMeters'] as num? ?? 100).toDouble(),
        qrSecret: json['qrSecret'] as String,
      );
}
