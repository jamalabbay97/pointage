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
  });

  final String uid;
  final String email;
  final String displayName;
  final String role; // 'admin', 'manager', 'employee'
  final String status; // 'active', 'disabled'
  final String department;
  final String? photoUrl;
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

  /// Optional PIN set by the manager/admin to exit presenter mode
  final String? kioskPin;

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
      };

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    String? status,
    String? department,
    String? photoUrl,
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
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      status: status ?? this.status,
      department: department ?? this.department,
      photoUrl: photoUrl ?? this.photoUrl,
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
