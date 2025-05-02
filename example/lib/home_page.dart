import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'search_page.dart';
import 'chapter_drawer.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final epubController = EpubController();
  bool _isScrolled = false;

  var textSelectionCfi = '';
  String textSelection = '';
  String currentChapter = '';

  bool isLoading = true;
  double progress = 0.0;
  double fontSize = 12;

  // For enhanced features
  List<EpubBookmark> bookmarks = [];
  List<EpubHighlight> highlights = [];
  EpubMetadata? metadata;
  EpubThemeType currentTheme = EpubThemeType.light;

  @override
  void initState() {
    super.initState();
    // Add lifecycle event listener to optimize memory usage
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Clean up resources
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background - clear memory cache
      epubController.clearMemoryCache();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground - prefetch content
      Future.delayed(const Duration(milliseconds: 500), () {
        epubController.prefetchContent();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ChapterDrawer(
        controller: epubController,
        key: const ValueKey('chapter_drawer'),
        currentCfi: currentChapter,
        onChapterSelected: (href, title) {
          setState(() {
            currentChapter = href;
          });
        },
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SearchPage(
                            epubController: epubController,
                          )));
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'bookmarks',
                onTap: () {
                  _showBookmarksDialog(context);
                },
                child: const Text('Bookmarks'),
              ),
              PopupMenuItem(
                value: 'highlights',
                onTap: () {
                  _showHighlightsDialog(context);
                },
                child: const Text('Highlights'),
              ),
              PopupMenuItem(
                value: 'metadata',
                onTap: () {
                  if (metadata != null) {
                    _showMetadataDialog(context);
                  }
                },
                child: const Text('Book Info'),
              ),
              PopupMenuItem(
                value: 'themes',
                onTap: () {
                  _showThemesDialog(context);
                },
                child: const Text('Themes'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Add bookmark button
          FloatingActionButton(
            heroTag: 'bookmark',
            onPressed: () async {
              final ctx = context;
              await epubController.addBookmark(customTitle: 'Custom Title');
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Bookmark added')),
              );
            },
            tooltip: 'Add Bookmark',
            child: const Icon(Icons.bookmark_add),
          ),
          const SizedBox(height: 10),
          // Text Increase Button
          FloatingActionButton(
            heroTag: 'text_increase',
            onPressed: () {
              setState(() {
                fontSize += 1;
              });
              // Use batch settings application for better performance
              epubController.applySettings(
                fontSize: fontSize,
                fontFamily: 'Georgia',
                lineHeight: '1.5',
              );
            },
            tooltip: 'Apply Settings',
            child: const Icon(Icons.text_increase),
          ),
          const SizedBox(height: 10),
          // Text Decrease Button
          FloatingActionButton(
            heroTag: 'text_decrease',
            onPressed: () {
              setState(() {
                fontSize -= 1;
              });

              // Use batch settings application for better performance
              epubController.applySettings(
                fontSize: fontSize,
                fontFamily: 'Georgia',
                lineHeight: '1.5',
              );
            },
            tooltip: 'Apply Settings',
            child: const Icon(Icons.text_decrease),
          ),
          const SizedBox(height: 10),
          // Flow toggle button
          FloatingActionButton(
            heroTag: 'flow',
            onPressed: () {
              // Toggle between paginated and scrolled flow
              final newFlow =
                  _isScrolled ? EpubFlow.paginated : EpubFlow.scrolled;
              epubController.applySettings(flow: newFlow);
              setState(() {
                _isScrolled = !_isScrolled;
              });
            },
            tooltip: 'Toggle Flow',
            child: const Icon(Icons.swap_vert),
          ),
          const SizedBox(height: 10),
          // Memory cache button
          FloatingActionButton(
            heroTag: 'memory_cache',
            onPressed: () {
              // Clear memory cache when needed
              epubController.clearMemoryCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memory cache cleared')),
              );
            },
            tooltip: 'Clear Cache',
            child: const Icon(Icons.cleaning_services),
          ),
          const SizedBox(height: 10),
          // Memory cache button
          FloatingActionButton(
            heroTag: 'local_storage',
            onPressed: () async {
              final ctx = context;
              final type = await showModalBottomSheet<ClearStorageType>(
                context: context,
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        List.generate(ClearStorageType.values.length, (index) {
                      final storageType = ClearStorageType.values[index];
                      return ListTile(
                        title: Text(storageType.name),
                        onTap: () {
                          Navigator.pop(context, storageType);
                        },
                      );
                    }),
                  );
                },
              );

              // Clear memory cache when needed
              if (type != null) {
                await epubController.clearStorage(type: type);
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Local Storage Cleared ${type.value}'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            tooltip: 'Clear Cache',
            child: const Icon(Icons.delete_outlined),
          ),
        ],
      ),
      body: SafeArea(
          child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent,
          ),
          Expanded(
            child: Stack(
              children: [
                EpubViewer(
                  epubSource: EpubSource.fromUrl(
                    widget.url,
                    isCachedToLocal: true,
                  ),
                  epubController: epubController,
                  displaySettings: EpubDisplaySettings(
                    flow: EpubFlow.paginated,
                    useSnapAnimationAndroid: false,
                    snap: true,
                    theme: getTheme(currentTheme),
                    allowScriptedContent: true,
                  ),
                  selectionContextMenu: ContextMenu(
                    menuItems: [
                      ContextMenuItem(
                        title: "Highlight",
                        id: 1,
                        action: () async {
                          final highlight = EpubHighlight(
                            cfi: textSelectionCfi,
                            color: Colors.yellow.toHex(),
                            opacity: 0.3,
                            text: textSelection,
                          );

                          epubController.addHighlight(highlight);
                        },
                      ),
                    ],
                    settings: ContextMenuSettings(
                        hideDefaultSystemContextMenuItems: true),
                  ),
                  onChaptersLoaded: (chapters) {
                    setState(() {
                      isLoading = false;
                    });
                  },
                  onEpubLoaded: () async {
                    debugPrint('Epub loaded');
                    // Prefetch content for smoother reading experience
                    epubController.prefetchContent();

                    // Load metadata
                    epubController.getMetadata().then((data) {
                      setState(() {
                        metadata = data;
                      });
                    });

                    // Register custom themes
                    await epubController.registerTheme(
                      name: 'sepia',
                      styles: {
                        'body': {'background': '#f4ecd8', 'color': '#5b4636'}
                      },
                    );
                  },
                  onRelocated: (value) {
                    debugPrint("Relocated to ${value.toJson()}");

                    // Update the chapter drawer state
                    if (value.startCfi != null) {
                      setState(() {
                        currentChapter = value.startCfi!;
                      });
                    }

                    // Prefetch content when location changes
                    epubController.prefetchContent();
                  },
                  onBookmarksUpdated: (value) {
                    debugPrint("Bookmarks updated $value");
                    setState(() {
                      bookmarks = value;
                    });
                  },
                  onAnnotationClicked: (cfi) {
                    debugPrint("Annotation clicked $cfi");
                  },
                  onTextSelected: (epubTextSelection) {
                    textSelection = epubTextSelection.selectedText;
                    textSelectionCfi = epubTextSelection.selectionCfi;
                  },
                  onHighlightsUpdated: (value) {
                    debugPrint(
                        "Highlights updated ${value.map((x) => x.toJson())}");
                    setState(() {
                      highlights = value;
                    });
                  },
                ),
                Visibility(
                  visible: isLoading,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              ],
            ),
          ),
        ],
      )),
    );
  }

  // Show bookmarks dialog
  void _showBookmarksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarks'),
        content: SizedBox(
          width: double.maxFinite,
          child: bookmarks.isEmpty
              ? const Center(child: Text('No bookmarks yet'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = bookmarks[index];
                    return ListTile(
                      title: Text(bookmark.title),
                      subtitle: Text(bookmark.cfi),
                      onTap: () {
                        // Go to bookmark
                        epubController.goTo(cfi: bookmark.cfi);
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          // Remove bookmark
                          epubController.removeBookmark(cfi: bookmark.cfi);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Show metadata dialog
  void _showMetadataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book Information'),
        content: SizedBox(
          width: double.maxFinite,
          child: metadata == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  shrinkWrap: true,
                  children: [
                    _metadataItem('Identifier', metadata!.identifier),
                    _metadataItem('Title', metadata!.title),
                    _metadataItem('Creator', metadata!.creator),
                    _metadataItem('Publisher', metadata!.publisher),
                    _metadataItem('Language', metadata!.language),
                    _metadataItem(
                        'Publication Date', _formatDate(metadata!.pubdate)),
                    _metadataItem(
                        'Modified Date', _formatDate(metadata!.modifiedDate)),
                    _metadataItem('Rights', metadata!.rights),
                    _metadataItem('Description', metadata!.description),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Show themes dialog
  void _showThemesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: EpubThemeType.values.length,
            itemBuilder: (context, index) {
              final theme = EpubThemeType.values[index];
              return ListTile(
                title:
                    Text(theme.name[0].toUpperCase() + theme.name.substring(1)),
                selected: theme == currentTheme,
                onTap: () {
                  // Apply theme
                  epubController.applySettings(theme: getTheme(theme));
                  setState(() {
                    currentTheme = theme;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  EpubTheme getTheme(EpubThemeType type) {
    switch (type) {
      case EpubThemeType.dark:
        return EpubTheme.dark();
      case EpubThemeType.light:
        return EpubTheme.light();
      case EpubThemeType.custom:
        return EpubTheme.custom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        );
    }
  }

  // Helper for metadata display
  Widget _metadataItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value ?? 'Not available'),
          const Divider(),
        ],
      ),
    );
  }

  // Format date for display
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  // Show highlights dialog
  void _showHighlightsDialog(BuildContext context) async {
    final ctx = context;
    final highlights = await epubController.getHighlights();
    if (!ctx.mounted) return;

    showDialog(
      context: ctx,
      builder: (ctxDialog) => AlertDialog(
        title: const Text('Highlights'),
        content: SizedBox(
          width: double.maxFinite,
          child: highlights.isEmpty
              ? const Center(child: Text('No highlights yet'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: highlights.length,
                  itemBuilder: (ctxItem, index) {
                    final highlight = highlights[index];
                    return ListTile(
                      title: Text(highlight.text),
                      subtitle: Text(highlight.cfi),
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: highlight.color.fromHex,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onTap: () {
                        // Go to highlight
                        epubController.goTo(cfi: highlight.cfi);
                        Navigator.pop(ctxItem);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          // Call the JavaScript function to remove the highlight
                          epubController.removeHighlight(highlight.cfi);
                          Navigator.pop(ctxItem);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctxDialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
