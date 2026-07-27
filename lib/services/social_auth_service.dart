import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SocialAuthStatus {
  success,
  accountNotFound,
  accountAlreadyExists,
  cancelled,
  error,
}

class SocialAuthResult {
  final SocialAuthStatus status;
  final String? role;
  final String? message;
  final User? user;

  const SocialAuthResult({
    required this.status,
    this.role,
    this.message,
    this.user,
  });
}

class SocialAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  SocialAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId:
                  '698772848965-9679lsp73spjnquk5t1rroghi4or4cre.apps.googleusercontent.com',
            );

  /// Handles Google Authentication.
  /// If [isSignUp] is false (Login Screen):
  ///   Checks if account exists in Firestore (`users/{uid}`). If NOT, signs out immediately and returns `accountNotFound`.
  /// If [isSignUp] is true (Signup Screen):
  ///   If account exists, logs user in and returns `accountAlreadyExists`.
  ///   If account does not exist, creates user doc in Firestore and returns `success`.
  Future<SocialAuthResult> signInWithGoogle({required bool isSignUp}) async {
    try {
      // 1. Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const SocialAuthResult(status: SocialAuthStatus.cancelled);
      }

      // 2. Obtain auth details from request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase Auth
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        return const SocialAuthResult(
          status: SocialAuthStatus.error,
          message: 'Failed to authenticate user with Google.',
        );
      }

      // 5. Verify Firestore account existence
      return await _processFirestoreAccount(
        user: user,
        isSignUp: isSignUp,
        fallbackName: googleUser.displayName ?? user.displayName ?? 'Google User',
        email: googleUser.email,
      );
    } on FirebaseAuthException catch (e) {
      return SocialAuthResult(
        status: SocialAuthStatus.error,
        message: e.message ?? 'Firebase Auth error during Google sign-in.',
      );
    } catch (e) {
      return SocialAuthResult(
        status: SocialAuthStatus.error,
        message: 'Google Sign-In failed: $e',
      );
    }
  }

  /// Handles Apple Authentication.
  Future<SocialAuthResult> signInWithApple({required bool isSignUp}) async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable && kIsWeb) {
        return const SocialAuthResult(
          status: SocialAuthStatus.error,
          message: 'Apple Sign-In is not supported on this device/platform.',
        );
      }

      // 1. Request Apple ID Credential
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2. Create Firebase OAuth Credential
      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
      );

      // 3. Sign in to Firebase Auth
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        return const SocialAuthResult(
          status: SocialAuthStatus.error,
          message: 'Failed to authenticate user with Apple.',
        );
      }

      String? appleName;
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        appleName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
      }

      // 4. Verify Firestore account existence
      return await _processFirestoreAccount(
        user: user,
        isSignUp: isSignUp,
        fallbackName: appleName ?? user.displayName ?? 'Apple User',
        email: appleCredential.email ?? user.email ?? '',
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const SocialAuthResult(status: SocialAuthStatus.cancelled);
      }
      return SocialAuthResult(
        status: SocialAuthStatus.error,
        message: e.message,
      );
    } on FirebaseAuthException catch (e) {
      return SocialAuthResult(
        status: SocialAuthStatus.error,
        message: e.message ?? 'Firebase Auth error during Apple sign-in.',
      );
    } catch (e) {
      return SocialAuthResult(
        status: SocialAuthStatus.error,
        message: 'Apple Sign-In failed: $e',
      );
    }
  }

  /// Processes Firestore account verification logic.
  Future<SocialAuthResult> _processFirestoreAccount({
    required User user,
    required bool isSignUp,
    required String fallbackName,
    required String email,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (isSignUp) {
      // User is on Sign Up screen
      if (docSnap.exists) {
        final role = docSnap.data()?['role'] ?? 'customer';
        return SocialAuthResult(
          status: SocialAuthStatus.accountAlreadyExists,
          role: role,
          user: user,
          message: 'Account already exists. Logging you in...',
        );
      } else {
        // Create new account in Firestore
        final userEmail = email.isNotEmpty ? email : (user.email ?? '');
        await docRef.set({
          'name': fallbackName.isNotEmpty ? fallbackName : 'User',
          'email': userEmail,
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return SocialAuthResult(
          status: SocialAuthStatus.success,
          role: 'customer',
          user: user,
        );
      }
    } else {
      // User is on Login screen
      if (!docSnap.exists) {
        // MUST CHECK FIRST: If account NOT signed up, user cannot sign in!
        // Sign out user immediately from Firebase Auth.
        await _auth.signOut();
        try {
          await _googleSignIn.signOut();
        } catch (_) {}

        return const SocialAuthResult(
          status: SocialAuthStatus.accountNotFound,
          message: 'Account does not exist! Please sign up first before signing in.',
        );
      } else {
        final role = docSnap.data()?['role'] ?? 'customer';
        return SocialAuthResult(
          status: SocialAuthStatus.success,
          role: role,
          user: user,
        );
      }
    }
  }
}
