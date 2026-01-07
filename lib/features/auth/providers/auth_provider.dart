import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Provider for the Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider that listens to authentication state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange.map((data) => data.session?.user);
});

/// Provider that fetches the current user's profile with subscription info
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  
  if (authState == null) {
    return null;
  }

  try {
    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase
        .from('profiles')
        .select('id, email, role, subscription_tier, premium_until, created_at, free_checks_remaining')
        .eq('id', authState.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserModel.fromJson(response);
  } catch (e) {
    print('Error fetching user profile: $e');
    return null;
  }
});

/// Provider to check if current user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value != null;
});

/// Provider to check if current user has premium access
final isPremiumProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  
  return user.when(
    data: (userData) => userData?.isPremium ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider to get remaining free checks for non-premium users
final freeChecksRemainingProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  
  return user.when(
    data: (userData) => userData?.freeChecksRemaining ?? 5,
    loading: () => 5,
    error: (_, __) => 5,
  );
});

/// Provider to check if user can use check answer feature
/// Returns true if user is premium OR has remaining free checks
final canUseCheckAnswerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  
  return user.when(
    data: (userData) => userData?.canUseCheckAnswer ?? true,
    loading: () => true,
    error: (_, __) => true,
  );
});

/// Function to decrement free checks in database
Future<void> decrementFreeChecks(String userId) async {
  try {
    await Supabase.instance.client.rpc('decrement_free_checks', params: {
      'user_id': userId,
    });
  } catch (e) {
    print('Error decrementing free checks: $e');
  }
}
