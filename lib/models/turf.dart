import 'package:cloud_firestore/cloud_firestore.dart';

/// A single coaching block: X courts reserved for a sport from [fromHour] to [toHour].
class CoachingBlock {
  final String sport;
  final int fromHour; // inclusive  e.g. 18 = 6 PM
  final int toHour;   // exclusive  e.g. 21 = last reserved slot starts at 20:00
  final int courts;   // number of courts held for coaching

  const CoachingBlock({
    required this.sport,
    required this.fromHour,
    required this.toHour,
    required this.courts,
  });

  factory CoachingBlock.fromMap(Map<String, dynamic> map) => CoachingBlock(
        sport: map['sport'] as String? ?? '',
        fromHour: (map['fromHour'] as num?)?.toInt() ?? 0,
        toHour: (map['toHour'] as num?)?.toInt() ?? 0,
        courts: (map['courts'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'sport': sport,
        'fromHour': fromHour,
        'toHour': toHour,
        'courts': courts,
      };
}

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

  /// Total courts available per sport. e.g. {'Badminton': 5, 'Football': 1}
  /// Defaults to 1 for any sport not listed (backward compat).
  final Map<String, int> courtCounts;

  /// Recurring coaching reservations. Applied automatically at slot-seed time.
  final List<CoachingBlock> coachingSchedule;

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
    this.courtCounts = const {},
    this.coachingSchedule = const [],
  });

  /// Returns the court count for a given sport (defaults to 1).
  int courtCountForSport(String sport) => courtCounts[sport] ?? 1;

  factory Turf.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // courtCounts: Map<String, int>
    final rawCounts = data['courtCounts'];
    final Map<String, int> courtCounts;
    if (rawCounts is Map) {
      courtCounts =
          rawCounts.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } else {
      courtCounts = {};
    }

    // coachingSchedule: List<Map>
    final rawSchedule = data['coachingSchedule'];
    final List<CoachingBlock> coachingSchedule;
    if (rawSchedule is List) {
      coachingSchedule = rawSchedule
          .whereType<Map<String, dynamic>>()
          .map(CoachingBlock.fromMap)
          .toList();
    } else {
      coachingSchedule = [];
    }

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
      courtCounts: courtCounts,
      coachingSchedule: coachingSchedule,
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
        'courtCounts': courtCounts,
        'coachingSchedule': coachingSchedule.map((b) => b.toMap()).toList(),
      };
}
