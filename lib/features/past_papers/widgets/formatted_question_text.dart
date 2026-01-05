import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// Helper enum for identifying block types
enum _BlockType { intro, mainQuestion, subQuestion }

// Helper class to store parsed data
class _TextBlock {
  final _BlockType type;
  final String? label;
  final String content;

  _TextBlock({required this.type, this.label, required this.content});
}

/// A widget that parses raw question text and displays it with visual hierarchy.
/// Separates introductory text, main questions (a), (b), and sub-questions (i), (ii).
class FormattedQuestionText extends StatelessWidget {
  final String content;
  final double fontSize;

  const FormattedQuestionText({
    super.key,
    required this.content,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Parse content into blocks
    final blocks = _parseContent(content);

    // 2. Build widgets from blocks
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) => _buildBlock(block)).toList(),
    );
  }

  List<_TextBlock> _parseContent(String text) {
    // Regex to find labels like (a), (b), (i), (ii), (1) at start of text or preceded by whitespace.
    // It captures the label group (e.g., "(a)").
    final regex = RegExp(r'(?:^|\s)(\((?:[a-z]+|\d+)\))(?=\s|$)');
    final matches = regex.allMatches(text);

    // If no labels found, treat everything as Intro/Body
    if (matches.isEmpty) {
      return [_TextBlock(type: _BlockType.intro, content: text.trim())];
    }

    final blocks = <_TextBlock>[];

    // Handle introductory text (anything before the first match)
    // Use the start of the first match to determine pre-text
    if (matches.first.start > 0) {
      final introText = text.substring(0, matches.first.start).trim();
      if (introText.isNotEmpty) {
        blocks.add(_TextBlock(type: _BlockType.intro, content: introText));
      }
    }

    for (var i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);
      final label = match.group(1)!; // The captured label (e.g. "(a)")

      // The content for this block starts after this match ends
      final startOfContent = match.end;

      // And ends at the start of the next match (or end of string)
      // Note: We need to be careful about newlines/whitespace, so we use trim() later.
      final endOfContent = (i + 1 < matches.length)
          ? matches.elementAt(i + 1).start
          : text.length;

      final blockContent = text.substring(startOfContent, endOfContent).trim();

      blocks.add(_TextBlock(
        type: _determineType(label),
        label: label,
        content: blockContent,
      ));
    }

    return blocks;
  }

  _BlockType _determineType(String label) {
    // Pattern (i), (ii), (iii), (iv), (v) -> Roman numerals = Sub-questions
    // Simple check: consists only of i, v, x inside parens
    final romanRegex = RegExp(r'^\([ivx]+\)$');
    if (romanRegex.hasMatch(label)) return _BlockType.subQuestion;

    // Pattern (a), (b), (c) -> Letters = Main questions
    // Simple check: single letter inside parens
    final letterRegex = RegExp(r'^\([a-z]\)$');
    if (letterRegex.hasMatch(label)) return _BlockType.mainQuestion;

    // Default to main for numeric (1), (2) or unknown patterns
    return _BlockType.mainQuestion;
  }

  Widget _buildBlock(_TextBlock block) {
    switch (block.type) {
      case _BlockType.intro:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SelectableText(
            block.content,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              height: 1.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
        );

      case _BlockType.mainQuestion:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              SizedBox(
                width: 32, // Fixed width for alignment
                child: Text(
                  block.label!,
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    height: 1.5,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: SelectableText(
                  block.content,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: fontSize,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.subQuestion:
        return Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 12), // Indent
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              SizedBox(
                width: 36, // Slightly wider to accommodate (iii)
                child: Text(
                  block.label!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize * 0.95,
                    height: 1.5,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: SelectableText(
                  block.content,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: fontSize * 0.95,
                    height: 1.5,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
