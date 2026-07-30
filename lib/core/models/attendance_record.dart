class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.time,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracy,
    required this.deviceModel,
    required this.operatingSystem,
    required this.batteryLevel,
    required this.internetStatus,
    required this.deviceId,
  });
  final String id,
      employeeId,
      employeeName,
      status,
      deviceModel,
      operatingSystem,
      internetStatus,
      deviceId;
  final DateTime date, time;
  final double latitude, longitude, locationAccuracy;
  final int batteryLevel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'date': date.toIso8601String().substring(0, 10),
        'time': time.toIso8601String(),
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'locationAccuracy': locationAccuracy,
        'deviceModel': deviceModel,
        'operatingSystem': operatingSystem,
        'batteryLevel': batteryLevel,
        'internetStatus': internetStatus,
        'deviceId': deviceId,
      };
}
