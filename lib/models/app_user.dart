import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String phone;
  final String cityId;
  final String role; // 'player', 'owner', 'admin'
  final String? referralCode;
  final String? referredBy;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.cityId,
    required this.role,
    this.referralCode,
    this.referredBy,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      cityId: data['cityId'] ?? '',
      role: (data['role'] as String?)?.trim() ?? 'player',
      referralCode: data['referralCode'],
      referredBy: data['referredBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'cityId': cityId,
        'role': role,
        'referralCode': referralCode,
        'referredBy': referredBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
