// Shared test turf data used across Home and Explore screens.
// Will be replaced with real Firestore data in Phase 2.

class TurfData {
  final String name;
  final String area;
  final double distanceKm;
  final double rating;
  final double pricePerHour;
  final List<String> sports;
  final String imageUrl;
  final List<String> amenities;

  TurfData({
    required this.name,
    required this.area,
    required this.distanceKm,
    required this.rating,
    required this.pricePerHour,
    required this.sports,
    required this.imageUrl,
    required this.amenities,
  });
}

final testTurfs = [
  TurfData(
    name: 'Green Valley Sports Arena',
    area: 'Downtown',
    distanceKm: 2.3,
    rating: 4.8,
    pricePerHour: 1500,
    sports: ['Football', 'Cricket'],
    imageUrl: 'https://picsum.photos/seed/sportsfield1/600/400',
    amenities: ['Parking', 'Floodlights', 'Changing Room', 'Drinking Water', 'First Aid'],
  ),
  TurfData(
    name: 'City Cricket Ground',
    area: 'Midtown',
    distanceKm: 3.7,
    rating: 4.6,
    pricePerHour: 1200,
    sports: ['Cricket'],
    imageUrl: 'https://picsum.photos/seed/cricketground2/600/400',
    amenities: ['Parking', 'Floodlights', 'Drinking Water'],
  ),
  TurfData(
    name: 'Premier Football Club',
    area: 'West Side',
    distanceKm: 1.8,
    rating: 4.5,
    pricePerHour: 1800,
    sports: ['Football'],
    imageUrl: 'https://picsum.photos/seed/football99/600/400',
    amenities: ['Parking', 'Floodlights', 'Changing Room', 'Cafeteria', 'First Aid'],
  ),
  TurfData(
    name: 'Ace Badminton Arena',
    area: 'East End',
    distanceKm: 4.2,
    rating: 4.3,
    pricePerHour: 800,
    sports: ['Badminton', 'Tennis'],
    imageUrl: 'https://picsum.photos/seed/badminton55/600/400',
    amenities: ['Parking', 'Changing Room', 'Drinking Water'],
  ),
];
