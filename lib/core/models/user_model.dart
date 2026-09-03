class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.status = 'active',
    this.department = 'General',
    this.photoUrl,
    this.createdAt,
    this.lastLogin,
    this.createdBy,
    this.managerId,
    this.scheduleType = 'standard',
    this.isFirstLogin = false,
    this.assignedLocationLat,
    this.assignedLocationLng,
    this.assignedLocationRadius,
    this.locationAssignedBy,
    this.kioskPin,
    this.phoneNumber,
    this.boundDeviceId,
    this.activeDeviceIdHash,
    this.deviceBinding,
    this.assignedQrSecret,
    this.assignedQrRotateIntervalSeconds,
    this.assignedAllowRemoteClockIn,
    this.assignedCompanyName,
  });

  final String uid;
  final String email;
  final String displayName;
  final String role; // 'admin', 'manager', 'employee'
  final String status; // 'active', 'disabled'
  final String department;
  final String? photoUrl;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final String? createdBy;
  final String? managerId;
  final String scheduleType; // 'days_20_10', 'standard'
  final bool isFirstLogin;

  // Location override: set by a Manager (or Admin) to override the global geofence.
  // Priority: manager-specific > manager-default > admin global.
  final double? assignedLocationLat;
  final double? assignedLocationLng;
  final double? assignedLocationRadius;

  /// UID of the manager who assigned this location, or 'admin' if set by admin.
  final String? locationAssignedBy;

  final String? assignedQrSecret;
  final int? assignedQrRotateIntervalSeconds;
  final bool? assignedAllowRemoteClockIn;
  final String? assignedCompanyName;

  /// Optional PIN set by the manager/admin to exit presenter mode
  final String? kioskPin;

  /// Unique Device ID permanently bound to this worker account for attendance.
  final String? boundDeviceId;

  /// Cryptographic hash of the device credential for authorization.
  final String? activeDeviceIdHash;

  /// Metadata about the bound device (status, platform, etc.).
  final Map<String, dynamic>? deviceBinding;

  /// Returns true if this user has a custom location that was assigned by a manager.
  bool get hasManagerLocation =>
      locationAssignedBy != null &&
      locationAssignedBy != 'admin' &&
      assignedLocationLat != null &&
      assignedLocationLng != null;

  bool get isAdmin => role.trim().toLowerCase() == 'admin';
  bool get isManager => role.trim().toLowerCase() == 'manager';
  bool get isEmployee => role.trim().toLowerCase() == 'employee';
  bool get isAdminOrManager => isAdmin || isManager;
  bool get isActive => status.trim().toLowerCase() == 'active';

  factory UserModel.fromJson(Map<String, dynamic> json, String id) {
    return UserModel(
      uid: id,
      email: _stringOrDefault(json['email'], ''),
      displayName: _stringOrDefault(json['displayName'], 'Employee'),
      role: _stringOrDefault(json['role'], 'employee').trim().toLowerCase(),
      status: _stringOrDefault(json['status'], 'active').trim().toLowerCase(),
      department: _stringOrDefault(json['department'], 'General'),
      photoUrl: json['photoUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'] as String)
          : null,
      createdBy: _nullableString(json['createdBy']),
      managerId: _nullableString(json['managerId']),
      scheduleType: _stringOrDefault(json['scheduleType'], 'standard'),
      isFirstLogin: json['isFirstLogin'] as bool? ?? false,
      assignedLocationLat: (json['assignedLocationLat'] as num?)?.toDouble(),
      assignedLocationLng: (json['assignedLocationLng'] as num?)?.toDouble(),
      assignedLocationRadius:
          (json['assignedLocationRadius'] as num?)?.toDouble(),
      locationAssignedBy: _nullableString(json['locationAssignedBy']),
      kioskPin: _nullableString(json['kioskPin']),
      phoneNumber: _nullableString(json['phoneNumber']),
      boundDeviceId: _nullableString(json['boundDeviceId']),
      activeDeviceIdHash: _nullableString(json['activeDeviceIdHash']),
      deviceBinding: json['deviceBinding'] as Map<String, dynamic>?,
      assignedQrSecret: _nullableString(json['assignedQrSecret']),
      assignedQrRotateIntervalSeconds:
          json['assignedQrRotateIntervalSeconds'] as int?,
      assignedAllowRemoteClockIn: json['assignedAllowRemoteClockIn'] as bool?,
      assignedCompanyName: _nullableString(json['assignedCompanyName']),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role,
        'status': status,
        'department': department,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (lastLogin != null) 'lastLogin': lastLogin!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        if (managerId != null) 'managerId': managerId,
        'scheduleType': scheduleType,
        'isFirstLogin': isFirstLogin,
        if (assignedLocationLat != null)
          'assignedLocationLat': assignedLocationLat,
        if (assignedLocationLng != null)
          'assignedLocationLng': assignedLocationLng,
        if (assignedLocationRadius != null)
          'assignedLocationRadius': assignedLocationRadius,
        if (locationAssignedBy != null)
          'locationAssignedBy': locationAssignedBy,
        if (kioskPin != null) 'kioskPin': kioskPin,
        if (boundDeviceId != null) 'boundDeviceId': boundDeviceId,
        if (activeDeviceIdHash != null)
          'activeDeviceIdHash': activeDeviceIdHash,
        if (deviceBinding != null) 'deviceBinding': deviceBinding,
        if (assignedQrSecret != null) 'assignedQrSecret': assignedQrSecret,
        if (assignedQrRotateIntervalSeconds != null)
          'assignedQrRotateIntervalSeconds': assignedQrRotateIntervalSeconds,
        if (assignedAllowRemoteClockIn != null)
          'assignedAllowRemoteClockIn': assignedAllowRemoteClockIn,
        if (assignedCompanyName != null)
          'assignedCompanyName': assignedCompanyName,
      };

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    String? status,
    String? department,
    String? photoUrl,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? createdBy,
    String? managerId,
    String? scheduleType,
    bool? isFirstLogin,
    Object? assignedLocationLat = _sentinel,
    Object? assignedLocationLng = _sentinel,
    Object? assignedLocationRadius = _sentinel,
    Object? locationAssignedBy = _sentinel,
    Object? kioskPin = _sentinel,
    Object? boundDeviceId = _sentinel,
    Object? activeDeviceIdHash = _sentinel,
    Object? deviceBinding = _sentinel,
    Object? assignedQrSecret = _sentinel,
    Object? assignedQrRotateIntervalSeconds = _sentinel,
    Object? assignedAllowRemoteClockIn = _sentinel,
    Object? assignedCompanyName = _sentinel,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      status: status ?? this.status,
      department: department ?? this.department,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      createdBy: createdBy ?? this.createdBy,
      managerId: managerId ?? this.managerId,
      scheduleType: scheduleType ?? this.scheduleType,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      assignedLocationLat: assignedLocationLat == _sentinel
          ? this.assignedLocationLat
          : assignedLocationLat as double?,
      assignedLocationLng: assignedLocationLng == _sentinel
          ? this.assignedLocationLng
          : assignedLocationLng as double?,
      assignedLocationRadius: assignedLocationRadius == _sentinel
          ? this.assignedLocationRadius
          : assignedLocationRadius as double?,
      locationAssignedBy: locationAssignedBy == _sentinel
          ? this.locationAssignedBy
          : locationAssignedBy as String?,
      kioskPin: kioskPin == _sentinel ? this.kioskPin : kioskPin as String?,
      boundDeviceId: boundDeviceId == _sentinel
          ? this.boundDeviceId
          : boundDeviceId as String?,
      activeDeviceIdHash: activeDeviceIdHash == _sentinel
          ? this.activeDeviceIdHash
          : activeDeviceIdHash as String?,
      deviceBinding: deviceBinding == _sentinel
          ? this.deviceBinding
          : deviceBinding as Map<String, dynamic>?,
      assignedQrSecret: assignedQrSecret == _sentinel
          ? this.assignedQrSecret
          : assignedQrSecret as String?,
      assignedQrRotateIntervalSeconds:
          assignedQrRotateIntervalSeconds == _sentinel
              ? this.assignedQrRotateIntervalSeconds
              : assignedQrRotateIntervalSeconds as int?,
      assignedAllowRemoteClockIn: assignedAllowRemoteClockIn == _sentinel
          ? this.assignedAllowRemoteClockIn
          : assignedAllowRemoteClockIn as bool?,
      assignedCompanyName: assignedCompanyName == _sentinel
          ? this.assignedCompanyName
          : assignedCompanyName as String?,
    );
  }

  static const Object _sentinel = Object();

  static String _stringOrDefault(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static String? _nullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }
}
