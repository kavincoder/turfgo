import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/owner_login_screen.dart';
import '../models/slot.dart';
import '../models/turf.dart';
import '../screens/admin/admin_bookings_detail_screen.dart';
import '../screens/admin/admin_revenue_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/admin_turfs_detail_screen.dart';
import '../screens/booking_confirmation/booking_confirmation_screen.dart';
import '../screens/booking_success/booking_success_screen.dart';
import '../screens/owner/owner_turf_edit_screen.dart';
import '../screens/slot_selection/slot_selection_screen.dart';
import '../screens/turf_detail/turf_detail_screen.dart';
import '../screens/owner/owner_shell.dart';
import '../screens/shell/main_shell.dart';
import '../screens/splash/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OtpScreen(
            verificationId: extra['verificationId'] as String,
            phone: extra['phone'] as String,
            resendToken: extra['resendToken'] as int?,
          );
        },
      ),
      GoRoute(
        path: '/owner-login',
        builder: (context, state) => const OwnerLoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerShell(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminShell(),
      ),
      GoRoute(
        path: '/admin/bookings',
        builder: (context, state) => const AdminBookingsDetailScreen(),
      ),
      GoRoute(
        path: '/admin/revenue',
        builder: (context, state) => const AdminRevenueScreen(),
      ),
      GoRoute(
        path: '/admin/turfs',
        builder: (context, state) => const AdminTurfsDetailScreen(),
      ),
      GoRoute(
        path: '/owner/turf-edit',
        builder: (context, state) =>
            OwnerTurfEditScreen(turf: state.extra as Turf),
      ),
      GoRoute(
        path: '/turf-detail',
        builder: (context, state) =>
            TurfDetailScreen(turf: state.extra as Turf),
      ),
      GoRoute(
        path: '/slot-selection',
        builder: (context, state) =>
            SlotSelectionScreen(turf: state.extra as Turf),
      ),
      GoRoute(
        path: '/booking-confirmation',
        builder: (context, state) {
          final e = state.extra as Map<String, dynamic>;
          return BookingConfirmationScreen(
            turf: e['turf'] as Turf,
            selectedSlots: (e['selectedSlots'] as List).cast<Slot>(),
            selectedDate: e['selectedDate'] as DateTime,
            slotLabel: e['slotLabel'] as String,
            duration: e['duration'] as int,
            sport: e['sport'] as String,
          );
        },
      ),
      GoRoute(
        path: '/booking-success',
        builder: (context, state) {
          final e = state.extra as Map<String, dynamic>;
          return BookingSuccessScreen(
            turfName: e['turfName'] as String,
            slotLabel: e['slotLabel'] as String,
            selectedDate: e['selectedDate'] as DateTime,
            totalPaid: e['totalPaid'] as int,
            bookingId: e['bookingId'] as String,
          );
        },
      ),
    ],
  );
});
