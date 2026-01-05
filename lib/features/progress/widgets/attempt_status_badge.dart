// Add this widget to your Question Detail Screen UI
// Place it at the top of the question card

Widget _buildAttemptStatusBadge() {
  if (_previousAttempt == null) {
    return const SizedBox.shrink();
  }

  final attemptedAt = DateTime.parse(_previousAttempt!['attempted_at']);
  final timeAgo = _formatTimeAgo(attemptedAt);
  final score = _previousAttempt!['score'] as int?;

  return Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _isViewingPreviousAnswer
            ? [Colors.blue.shade50, Colors.blue.shade100]
            : [Colors.green.shade50, Colors.green.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _isViewingPreviousAnswer
            ? Colors.blue.shade300
            : Colors.green.shade300,
        width: 1.5,
      ),
    ),
    child: Row(
      children: [
        Icon(
          _isViewingPreviousAnswer ? Icons.history : Icons.cloud_done,
          color: _isViewingPreviousAnswer
              ? Colors.blue.shade700
              : Colors.green.shade700,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isViewingPreviousAnswer
                    ? 'Viewing Previous Answer'
                    : 'Answer Saved',
                style: TextStyle(
                  color: _isViewingPreviousAnswer
                      ? Colors.blue.shade900
                      : Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Attempted $timeAgo${score != null ? " • Score: $score%" : ""}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (_isViewingPreviousAnswer)
          ElevatedButton.icon(
            onPressed: _retryQuestion,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    ),
  );
}

String _formatTimeAgo(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);

  if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()} month(s) ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} day(s) ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour(s) ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute(s) ago';
  } else {
    return 'Just now';
  }
}
