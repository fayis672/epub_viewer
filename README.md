# Flutter Epub Viewer

[![Pub Version](https://img.shields.io/pub/v/flutter_epub_viewer?color=blue)](https://pub.dev/packages/flutter_epub_viewer)
[![License](https://img.shields.io/github/license/fayis672/epub_viewer)](https://github.com/fayis672/epub_viewer/blob/main/LICENSE)

A complete EPUB reader for Flutter in one widget. It pages through books, tracks
reading progress, searches, highlights, shows footnotes and applies themes, on
Android, iOS, macOS and the web. Rendering is done by
[epub.js](https://github.com/futurepress/epub.js) inside a WebView.

<img width="50%" src="https://github.com/fayis672/epub_viewer/blob/main/example/epub_viewr_exp.gif?raw=true" alt="Demo GIF">

| Android | iOS | macOS | Web |
| :---: | :---: | :---: | :---: |
| ✅ | ✅ | ✅ (10.15+) | ✅ |

**Contents:** [Install](#install) · [Quick start](#quick-start) · [Guides](#guides) ·
[Troubleshooting](#troubleshooting) · [API overview](#api-overview) ·
[Performance](#performance) · [Known issues](#known-issues) · [Contributing](#contributing)

## Install

```shell
flutter pub add flutter_epub_viewer
```

Then set up the platforms you ship on:

**Android**: nothing for the viewer itself. If you load books from the network,
declare the `INTERNET` permission in `android/app/src/main/AndroidManifest.xml`.
Flutter only adds it to debug builds:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS**: nothing.

**macOS**: use a deployment target of 10.15 or higher (`platform :osx, '10.15'` in
`macos/Podfile`). Add these entitlements to both `macos/Runner/DebugProfile.entitlements`
and `macos/Runner/Release.entitlements`; the viewer serves its page and the book
from `127.0.0.1`:

```xml
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

**Web**: nothing. See [web notes](#web) for what differs.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final controller = EpubController();
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${(progress * 100).round()}%')),
      body: SafeArea(
        child: EpubViewer(
          epubController: controller,
          epubSource: EpubSource.fromAsset('assets/book.epub'),
          onRelocated: (location) => setState(() => progress = location.progress),
        ),
      ),
    );
  }
}
```

The [example app](example/lib/main.dart) builds on this with a chapter list,
search, highlights, footnote popups and error handling.

## Guides

### Loading a book

```dart
EpubSource.fromAsset('assets/book.epub')
EpubSource.fromFile(File(path))
EpubSource.fromUrl(url, headers: {'Authorization': 'Bearer …'})
EpubSource.fromData(bytes)
```

Sources are read only when the viewer needs them. To open another book, pass a
new source to the same `EpubViewer`; the previous book is released.

If a book cannot be opened (missing file, HTTP error, not an EPUB), the viewer
calls `onLoadError` instead of staying blank:

```dart
onLoadError: (error) => showError('Could not open the book: ${error.message}'),
```

### Navigating

```dart
controller.next();
controller.prev();
controller.display(cfi: chapter.href);   // a chapter, or any CFI
controller.toProgressPercentage(0.5);
controller.moveToFistPage();
controller.moveToLastPage();
```

`onChaptersLoaded` gives the table of contents as `EpubChapter`s (`title`,
`href`, nested `subitems`), ready for a drawer or list.

### Saving and restoring progress

Every page change calls `onRelocated` with an `EpubLocation`:

| Field | Meaning |
| :--- | :--- |
| `startCfi` / `endCfi` | Position of the page; save `startCfi` to resume later. |
| `startXpath` / `endXpath` | The same position as XPath, when it can be resolved. |
| `progress` | 0–1 through the whole book. |
| `chapterPage` / `chapterTotalPages` | Screen page within the current chapter (paginated flow). |

Pass the saved CFI back as `initialCfi` (or an XPath as `initialXPath`) to resume.

`progress` depends on the book's *locations*, which the viewer computes after
opening by reading every chapter once (`onLocationLoaded` fires when they are
ready). Save them per book to make progress available instantly next time:

```dart
EpubViewer(
  epubController: controller,
  epubSource: source,
  initialCfi: savedCfi,
  initialLocations: savedLocations,   // null on the first open
  onLocationsGenerated: (locations) => store.saveLocations(bookId, locations),
  onRelocated: (location) => store.saveCfi(bookId, location.startCfi),
)
```

### Search

```dart
final results = await controller.search(query: 'whale');
for (final r in results) {
  print(r.excerpt);                 // text around the match
}
controller.display(cfi: results.first.cfi);
```

### Selection, highlights and context menus

`onTextSelected` gives the selected text and its CFI range. Use the range to
annotate:

```dart
controller.addHighlight(cfi: cfiRange, color: Colors.yellow);
controller.addUnderline(cfi: cfiRange);
controller.removeHighlight(cfi: cfiRange);
controller.removeUnderline(cfi: cfiRange);
```

Tapping an annotation calls `onAnnotationClicked` with its range.

Add actions to the system selection menu (Android, iOS, macOS):

```dart
selectionContextMenu: EpubContextMenu(
  hideDefaultSystemItems: true,
  items: [
    EpubContextMenuItem(id: 1, title: 'Highlight',
        action: () => controller.addHighlight(cfi: selectedCfi)),
  ],
),
```

Or draw your own menu: set `suppressNativeContextMenu: true` and position it
with `onSelection`, which gives the selection's rect. `onSelectionChanging` and
`onDeselection` tell you when to hide it.

Text helpers: `extractText(startCfi:, endCfi:)`, `extractCurrentPageText()` and
`getRectFromCfi(cfiRange)`.

### Footnotes

Set `onFootnoteTapped` and footnote links stop navigating away. You get an
`EpubFootnote` with the note's `text`, `html` and `href` to show in your own
popup:

```dart
onFootnoteTapped: (note) => showModalBottomSheet(
  context: context,
  builder: (_) => Padding(padding: const EdgeInsets.all(16), child: Text(note.text)),
),
```

### Themes and display

Initial settings go in `displaySettings`:

```dart
displaySettings: EpubDisplaySettings(
  flow: EpubFlow.paginated,      // or EpubFlow.scrolled
  snap: true,
  fontSize: 18,
  theme: EpubTheme.dark(),       // light(), dark() or custom(...)
),
```

Change them while reading with `setFlow`, `setFontSize`, `setSpread`,
`setManager` and `updateTheme`.

Custom themes take colors and CSS:

```dart
EpubTheme.custom(
  backgroundDecoration: const BoxDecoration(color: Color(0xFFFBF0D9)),
  foregroundColor: const Color(0xFF3B2F2F),
  customCss: {
    'p': {'font-family': 'Georgia, serif', 'line-height': '1.6'},
    '::selection': {'background': 'rgba(255, 200, 0, 0.4)'},
  },
);
```

Selection handles are drawn by the OS and can't be styled with CSS: on Android
they follow your theme's `colorControlActivated` / `colorAccent`, on iOS the
system tint.

`allowScriptedContent` runs scripts embedded in the book. Keep it `false` (the
default) for books you don't trust.

### Web

- Use `EpubSource.fromAsset` or `fromData`. `fromUrl` needs a server that sends
  CORS headers, and `fromFile` is unavailable.
- The book is drawn in an `<iframe>` above the Flutter scene, so Flutter widgets
  placed over it (a `Drawer`, dialog or pushed route) may not receive taps. Put
  controls beside the viewer, e.g. in the `AppBar` or a side panel, as the
  example app does.
- `selectionContextMenu` is ignored; use `onSelection` for a custom menu.

## Troubleshooting

**macOS shows a blank page.** The `network.server` entitlement is missing; see
[Install](#install).

**`fromUrl` works in debug but not in release on Android.** Add the `INTERNET`
permission; see [Install](#install).

**`fromUrl` fails on the web.** The server must allow your origin with CORS
headers. Download the bytes yourself and use `fromData` if you can't change it.

**`progress` is 0 right after opening.** Locations are still being generated.
Wait for `onLocationLoaded`, or cache them with `initialLocations`.

**Requests like `search` throw `TimeoutException`.** The viewer didn't answer in
time, e.g. a very long search. Raise `controller.requestTimeout`.

## API overview

Full documentation is on [pub.dev](https://pub.dev/documentation/flutter_epub_viewer/latest/).

**`EpubViewer`**

| Parameter | Description |
| :--- | :--- |
| `epubController`, `epubSource` | **Required.** The controller and the book. |
| `initialCfi`, `initialXPath` | Position to open at. |
| `initialLocations` | Cached locations from `onLocationsGenerated`. |
| `displaySettings` | Flow, snap, spread, font size, theme, direction, scripts. |
| `selectionContextMenu` | Extra items for the system selection menu. |
| `suppressNativeContextMenu` | Hide the system selection menu. Default `false`. |
| `clearSelectionOnPageChange` | Default `true`. |
| `selectAnnotationRange` | Tapping an annotation also selects its text. Default `false`. |
| `useLocalServer` | See [Performance](#performance). Default `true`. |

| Callback | Called when |
| :--- | :--- |
| `onEpubLoaded` | The first page is displayed. |
| `onLoadError` | The book can't be opened. |
| `onChaptersLoaded` | The table of contents is ready. |
| `onRelocated` | The page changes. |
| `onLocationLoaded` | Locations are ready; `progress` is accurate from now on. |
| `onLocationsGenerated` | Locations were generated; cache them. |
| `onInitialPositionLoading` / `onInitialPositionLoaded` | Opening at the initial position starts / ends. |
| `onTextSelected` | Text is selected. |
| `onSelection`, `onSelectionChanging`, `onDeselection` | Selection is final / being dragged / cleared. |
| `onAnnotationClicked` | A highlight or underline is tapped. |
| `onFootnoteTapped` | A footnote link is tapped. |
| `onTouchDown`, `onTouchUp` | Touch events, coordinates normalized to 0–1. |

**`EpubController`**

| Area | Methods |
| :--- | :--- |
| Navigation | `next`, `prev`, `display`, `toProgressPercentage`, `moveToFistPage`, `moveToLastPage` |
| Information | `getCurrentLocation`, `getChapters`, `getMetadata`, `search` |
| Annotations | `addHighlight`, `removeHighlight`, `addUnderline`, `removeUnderline` |
| Text | `clearSelection`, `extractText`, `extractCurrentPageText`, `getRectFromCfi` |
| Display | `setFlow`, `setFontSize`, `setSpread`, `setManager`, `updateTheme` |

## Performance

On Android, iOS and macOS the viewer serves the book to the WebView by URL
(`useLocalServer: true`, the default). epub.js then opens it like an unpacked
folder and reads only the chapters it displays and the images, fonts and
styles they use.

- **Android** answers the WebView's requests itself, so no port is opened and no
  cleartext configuration is needed.
- **iOS / macOS** use a server on `127.0.0.1` with a random port. Each book is
  reachable only under a random 128-bit token while it is open.
- `fromUrl` books are downloaded to a temporary file first, which is deleted
  when the book is closed.
- ZIP64 and encrypted archives fall back to in-memory loading automatically.

With `useLocalServer: false`, and always on the web, the whole book is passed to
the WebView, and every image, font and stylesheet is unpacked before the first
page appears.

Measured with `example/integration_test/epub_performance_test.dart`: median of 3
runs, in milliseconds from mounting the viewer. These are debug builds on the
Android emulator (Pixel 8, API 36) and the iOS simulator (iPhone 17), so compare
within a row; release builds on devices are faster across the board. *Search*
looks for a word with thousands of hits.

| Book | Measure | 2.1.0 | 2.2.0, `useLocalServer: false` | 2.2.0, default |
| :--- | :--- | ---: | ---: | ---: |
| Illustrated, 40 chapters + 40 images (26.5 MB) | First page, Android | 7 130 | 6 372 | **1 583** |
| | First page, iOS | 932 | 827 | **336** |
| | Locations ready, Android | 13 753 | 7 791 | **3 589** |
| | Locations ready, iOS | 5 030 | 1 500 | **1 018** |
| | Search, Android | 20 738 | 1 578 | 2 294 |
| | Search, iOS | 900 | 133 | **102** |
| Text only, 300 chapters (1.2 MB) | Locations ready, Android | did not finish¹ | 11 442 | **10 117** |
| | Locations ready, iOS | 31 089 | 5 551 | 5 552 |
| | Search, iOS | 8 533 | 844 | **783** |
| Peak memory, app + WebView, Android | All three books | 1 140 MB | 822 MB | **577 MB** |

¹ The test lost its connection to the app during this book, in both 2.1.0 runs.

Page turns take the same time in all three.

## Known issues

- **No whole-book page count.** It would require laying out every chapter. Use
  `progress`, or `chapterPage` / `chapterTotalPages`.
- **Printed page numbers.** `EpubLocation.printedPage` is null for most books, even
  those with a page list ([#101](https://github.com/fayis672/epub_viewer/issues/101)).
- **Scrolled flow.** Chapter navigation can land past the requested position
  ([#27](https://github.com/fayis672/epub_viewer/issues/27)).
- **Android snap animation.** `onRelocated` may not fire when
  `useSnapAnimationAndroid` is `true`.
- **OPF sources.** Opening an unpacked book by its `.opf` file is not fully tested.

## Upgrading from 1.x

- Use `EpubContextMenu` / `EpubContextMenuItem` instead of `flutter_inappwebview`'s
  `ContextMenu`, which is no longer re-exported.
- Request methods (`getCurrentLocation`, `search`, `extractText`, …) return their
  values directly and throw `TimeoutException` instead of hanging.

All changes are in the [CHANGELOG](CHANGELOG.md).

## Contributing

Issues and pull requests are welcome. Please follow the existing style and add
tests with your change.

```shell
flutter test                                    # unit tests

cd example
flutter test integration_test/epub_loading_test.dart -d <device>       # end-to-end
flutter test integration_test/epub_performance_test.dart -d <device>   # benchmark
tool/measure_memory.sh [android-serial]                                # Android peak memory
```

The end-to-end tests drive real WebViews in both loading modes. They cover every
source type, load errors, book swapping, cached locations and lazy reading. On
macOS keep the test window visible and the lid open; hidden WebViews are
throttled and the tests time out.

## License

MIT. See [LICENSE](LICENSE).

Built on [epub.js](https://github.com/futurepress/epub.js) and
[flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview). Thanks to
everyone who has contributed:

<a href="https://github.com/fayis672/epub_viewer/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=fayis672/epub_viewer" />
</a>
