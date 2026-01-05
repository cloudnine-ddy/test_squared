/// User model representing a user profile from Supabase
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String role;
  final String subscriptionTier;
  final DateTime? premiumUntil;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.role = 'student',
    this.subscriptionTier = 'free',
    this.premiumUntil,
    this.createdAt,
  });

  /// Check if user has active premium access
  /// Returns true if:
  /// 1. User is an admin (always has premium features)
  /// 2. User has 'premium' or 'lifetime' tier AND not expired
  bool get isPremium {
    // Admin users always have premium access
    if (role.toLowerCase() == 'admin') {
      return true;
    }

    // Free tier users don't have premium
    if (subscriptionTier == 'free') {
      return false;
    }

    // Lifetime tier always has premium
    if (subscriptionTier == 'lifetime') {
      return true;
    }

    // For premium tier, check expiry
    if (subscriptionTier == 'premium') {
      // If premiumUntil is null, treat as lifetime
      if (premiumUntil == null) {
        return true;
      }
      
      // Check if not expired
      return premiumUntil!.isAfter(DateTime.now());
    }

    // Default to false for unknown tiers or null subscriptionTier
    return false;
  }

  /// Get a display-friendly subscription status
  String get subscriptionStatus {
    if (role == 'admin') {
      return 'Admin';
    }
    
    switch (subscriptionTier) {
      case 'lifetime':
        return 'Premium (Lifetime)';
      case 'premium':
        if (premiumUntil == null) {
          return 'Premium';
        }
        final daysLeft = premiumUntil!.difference(DateTime.now()).inDays;
        if (daysLeft > 0) {
          return 'Premium ($daysLeft days left)';
        }
        return 'Expired';
      case 'free':
      default:
        return 'Free';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      role: json['role'] as String? ?? 'student',
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      premiumUntil: json['premium_until'] != null
          ? DateTime.parse(json['premium_until'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'subscription_tier': subscriptionTier,
      'premium_until': premiumUntil?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? role,
    String? subscriptionTier,
    DateTime? premiumUntil,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
