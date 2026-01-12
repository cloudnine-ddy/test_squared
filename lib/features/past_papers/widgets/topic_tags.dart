import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../models/topic_model.dart';

/// Widget to display topic tags for a question
class TopicTags extends StatelessWidget {
  final List<String> topicIds;
  final bool clickable;

  const TopicTags({
    super.key,
    required this.topicIds,
    this.clickable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (topicIds.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<TopicModel>>(
      future: _loadTopics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final topics = snapshot.data!;

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: topics.map((topic) {
            return _buildTopicChip(context, topic);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTopicChip(BuildContext context, TopicModel topic) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: topic.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: topic.color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: topic.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            topic.name,
            style: TextStyle(
              fontFamily: 'PatrickHand', // Sketchy font
              color: topic.color,
              fontSize: 13, // Slightly larger for handwritten font
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (!clickable) return chip;

    return InkWell(
      onTap: () => context.push('/topic/${topic.id}'),
      borderRadius: BorderRadius.circular(12),
      child: chip,
    );
  }

  Future<List<TopicModel>> _loadTopics() async {
    try {
      final data = await Supabase.instance.client
          .from('topics')
          .select()
          .inFilter('id', topicIds);

      return (data as List).map((json) => TopicModel.fromMap(json)).toList();
    } catch (e) {
      print('Error loading topics: $e');
      return [];
    }
  }
}
