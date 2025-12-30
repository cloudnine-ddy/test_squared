import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bookmark_model.dart';
import '../../past_papers/models/question_model.dart';

class BookmarkRepository {
  final _supabase = Supabase.instance.client;

  /// Add a bookmark
  Future<void> addBookmark(
    String questionId, {
    String folder = 'My Bookmarks',
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase.from('user_bookmarks').insert({
      'user_id': userId,
      'question_id': questionId,
      'folder_name': folder,
    });
  }

  /// Remove a bookmark
  Future<void> removeBookmark(String questionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('user_bookmarks')
        .delete()
        .eq('user_id', userId)
        .eq('question_id', questionId);
  }

  /// Check if a question is bookmarked
  Future<bool> isBookmarked(String questionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await _supabase
        .from('user_bookmarks')
        .select('id')
        .eq('user_id', userId)
        .eq('question_id', questionId)
        .limit(1);

    return (data as List).isNotEmpty;
  }

  /// Get all bookmarks for current user
  Future<List<BookmarkModel>> getUserBookmarks({String? folder}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _supabase
        .from('user_bookmarks')
        .select()
        .eq('user_id', userId);

    if (folder != null) {
      query = query.eq('folder_name', folder);
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((json) => BookmarkModel.fromMap(json)).toList();
  }

  /// Get bookmarked questions with full question data
  Future<List<QuestionModel>> getBookmarkedQuestions({String? folder}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _supabase
        .from('user_bookmarks')
        .select('question_id, questions(*, papers(*))')
        .eq('user_id', userId);
    
    if (folder != null) {
      query = query.eq('folder_name', folder);
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List)
        .where((item) => item['questions'] != null)
        .map((item) => QuestionModel.fromMap(item['questions']))
        .toList();
  }

  /// Get all folder names for current user
  Future<List<String>> getFolders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _supabase
        .from('user_bookmarks')
        .select('folder_name')
        .eq('user_id', userId);

    final folders = (data as List)
        .map((row) => row['folder_name'] as String)
        .toSet()
        .toList();

    folders.sort();
    return folders;
  }

  /// Move bookmark to a different folder
  Future<void> moveToFolder(String questionId, String newFolder) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('user_bookmarks')
        .update({'folder_name': newFolder})
        .eq('user_id', userId)
        .eq('question_id', questionId);
  }

  /// Rename a folder (updates all bookmarks in that folder)
  Future<void> renameFolder(String oldName, String newName) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('user_bookmarks')
        .update({'folder_name': newName})
        .eq('user_id', userId)
        .eq('folder_name', oldName);
  }

  /// Delete a folder (removes all bookmarks in that folder)
  Future<void> deleteFolder(String folderName) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('user_bookmarks')
        .delete()
        .eq('user_id', userId)
        .eq('folder_name', folderName);
  }

  /// Get bookmark count by folder
  Future<Map<String, int>> getFolderCounts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final data = await _supabase
        .from('user_bookmarks')
        .select('folder_name')
        .eq('user_id', userId);

    final counts = <String, int>{};
    for (final row in data as List) {
      final folder = row['folder_name'] as String;
      counts[folder] = (counts[folder] ?? 0) + 1;
    }

    return counts;
  }

  /// Get total bookmark count
  Future<int> getTotalBookmarkCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _supabase
        .from('user_bookmarks')
        .select('id')
        .eq('user_id', userId);

    return (data as List).length;
  }

  /// Move all bookmarks from one folder to another
  Future<void> moveFolderBookmarks(String fromFolder, String toFolder) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('user_bookmarks')
        .update({'folder_name': toFolder})
        .eq('user_id', userId)
        .eq('folder_name', fromFolder);
  }
}
