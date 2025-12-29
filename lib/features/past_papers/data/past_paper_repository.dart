import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic_model.dart';
import '../models/question_model.dart';
import '../models/subject_model.dart';

class PastPaperRepository {
  final _supabase = Supabase.instance.client;

  Future<List<TopicModel>> getTopics({required String subjectId}) async {
    try {
      // Fetch topics for this subject
      final topicsResponse = await _supabase
          .from('topics')
          .select()
          .eq('subject_id', subjectId);
      
      final List<dynamic> topicsData = topicsResponse as List<dynamic>;
      
      if (topicsData.isEmpty) {
        return [];
      }
      
      // Fetch all questions for this subject to count by topic
      // First get paper IDs for this subject
      final papersResponse = await _supabase
          .from('papers')
          .select('id')
          .eq('subject_id', subjectId);
      
      final paperIds = (papersResponse as List<dynamic>)
          .map((p) => p['id'] as String)
          .toList();
      
      // Count questions per topic
      Map<String, int> topicCounts = {};
      
      if (paperIds.isNotEmpty) {
        final questionsResponse = await _supabase
            .from('questions')
            .select('topic_ids')
            .inFilter('paper_id', paperIds);
        
        final questionsData = questionsResponse as List<dynamic>;
        
        for (var q in questionsData) {
          final topicIds = q['topic_ids'];
          if (topicIds is List) {
            for (var topicId in topicIds) {
              final id = topicId.toString();
              topicCounts[id] = (topicCounts[id] ?? 0) + 1;
            }
          }
        }
      }
      
      // Map topics with counts
      final topics = topicsData.map((e) {
        final map = e as Map<String, dynamic>;
        final topicId = map['id']?.toString() ?? '';
        return TopicModel.fromMap({
          ...map,
          'question_count': topicCounts[topicId] ?? 0,
        });
      }).toList();
      
      return topics;
    } catch (e, stackTrace) {
      print('ERROR in getTopics: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  // Get a single question by ID
  Future<QuestionModel?> getQuestionById(String questionId) async {
    try {
      final response = await _supabase
          .from('questions')
          .select('*, papers(year, season, variant, paper_type)')
          .eq('id', questionId)
          .single();
      
      // Debug: Print raw response to see what's coming from DB
      print('[DEBUG] getQuestionById raw response: $response');
      print('[DEBUG] type field: ${response['type']}');
      print('[DEBUG] options field: ${response['options']}');
      
      return QuestionModel.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      print('ERROR in getQuestionById: $e');
      return null;
    }
  }

  Future<List<QuestionModel>> getQuestionsByTopic(String topicId) async {
    try {
      // Join with papers table to get year/season info
      final response = await _supabase
          .from('questions')
          .select('*, papers(year, season, variant)')
          .contains('topic_ids', [topicId])
          .order('question_number');
      
      final List<dynamic> data = response as List<dynamic>;
      
      if (data.isEmpty) {
        return [];
      }
      
      final questions = <QuestionModel>[];
      
      for (var item in data) {
        try {
          if (item is Map<String, dynamic>) {
            final question = QuestionModel.fromMap(item);
            questions.add(question);
          }
        } catch (e) {
          print('Skipping bad question: $e');
        }
      }
      
      return questions;
    } catch (e, stackTrace) {
      print('ERROR in getQuestionsByTopic: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  Future<List<SubjectModel>> getSubjects() async {
    try {
      print('DEBUG: Starting getSubjects() method');
      print('DEBUG: About to call Supabase.from("subjects").select()');
      
      final response = await _supabase
          .from('subjects')
          .select()
          .limit(50);
      
      print('DEBUG: Supabase call completed');
      print('DEBUG: Response type: ${response.runtimeType}');
      
      final List<dynamic> data = response as List<dynamic>;
      
      print('RAW DATA: $data');
      print('DEBUG: Data length: ${data.length}');
      
      if (data.isEmpty) {
        print('WARNING: Supabase returned an empty list for subjects');
        return [];
      }
      
      print('DEBUG: Starting to map data to SubjectModel');
      final subjects = <SubjectModel>[];
      
      for (var item in data) {
        try {
          if (item is Map<String, dynamic>) {
            print('DEBUG: Mapping subject item: $item');
            final subject = SubjectModel.fromMap(item);
            subjects.add(subject);
          } else {
            print('WARNING: Skipping invalid subject item (not a Map): $item');
          }
        } catch (e, stackTrace) {
          print('Skipping bad subject: $e');
          print('Item that failed: $item');
          print('Stack trace: $stackTrace');
          // Continue to next item instead of crashing
        }
      }
      
      print('DEBUG: Successfully mapped ${subjects.length} out of ${data.length} subjects');
      return subjects;
    } catch (e, stackTrace) {
      print('ERROR: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  Future<List<SubjectModel>> getPinnedSubjects() async {
    try {
      print('DEBUG: Starting getPinnedSubjects() method');
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('WARNING: No current user, returning empty list');
        return [];
      }

      print('DEBUG: Fetching pinned subjects for user: ${user.id}');
      print('DEBUG: About to call Supabase.from("user_subjects").select("subject_id, subjects(*)")');
      
      final response = await _supabase
          .from('user_subjects')
          .select('subject_id, subjects(*)');
      
      print('DEBUG: Supabase call completed');
      print('DEBUG: Response type: ${response.runtimeType}');
      
      final List<dynamic> data = response as List<dynamic>;
      
      print('RAW DATA: $data');
      print('DEBUG: Data length: ${data.length}');
      
      if (data.isEmpty) {
        print('WARNING: Supabase returned an empty list for pinned subjects');
        return [];
      }
      
      print('DEBUG: Starting to map data to SubjectModel');
      final subjects = <SubjectModel>[];
      
      for (var item in data) {
        try {
          if (item is Map<String, dynamic>) {
            print('DEBUG: Mapping pinned subject item: $item');
            // The nested subject data is in item['subjects']
            final subjectData = item['subjects'];
            if (subjectData != null && subjectData is Map<String, dynamic>) {
              final subject = SubjectModel.fromMap(subjectData);
              subjects.add(subject);
            } else {
              print('WARNING: Subject data is null or not a Map: $subjectData');
            }
          } else {
            print('WARNING: Skipping invalid pinned subject item (not a Map): $item');
          }
        } catch (e, stackTrace) {
          print('Skipping bad pinned subject: $e');
          print('Item that failed: $item');
          print('Stack trace: $stackTrace');
        }
      }
      
      print('DEBUG: Successfully mapped ${subjects.length} out of ${data.length} pinned subjects');
      return subjects;
    } catch (e, stackTrace) {
      print('ERROR: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  Future<void> pinSubject(String subjectId) async {
    try {
      print('DEBUG: Starting pinSubject() method');
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No current user');
      }

      print('DEBUG: Pinning subject $subjectId for user ${user.id}');
      
      await _supabase.from('user_subjects').upsert(
        {
          'user_id': user.id,
          'subject_id': subjectId,
        },
        onConflict: 'user_id,subject_id',
      );
      
      print('DEBUG: Successfully pinned subject $subjectId');
    } catch (e, stackTrace) {
      print('ERROR pinning subject: $e');
      print('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  Future<void> unpinSubject(String subjectId) async {
    try {
      print('DEBUG: Starting unpinSubject() method');
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No current user');
      }

      print('DEBUG: Unpinning subject $subjectId for user ${user.id}');
      
      await _supabase
          .from('user_subjects')
          .delete()
          .eq('user_id', user.id)
          .eq('subject_id', subjectId);
      
      print('DEBUG: Successfully unpinned subject $subjectId');
    } catch (e, stackTrace) {
      print('ERROR unpinning subject: $e');
      print('STACK TRACE: $stackTrace');
      rethrow;
    }
  }
}

