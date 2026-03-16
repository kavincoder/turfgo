// Seed entry point — run with:
//   flutter run --target lib/seed_main.dart
// Wipes and re-seeds cities, turfs, and slots in Firestore.
// NEVER run against production data.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SeedApp());
}

class SeedApp extends StatelessWidget {
  const SeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C96A)),
        useMaterial3: true,
      ),
      home: const SeedScreen(),
    );
  }
}

class SeedScreen extends StatefulWidget {
  const SeedScreen({super.key});

  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  String _status = 'Ready to seed Firestore.';
  bool _seeding = false;

  Future<void> _runSeed() async {
    setState(() {
      _seeding = true;
      _status = 'Seeding…';
    });
    try {
      await _SeedService().seed(onProgress: (msg) {
        setState(() => _status = msg);
      });
      setState(() {
        _status = '✅ Done! Firestore is seeded.';
        _seeding = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _seeding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'TurfGo Seed Tool',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '⚠️  Dev only. Do not run on prod.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 40),
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _seeding ? null : _runSeed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C96A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                ),
                child: _seeding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Seed Firestore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seed data
// ---------------------------------------------------------------------------

class _SeedService {
  final _db = FirebaseFirestore.instance;

  // 3 Madurai turf owners (placeholder UIDs — update with real owner UIDs later)
  static const _ownerUid = 'seed_owner_001';

  // Turf definitions
  static final _turfs = [
    {
      'id': 'turf_kg_arena',
      'name': 'KG Turf Arena',
      'sports': ['Football', 'Cricket'],
      'pricePerHour': 800.0,
      'ownerId': _ownerUid,
      'cityId': 'city_madurai',
      'photos': [
        'https://picsum.photos/seed/turf_kg1/600/400',
        'https://picsum.photos/seed/turf_kg2/600/400',
      ],
      'location': const GeoPoint(9.9252, 78.1198),
      'area': 'Kochadai',
      'address': '14, Kochadai Main Road, Madurai - 625016',
      'isActive': true,
      'rating': 4.7,
      'amenities': [
        'Floodlights',
        'Parking',
        'Changing Room',
        'Drinking Water',
        'First Aid',
      ],
      'openTime': '06:00',
      'closeTime': '22:00',
    },
    {
      'id': 'turf_madurai_sports_hub',
      'name': 'Madurai Sports Hub',
      'sports': ['Football', 'Badminton'],
      'pricePerHour': 600.0,
      'ownerId': _ownerUid,
      'cityId': 'city_madurai',
      'photos': [
        'https://picsum.photos/seed/turf_msh1/600/400',
        'https://picsum.photos/seed/turf_msh2/600/400',
      ],
      'location': const GeoPoint(9.9312, 78.1145),
      'area': 'Anna Nagar',
      'address': '7, Anna Nagar 3rd Street, Madurai - 625020',
      'isActive': true,
      'rating': 4.5,
      'amenities': [
        'Floodlights',
        'Parking',
        'Drinking Water',
      ],
      'openTime': '05:00',
      'closeTime': '23:00',
    },
    {
      'id': 'turf_ace_badminton',
      'name': 'Ace Badminton Club',
      'sports': ['Badminton'],
      'pricePerHour': 400.0,
      'ownerId': _ownerUid,
      'cityId': 'city_madurai',
      'photos': [
        'https://picsum.photos/seed/turf_ace1/600/400',
        'https://picsum.photos/seed/turf_ace2/600/400',
      ],
      'location': const GeoPoint(9.9180, 78.1350),
      'area': 'KK Nagar',
      'address': '22, KK Nagar East, Madurai - 625020',
      'isActive': true,
      'rating': 4.3,
      'amenities': [
        'Parking',
        'Changing Room',
        'Drinking Water',
      ],
      'openTime': '06:00',
      'closeTime': '21:00',
    },
  ];

  Future<void> seed({required void Function(String) onProgress}) async {
    onProgress('Seeding cities…');
    await _seedCities();

    onProgress('Seeding turfs…');
    await _seedTurfs();

    onProgress('Seeding slots (7 days)…');
    await _seedSlots();
  }

  Future<void> _seedCities() async {
    final cities = [
      {
        'id': 'city_madurai',
        'name': 'Madurai',
        'state': 'Tamil Nadu',
        'status': 'live',
      },
      {
        'id': 'city_chennai',
        'name': 'Chennai',
        'state': 'Tamil Nadu',
        'status': 'coming_soon',
      },
      {
        'id': 'city_coimbatore',
        'name': 'Coimbatore',
        'state': 'Tamil Nadu',
        'status': 'coming_soon',
      },
    ];

    final batch = _db.batch();
    for (final city in cities) {
      final id = city['id'] as String;
      final data = Map<String, dynamic>.from(city)..remove('id');
      batch.set(_db.collection('cities').doc(id), data);
    }
    await batch.commit();
  }

  Future<void> _seedTurfs() async {
    final batch = _db.batch();
    for (final turf in _turfs) {
      final id = turf['id'] as String;
      final data = Map<String, dynamic>.from(turf)..remove('id');
      batch.set(_db.collection('turfs').doc(id), data);
    }
    await batch.commit();
  }

  Future<void> _seedSlots() async {
    final today = DateTime.now();

    for (final turf in _turfs) {
      final turfId = turf['id'] as String;
      final sports = turf['sports'] as List<String>;
      final price = turf['pricePerHour'] as double;
      final openHour = _parseHour(turf['openTime'] as String);
      final closeHour = _parseHour(turf['closeTime'] as String);

      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final date = today.add(Duration(days: dayOffset));
        final dateStr = _formatDate(date);

        // Delete existing slots for this turf+date range first
        // (skip on seed — assume clean DB or idempotent sets)

        final batch = _db.batch();

        for (final sport in sports) {
          for (int hour = openHour; hour < closeHour; hour++) {
            final start = _formatTime(hour);
            final end = _formatTime(hour + 1);
            final slotId = '${dateStr}_${start.replaceAll(':', '-')}_$sport';

            // Make a few slots appear booked for realism
            final isBooked = dayOffset == 0 &&
                (hour == openHour + 2 || hour == openHour + 3);

            final slotData = {
              'date': dateStr,
              'startTime': start,
              'endTime': end,
              'sport': sport,
              'price': price,
              'isBooked': isBooked,
              'bookingId': null,
              'lockedUntil': null,
              'lockedBy': null,
            };

            batch.set(
              _db
                  .collection('turfs')
                  .doc(turfId)
                  .collection('slots')
                  .doc(slotId),
              slotData,
            );
          }
        }

        await batch.commit();
      }
    }
  }

  int _parseHour(String time) => int.parse(time.split(':')[0]);

  String _formatTime(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00';

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
