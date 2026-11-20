import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';

// Pass --dart-define=USE_EMULATOR=true to connect to the local emulator.
// Normal `flutter run` always uses real Firebase — emulator is opt-in only.
const bool _kUseEmulator = bool.fromEnvironment('USE_EMULATOR');

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

  // ── Crashlytics ──────────────────────────────────────────────────────────
  // Route Flutter framework errors and async errors to Crashlytics.
  // Disabled in debug mode so we see full stack traces in the console instead.
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // ── Local Emulator (opt-in via --dart-define=USE_EMULATOR=true) ──────────
  // Uses localhost for iOS simulator / macOS.
  // For Android emulator change host to '10.0.2.2'.
  if (_kUseEmulator) {
    const host = 'localhost';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator(host, 5001);
    await FirebaseAuth.instance
        .setSettings(appVerificationDisabledForTesting: true);
    debugPrint('⚠️  EMULATOR MODE — connected to localhost');
  }

  // ── Firebase App Check ────────────────────────────────────────────────────
  // Ensures only the genuine app binary can make requests to Firebase services.
  // In debug/emulator builds we use the debug provider so development still
  // works. In release builds we use Play Integrity (Android) and DeviceCheck
  // (iOS) — both require the app to be a signed, unmodified binary.
  //
  // IMPORTANT: after enabling App Check here you must also enforce it in the
  // Firebase Console (App Check → your app → Enforce) so that requests without
  // a valid token are rejected by Firebase itself.
  // Web has no App Check provider configured (app ships on iOS/Android only);
  // activating without one throws, so skip it there.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
  }

  // Skip reCAPTCHA on simulator/debug (needed for test phone numbers)
  // NOTE: emulator routing is handled above by the USE_EMULATOR flag only.
  // Never route to emulator automatically in debug mode — that breaks real
  // device testing against production Firebase.

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
