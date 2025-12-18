import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic_model.dart';
import '../models/question_model.dart';
import '../models/subject_model.dart';

class PastPaperRepository {
  final _supabase = Supabase.instance.client;

  Future<List<TopicModel>> getTopics() async {
    try {
      print('DEBUG: Starting getTopics() method');
      print('DEBUG: About to call Supabase.from("topics").select()');
      
      final response = await _supabase.from('topics').select();
      
      print('DEBUG: Supabase call completed');
      print('DEBUG: Response type: ${response.runtimeType}');
      
      final List<dynamic> data = response as List<dynamic>;
      
      print('RAW DATA: $data');
      print('DEBUG: Data length: ${data.length}');
      
      if (data.isEmpty) {
        print('WARNING: Supabase returned an empty list.');
        return [];
      }
      
      print('DEBUG: Starting to map data to TopicModel');
      final topics = data.map((e) {
        print('DEBUG: Mapping item: $e');
        return TopicModel.fromMap(e as Map<String, dynamic>);
      }).toList();
      
      print('DEBUG: Successfully mapped ${topics.length} topics');
      return topics;
    } catch (e, stackTrace) {
      print('ERROR: $e');
      print('STACK TRACE: $stackTrace');
      // Return empty list on error, or you could throw the error
      return [];
    }
  }

  Future<List<QuestionModel>> getQuestionsByTopic(String topicId) async {
    try {
      print('DEBUG: Starting getQuestionsByTopic() method');
      print('DEBUG: Topic ID: $topicId');
      print('DEBUG: About to call Supabase.from("questions").select().contains("topic_ids", [$topicId])');
      
      final response = await _supabase
          .from('questions')
          .select()
          .contains('topic_ids', [topicId]);
      
      print('DEBUG: Supabase call completed');
      print('DEBUG: Response type: ${response.runtimeType}');
      
      final List<dynamic> data = response as List<dynamic>;
      
      print('RAW DATA: $data');
      print('DEBUG: Data length: ${data.length}');
      
      if (data.isEmpty) {
        print('WARNING: Supabase returned an empty list for topic $topicId');
        return [];
      }
      
      print('DEBUG: Starting to map data to QuestionModel');
      final questions = <QuestionModel>[];
      
      for (var item in data) {
        try {
          if (item is Map<String, dynamic>) {
            print('DEBUG: Mapping question item: $item');
            final question = QuestionModel.fromMap(item);
            questions.add(question);
          } else {
            print('WARNING: Skipping invalid question item (not a Map): $item');
          }
        } catch (e, stackTrace) {
          print('Skipping bad question: $e');
          print('Item that failed: $item');
          print('Stack trace: $stackTrace');
          // Continue to next item instead of crashing
        }
      }
      
      print('DEBUG: Successfully mapped ${questions.length} out of ${data.length} questions');
      return questions;
    } catch (e, stackTrace) {
      print('ERROR: $e');
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
}

