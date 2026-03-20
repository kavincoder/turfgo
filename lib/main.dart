import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load non-secret environment config.
  // IMPORTANT: .env must never contain secrets (Razorpay key secret, etc.).
  // Secrets belong in Cloud Functions environment variables only.
  // API keys that must be in the client (e.g. Maps) should be injected via
  // --dart-define at build time, not via this file.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional — no keys are required at runtime from this file.
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Firebase App Check ────────────────────────────────────────────────────
  // Ensures only the genuine app binary can make requests to Firebase services.
  // In debug/emulator builds we use the debug provider so development still
  // works. In release builds we use Play Integrity (Android) and DeviceCheck
  // (iOS) — both require the app to be a signed, unmodified binary.
  //
  // IMPORTANT: after enabling App Check here you must also enforce it in the
  // Firebase Console (App Check → your app → Enforce) so that requests without
  // a valid token are rejected by Firebase itself.
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  // ── Local emulator (debug only) ───────────────────────────────────────────
  // In debug mode, point all Firebase services at the local emulator suite.
  // This lets you test Cloud Functions, Firestore, and Auth without hitting
  // the real Firebase project — and without needing Blaze plan deployed.
  //
  // Start the emulator with: firebase emulators:start
  // Emulator UI at: http://localhost:4000
  if (kDebugMode) {
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }

  // Skip reCAPTCHA on simulator/debug (needed for test phone numbers)
  if (kDebugMode) {
    await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  }

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: TurfGoApp()));
}

class TurfGoApp extends ConsumerWidget {
  const TurfGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 16 Pro
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'TurfGo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: router,
        );
      },
    );
  }
}
