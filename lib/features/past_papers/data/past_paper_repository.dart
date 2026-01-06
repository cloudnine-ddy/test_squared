import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic_model.dart';
import '../models/question_model.dart';
import '../models/subject_model.dart';
import '../models/paper_model.dart';

class PastPaperRepository {
  final _supabase = Supabase.instance.client;

  Future<List<TopicModel>> getTopics({required String subjectId}) async {
    try {
      print('DEBUG getTopics: Starting for subjectId=$subjectId');

      // Fetch topics for this subject
      final topicsResponse = await _supabase
          .from('topics')
          .select()
          .eq('subject_id', subjectId);

      final List<dynamic> topicsData = topicsResponse as List<dynamic>;
      print('DEBUG getTopics: Found ${topicsData.length} topics');

      if (topicsData.isEmpty) {
        print('DEBUG getTopics: No topics found for subject $subjectId');
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
      print('DEBUG getTopics: Found ${paperIds.length} papers');

      // Count questions per topic
      Map<String, int> topicCounts = {};

      if (paperIds.isNotEmpty) {
        final questionsResponse = await _supabase
            .from('questions')
            .select('topic_ids')
            .inFilter('paper_id', paperIds);

        final questionsData = questionsResponse as List<dynamic>;
        print('DEBUG getTopics: Found ${questionsData.length} questions');

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

      print('DEBUG getTopics: Topic counts: $topicCounts');

      // Map topics with counts
      final topics = topicsData.map((e) {
        final map = e as Map<String, dynamic>;
        final topicId = map['id']?.toString() ?? '';
        return TopicModel.fromMap({
          ...map,
          'question_count': topicCounts[topicId] ?? 0,
        });
      }).toList();

      print('DEBUG getTopics: Returning ${topics.length} topics');
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

      // Sort by Year (Desc), Season (Asc), Number (Asc)
      questions.sort((a, b) {
        // Year Descending
        int yearCompare = (b.paperYear ?? 0).compareTo(a.paperYear ?? 0);
        if (yearCompare != 0) return yearCompare;

        // Season Ascending (e.g. 's' < 'w')
        int seasonCompare = (a.paperSeason ?? '').compareTo(b.paperSeason ?? '');
        if (seasonCompare != 0) return seasonCompare;

        // Number Ascending
        return a.questionNumber.compareTo(b.questionNumber);
      });

      return questions;
    } catch (e, stackTrace) {
      print('ERROR in getQuestionsByTopic: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  /// Get IDs of the previous and next questions in the same paper
  Future<Map<String, String?>> getAdjacentQuestionIds(String paperId, int currentNumber) async {
    try {
      String? prevId;
      String? nextId;

      // Get Previous
      final prevResponse = await _supabase
          .from('questions')
          .select('id')
          .eq('paper_id', paperId)
          .lt('question_number', currentNumber)
          .order('question_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (prevResponse != null) {
        prevId = prevResponse['id']?.toString();
      }

      // Get Next
      final nextResponse = await _supabase
          .from('questions')
          .select('id')
          .eq('paper_id', paperId)
          .gt('question_number', currentNumber)
          .order('question_number', ascending: true)
          .limit(1)
          .maybeSingle();

      if (nextResponse != null) {
        nextId = nextResponse['id']?.toString();
      }

      return {'prev': prevId, 'next': nextId};
    } catch (e) {
      print('ERROR in getAdjacentQuestionIds: $e');
      return {'prev': null, 'next': null};
    }
  }

  /// Get IDs (prev/next) within the context of a Topic
  /// Fetches all IDs for the topic to determine order.
  Future<Map<String, String?>> getAdjacentIdsForTopic(String topicId, String currentQuestionId, {String? type}) async {
    try {
      // Fetch all IDs for this topic + sort info
      var query = _supabase
          .from('questions')
          .select('id, question_number, papers(year, season)')
          .contains('topic_ids', [topicId]);

      if (type != null) {
        query = query.eq('type', type);
      }

      final response = await query;

      final List<dynamic> data = response as List<dynamic>;

      // Sort in Dart to match getQuestionsByTopic (Year Desc, Season Asc, Number Asc)
      data.sort((a, b) {
        final mapA = a as Map<String, dynamic>;
        final mapB = b as Map<String, dynamic>;

        final paperA = mapA['papers'] as Map<String, dynamic>?;
        final paperB = mapB['papers'] as Map<String, dynamic>?;

        final yearA = paperA?['year'] as int? ?? 0;
        final yearB = paperB?['year'] as int? ?? 0;

        // Year Descending
        int yearCompare = yearB.compareTo(yearA);
        if (yearCompare != 0) return yearCompare;

        final seasonA = paperA?['season']?.toString() ?? '';
        final seasonB = paperB?['season']?.toString() ?? '';

        // Season Ascending
        int seasonCompare = seasonA.compareTo(seasonB);
        if (seasonCompare != 0) return seasonCompare;

        final numA = mapA['question_number'] as int? ?? 0;
        final numB = mapB['question_number'] as int? ?? 0;

        // Number Ascending
        return numA.compareTo(numB);
      });

      final ids = data.map((e) => e['id'].toString()).toList();

      final currentIndex = ids.indexOf(currentQuestionId);
      if (currentIndex == -1) {
        return {'prev': null, 'next': null};
      }

      final prevId = currentIndex > 0 ? ids[currentIndex - 1] : null;
      final nextId = currentIndex < ids.length - 1 ? ids[currentIndex + 1] : null;

      return {'prev': prevId, 'next': nextId};
    } catch (e) {
      print('ERROR in getAdjacentIdsForTopic: $e');
      return {'prev': null, 'next': null};
    }
  }

  Future<List<SubjectModel>> getSubjects({String? curriculum}) async {
    try {
      dynamic response;

      if (curriculum != null) {
        response = await _supabase
            .from('subjects')
            .select()
            .eq('curriculum', curriculum);
      } else {
        response = await _supabase
            .from('subjects')
            .select()
            .limit(50);
      }

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
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      // Get pinned subject IDs from user profile
      final profileResponse = await _supabase
          .from('profiles')
          .select('pinned_subject_ids')
          .eq('id', user.id)
          .single();

      final List<dynamic> pinnedIds = profileResponse['pinned_subject_ids'] ?? [];

      if (pinnedIds.isEmpty) {
        return [];
      }

      // Fetch the actual subject data
      final subjectsResponse = await _supabase
          .from('subjects')
          .select()
          .inFilter('id', pinnedIds.map((e) => e.toString()).toList());

      final List<dynamic> data = subjectsResponse as List<dynamic>;

      final subjects = <SubjectModel>[];
      for (var item in data) {
        try {
          if (item is Map<String, dynamic>) {
            subjects.add(SubjectModel.fromMap(item));
          }
        } catch (e) {
          print('Skipping bad subject: $e');
        }
      }

      return subjects;
    } catch (e, stackTrace) {
      print('ERROR: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  Future<void> pinSubject(String subjectId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No current user');
      }

      // Get current pinned IDs
      final response = await _supabase
          .from('profiles')
          .select('pinned_subject_ids')
          .eq('id', user.id)
          .single();

      final List<dynamic> current = response['pinned_subject_ids'] ?? [];
      final List<String> pinnedIds = current.map((e) => e.toString()).toList();

      // Add if not already pinned
      if (!pinnedIds.contains(subjectId)) {
        pinnedIds.add(subjectId);

        await _supabase
            .from('profiles')
            .update({'pinned_subject_ids': pinnedIds})
            .eq('id', user.id);
      }
    } catch (e, stackTrace) {
      print('ERROR pinning subject: $e');
      print('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  Future<void> unpinSubject(String subjectId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No current user');
      }

      // Get current pinned IDs
      final response = await _supabase
          .from('profiles')
          .select('pinned_subject_ids')
          .eq('id', user.id)
          .single();

      final List<dynamic> current = response['pinned_subject_ids'] ?? [];
      final List<String> pinnedIds = current.map((e) => e.toString()).toList();

      // Remove the subject ID
      pinnedIds.remove(subjectId);

      await _supabase
          .from('profiles')
          .update({'pinned_subject_ids': pinnedIds})
          .eq('id', user.id);
    } catch (e, stackTrace) {
      print('ERROR unpinning subject: $e');
      print('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  /// Get papers for a specific year and subject
  Future<List<PaperModel>> getPapersByYear(int year, String subjectId) async {
    try {
      final response = await _supabase
          .from('papers')
          .select()
          .eq('subject_id', subjectId)
          .eq('year', year)
          .order('season')
          .order('variant');

      final List<dynamic> data = response as List<dynamic>;

      return data
          .map((item) => PaperModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      print('ERROR in getPapersByYear: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  /// Get all questions from a specific paper, ordered by question number
  Future<List<QuestionModel>> getQuestionsByPaper(String paperId) async {
    try {
      final response = await _supabase
          .from('questions')
          .select('*, papers(year, season, variant, paper_type)')
          .eq('paper_id', paperId)
          .order('question_number', ascending: true);

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
      print('ERROR in getQuestionsByPaper: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  /// Get distinct years from papers table
  Future<List<int>> fetchAvailableYears(String subjectId) async {
    try {
      final response = await _supabase
          .from('papers')
          .select('year')
          .eq('subject_id', subjectId)
          .order('year', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      // Get distinct years
      final years = <int>{};
      for (var item in data) {
        if (item is Map<String, dynamic> && item['year'] != null) {
          years.add(item['year'] as int);
        }
      }

      return years.toList()..sort((a, b) => b.compareTo(a)); // Descending order
    } catch (e, stackTrace) {
      print('ERROR in fetchAvailableYears: $e');
      print('STACK TRACE: $stackTrace');
      return [];
    }
  }

  // Get paper details by ID (for debug view)
  Future<Map<String, dynamic>?> getPaperById(String paperId) async {
    try {
      final data = await _supabase
          .from('papers')
          .select('id, pdf_url, year, season, variant, subject_id')
          .eq('id', paperId)
          .maybeSingle();
      return data;
    } catch (e) {
      print('ERROR in getPaperById: $e');
      return null;
    }
  }
}
