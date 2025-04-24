import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class ChapterDrawer extends StatefulWidget {
  const ChapterDrawer({
    super.key,
    required this.controller,
    this.onChapterSelected,
    this.currentCfi,
  });

  final EpubController controller;
  final Function(String href, String title)? onChapterSelected;
  final String? currentCfi;

  @override
  State<ChapterDrawer> createState() => _ChapterDrawerState();
}

class _ChapterDrawerState extends State<ChapterDrawer> {
  late List<EpubChapter> chapters;
  String? currentChapterHref;
  List<EpubChapter> allChapters = [];

  @override
  void initState() {
    super.initState();
    chapters = widget.controller.getChapters();

    // Get all chapters including subchapters for better matching
    allChapters = getAllChapters(chapters);

    // Initialize with last known location if available
    _initializeLocation();
  }

  @override
  void didUpdateWidget(ChapterDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the currentCfi prop changed, update the active chapter
    if (widget.currentCfi != null &&
        widget.currentCfi != oldWidget.currentCfi) {
      updateActiveChapter(widget.currentCfi!);
    }
  }

  // Initialize with the last known location
  Future<void> _initializeLocation() async {
    try {
      // If we have a currentCfi from the widget, use it
      if (widget.currentCfi != null) {
        updateActiveChapter(widget.currentCfi!);
        return;
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  // Build a chapter tile with nesting support
  Widget _buildChapterTile(EpubChapter chapter, bool isNested) {
    final isActive = chapter.href == currentChapterHref;

    // Debug output to help diagnose highlighting issues
    debugPrint('Building tile for chapter: ${chapter.title}');
    debugPrint('Chapter href: ${chapter.href}');
    debugPrint('Current chapter href: $currentChapterHref');
    debugPrint('Is active: $isActive');

    return Padding(
      padding: EdgeInsets.only(left: isNested ? 16.0 : 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              chapter.title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Theme.of(context).primaryColor : null,
              ),
            ),
            leading: isActive
                ? Icon(Icons.bookmark, color: Theme.of(context).primaryColor)
                : const Icon(Icons.book_outlined),
            tileColor: isActive
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : null,
            onTap: () {
              // Navigate to the chapter
              widget.controller.display(cfi: chapter.href);

              // Update the active chapter immediately for better UX
              updateActiveChapter(chapter.href);

              // Notify parent if callback is provided
              widget.onChapterSelected?.call(chapter.href, chapter.title);

              // Close the drawer
              Navigator.pop(context);
            },
          ),
          // If this chapter has subitems, build them recursively
          if (chapter.subitems.isNotEmpty)
            ...chapter.subitems
                .map((subChapter) => _buildChapterTile(subChapter, true)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Chapters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: chapters
                  .map((chapter) => _buildChapterTile(chapter, false))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String? findChapterForCfi(String cfi) {
    if (allChapters.isEmpty) return null;

    // Print the CFI for debugging
    debugPrint('Finding chapter for CFI: $cfi');

    // First, try exact matches
    for (final chapter in allChapters) {
      if (chapter.href == cfi) {
        debugPrint('Found exact match: ${chapter.href}');
        return chapter.href;
      }
    }

    // Then try partial matches - find chapters whose href is contained in the CFI
    String? bestMatch;
    int bestMatchLength = 0;

    for (final chapter in allChapters) {
      // Check if the chapter href is contained in the CFI
      if (cfi.contains(chapter.href)) {
        // If this match is longer than our current best match, use it
        if (chapter.href.length > bestMatchLength) {
          bestMatch = chapter.href;
          bestMatchLength = chapter.href.length;
        }
      }
    }

    if (bestMatch != null) {
      debugPrint('Found partial match: $bestMatch');
    } else {
      debugPrint('No matching chapter found for CFI: $cfi');
    }

    return bestMatch;
  }

  // Update the active chapter based on a CFI
  void updateActiveChapter(String cfi) {
    debugPrint('Updating active chapter with CFI: $cfi');

    // Try to find which chapter this CFI belongs to
    final chapterHref = findChapterForCfi(cfi);

    // Always update the UI, even if the chapter is the same
    // This ensures the UI reflects the current state
    setState(() {
      if (chapterHref != null) {
        currentChapterHref = chapterHref;
        debugPrint('Active chapter updated to: $chapterHref');
      } else {
        debugPrint('Could not find a chapter for CFI: $cfi');
      }
    });
  }

  // Get a flattened list of all chapters including subchapters
  List<EpubChapter> getAllChapters(List<EpubChapter> chapters) {
    List<EpubChapter> result = [];

    for (final chapter in chapters) {
      result.add(chapter);
      if (chapter.subitems.isNotEmpty) {
        result.addAll(getAllChapters(chapter.subitems));
      }
    }

    return result;
  }
}
