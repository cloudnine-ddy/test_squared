import 'package:flutter/material.dart';

class TopicDetailScreen extends StatelessWidget {
  final String topicId;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Topic $topicId'),
      ),
      body: Center(
        child: Text('Questions for $topicId go here'),
      ),
    );
  }
}

