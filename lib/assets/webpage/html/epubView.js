var book = ePub();
var rendition;
var displayed;
var chapters = [];
var bookmarks = [];
var highlights = [];
var underlines = [];
var currentTheme = "default";
var currentFontSize = 16;
var currentFontFamily = "sans-serif";
var currentLineHeight = "1.5";
var currentLetterSpacing = "normal";

// Try to load saved state from localStorage
try {
  const savedState = localStorage.getItem('epubReaderState');
  if (savedState) {
    const state = JSON.parse(savedState);
    currentTheme = state.theme || "default";
    currentFontSize = state.fontSize || 16;
    currentFontFamily = state.fontFamily || "sans-serif";
    currentLineHeight = state.lineHeight || "1.5";
    currentLetterSpacing = state.letterSpacing || "normal";
    bookmarks = state.bookmarks || [];
    highlights = state.highlights || [];
    underlines = state.underlines || [];
  }
} catch (e) {
  console.error("Error loading saved state:", e);
}



function loadBook(data, cfi, manager, flow, spread, snap, allowScriptedContent, direction, useCustomSwipe, backgroundColor, foregroundColor) {
  var viewportHeight = window.innerHeight;
  document.getElementById('viewer').style.height = viewportHeight;
  var uint8Array = new Uint8Array(data)
  book.open(uint8Array,)
  rendition = book.renderTo("viewer", {
    manager: manager,
    flow: flow,
    // method: "continuous",
    spread: spread,
    width: "100vw",
    height: "100vh",
    snap: snap && !useCustomSwipe,
    allowScriptedContent: allowScriptedContent,
    defaultDirection: direction
  });

  if (cfi) {
    displayed = rendition.display(cfi)
  } else {
    displayed = rendition.display()
  }

  displayed.then(function (renderer) {
    console.log("displayed")
    window.flutter_inappwebview.callHandler('displayed');

    // Apply saved highlights after book is displayed
    if (highlights && highlights.length > 0) {
      highlights.forEach(highlight => {
        rendition.annotations.highlight(
          highlight.cfi,
          {},
          (e) => { },
          "hl",
          {
            "fill": highlight.color,
            "fill-opacity": highlight.opacity.toString(),
            "mix-blend-mode": "multiply"
          }
        );
      });
    }

    // Apply saved underlines after book is displayed
    if (underlines && underlines.length > 0) {
      underlines.forEach(underline => {
        rendition.annotations.underline(
          underline.cfi,
          {},
          (e) => { },
          "ul",
          {
            "stroke": underline.color,
            "stroke-opacity": underline.opacity.toString(),
            "stroke-width": underline.thickness.toString() + "px"
          }
        );
      });
    }
  });

  book.loaded.navigation.then(function (toc) {
    chapters = parseChapters(toc);
    window.flutter_inappwebview.callHandler('chapters');
  });

  rendition.on("rendered", function (section) {
    window.flutter_inappwebview.callHandler('rendered');
    // Optimize images when new content is rendered
    optimizeImages();
  });

  rendition.hooks.content.register((contents) => {
    if (useCustomSwipe) {
      const el = contents.document.documentElement;
      if (el) {
        detectSwipe(el, function (el, direction) {
          if (direction == 'l') {
            rendition.next();
          }
          if (direction == 'r') {
            rendition.prev();
          }
        });
      }
    }
  });

  //set background and foreground color
  updateTheme(backgroundColor, foregroundColor);

  ///text selection callback
  rendition.on("selected", function (cfiRange, contents) {
    book.getRange(cfiRange).then(function (range) {
      var selectedText = range.toString();
      var args = [cfiRange.toString(), selectedText]
      window.flutter_inappwebview.callHandler('selection', ...args);
    })
  });

  //book location changes callback
  rendition.on('relocated', function (locationData) {
    displayed = locationData;
    var percent = locationData.start.percentage;
    var locationObj = {
      startCfi: locationData.start.cfi,
      endCfi: locationData.end.cfi,
      progress: percent
    };
    var args = [locationObj];
    window.flutter_inappwebview.callHandler('relocated', ...args);

    // Also send the enhanced location data
    // Check if book.locations is available before using it
    let percentage = percent; // Default to the basic percentage if locations not available
    if (book.locations && book.locations.percentageFromCfi) {
      try {
        percentage = book.locations.percentageFromCfi(locationObj.startCfi) || percent;
      } catch (e) {
        console.error("Error calculating percentage from CFI:", e);
      }
    }

    const progress = Math.round(percentage * 100);
    const currentLocation = {
      cfi: locationObj.startCfi,
      chapterName: locationData.start ? locationData.start.chapterName : '',
      chapterHref: locationData.start ? locationData.start.href : '',
      percentage: percentage,
      progress: progress
    };

    const locationArgs = [currentLocation];
    window.flutter_inappwebview.callHandler('locationChanged', ...locationArgs);

    // Optimize memory by lazy loading chapters
    if (typeof lazyLoadChapters === 'function') {
      lazyLoadChapters();
    }
  });

  rendition.on('displayError', function (e) {
    console.log("displayError")
    window.flutter_inappwebview.callHandler('displayError');
  })

  rendition.on('markClicked', function (cfiRange) {
    console.log("markClicked");
    var args = [cfiRange.toString()];
    window.flutter_inappwebview.callHandler('markClicked', ...args);
  });
}

book.ready.then(function () {
  book.locations.generate(1600);
});

window.addEventListener("flutterInAppWebViewPlatformReady", function (event) {
  window.flutter_inappwebview.callHandler('readyToLoad');
});

//move to next page
function next() {
  rendition.next();
}

//move to previous page
function previous() {
  rendition.prev();
}

//move to given cfi location
function toCfi(cfi) {
  rendition.display(cfi);
}

//get all chapters
function getChapters() {
  return chapters;
}

function getCurrentLocation() {
  var percent = rendition.location.start.percentage;
  var location = {
    startCfi: rendition.location.start.cfi,
    endCfi: rendition.location.end.cfi,
    progress: percent
  };
  return location;
}

///parsing chapters and subitems recursively
var parseChapters = function (toc) {
  var chapters = [];
  toc.forEach(function (chapter) {
    const matchedSpine = book.spine.items.find(item => item.href.includes(chapter.href));
    chapters.push({
      title: chapter.label,
      href: matchedSpine ? matchedSpine.href : chapter.href,
      id: chapter.id,
      subitems: parseChapters(chapter.subitems)
    });
  });
  return chapters;
};

function searchInBook(query) {
  search(query).then(function (data) {
    var args = [data];
    window.flutter_inappwebview.callHandler('search', ...args);
  });
}

function search(q) {
  return Promise.all(
    book.spine.spineItems.map(item => item.load(book.load.bind(book)).then(item.find.bind(item, q)).finally(item.unload.bind(item)))
  ).then(results => Promise.resolve([].concat.apply([], results)));
}

function getCurrentPageText() {
  var startCfi = rendition.location.start.cfi
  var endCfi = rendition.location.end.cfi
  var cfiRange = makeRangeCfi(startCfi, endCfi)
  book.getRange(cfiRange).then(function (range) {
    var text = range.toString();
    var args = [text, cfiRange]
    window.flutter_inappwebview.callHandler('epubText', ...args);
  })
}

function getTextFromCfi(startCfi, endCfi) {
  var cfiRange = makeRangeCfi(startCfi, endCfi)
  book.getRange(cfiRange).then(function (range) {
    var text = range.toString();
    var args = [text, cfiRange]
    window.flutter_inappwebview.callHandler('epubText', ...args);
  })
}

///update theme
function updateTheme(backgroundColor, foregroundColor) {
  if (backgroundColor && foregroundColor) {
    rendition.themes.register("custom", { "body": { "background": backgroundColor, "color": foregroundColor } });
    rendition.themes.select("custom");
    currentTheme = "custom";
    saveReadingState();
  }
}

/**
 * Register a new theme with custom styles
 * @param {string} name - Theme name
 * @param {object} styles - CSS styles object
 */
function registerTheme(name, styles) {
  rendition.themes.register(name, styles);
  saveReadingState();
}

/**
 * Select a theme by name or apply theme properties
 * @param {string|object} theme - Theme name as string or theme object with properties
 */
function selectTheme(theme) {
  // Store current location
  const currentCfi = rendition.location ? rendition.location.start.cfi : null;

  if (typeof theme === 'string') {
    rendition.themes.select(theme);
    currentTheme = theme;
  } else if (typeof theme === 'object') {
    const backgroundColor = theme.backgroundColor ? '#' + (theme.backgroundColor >>> 0).toString(16).padStart(8, '0').substring(2) : null;
    const foregroundColor = theme.foregroundColor ? '#' + (theme.foregroundColor >>> 0).toString(16).padStart(8, '0').substring(2) : null;

    const themeName = theme.themeType || 'custom';

    // Apply theme directly to iframe documents
    try {
      const iframes = document.querySelectorAll('iframe');
      iframes.forEach(iframe => {
        try {
          if (iframe.contentDocument) {
            const doc = iframe.contentDocument;
            doc.body.style.backgroundColor = backgroundColor;
            doc.body.style.color = foregroundColor;
            doc.documentElement.style.backgroundColor = backgroundColor;
          }
        } catch (e) {
          console.error('Error applying theme to iframe:', e);
        }
      });
    } catch (e) {
      console.error('Error selecting iframes:', e);
    }

    // Create CSS for the theme
    const themeCSS = {
      'body': {
        'background-color': backgroundColor,
        'color': foregroundColor
      }
    };

    // Register and select the theme
    rendition.themes.register(themeName, themeCSS);
    rendition.themes.select(themeName);
    currentTheme = themeName;

    // Set up a hook for future content
    rendition.hooks.content.register(function (contents) {
      contents.addStylesheetRules({
        'body': {
          'background-color': backgroundColor,
          'color': foregroundColor
        }
      });
    });
  }

  saveReadingState();

  // Force a refresh of the current page
  if (currentCfi) {
    // Small delay to ensure theme is applied
    setTimeout(() => {
      rendition.display(currentCfi);
    }, 50);
  }
}

const makeRangeCfi = (a, b) => {
  const CFI = new ePub.CFI()
  const start = CFI.parse(a), end = CFI.parse(b)
  const cfi = {
    range: true,
    base: start.base,
    path: {
      steps: [],
      terminal: null
    },
    start: start.path,
    end: end.path
  }
  const len = cfi.start.steps.length
  for (let i = 0; i < len; i++) {
    if (CFI.equalStep(cfi.start.steps[i], cfi.end.steps[i])) {
      if (i == len - 1) {
        // Last step is equal, check terminals
        if (cfi.start.terminal === cfi.end.terminal) {
          // CFI's are equal
          cfi.path.steps.push(cfi.start.steps[i])
          // Not a range
          cfi.range = false
        }
      } else cfi.path.steps.push(cfi.start.steps[i])
    } else break
  }
  cfi.start.steps = cfi.start.steps.slice(cfi.path.steps.length)
  cfi.end.steps = cfi.end.steps.slice(cfi.path.steps.length)

  return 'epubcfi(' + CFI.segmentString(cfi.base)
    + '!' + CFI.segmentString(cfi.path)
    + ',' + CFI.segmentString(cfi.start)
    + ',' + CFI.segmentString(cfi.end)
    + ')'
}

function detectSwipe(el, func) {
  swipe_det = new Object();
  swipe_det.sX = 0;
  swipe_det.sY = 0;
  swipe_det.eX = 0;
  swipe_det.eY = 0;
  var min_x = 50;  //min x swipe for horizontal swipe
  var max_x = 40;  //max x difference for vertical swipe
  var min_y = 40;  //min y swipe for vertical swipe
  var max_y = 50;  //max y difference for horizontal swipe
  var direc = "";
  ele = el
  ele.addEventListener('touchstart', function (e) {
    var t = e.touches[0];
    swipe_det.sX = t.screenX;
    swipe_det.sY = t.screenY;
  }, false);
  ele.addEventListener('touchmove', function (e) {
    e.preventDefault();
    var t = e.touches[0];
    swipe_det.eX = t.screenX;
    swipe_det.eY = t.screenY;
  }, { passive: false });
  ele.addEventListener('touchend', function (e) {
    //horizontal detection
    if ((((swipe_det.eX - min_x > swipe_det.sX) || (swipe_det.eX + min_x < swipe_det.sX)) && ((swipe_det.eY < swipe_det.sY + max_y) && (swipe_det.sY > swipe_det.eY - max_y)))) {
      if (swipe_det.eX > swipe_det.sX) direc = "r";
      else direc = "l";
    }
    //vertical detection
    if ((((swipe_det.eY - min_y > swipe_det.sY) || (swipe_det.eY + min_y < swipe_det.sY)) && ((swipe_det.eX < swipe_det.sX + max_x) && (swipe_det.sX > swipe_det.eX - max_x)))) {
      if (swipe_det.eY > swipe_det.sY) direc = "d";
      else direc = "u";
    }

    if (direc != "") {
      if (typeof func == 'function') func(el, direc);
    }
    direc = "";
  }, false);
}

/**
 * Set font family for the book content
 * @param {string} family - Font family name
 */
function setFont(family) {
  currentFontFamily = family;
  rendition.themes.default({
    body: {
      'font-family': family
    }
  });
  saveReadingState();
}

/**
 * Set line height for the book content
 * @param {string} height - Line height value (e.g., '1.5')
 */
function setLineHeight(height) {
  currentLineHeight = height;
  rendition.themes.default({
    body: {
      'line-height': height
    }
  });
  saveReadingState();
}

/**
 * Set letter spacing for the book content
 * @param {string} spacing - Letter spacing value (e.g., 'normal', '0.5px', '1px')
 */
function setLetterSpacing(spacing) {
  currentLetterSpacing = spacing;
  rendition.themes.default({
    body: {
      'letter-spacing': spacing
    }
  });
  saveReadingState();
}

/**
 * Toggle spreads mode (single or double page view)
 * @param {string} spread - 'auto', 'none', etc.
 */
function toggleSpreads(spread) {
  rendition.spread(spread);
  saveReadingState();
}

/**
 * Resize the viewport
 * @param {number} width - Width in pixels
 * @param {number} height - Height in pixels
 */
function setViewportSize(width, height) {
  rendition.resize(width, height);
}

/**
 * Go to the first page of the book
 */
function firstPage() {
  let first = book.spine.first();
  rendition.display(first.href);
}

/**
 * Go to the last page of the book
 */
function lastPage() {
  let last = book.spine.last();
  rendition.display(last.href);
}

/**
 * Go to a specific chapter by ID
 * @param {string} chapterId - Chapter ID or href
 */
function gotoChapter(chapterId) {
  let chapter = book.spine.get(chapterId);
  if (chapter) rendition.display(chapter.href);
}

/**
 * Add a bookmark at the current location
 * @param {string} [customTitle] - Optional custom title for the bookmark
 * @returns {string} The CFI of the bookmark
 */
function addBookmark(customTitle) {
  let cfi = rendition.location.start.cfi;
  let title = customTitle || "";

  // If no custom title provided, try to get the chapter title
  if (!customTitle && rendition.location.start.href) {
    const chapter = book.spine.get(rendition.location.start.href);
    if (chapter && chapter.label) {
      title = chapter.label;
    }
  }

  const bookmark = {
    cfi: cfi,
    title: title || "Bookmark at " + Math.floor(rendition.location.start.percentage * 100) + "%",
    created: new Date().toISOString()
  };

  // Check if bookmark already exists
  const exists = bookmarks.findIndex(b => b.cfi === cfi) >= 0;
  if (!exists) {
    bookmarks.push(bookmark);
    saveReadingState();
  }

  // Notify Flutter
  const args = [bookmarks];
  window.flutter_inappwebview.callHandler('bookmarksUpdated', ...args);

  return cfi;
}

/**
 * Remove a bookmark by its CFI
 * @param {string} cfi - The CFI of the bookmark to remove
 */
function removeBookmark(cfi) {
  const index = bookmarks.findIndex(b => b.cfi === cfi);
  if (index >= 0) {
    bookmarks.splice(index, 1);
    saveReadingState();

    // Notify Flutter
    const args = [bookmarks];
    window.flutter_inappwebview.callHandler('bookmarksUpdated', ...args);
  }
}

/**
 * Get all bookmarks
 * @returns {Array} Array of bookmark objects
 */
function getBookmarks() {
  return bookmarks;
}

/**
 * Get all highlights
 * @returns {Array} Array of highlight objects
 */
function getHighlights() {
  return highlights;
}

/**
 * Get all underlines
 * @returns {Array} Array of underline objects
 */
function getUnderlines() {
  return underlines;
}

/**
 * Add a highlight at the current selection or at a specific CFI
 * @param {string} cfiOrColor - Either the CFI to highlight or the color if highlighting current selection
 * @param {string|number} colorOrOpacity - Either the color if highlighting a specific CFI, or opacity if highlighting current selection
 * @param {number} opacityParam - The opacity if highlighting a specific CFI
 * @returns {string} The CFI of the created highlight
 */
function addHighlight(cfiOrColor, colorOrOpacity, opacityParam, textParam) {
  try {
    let cfi, color, opacity, text;

    // Check if we're highlighting a specific CFI or the current selection
    if (arguments.length >= 2 && typeof colorOrOpacity === 'string') {
      // Case 1: addHighlight(cfi, color, opacity, text) - highlighting a specific CFI
      cfi = cfiOrColor;
      color = colorOrOpacity;
      opacity = opacityParam || 0.3;
      text = textParam || 'Highlighted text';
    } else {
      // Case 2: addHighlight(color, opacity) - highlighting current selection
      if (!rendition || !window.getSelection) return null;

      const selection = window.getSelection();
      if (!selection || selection.rangeCount === 0) return null;

      const range = selection.getRangeAt(0);
      if (!range) return null;

      cfi = rendition.currentLocation().start.cfi;
      if (!cfi) return null;

      color = cfiOrColor || '#ffff00';
      opacity = colorOrOpacity || 0.3;
      text = selection.toString();
    }

    // Create highlight
    rendition.annotations.highlight(
      cfi,
      {},
      (e) => { },
      "hl",
      {
        "fill": color,
        "fill-opacity": opacity.toString(),
        "mix-blend-mode": "multiply"
      }
    );

    // Add to highlights array
    const highlight = {
      cfi: cfi,
      text: text,
      color: color,
      opacity: opacity,
      created: new Date().toISOString()
    };

    highlights.push(highlight);

    // Save state
    saveReadingState();

    // Notify Flutter
    window.flutter_inappwebview.callHandler('highlightsUpdated', highlights);

    return cfi;
  } catch (e) {
    console.error('Error adding highlight:', e);
    return null;
  }
}

/**
 * Remove a highlight by its CFI
 * @param {string} cfi - The CFI of the highlight to remove
 */
function removeHighlight(cfi) {
  try {
    if (!rendition || !cfi) return;

    // Remove the highlight from the rendition
    rendition.annotations.remove(cfi, "highlight");

    // Remove from highlights array
    const index = highlights.findIndex(h => h.cfi === cfi);
    if (index !== -1) {
      highlights.splice(index, 1);
    }

    // Save state
    saveReadingState();

    // Notify Flutter
    window.flutter_inappwebview.callHandler('highlightsUpdated', highlights);
  } catch (e) {
    console.error('Error removing highlight:', e);
  }
}

/**
 * Add an underline at the current selection or at a specific CFI
 * @param {string} cfiOrColor - Either the CFI to underline or the color if underlining current selection
 * @param {string|number} colorOrOpacity - Either the color if underlining a specific CFI, or opacity if underlining current selection
 * @param {number} opacityParam - The opacity if underlining a specific CFI
 * @param {number} thicknessParam - The thickness of the underline in pixels
 * @returns {string} The CFI of the created underline
 */
function addUnderline(cfiOrColor, colorOrOpacity, opacityParam, thicknessParam, textParam) {
  try {
    let cfi, color, opacity, thickness, text;

    // Check if we're underlining a specific CFI or the current selection
    if (arguments.length >= 2 && typeof colorOrOpacity === 'string') {
      // Case 1: addUnderline(cfi, color, opacity, thickness, text) - underlining a specific CFI
      cfi = cfiOrColor;
      color = colorOrOpacity;
      opacity = opacityParam || 0.7;
      thickness = thicknessParam || 1;
      text = textParam || 'Underlined text';
    } else {
      // Case 2: addUnderline(color, opacity, thickness) - underlining current selection
      if (!rendition || !window.getSelection) return null;

      const selection = window.getSelection();
      if (!selection || selection.rangeCount === 0) return null;

      const range = selection.getRangeAt(0);
      if (!range) return null;

      cfi = rendition.currentLocation().start.cfi;
      if (!cfi) return null;

      color = cfiOrColor || '#0000ff';
      opacity = colorOrOpacity || 0.7;
      thickness = thicknessParam || 1;
      text = selection.toString();
    }

    // Create underline
    rendition.annotations.underline(
      cfi,
      {},
      (e) => { },
      "ul",
      {
        "stroke": color,
        "stroke-opacity": opacity.toString(),
        "stroke-width": thickness.toString() + "px"
      }
    );

    // Add to underlines array
    const underline = {
      cfi: cfi,
      text: text,
      color: color,
      opacity: opacity,
      thickness: thickness,
      created: new Date().toISOString()
    };

    underlines.push(underline);

    // Save state
    saveReadingState();

    // Notify Flutter
    window.flutter_inappwebview.callHandler('underlinesUpdated', underlines);

    return cfi;
  } catch (e) {
    console.error('Error adding underline:', e);
    return null;
  }
}

/**
 * Remove an underline by its CFI
 * @param {string} cfi - The CFI of the underline to remove
 */
function removeUnderline(cfi) {
  try {
    if (!rendition || !cfi) return;

    // Remove the underline from the rendition
    rendition.annotations.remove(cfi, "underline");

    // Remove from underlines array
    const index = underlines.findIndex(u => u.cfi === cfi);
    if (index !== -1) {
      underlines.splice(index, 1);
    }

    // Save state
    saveReadingState();

    // Notify Flutter
    window.flutter_inappwebview.callHandler('underlinesUpdated', underlines);
  } catch (e) {
    console.error('Error removing underline:', e);
  }
}

function addMark(cfiString) {
  rendition.annotations.mark(cfiString)
}

function removeMark(cfiString) {
  rendition.annotations.remove(cfiString, "mark");
}

function toProgress(progress) {
  var cfi = book.locations.cfiFromPercentage(progress);
  rendition.display(cfi);
}

// Get page number from CFI
function pageFromCfi(cfi) {
  if (!book.pageList || !book.pageList.pageFromCfi) {
    console.warn("Page list not available");
    return -1;
  }
  return book.pageList.pageFromCfi(cfi);
}

// Get CFI from page number
function cfiFromPage(page) {
  if (!book.pageList || !book.pageList.cfiFromPage) {
    console.warn("Page list not available");
    return null;
  }
  return book.pageList.cfiFromPage(page);
}

// Get page number from percentage
function pageFromPercentage(percentage) {
  if (!book.pageList || !book.pageList.pageFromPercentage) {
    console.warn("Page list not available");
    return -1;
  }
  return book.pageList.pageFromPercentage(percentage);
}

// Get percentage from page number
function percentageFromPage(page) {
  if (!book.pageList || !book.pageList.percentageFromPage) {
    console.warn("Page list not available");
    return -1;
  }
  return book.pageList.percentageFromPage(page);
}

// Get percentage from CFI
function percentageFromCfi(cfi) {
  if (!book.pageList || !book.pageList.percentageFromCfi) {
    console.warn("Page list not available");
    return -1;
  }
  return book.pageList.percentageFromCfi(cfi);
}

/**
 * Lazy load chapters to improve performance
 * Only keeps a few chapters loaded in memory at a time
 */
function lazyLoadChapters() {
  // Only load chapters that are near the current reading position
  const visibleChapters = 2; // Number of chapters to keep loaded before and after current
  if (!rendition || !rendition.location || !rendition.location.start) return;

  const currentHref = rendition.location.start.href;
  if (!currentHref || !book || !book.spine || !book.spine.spineItems) return;

  const currentChapterIndex = book.spine.spineItems.findIndex(item =>
    item.href === currentHref);

  if (currentChapterIndex === -1) return;

  book.spine.spineItems.forEach((item, index) => {
    const distance = Math.abs(index - currentChapterIndex);
    if (distance > visibleChapters) {
      // Unload distant chapters to save memory
      if (item.unloaded !== true) {
        item.unload();
        item.unloaded = true;
      }
    } else if (item.unloaded === true) {
      // Reload chapters that are now within range
      item.load(book.load.bind(book));
      item.unloaded = false;
    }
  });
}

/**
 * Optimize images in the current view
 */
function optimizeImages() {
  try {
    // Set maximum image dimensions based on device screen
    const maxWidth = window.innerWidth;
    const maxHeight = window.innerHeight;

    // Find all images in the current view
    const images = document.querySelectorAll('img');
    if (!images || images.length === 0) return;

    images.forEach(img => {
      try {
        // Don't load images until they're needed
        img.loading = 'lazy';

        // Resize large images to fit screen
        if (img.naturalWidth > maxWidth || img.naturalHeight > maxHeight) {
          img.style.maxWidth = '100%';
          img.style.height = 'auto';
        }

        // Optimize quality for faster rendering
        img.style.imageRendering = 'optimizeSpeed';
      } catch (e) {
        console.error('Error optimizing image:', e);
      }
    });
  } catch (e) {
    console.error('Error in optimizeImages:', e);
  }
}

/**
 * Prefetch content for smoother reading experience
 */
function prefetchContent() {
  try {
    // Get current location
    if (!rendition || !rendition.location || !rendition.location.start) return;
    const currentHref = rendition.location.start.href;

    // Prefetch the next few sections
    if (!book || !book.spine || !book.spine.spineItems) return;
    const spineItems = book.spine.spineItems;
    const currentIndex = spineItems.findIndex(item => item.href === currentHref);

    if (currentIndex === -1) return;

    // Prefetch next 3 sections
    for (let i = 1; i <= 3; i++) {
      if (currentIndex + i < spineItems.length) {
        const item = spineItems[currentIndex + i];
        if (item.unloaded === true) {
          item.load(book.load.bind(book));
          item.unloaded = false;
        }
      }
    }
  } catch (e) {
    console.error('Error in prefetchContent:', e);
  }
}

/**
 * Clear memory cache to reduce memory usage
 */
function clearMemoryCache() {
  try {
    // Clear any large objects that might be in memory
    if (window.gc) {
      window.gc(); // Request garbage collection if available
    }

    // Clear any cached content not currently visible
    if (rendition && rendition.views) {
      const views = rendition.views();
      if (views) {
        views.forEach(view => {
          if (!view.displayed) {
            view.unload();
          }
        });
      }
    }

    // Force browser to free up memory
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    if (ctx) {
      // Create a large canvas and then clear it to force memory cleanup
      canvas.width = 1;
      canvas.height = 1;
      ctx.clearRect(0, 0, 1, 1);
    }
  } catch (e) {
    console.error('Error in clearMemoryCache:', e);
  }
}

/**
 * Go to a bookmarked location
 * @param {string} cfi - The CFI of the bookmark
 */
function goTo(cfi) {
  rendition.display(cfi);
}

/**
 * Get book metadata
 * @returns {object} Book metadata
 */
function getMetadata() {
  return {
    identifier: book.package.metadata.identifier,
    title: book.package.metadata.title,
    creator: book.package.metadata.creator,
    publisher: book.package.metadata.publisher,
    language: book.package.metadata.language,
    pubdate: book.package.metadata.pubdate,
    modified_date: book.package.metadata.modified_date,
    rights: book.package.metadata.rights,
    description: book.package.metadata.description
  };
}

/**
 * Get all annotations
 * @returns {Array} Array of annotation objects
 */
function getAnnotations() {
  return rendition.annotations.all();
}

/**
 * Export all annotations as JSON
 * @returns {string} JSON string of annotations
 */
function exportAnnotations() {
  return JSON.stringify(rendition.annotations.all());
}

/**
 * Import annotations from JSON
 * @param {string} json - JSON string of annotations
 */
function importAnnotations(json) {
  try {
    let annotations = JSON.parse(json);
    annotations.forEach(annotation => {
      if (annotation.type === "highlight") {
        rendition.annotations.highlight(annotation.cfi, {}, annotation.data);
      } else if (annotation.type === "underline") {
        rendition.annotations.underline(annotation.cfi, {}, annotation.data);
      } else if (annotation.type === "mark") {
        rendition.annotations.mark(annotation.cfi, {}, annotation.data);
      }
    });
  } catch (e) {
    console.error("Error importing annotations:", e);
  }
}

/**
 * Display table of contents
 * @returns {Array} Array of TOC items
 */
function displayTOC() {
  return chapters;
}

/**
 * Go to a specific page number
 * @param {number} pageNumber - Page number to navigate to
 */
function goToPage(pageNumber) {
  if (book.locations && book.locations.length()) {
    let cfi = book.locations.cfiFromPage(pageNumber);
    if (cfi) {
      rendition.display(cfi);
    }
  }
}

/**
 * Save the current reading state to localStorage
 */
/**
 * Apply multiple settings at once to reduce layout recalculations
 * @param {Object} settings - Object containing settings to apply
 */
function applySettingsBatch(settings) {
  try {
    if (settings.fontSize) setFontSize(settings.fontSize);
    if (settings.fontFamily) setFont(settings.fontFamily);
    if (settings.lineHeight) setLineHeight(settings.lineHeight);
    if (settings.theme) selectTheme(settings.theme);
    if (settings.spread) setSpread(settings.spread);
    if (settings.flow) setFlow(settings.flow);

    // Only trigger one layout recalculation
    rendition.resize();
  } catch (e) {
    console.error('Error in applySettingsBatch:', e);
  }
}

/**
 * Set font size
 * @param {number} size - Font size in pixels
 */
function setFontSize(size) {
  if (!rendition) return;
  currentFontSize = size;
  rendition.themes.fontSize(size + 'px');
  saveReadingState();
}

/**
 * Set font family
 * @param {string} font - Font family name
 */
function setFont(font) {
  if (!rendition) return;
  currentFontFamily = font;
  rendition.themes.font(font);
  saveReadingState();
}

/**
 * Set line height
 * @param {string} height - Line height value
 */
function setLineHeight(height) {
  if (!rendition) return;
  currentLineHeight = height;
  rendition.themes.override('line-height', height);
  saveReadingState();
}

/**
 * Set spread (single or double page view)
 * @param {string} spread - Spread value ('auto', 'none', etc.)
 */
function setSpread(spread) {
  if (!rendition) return;
  rendition.spread(spread);
  saveReadingState();
}

/**
 * Set flow (paginated or scrolled)
 * @param {string} flow - Flow value ('paginated' or 'scrolled')
 */
function setFlow(flow) {
  if (!rendition) return;
  rendition.flow(flow);
  saveReadingState();
}

function setManager(manager) {
  rendition.manager(manager);
}

/**
 * Save the current reading state to localStorage
 */
function saveReadingState() {
  try {
    // Get book identifier (using book.key or falling back to a hash of metadata)
    let bookId = null;
    if (book && book.key) {
      bookId = book.key;
    } else if (book && book.package && book.package.metadata) {
      // Create a unique identifier from metadata
      const metadata = book.package.metadata;
      const idComponents = [
        metadata.title,
        metadata.creator,
        metadata.identifier
      ].filter(Boolean).join('-');
      bookId = idComponents || 'unknown-book';
    }

    // Create state object
    const state = {
      bookId: bookId,
      fontSize: currentFontSize,
      fontFamily: currentFontFamily,
      lineHeight: currentLineHeight,
      letterSpacing: currentLetterSpacing,
      bookmarks: bookmarks,
      highlights: highlights,
      underlines: underlines,
      lastLocation: rendition && rendition.location ? rendition.location.start.cfi : null,
      lastRead: new Date().toISOString()
    };

    // Save to localStorage
    localStorage.setItem('epubReaderState', JSON.stringify(state));
  } catch (e) {
    console.error("Error saving reading state:", e);
  }
}

// ... (rest of the code remains the same)

// Clear underlines from storage
function clearStorage(type) {
  try {
    switch (type) {
      case 'all':
        localStorage.removeItem('epubReaderState');
        bookmarks = [];
        highlights = [];
        underlines = [];
        return true;

      case 'bookmarks':
        const state = JSON.parse(localStorage.getItem('epubReaderState') || '{}');
        state.bookmarks = [];
        localStorage.setItem('epubReaderState', JSON.stringify(state));
        bookmarks = [];
        return true;

      case 'highlights':
        const state2 = JSON.parse(localStorage.getItem('epubReaderState') || '{}');
        state2.highlights = [];
        localStorage.setItem('epubReaderState', JSON.stringify(state2));
        highlights = [];
        return true;

      case 'underlines':
        const state3 = JSON.parse(localStorage.getItem('epubReaderState') || '{}');
        state3.underlines = [];
        localStorage.setItem('epubReaderState', JSON.stringify(state3));
        underlines = [];
        return true;

      case 'current-book':
        // Clear data only for the current book
        bookmarks = [];
        highlights = [];
        underlines = [];

        // Clear annotations from the current view
        if (rendition) {
          rendition.annotations.remove('hl');
          rendition.annotations.remove('ul');
        }

        saveReadingState();
        return true;

      default:
        return false;

      // ... (rest of the code remains the same)
    }
  } catch (e) {
    console.error("Error clearing storage:", e);
    return false;
  }
}

// ... (rest of the code remains the same)

// Import underlines
function importAnnotations(json) {
  try {
    if (!json) return false;

    const data = JSON.parse(json);

    // Import bookmarks
    if (data.bookmarks && Array.isArray(data.bookmarks)) {
      data.bookmarks.forEach(bookmark => {
        if (bookmark.cfi && !bookmarks.some(b => b.cfi === bookmark.cfi)) {
          bookmarks.push(bookmark);
        }
      });
    }

    // Import highlights
    if (data.highlights && Array.isArray(data.highlights)) {
      data.highlights.forEach(highlight => {
        if (highlight.cfi && !highlights.some(h => h.cfi === highlight.cfi)) {
          highlights.push(highlight);
          if (rendition) {
            rendition.annotations.highlight(
              highlight.cfi,
              {},
              (e) => { },
              "hl",
              {
                "fill": highlight.color || '#ffff00',
                "fill-opacity": (highlight.opacity || 0.3).toString(),
                "mix-blend-mode": "multiply"
              }
            );
          }
        }
      });
    }

    // Import underlines
    if (data.underlines && Array.isArray(data.underlines)) {
      data.underlines.forEach(underline => {
        if (underline.cfi && !underlines.some(u => u.cfi === underline.cfi)) {
          underlines.push(underline);
          if (rendition) {
            rendition.annotations.underline(
              underline.cfi,
              {},
              (e) => { },
              "ul",
              {
                "stroke": underline.color || '#0000ff',
                "stroke-opacity": (underline.opacity || 0.7).toString(),
                "stroke-width": (underline.thickness || 1).toString() + "px"
              }
            );
          }
        }
      });
    }

    // Save state
    saveReadingState();
    return true;
  } catch (e) {
    console.error('Error importing annotations:', e);
    return false;
  }
}