import 'package:flutter/material.dart';

/// Consolidated bottom action bar for Question Screen actions.
class QuestionActionBar extends StatelessWidget {
  final VoidCallback onToggleOfficialAnswer;
  final VoidCallback onToggleAiExplanation;
  final bool hasAiSolution;
  final bool isAiSolutionVisible;

  const QuestionActionBar({
    super.key,
    required this.onToggleOfficialAnswer,
    required this.onToggleAiExplanation,
    required this.hasAiSolution,
    required this.isAiSolutionVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E14), // Match scaffold background
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Official Answer Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onToggleOfficialAnswer,
                icon: const Icon(Icons.visibility_outlined, size: 20),
                label: const Text('Answer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF151A23),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // AI Explanation Button
            if (hasAiSolution)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onToggleAiExplanation,
                  icon: Icon(
                    isAiSolutionVisible ? Icons.auto_awesome_motion : Icons.auto_awesome,
                    size: 20
                  ),
                  label: Text(isAiSolutionVisible ? 'Hide AI' : 'Explain'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAiSolutionVisible
                        ? Colors.indigoAccent.withValues(alpha: 0.2)
                        : Colors.blueAccent.withValues(alpha: 0.1),
                    foregroundColor: isAiSolutionVisible
                        ? Colors.indigoAccent
                        : Colors.blueAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isAiSolutionVisible
                           ? Colors.indigoAccent.withValues(alpha: 0.5)
                           : Colors.blueAccent.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Opacity(
                  opacity: 0.5,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text('No AI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white30,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
