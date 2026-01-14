import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/toast_service.dart';

/// User Management View - Search and manage student subscriptions
class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _users = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchError = null;
    });

    try {
      // Search by email (partial match)
      final response = await _supabase
          .from('profiles')
          .select('id, email, role, subscription_tier, premium_until, free_checks_remaining, created_at')
          .ilike('email', '%$query%')
          .limit(20);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserTier(String userId, String newTier, DateTime? premiumUntil) async {
    debugPrint('🔄 Updating user $userId to tier: $newTier, premiumUntil: $premiumUntil');
    
    try {
      // Build update payload
      final updateData = <String, dynamic>{
        'subscription_tier': newTier,
      };
      
      // Only set premium_until if premium tier, otherwise clear it
      if (newTier == 'premium' && premiumUntil != null) {
        updateData['premium_until'] = premiumUntil.toIso8601String();
      } else if (newTier != 'premium') {
        updateData['premium_until'] = null; // Clear for free/lifetime
      }
      
      debugPrint('📤 Update payload: $updateData');
      
      // Perform update
      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId);
      
      debugPrint('✅ Database update completed');
      ToastService.showSuccess('User updated successfully!');
      
      // Refresh search results to show changes
      await _searchUsers(_searchController.text);
    } catch (e, stack) {
      debugPrint('❌ Update failed: $e');
      debugPrint('Stack: $stack');
      ToastService.showError('Update failed: $e');
    }
  }

  void _showEditDialog(Map<String, dynamic> user) {
    String selectedTier = user['subscription_tier'] ?? 'free';
    DateTime? premiumUntil = user['premium_until'] != null 
        ? DateTime.tryParse(user['premium_until']) 
        : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Edit: ${user['email']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF37352F)),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subscription Tier', style: TextStyle(fontSize: 12, color: Color(0xFF787774))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedTier,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF7F6F3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('Free')),
                    DropdownMenuItem(value: 'premium', child: Text('Premium')),
                    DropdownMenuItem(value: 'lifetime', child: Text('Lifetime')),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      selectedTier = v ?? 'free';
                      // Auto-set premium_until for premium tier
                      if (selectedTier == 'premium' && premiumUntil == null) {
                        premiumUntil = DateTime.now().add(const Duration(days: 30));
                      }
                    });
                  },
                ),
                
                // Premium expiry date (only for premium tier)
                if (selectedTier == 'premium') ...[
                  const SizedBox(height: 16),
                  const Text('Premium Until', style: TextStyle(fontSize: 12, color: Color(0xFF787774))),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: premiumUntil ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setDialogState(() => premiumUntil = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F6F3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE9E9E7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF787774)),
                          const SizedBox(width: 8),
                          Text(
                            premiumUntil != null 
                                ? '${premiumUntil!.year}-${premiumUntil!.month.toString().padLeft(2, '0')}-${premiumUntil!.day.toString().padLeft(2, '0')}'
                                : 'Select date',
                            style: const TextStyle(color: Color(0xFF37352F)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Current info
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F6F3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User ID: ${user['id']}', style: const TextStyle(fontSize: 11, color: Color(0xFF787774))),
                      Text('Role: ${user['role'] ?? 'student'}', style: const TextStyle(fontSize: 11, color: Color(0xFF787774))),
                      Text('Free Checks: ${user['free_checks_remaining'] ?? 5}', style: const TextStyle(fontSize: 11, color: Color(0xFF787774))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateUserTier(
                  user['id'], 
                  selectedTier, 
                  selectedTier == 'premium' ? premiumUntil : null,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37352F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  String _getTierBadgeColor(String? tier) {
    switch (tier) {
      case 'premium':
        return '#F59E0B'; // Amber
      case 'lifetime':
        return '#10B981'; // Green
      default:
        return '#787774'; // Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F6F3),
              border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(
                    color: Color(0xFF37352F),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search for students and manage their subscription plans',
                  style: TextStyle(color: Color(0xFF787774), fontSize: 13),
                ),
                const SizedBox(height: 16),
                
                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by email...',
                          hintStyle: const TextStyle(color: Color(0xFF787774)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF787774)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF37352F)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: _searchUsers,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _searchUsers(_searchController.text),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF37352F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF37352F)))
                : _searchError != null
                    ? Center(
                        child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty 
                                      ? 'Enter an email address to search'
                                      : 'No users found',
                                  style: const TextStyle(color: Color(0xFF787774)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final tier = user['subscription_tier'] ?? 'free';
                              final premiumUntil = user['premium_until'] != null
                                  ? DateTime.tryParse(user['premium_until'])
                                  : null;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE9E9E7)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFF7F6F3),
                                    child: Text(
                                      (user['email'] as String? ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF37352F), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    user['email'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF37352F)),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Color(int.parse(_getTierBadgeColor(tier).replaceFirst('#', '0xFF'))).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tier.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(int.parse(_getTierBadgeColor(tier).replaceFirst('#', '0xFF'))),
                                          ),
                                        ),
                                      ),
                                      if (premiumUntil != null && tier == 'premium') ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'Expires: ${premiumUntil.year}-${premiumUntil.month.toString().padLeft(2, '0')}-${premiumUntil.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF787774)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _showEditDialog(user),
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    color: const Color(0xFF787774),
                                    tooltip: 'Edit User',
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
