import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'search_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Epub Viewer Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final epubController = EpubController();

  var textSelectionCfi = '';

  bool isLoading = true;

  double progress = 0.0;

  List<EpubChapter> chapters = [];

  /// Web only: whether the beside-the-viewer chapters panel is visible.
  bool _showChapters = false;

  @override
  Widget build(BuildContext context) {
    // On mobile the epub is a native platform view we can freely overlay, so we
    // use the standard Drawer for chapters and epub.js swipe for page turning.
    //
    // On the web the epub <iframe> composites above the Flutter scene, so
    // overlays (Drawer / routes) placed over it don't receive taps and there is
    // no swipe with a mouse. There we use a side panel beside the viewer plus
    // AppBar page-turn buttons — all outside the iframe's rectangle.
    return kIsWeb ? _buildWebLayout(context) : _buildMobileLayout(context);
  }

  // ---------------------------------------------------------------------------
  // Mobile: Drawer + swipe (original behavior)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: _chapterList(onTap: () => Navigator.pop(context)),
        ),
      ),
      appBar: _appBar(context, leading: null, showPageButtons: false),
      body: SafeArea(
        child: Column(
          children: [
            _progressBar(),
            Expanded(child: _viewerStack()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Web: side panel + AppBar page-turn buttons
  // ---------------------------------------------------------------------------
  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      appBar: _appBar(
        context,
        leading: IconButton(
          tooltip: 'Chapters',
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => _showChapters = !_showChapters),
        ),
        showPageButtons: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _progressBar(),
            Expanded(
              child: Row(
                children: [
                  if (_showChapters)
                    Container(
                      width: 280,
                      decoration: BoxDecoration(
                        border: Border(
                          right:
                              BorderSide(color: Theme.of(context).dividerColor),
                        ),
                      ),
                      child: _chapterList(),
                    ),
                  Expanded(child: _viewerStack()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------
  AppBar _appBar(
    BuildContext context, {
    required Widget? leading,
    required bool showPageButtons,
  }) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      leading: leading,
      title: Text(widget.title),
      actions: [
        if (showPageButtons) ...[
          IconButton(
            tooltip: 'Previous page',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => epubController.prev(),
          ),
          IconButton(
            tooltip: 'Next page',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => epubController.next(),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SearchPage(epubController: epubController),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _progressBar() => LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.transparent,
      );

  Widget _chapterList({VoidCallback? onTap}) {
    if (chapters.isEmpty) {
      return const Center(child: Text('Chapters not loaded yet'));
    }
    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(chapters[index].title),
          onTap: () {
            epubController.display(cfi: chapters[index].href);
            onTap?.call();
          },
        );
      },
    );
  }

  Widget _viewerStack() {
    return Stack(
      children: [
        EpubViewer(
          initialCfi: 'epubcfi(/6/20!/4/2[introduction]/2[c1_h]/1:0)',
          // Bundled asset so it works on every platform (including web, where
          // cross-origin URLs are blocked by CORS). On web you can also use
          // EpubSource.fromData(bytes).
          epubSource: EpubSource.fromAsset('assets/sample.epub'),
          epubController: epubController,
          displaySettings: EpubDisplaySettings(
            flow: EpubFlow.paginated,
            useSnapAnimationAndroid: false,
            snap: true,
            theme: EpubTheme.light(),
            // Safe here because the bundled sample is trusted. Keep this `false`
            // for user-provided / untrusted EPUBs (see EpubDisplaySettings docs).
            allowScriptedContent: true,
          ),
          selectionContextMenu: EpubContextMenu(
            hideDefaultSystemItems: true,
            items: [
              EpubContextMenuItem(
                title: "Highlight",
                id: 1,
                action: () {
                  epubController.addHighlight(cfi: textSelectionCfi);
                },
              ),
            ],
          ),
          onChaptersLoaded: (loaded) {
            setState(() {
              chapters = loaded;
              isLoading = false;
            });
          },
          onEpubLoaded: () async {
            debugPrint('Epub loaded');
          },
          onRelocated: (value) {
            debugPrint("Reloacted to $value");
            setState(() {
              progress = value.progress;
            });
          },
          onAnnotationClicked: (cfi, data) {
            debugPrint("Annotation clicked $cfi");
          },
          onTextSelected: (epubTextSelection) {
            textSelectionCfi = epubTextSelection.selectionCfi;
            debugPrint(textSelectionCfi);
          },
          onLocationLoaded: () {
            debugPrint('on location loaded');
          },
          onSelection: (selectedText, cfiRange, selectionRect, viewRect) {
            debugPrint("On selection changes");
          },
          onDeselection: () {
            debugPrint("on delection");
          },
          onSelectionChanging: () {
            debugPrint("on slection chnages");
          },
          onTouchDown: (x, y) {
            debugPrint("Touch down at $x , $y");
          },
          onTouchUp: (x, y) {
            debugPrint("Touch up at $x , $y");
          },
          onWordTapped: (word) {
            debugPrint("Word tapped: $word");
          },
          selectAnnotationRange: true,
        ),
        Visibility(
          visible: isLoading,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}
