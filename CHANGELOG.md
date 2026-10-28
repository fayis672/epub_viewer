## 2.2.1

### 📦 Size
- Removed epub.js's source map (`epub.js.map`, 1.1 MB) from the bundled
  assets. It was only for debugging and was shipped inside every app using
  the package.
- The demo GIF is no longer part of the published package (the README
  loads it from GitHub), shrinking the download from 9 MB to about 4 MB.

## 2.2.0

### ⚡ Performance
- Books are now served to the viewer by URL instead of being passed through
  the JavaScript bridge (`EpubViewer.useLocalServer`, on by default on
  Android, iOS and macOS). epub.js opens the book like an unpacked folder and
  reads only the chapters it shows and the images they use. Previously the
  whole file was base64-encoded across the bridge, held in JSZip, and every
  image, font and stylesheet was unpacked into a blob URL before the first
  page appeared. On a 26.5 MB illustrated book the first page now appears
  4–5× sooner (Android emulator 7.1 s → 1.6 s, iOS simulator 0.93 s →
  0.34 s) and peak memory on Android drops from 1140 MB to 577 MB. See
  "How books are loaded" in the README for all measurements.
  - Android serves books through request interception, so no cleartext
    configuration is needed; iOS and macOS use a loopback server on
    `127.0.0.1`. Books are only reachable under a random per-book token.
  - `EpubSource.fromUrl` now downloads straight to a temporary file instead of
    memory (deleted when the viewer closes or changes book).
  - Archives that cannot be served this way (ZIP64, encrypted) fall back to
    the previous in-memory path automatically.
- Search loads each chapter once (and four at a time) instead of once per
  hit, so common words no longer trigger thousands of chapter loads.
- Location generation waits 10 ms between chapters instead of epub.js's
  default 100 ms, which dominated the time on long books, and fetches the
  next chapters while the current one is parsed. A 300-chapter book is ready
  in about 5.6 s instead of 31 s on the iOS simulator.
- Search and location speedups also apply on web, which keeps loading the
  whole book in memory (`useLocalServer` is ignored there).

### 🐛 Fixes
- iOS: `next()` / `prev()` turned the page but `onRelocated` did not fire, so
  the app kept reporting the previous location (WebKit does not always fire
  the scroll event epub.js relies on). Possibly related to #64.
- Swapping `epubSource`: the previous book is now fully released even when
  epub.js throws while destroying its views, and its pages no longer remain
  in the view.
- Load errors from failed requests now carry a readable message
  (`HTTP 404`, `request error`) instead of `[object ProgressEvent]`.

### 🧹 Cleanup
- Removed verbose debug logging from the viewer (step-by-step load traces,
  touch and navigation logs, forwarding of every WebView console message).
  Errors from the reader page are still printed in debug builds.
- Example app: removed debug prints; shows load errors in a snackbar.

### 📖 Docs
- README rewritten around tasks: short platform setup (Android `INTERNET`
  permission for release builds, macOS entitlements), guides for loading,
  navigation, progress, search, selection, footnotes and themes,
  troubleshooting, an API overview, and performance measurements.
- Android no longer needs `usesCleartextTraffic` for the viewer.

### 🧪 Tests
- End-to-end tests on real WebViews (`example/integration_test`) for every
  source type, load errors, source swapping, location caching and lazy
  loading, run in both loading modes; plus a before/after benchmark
  (`epub_performance_test.dart`) and an Android memory script
  (`example/tool/measure_memory.sh`).

## 2.1.0

### ✨ New
- `EpubViewer.onFootnoteTapped` — receive footnote taps as an `EpubFootnote`
  (text, HTML, href) instead of navigating to the note, e.g. to show the note
  in a bottom sheet. Opt-in: without the callback, footnote links navigate as
  before (#84).
- `EpubLocation.chapterPage`, `chapterTotalPages` (screen pages within the
  current chapter, paginated flow) and `printedPage` (from the book's page
  list, when present) (#101).
- `EpubViewer.onLoadError` — receive an `EpubLoadException` when a book cannot
  be opened (missing file or asset, HTTP error, invalid EPUB). Previously the
  error was unhandled and the viewer stayed blank. Without the callback, the
  error goes to `FlutterError.reportError`.
- Location caching: `EpubViewer.onLocationsGenerated` hands you the generated
  locations; pass them back as `initialLocations` next time to skip
  generation, so progress is available immediately on large books.
- Changing `EpubViewer.epubSource` now loads the new book in place; the
  previous book is destroyed instead of leaking.

### 🐛 Fixes
- Table of contents entries now navigate correctly in books whose nav/NCX file
  is in a subfolder (hrefs like `../Text/ch1.xhtml`); `EpubChapter.href` is
  now relative to the package folder (#112).
- `progress` is no longer stuck at 0 after opening a book at `initialCfi`:
  the location is re-sent once locations are generated, and
  `getCurrentLocation()` computes progress from the current position (#28).
- The first page appears sooner on large books: location generation now
  starts after the first page is displayed (#100, #39, #72).
- `EpubSource` loads lazily and sources are compared by what they point at,
  so creating one inside `build()` no longer re-reads or re-downloads the book
  on every rebuild. A failed load is retried on the next access.
- `EpubSource.fromUrl` accepts any 2xx response and reports the HTTP status on
  failure.
- Search loads one chapter at a time instead of all at once, avoiding memory
  spikes on large books; a chapter that fails to load is skipped.
- `EpubSource.fromFile(File(...))` no longer shows an analyzer type error in
  apps (the conditional import defaulted to the web `File` stub).

### 🔒 Security
- Updated the bundled JSZip from 3.1.5 to 3.10.1. Versions before 3.7.0 allow
  prototype pollution through crafted file names in a zip
  (CVE-2021-23413), which a malicious EPUB could trigger.

### ⚠️ Requirements
- Now depends on `flutter_inappwebview: ^6.2.0-beta.3` (needed for macOS).
  On Android this requires your app to use **Android Gradle Plugin 8.9.1+**
  and **`compileSdk` 36+** (from `androidx.browser:browser:1.9.0`).
- macOS: deployment target 10.15+ (Flutter's own minimum).

### 🧹 Maintenance
- Removed the `json_annotation`, `json_serializable` and `build_runner`
  dependencies; models now have hand-written `fromJson` / `toJson` with the
  same JSON keys. `EpubTheme` JSON now also includes `customCss`.
- `EpubController` methods now declare return types (`void` /
  `Future<void>`); no behavior change.
- Example app: Android Gradle Plugin 8.11.1, Gradle 8.14.3, Kotlin 2.2.20,
  Java 17; `flutter_lints` 6. Adds a paginated/scrolled toggle, page info under
  the progress bar and a footnote bottom sheet.

### 📖 Docs
- README: setting the selection highlight color with `::selection` in
  `customCss`, and why the selection handles cannot be styled (#111).
- README: corrected the macOS minimum to 10.15.

### 🔧 Debugging
- Debug builds log `[EPUB-TEST]` diagnostics (load timings, relocations,
  TOC hrefs, footnote lookups) to the console.

## 2.0.0

Adds **Flutter Web** and **macOS** support and a substantial architecture
cleanup for performance, stability and maintainability.

### ✨ New
- **Flutter Web support.** On the web the viewer runs epub.js inside a native
  `<iframe>` (via `HtmlElementView`) and bridges to it with `dart:js_interop`
  instead of a webview plugin — all `EpubController`/`EpubViewer` APIs and
  callbacks work the same as on mobile.
- **macOS support.** macOS reuses the existing `flutter_inappwebview` (WKWebView)
  rendering path as iOS/Android, so all APIs and callbacks behave the same.
  Requires macOS 10.13+ (per `flutter_inappwebview`).
- `EpubSource.fromData(Uint8List)` — load an EPUB from in-memory bytes
  (recommended on the web, where `fromFile` is unavailable and `fromUrl` is
  subject to CORS).
- `EpubContextMenu` / `EpubContextMenuItem` — package-owned selection context
  menu types (mobile), replacing the re-exported `flutter_inappwebview` types.
- `EpubController.requestTimeout` — configurable timeout for request/response
  calls (default 20s).

### 🩹 Stability
- Request/response calls (`getCurrentLocation`, `search`, `extractText`,
  `getRectFromCfi`, `extractCurrentPageText`, `getMetadata`, `getChapters`) now
  return their values directly and **time out** instead of hanging forever if the
  JS side fails to reply. The previous shared-`Completer` design could hang or
  drop concurrent calls.
- `getRectFromCfi` now works (it previously called a JS function that did not
  exist and never completed).
- Annotation taps now reliably fire `onAnnotationClicked` (the `markClicked`
  event was never emitted to Dart before).

### ⚡ Performance
- Text-selection **polling is disabled on web/desktop** (browsers fire
  `selectionchange` reliably), removing perpetual background 200ms/2000ms timers.
  Mobile keeps the iOS/iPad polling fallback.
- Mobile transfers the EPUB bytes to JS as **base64** instead of a decimal array
  literal (a 4 MB book is ~5.5 MB of source instead of ~16 MB).

### 🧹 Maintainability
- `EpubController` no longer depends on `flutter_inappwebview` directly; all
  platform communication goes through an `EpubWebViewController` bridge.
- `loadBook` now takes an options object instead of 16 positional arguments.
- CFI/XPath conversion helpers were extracted from `epubView.js` into
  `epub_cfi_utils.js` (main glue file reduced by ~700 lines).
- Added a unit-test suite (controller RPC/parsing/timeout + model round-trips).

### ⚠️ Breaking changes
- The package no longer re-exports `ContextMenu`, `ContextMenuSettings`,
  `ContextMenuItem` from `flutter_inappwebview`. Use `EpubContextMenu` and
  `EpubContextMenuItem`:
  ```dart
  // before
  selectionContextMenu: ContextMenu(
    menuItems: [ContextMenuItem(id: 1, title: 'Highlight', action: ...)],
    settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
  ),
  // after
  selectionContextMenu: EpubContextMenu(
    hideDefaultSystemItems: true,
    items: [EpubContextMenuItem(id: 1, title: 'Highlight', action: ...)],
  ),
  ```
- `EpubController.webViewController` is now `EpubWebViewController?` (was
  `InAppWebViewController?`). The removed internal members
  `searchResultCompleter`, `currentLocationCompleter`, `cfiRectCompleter` and
  `completePageText()` were implementation details and are gone.
- Request methods now throw `TimeoutException` (from `dart:async`) on timeout.

## 1.2.8
- Fixed `getCurrentLocation` function

## 1.2.7
- Added `customCss` support in `EpubTheme` for granular styling

## 1.2.6
- Fixed dispose issue ([#71](https://github.com/fayis672/epub_viewer/issues/71))

## 1.2.5
- Added onTouchUp and onTouchDown ([#93](https://github.com/fayis672/epub_viewer/pull/93))
- Add selectAnnotationRange parameter to control annotation selection behavior ([#96](https://github.com/fayis672/epub_viewer/pull/96))
- Block navigation while text is selected ([#92](https://github.com/fayis672/epub_viewer/pull/92))
- Add XPath/XPointer support for EPUB navigation and search ([#89](https://github.com/fayis672/epub_viewer/pull/89))

## 1.2.4
- Initial progress fixes
- Relocation on font change fixes
- background decoration fixes
- Added onSelection callback with WebView-relative coordinates for custom selection UI
- Added onSelectionChanging callback for detecting selection handle dragging
- Added onDeselection callback for selection cleared events
- Added clearSelectionOnPageChange property to control selection behavior on navigation
- Fixed suppressNativeContextMenu to properly hide native context menu
- Fixed text selection coordinate mapping for accurate positioning

## 1.2.3
- iOS chapter parsing fixes

## 1.2.2
- Added book metadata

## 1.2.1
- Fixed book loading issues
- Fixed font size adjust issues
- Added change theme function
- Added navigation to first and last pages

## 1.2.0
- Added Epub Theme with background and foreground color

## 1.1.6
- Remove Highlight fix

## 1.1.5
- LTR -RTL fixes
- Sub chapter parsing fixes
- Fixed `onRelocated` callback on Android
- Changed Default display settings

## 1.1.4

- Size fit fixes

## 1.1.3

- Added reading progress

## 1.1.2

- Added Annotation click handler

## 1.1.1

- Fixed book reloading issues

## 1.1.0

- Added Local file and asset support
- Added underline annotation
- Added text content extraction

## 1.0.2

- Document changes

## 1.0.1

- Fixed blank screen

## 1.0.0

- Highlight text
- Search in Epub
- List chapters
- Text selection
- Highly customizable UI
- Resume reading using cfi
- Custom context menus for selection
