import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Sign up with email, password, and full name
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
      },
    );
  }

  // Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with Google
  Future<dynamic> signInWithGoogle() async {
    try {
      // WEB: Use Supabase Standard OAuth (Redirect Flow)
      // This is more reliable for Web than the google_sign_in plugin
      if (kIsWeb) {
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:3000',
        );
        return true; // Return true to indicate flow started (redirect will happen)
      }

      // MOBILE: Use Native Google Sign-In (Native UX)
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // serverClientId required for Android/iOS to get valid ID tokens for Supabase
        serverClientId: '150972045192-npc4js9lhnngl46s8fkkegbt8m58eapk.apps.googleusercontent.com',
        scopes: ['email', 'profile', 'openid'],
      );

      // Force sign out first to clear any stale state
      try {
        await googleSignIn.signOut();
      } catch (error) {
        // Ignore errors here
      }

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      // User cancelled the sign-in
      if (googleUser == null) {
        return null;
      }

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      // Validate tokens
      if (idToken == null) {
        throw Exception('No ID Token found');
      }

      // Sign in to Supabase with Google tokens
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response;
    } on Exception catch (e) {
      // Re-throw for UI to handle
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Sign out from Google as well
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (e) {
      // Ignore Google sign-out errors
    }
    
    await _supabase.auth.signOut();
  }

  // Send password reset email
  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      // Redirect to root - the app will detect recovery session and navigate to reset-password
      redirectTo: 'http://localhost:3000/',
    );
  }

  // Update user password (after recovery)
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}

