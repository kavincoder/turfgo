import 'package:cloud_firestore/cloud_firestore.dart';

class Turf {
  final String id;
  final String name;
  final List<String> sports;
  final double pricePerHour;
  final String ownerId;
  final String cityId;
  final List<String> photos;
  final GeoPoint? location;
  final String area;
  final String address;
  final bool isActive;
  final double rating;
  final List<String> amenities;
  final String openTime; // e.g. '06:00'
  final String closeTime; // e.g. '22:00'

  const Turf({
    required this.id,
    required this.name,
    required this.sports,
    required this.pricePerHour,
    required this.ownerId,
    required this.cityId,
    required this.photos,
    this.location,
    required this.area,
    required this.address,
    required this.isActive,
    required this.rating,
    required this.amenities,
    required this.openTime,
    required this.closeTime,
  });

  factory Turf.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Turf(
      id: doc.id,
      name: data['name'] ?? '',
      sports: List<String>.from(data['sports'] ?? []),
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      ownerId: data['ownerId'] ?? '',
      cityId: data['cityId'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      location: data['location'] as GeoPoint?,
      area: data['area'] ?? '',
      address: data['address'] ?? '',
      isActive: data['isActive'] ?? false,
      rating: (data['rating'] ?? 0).toDouble(),
      amenities: List<String>.from(data['amenities'] ?? []),
      openTime: data['openTime'] ?? '06:00',
      closeTime: data['closeTime'] ?? '22:00',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'sports': sports,
        'pricePerHour': pricePerHour,
        'ownerId': ownerId,
        'cityId': cityId,
        'photos': photos,
        'location': location,
        'area': area,
        'address': address,
        'isActive': isActive,
        'rating': rating,
        'amenities': amenities,
        'openTime': openTime,
        'closeTime': closeTime,
      };
}
