A Flutter package for viewing Epub documents, developed by combining the power of [Epubjs](https://github.com/futurepress/epub.js) and [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview)

## Features

- Highlight text
- Search in Epub
- List chapters
- Text selection
- Highly customizable UI
- Resume reading using cfi
- Custom context menus for selection
- Load from File, URl, Assets

<img width='50%' src="https://github.com/fayis672/epub_viewer/blob/main/example/epub_viewr_exp.gif?raw=true">

## Limitations

- opf format not supported fully

## Getting started

In your Flutter project add the dependency:

```shell
flutter pub add flutter_epub_viewer
```

- ### Important: Complete the platfrom-wise setup from [here](https://inappwebview.dev/docs/intro)
- Enable clear text traffic, [instructions here](https://stackoverflow.com/questions/45940861/android-8-cleartext-http-traffic-not-permitted/50834600#50834600)

Make sure to follow and complete each step

## Usage

### Basic usage

```dart
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter/material.dart';

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
      body: SafeArea(
          child: Column(
        children: [
          Expanded(
            child: EpubViewer(
              epubSource: EpubSource.fromUrl(
                  'https://github.com/IDPF/epub3-samples/releases/download/20230704/accessible_epub_3.epub'),
              epubController: epubController,
              displaySettings:
                  EpubDisplaySettings(flow: EpubFlow.paginated, snap: true),
              onChaptersLoaded: (chapters) {},
              onEpubLoaded: () async {},
              onRelocated: (value) {},
              onTextSelected: (epubTextSelection) {},
            ),
          ),
        ],
      )),
    );
  }
}

```

### Parameters and callbacks

```dart
//Epub controller to manage epub
final  EpubController  epubController;

///Epub source, accepts url, file or assets
///opf format is not tested, use with caution
final  String  epubSource;

///Epub headers to load epub from network
final  Map<String, String> headers;

///Initial cfi string to specify which part of epub to load initially
///if null, the first chapter will be loaded
final  String?  initialCfi;

///Call back when epub is loaded and displayed
final  VoidCallback?  onEpubLoaded;

///Call back when chapters are loaded
final  ValueChanged<List<EpubChapter>>?  onChaptersLoaded;

///Call back when epub page changes
final  ValueChanged<EpubLocation>?  onRelocated;

///Call back when text selection changes
final  ValueChanged<EpubTextSelection>?  onTextSelected;

///Callback for handling annotation click (Highlight and Underline)
final ValueChanged<String>? onAnnotationClicked;

///initial display settings
final  EpubDisplaySettings?  displaySettings;

///context menu for text selection
///if null, the default context menu will be used
final  ContextMenu?  selectionContextMenu;
```

### Methods

```dart
///Move epub view to a specific area using Cfi string or chapter href
epubController.display(cfi:cfiString)

///moves to next page
epubController.next()

///Moves to the previous page in epub view
epubController.prev()

///Returns the current location of epub viewer
epubController.getCurrentLocation()

///Returns list of [EpubChapter] from epub,
/// should be called after onChaptersLoaded callback, otherwise returns empty list
epubController.getChapters()

///Search in epub using query string
///Returns a list of [EpubSearchResult]
epubController.search(query:query)

///Adds a highlight to epub viewer
epubController.addHighlight(
	cfi:cfiString,
	color:color
	opacity:0,5
)

///remove highlight
epubController.removeHighlight(cfi:cfi)

///Add underline annotation
epubController.addUnderline(cfi:cfi)

///Remove underline annotation
epubController.removeUnderline(cfi:cfi)

///Set [EpubSpread] value
epubController.setSpread(spread:spread)

///Set [EpubFlow] value
epubController.setFlow(flow:flow)

///Set [EpubManager] value
epubController.setManager(manager:manager)

///Adjust font size in epub viewer
epubController.setFontSize(fontSize:16)

///Extract text from a given cfi range
epubController.extractText(startCfi:cfi,endCfi:cfi)

///Extract text from current page
epubController.extractCurrentPageText()

 ///Given a percentage moves to the corresponding page
///Progress percentage should be between 0.0 and 1.0
epubController.toProgressPercentage(progressPercent)

///Move to the first page
 epubController.moveToFistPage();

///Move to the last page
 epubController.moveToLastPage();
```

## Known Issues

- `onRelocated` callback is broken when `useSnapAnimationAndroid==true` in `epubDisplaySettings` for android
- in `scrolled` flow, chapter navigation breaks initially.

## Upcoming features

- Annotations customization
- More callbacks (rendered, error etc)
