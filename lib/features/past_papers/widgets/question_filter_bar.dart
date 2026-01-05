import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Filter bar for question list with chips for difficulty, type, status
class QuestionFilterBar extends StatelessWidget {
  final Set<String> selectedDifficulties;
  final Set<String> selectedTypes;
  final Set<String> selectedStatuses;
  final Function(String) onDifficultyToggle;
  final Function(String) onTypeToggle;
  final Function(String) onStatusToggle;
  final VoidCallback onClearAll;

  const QuestionFilterBar({
    super.key,
    required this.selected Difficulties,
    required this.selectedTypes,
    required this.selectedStatuses,
    required this.onDifficultyToggle,
    required this.onTypeToggle,
    required this.onStatusToggle,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = selectedDifficulties.isNotEmpty ||
        selectedTypes.isNotEmpty ||
        selectedStatuses.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedDifficulties.length + selectedTypes.length + selectedStatuses.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Difficulty chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                'Easy',
                selectedDifficulties.contains('easy'),
                () => onDifficultyToggle('easy'),
                Colors.green,
              ),
              _buildFilterChip(
                'Medium',
                selectedDifficulties.contains('medium'),
                () => onDifficultyToggle('medium'),
                Colors.orange,
              ),
              _buildFilterChip(
                'Hard',
                selectedDifficulties.contains('hard'),
                () => onDifficultyToggle('hard'),
                Colors.red,
              ),
              const SizedBox(width: 16),
              _buildFilterChip(
                'MCQ',
                selectedTypes.contains('mcq'),
                () => onTypeToggle('mcq'),
                AppColors.primary,
              ),
              _buildFilterChip(
                'Written',
                selectedTypes.contains('written'),
                () => onTypeToggle('written'),
                AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildFilterChip(
                'Unattempted',
                selectedStatuses.contains('unattempted'),
                () => onStatusToggle('unattempted'),
                AppColors.textSecondary,
              ),
              _buildFilterChip(
                'Correct',
                selectedStatuses.contains('correct'),
                () => onStatusToggle('correct'),
                Colors.green,
              ),
              _buildFilterChip(
                'Incorrect',
                selectedStatuses.contains('incorrect'),
                () => onStatusToggle('incorrect'),
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 16, color: color),
              ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sort dropdown for question list
class QuestionSortDropdown extends StatelessWidget {
  final String currentSort;
  final Function(String) onSortChanged;

  const QuestionSortDropdown({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentSort,
          icon: Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          onChanged: (value) {
            if (value != null) onSortChanged(value);
          },
          items: const [
            DropdownMenuItem(value: 'newest', child: Text('Newest First')),
            DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
            DropdownMenuItem(value: 'hardest', child: Text('Hardest First')),
            DropdownMenuItem(value: 'easiest', child: Text('Easiest First')),
            DropdownMenuItem(value: 'number_asc', child: Text('Question # ↑')),
            DropdownMenuItem(value: 'number_desc', child: Text('Question # ↓')),
          ],
        ),
      ),
    );
  }
}
