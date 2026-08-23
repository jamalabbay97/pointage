import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type, // 'admin' | 'manager'
    required this.senderId,
    required this.createdAt,
    required this.readBy,
    required this.deletedBy,
    this.senderName, // null for admin (system) notifications
    this.targetManagerId, // null for admin broadcasts
    this.link,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String senderId;
  final String? senderName;
  final String? targetManagerId;
  final String? link;
  final DateTime createdAt;
  final List<String> readBy;
  final List<String> deletedBy;

  bool get isAdminType => type == 'admin';
  bool get isManagerType => type == 'manager';

  factory AppNotification.fromJson(Map<String, dynamic> json, String docId) {
    return AppNotification(
      id: docId,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'admin',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String?,
      targetManagerId: json['targetManagerId'] as String?,
      link: json['link'] as String?,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      readBy: List<String>.from(json['readBy'] as List? ?? []),
      deletedBy: List<String>.from(json['deletedBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'type': type,
        'senderId': senderId,
        if (senderName != null) 'senderName': senderName,
        if (targetManagerId != null) 'targetManagerId': targetManagerId,
        if (link != null) 'link': link,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': readBy,
        'deletedBy': deletedBy,
      };
}
