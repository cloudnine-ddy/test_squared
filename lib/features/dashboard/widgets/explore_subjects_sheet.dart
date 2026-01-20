import 'package:flutter/material.dart';
import '../../past_papers/data/past_paper_repository.dart';
import '../../past_papers/models/subject_model.dart';
import '../../../shared/wired/wired_widgets.dart';

class ExploreSubjectsSheet extends StatefulWidget {
  final String curriculum;
  
  const ExploreSubjectsSheet({super.key, required this.curriculum});

  @override
  State<ExploreSubjectsSheet> createState() => _ExploreSubjectsSheetState();
}

class _ExploreSubjectsSheetState extends State<ExploreSubjectsSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _primaryColor = Color(0xFF2D3E50);
  static const Color _backgroundColor = Color(0xFFFDFBF7);

  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
      height: height,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: WiredCard(
        backgroundColor: _backgroundColor,
        borderColor: _primaryColor,
        borderWidth: 2,
        padding: const EdgeInsets.all(24),
        width: 500,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Subject',
                    style: _patrickHand(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Search Bar
              WiredCard(
                backgroundColor: Colors.white,
                borderColor: _primaryColor.withValues(alpha: 0.2), // Lightened border
                borderWidth: 1.5,
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for Biology, History...',
                    hintStyle: _patrickHand(
                      fontSize: 16,
                      color: _primaryColor.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: _primaryColor.withValues(alpha: 0.6),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),  
                  ),
                  style: _patrickHand(fontSize: 16),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Subjects List
              Flexible(
                child: FutureBuilder<List<SubjectModel>>(
                  future: PastPaperRepository().getSubjects(curriculum: widget.curriculum),    
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'Failed to load subjects',
                            style: _patrickHand(
                              fontSize: 16,
                              color: _primaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      );
                    }

                    final allSubjects = snapshot.data ?? [];
                    final filteredSubjects = _searchQuery.isEmpty
                        ? allSubjects
                        : allSubjects.where((subject) =>
                            subject.name
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase())).toList();

                    if (filteredSubjects.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'No subjects found',
                            style: _patrickHand(),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredSubjects.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final subject = filteredSubjects[index];
                        return WiredButton(
                          onPressed: () {
                            Navigator.pop(context, {'id': subject.id, 'name': subject.name});
                          },
                          filled: false,
                          borderColor: _primaryColor.withValues(alpha: 0.2), // Lighter border
                          hoverColor: _primaryColor.withValues(alpha: 0.1), // Darker on hover
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subject.name,
                                  style: _patrickHand(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center, // Center text for cleaner look
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
