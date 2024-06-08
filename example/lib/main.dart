import 'package:epub_viewer/epub_viewer.dart';
import 'package:example/chapter_drawer.dart';
import 'package:example/search_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ChapterDrawer(
        controller: epubController,
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
        ],
      ),
      body: SafeArea(
          child: Column(
        children: [
          Expanded(
            child: EpubViewer(
              epubUrl: 'https://s3.amazonaws.com/moby-dick/OPS/package.opf',
              epubController: epubController,
              displaySettings:
                  EpubDisplaySettings(flow: EpubFlow.paginated, snap: true),
              selectionContextMenu: ContextMenu(
                menuItems: [
                  ContextMenuItem(
                    title: "Highlight",
                    id: 1,
                    action: () async {
                      epubController.addHighlight(cfi: textSelectionCfi);
                    },
                  ),
                ],
                settings: ContextMenuSettings(
                    hideDefaultSystemContextMenuItems: true),
              ),
              headers: {},
              onChaptersLoaded: (chapters) {},
              onEpubLoaded: () async {
                print('Epub loaded');
              },
              onRelocated: (value) {
                print("Reloacted to $value");
              },
              onTextSelected: (epubTextSelection) {
                textSelectionCfi = epubTextSelection.selectionCfi;
                print(textSelectionCfi);
              },
            ),
          ),
        ],
      )),
    );
  }
}
