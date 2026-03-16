import 'package:cloud_firestore/cloud_firestore.dart';

class City {
  final String id;
  final String name;
  final String state;
  final String status; // 'live' or 'coming_soon'

  const City({
    required this.id,
    required this.name,
    required this.state,
    required this.status,
  });

  bool get isLive => status == 'live';

  factory City.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return City(
      id: doc.id,
      name: data['name'] ?? '',
      state: data['state'] ?? '',
      status: data['status'] ?? 'coming_soon',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'state': state,
        'status': status,
      };
}
