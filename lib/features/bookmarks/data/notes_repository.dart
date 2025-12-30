import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_model.dart';

class NotesRepository {
  final _supabase = Supabase.instance.client;

  /// Save or update a note
  Future<void> saveNote(String questionId, String noteText) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();

    // Check if note exists
    final existing = await _supabase
        .from('question_notes')
        .select('id')
        .eq('user_id', userId)
        .eq('question_id', questionId)
        .maybeSingle();

    if (existing != null) {
      // Update existing note
      await _supabase
          .from('question_notes')
          .update({
            'note_text': noteText,
            'updated_at': now.toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('question_id', questionId);
    } else {
      // Insert new note
      await _supabase.from('question_notes').insert({
        'user_id': userId,
        'question_id': questionId,
        'note_text': noteText,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }
  }

  /// Get note for a specific question
  Future<NoteModel?> getNote(String questionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _supabase
        .from('question_notes')
        .select()
        .eq('user_id', userId)
        .eq('question_id', questionId)
        .maybeSingle();

    if (data == null) return null;
    return NoteModel.fromMap(data);
  }

  /// Delete a note
  Future<void> deleteNote(String questionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('question_notes')
        .delete()
        .eq('user_id', userId)
        .eq('question_id', questionId);
  }

  /// Get all notes for current user
  Future<List<NoteModel>> getAllNotes() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _supabase
        .from('question_notes')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (data as List).map((json) => NoteModel.fromMap(json)).toList();
  }

  /// Get notes with question data
  Future<List<Map<String, dynamic>>> getNotesWithQuestions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _supabase
        .from('question_notes')
        .select('*, questions(id, question_number, content, image_url)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Check if a question has a note
  Future<bool> hasNote(String questionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await _supabase
        .from('question_notes')
        .select('id')
        .eq('user_id', userId)
        .eq('question_id', questionId)
        .limit(1);

    return (data as List).isNotEmpty;
  }

  /// Get total note count
  Future<int> getTotalNoteCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _supabase
        .from('question_notes')
        .select('id')
        .eq('user_id', userId);

    return (data as List).length;
  }

  /// Search notes by text
  Future<List<NoteModel>> searchNotes(String query) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _supabase
        .from('question_notes')
        .select()
        .eq('user_id', userId)
        .ilike('note_text', '%$query%')
        .order('updated_at', ascending: false);

    return (data as List).map((json) => NoteModel.fromMap(json)).toList();
  }
}
