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
    );
  }

  static String _stringOrDefault(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static String? _nullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }
}
