import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;

  // Turf details
  final String turfName;
  final String area;
  final String address;
  final String cityId;
  final List<String> sports;
  final double pricePerHour;
  final String openTime;
  final String closeTime;
  final List<String> amenities;
  final List<String> photos; // Firebase Storage URLs

  // Request status
  final String status; // pending, approved, rejected
  final String? rejectionReason;
  final DateTime createdAt;

  const OwnerRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.turfName,
    required this.area,
    required this.address,
    required this.cityId,
    required this.sports,
    required this.pricePerHour,
    required this.openTime,
    required this.closeTime,
    required this.amenities,
    required this.photos,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  factory OwnerRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OwnerRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      turfName: data['turfName'] ?? '',
      area: data['area'] ?? '',
      address: data['address'] ?? '',
      cityId: data['cityId'] ?? '',
      sports: List<String>.from(data['sports'] ?? []),
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      openTime: data['openTime'] ?? '06:00',
      closeTime: data['closeTime'] ?? '22:00',
      amenities: List<String>.from(data['amenities'] ?? []),
      photos: List<String>.from(data['photos'] ?? []),
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'turfName': turfName,
        'area': area,
        'address': address,
        'cityId': cityId,
        'sports': sports,
        'pricePerHour': pricePerHour,
        'openTime': openTime,
        'closeTime': closeTime,
        'amenities': amenities,
        'photos': photos,
        'status': status,
        'rejectionReason': rejectionReason,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class RequestStatus {
  RequestStatus._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}
