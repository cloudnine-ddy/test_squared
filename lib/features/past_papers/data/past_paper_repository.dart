import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic_model.dart';

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
}

