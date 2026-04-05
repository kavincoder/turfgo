import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Duration timeout,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    // Check rate limit server-side before triggering Firebase Auth OTP.
    // Skipped in debug mode (simulator/testing) — CF may not be deployed yet.
    // In release builds this is enforced; resource-exhausted blocks the request.
    if (!kDebugMode) {
      await FirebaseFunctions.instance
          .httpsCallable('checkOtpRateLimit')
          .call({'phone': phoneNumber});
    }

    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );
  }

  Future<UserCredential> signInWithCredential(
      PhoneAuthCredential credential) async {
    final userCred = await _auth.signInWithCredential(credential);
    await _createUserDocIfNeeded(userCred.user!);
    return userCred;
  }

  Future<void> _createUserDocIfNeeded(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _firestore.collection('users').doc(user.uid).set({
        'name': '',
        'phone': user.phoneNumber ?? '',
        'cityId': '',
        'role': 'player',
        'referralCode': null,
        'referredBy': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> ensureUserDoc(User user) => _createUserDocIfNeeded(user);

  Future<void> signInWithEmailPassword(
      String username, String password) async {
    final email = '$username@turfgo.in';
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    // No _createUserDocIfNeeded — owner docs are created manually by Kavin.
  }

  Future<void> signOut() => _auth.signOut();
}
