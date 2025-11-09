var book = ePub();
var rendition;
var displayed;
var chapters = []



function loadBook(data, cfi, initialXPath, manager, flow, spread, snap, allowScriptedContent, direction, useCustomSwipe, backgroundColor, foregroundColor, fontSize, clearSelectionOnPageChange) {
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
    // If we were loading initial position, notify that it's complete
    if (initialPositionLoading) {
      initialPositionLoading = false;
      try {
        window.flutter_inappwebview.callHandler('initialPositionLoaded');
      } catch (e) {
        console.error('Error calling initialPositionLoaded callback:', e);
      }
    }
  });

  // Selection state tracking
  var selectionTimeout = null;
  var isSelecting = false;
  var lastCfiRange = null;

  // Helper function to check and process selection
  function checkAndProcessSelection(contents) {
    try {
      // Try contents window first
      var selection = contents.window.getSelection();
      var range = null;
      var selectedText = '';

      if (selection && selection.rangeCount > 0) {
        try {
          range = selection.getRangeAt(0);
          selectedText = selection.toString();
        } catch (e) {
          // Ignore errors
        }
      }

      // If no selection in contents, try parent window (iPad sometimes puts it there)
      if ((!selectedText || !range || range.collapsed) && window.getSelection) {
        try {
          var parentSelection = window.getSelection();
          if (parentSelection && parentSelection.rangeCount > 0) {
            var parentRange = parentSelection.getRangeAt(0);
            var parentText = parentSelection.toString();
            // Check if parent selection is actually in the epub content
            if (parentText && !parentRange.collapsed) {
              // Try to find which iframe this selection is in
              var iframe = contents.document.defaultView.frameElement;
              if (iframe && parentRange.commonAncestorContainer) {
                // Check if the selection is within our iframe
                try {
                  if (iframe.contentDocument &&
                    (iframe.contentDocument === parentRange.commonAncestorContainer.ownerDocument ||
                      iframe.contentDocument.contains(parentRange.commonAncestorContainer))) {
                    selection = parentSelection;
                    range = parentRange;
                    selectedText = parentText;
                  }
                } catch (e) {
                  // Cross-origin or other error, try anyway
                  selection = parentSelection;
                  range = parentRange;
                  selectedText = parentText;
                }
              }
            }
          }
        } catch (e) {
          // Ignore errors
        }
      }

      if (!selection || !range || selection.rangeCount === 0) {
        return false;
      }

      if (!selectedText || range.collapsed) {
        return false;
      }

      // If we already have this selection, don't process again
      if (isSelecting && lastCfiRange) {
        return true;
      }

      // Try to get CFI from range using epub.js API
      try {
        if (typeof contents.cfiFromRange === 'function') {
          var cfiRange = contents.cfiFromRange(range);
          if (cfiRange) {
            lastCfiRange = cfiRange;
            isSelecting = true;
            // Clear any existing timeout
            if (selectionTimeout) {
              clearTimeout(selectionTimeout);
            }
            // Debounce to allow selection to stabilize
            selectionTimeout = setTimeout(function () {
              sendSelectionData(cfiRange, contents);
            }, 200);
            return true;
          }
        }
      } catch (e) {
        // Ignore errors
      }
    } catch (e) {
      // Ignore errors
    }
    return false;
  }

  // Continuous polling for iPad (as last resort when events don't fire)
  var pollIntervals = []; // Store intervals for each content frame
  var lastPolledSelections = new Map(); // Track last selection per contents

  function startPolling(contents) {
    // Check if we're already polling this contents
    var contentsId = contents.document ? contents.document.URL : 'unknown';
    if (lastPolledSelections.has(contentsId)) {
      return;
    }

    lastPolledSelections.set(contentsId, null);

    var pollCount = 0;
    var noSelectionCount = 0;
    var interval = setInterval(function () {
      try {
        pollCount++;

        // Stop polling if no selection found for 5 seconds (50 polls * 100ms)
        // This optimizes performance - only poll when there might be a selection
        if (pollCount > 50 && noSelectionCount > 40) {
          clearInterval(interval);
          lastPolledSelections.delete(contentsId);
          return;
        }

        // Check if window/selection API is available
        if (!contents.window || !contents.window.getSelection) {
          return;
        }

        var selection = contents.window.getSelection();
        if (!selection) {
          noSelectionCount++;
          return;
        }

        // Check selection properties even if toString() is empty
        var rangeCount = selection.rangeCount || 0;
        var selectedText = selection.toString() || '';
        var hasRanges = rangeCount > 0;

        // Even if toString() is empty, check if there are ranges (iPad quirk)
        var currentSelection = selectedText || (hasRanges ? 'HAS_RANGE_BUT_NO_TEXT' : null);
        var lastSelection = lastPolledSelections.get(contentsId);

        // Only process if selection changed
        if (currentSelection !== lastSelection) {
          lastPolledSelections.set(contentsId, currentSelection);
          noSelectionCount = 0; // Reset counter when selection found

          if (!selectedText && !hasRanges) {
            // Selection cleared
            if (isSelecting) {
              isSelecting = false;
              lastCfiRange = null;
              window.flutter_inappwebview.callHandler('selectionCleared');
            }
          } else {
            // Selection exists - try to process it
            if (!isSelecting) {
              checkAndProcessSelection(contents);
            }
          }
        } else if (!currentSelection) {
          noSelectionCount++;
        }
      } catch (e) {
        // Ignore errors
      }
    }, 200); // Check every 200ms

    pollIntervals.push({ contentsId: contentsId, interval: interval });
  }

  function stopPolling() {
    pollIntervals.forEach(function (item) {
      clearInterval(item.interval);
    });
    pollIntervals = [];
    lastPolledSelections.clear();
  }

  // Handle selection clearing and changes
  rendition.hooks.content.register(function (contents) {
    // Listen on document
    contents.window.document.addEventListener('selectionchange', function () {
      var selection = contents.window.getSelection();
      var selectedText = selection.toString();

      if (!selectedText) {
        // Selection cleared
        isSelecting = false;
        lastCfiRange = null;
        if (selectionTimeout) {
          clearTimeout(selectionTimeout);
          selectionTimeout = null;
        }
        window.flutter_inappwebview.callHandler('selectionCleared');
      } else if (isSelecting) {
        // Selection is being modified (dragging handles)
        // Notify Flutter to hide the widget
        window.flutter_inappwebview.callHandler('selectionChanging');

        // Clear existing timeout
        if (selectionTimeout) {
          clearTimeout(selectionTimeout);
        }

        // Set timeout to detect when dragging stops
        selectionTimeout = setTimeout(function () {
          // Selection has stabilized, send the final selection
          if (lastCfiRange) {
            sendSelectionData(lastCfiRange, contents);
          }
          isSelecting = false;
        }, 300); // 300ms debounce
      } else {
        // Fallback for iPad/iOS: Detect initial selection when epub.js "selected" event doesn't fire
        checkAndProcessSelection(contents);
      }
    });

    // Also listen on window (some browsers fire it there)
    if (contents.window.addEventListener) {
      contents.window.addEventListener('selectionchange', function () {
        var selection = contents.window.getSelection();
        var selectedText = selection.toString();
        if (selectedText && !isSelecting) {
          checkAndProcessSelection(contents);
        }
      });
    }

    // Start polling for this content frame (optimized - stops if no selection found)
    try {
      startPolling(contents);
    } catch (e) {
      // Ignore errors
    }

    // Also try to get all contents and poll them (important for spread layout with 2 pages)
    try {
      var allContents = rendition.getContents();
      allContents.forEach(function (cont, index) {
        var frameId = cont.document ? cont.document.URL : ('frame' + index);
        if (cont.window && !lastPolledSelections.has(frameId)) {
          startPolling(cont);
        }
      });

      // Set up a periodic check to ensure all frames are being polled
      // (in case frames are added/removed dynamically)
      setInterval(function () {
        try {
          var currentContents = rendition.getContents();
          currentContents.forEach(function (cont, index) {
            var frameId = cont.document ? cont.document.URL : ('frame' + index);
            if (cont.window && !lastPolledSelections.has(frameId)) {
              startPolling(cont);
            }
          });
        } catch (e) {
          // Ignore errors in periodic check
        }
      }, 2000); // Check every 2 seconds for new frames
    } catch (e) {
      // Ignore errors
    }

    // Also poll parent window selection (iPad often puts selection there)
    if (!lastPolledSelections.has('parent')) {
      lastPolledSelections.set('parent', null);
      var parentNoSelectionCount = 0;
      var parentInterval = setInterval(function () {
        try {
          if (!window.getSelection) return;
          var parentSelection = window.getSelection();
          var parentText = parentSelection ? parentSelection.toString() : '';
          var currentParentSelection = parentText || null;
          var lastParentSelection = lastPolledSelections.get('parent');

          if (currentParentSelection !== lastParentSelection) {
            lastPolledSelections.set('parent', currentParentSelection);
            parentNoSelectionCount = 0;

            if (parentText && parentSelection.rangeCount > 0) {
              // Try to process with each content frame (important for spread with 2 pages)
              try {
                var allContents = rendition.getContents();
                allContents.forEach(function (cont, index) {
                  if (!isSelecting) {
                    checkAndProcessSelection(cont);
                  }
                });
              } catch (e) {
                // Ignore errors
              }
            } else {
              parentNoSelectionCount++;
            }
          } else if (!currentParentSelection) {
            parentNoSelectionCount++;
          }

          // Stop polling if no selection found for 5 seconds
          if (parentNoSelectionCount > 25) {
            clearInterval(parentInterval);
            lastPolledSelections.delete('parent');
          }
        } catch (e) {
          // Ignore errors
        }
      }, 200);
      pollIntervals.push({ contentsId: 'parent', interval: parentInterval });
    }
  });

  book.loaded.navigation.then(function (toc) {
    chapters = parseChapters(toc)
    window.flutter_inappwebview.callHandler('chapters');
  })

  rendition.on("rendered", function () {
    window.flutter_inappwebview.callHandler('rendered');
  })

  // Function to calculate and send selection data
  // Make it globally accessible for native callbacks
  window.sendSelectionData = function (cfiRange, contents) {
    book.getRange(cfiRange).then(function (range) {
      var selectedText = range.toString();

      // Convert CFI to XPath
      cfiRangeToXPath(cfiRange.toString()).then(function (selectionXpath) {
        try {
          // Get selection coordinates
          var selection = contents.window.getSelection();
          var rect = null;

          if (selection && selection.rangeCount > 0) {
            // Get the range and its client rect (relative to iframe viewport)
            var selRange = selection.getRangeAt(0);
            var clientRect = selRange.getBoundingClientRect();

            // Get the WebView dimensions (parent window)
            var webViewWidth = window.innerWidth;
            var webViewHeight = window.innerHeight;

            // Get the iframe element in the parent document
            var iframe = contents.document.defaultView.frameElement;

            if (iframe) {
              var iframeRect = iframe.getBoundingClientRect();

              // Calculate absolute position in WebView (iframe offset + selection position)
              var absoluteLeft = iframeRect.left + clientRect.left;
              var absoluteTop = iframeRect.top + clientRect.top;

              // Normalize to 0-1 range relative to WebView dimensions
              rect = {
                left: absoluteLeft / webViewWidth,
                top: absoluteTop / webViewHeight,
                width: clientRect.width / webViewWidth,
                height: clientRect.height / webViewHeight,
                contentHeight: webViewHeight
              };
            }
          }

          var args = [cfiRange.toString(), selectedText, rect, selectionXpath];
          window.flutter_inappwebview.callHandler('selection', ...args);
        } catch (e) {
          // Still send the selection without coordinates if there's an error
          var args = [cfiRange.toString(), selectedText, null, selectionXpath];
          window.flutter_inappwebview.callHandler('selection', ...args);
        }
      }).catch(function (e) {
        // If XPath conversion fails, still send CFI
        try {
          var selection = contents.window.getSelection();
          var rect = null;
          if (selection && selection.rangeCount > 0) {
            var selRange = selection.getRangeAt(0);
            var clientRect = selRange.getBoundingClientRect();
            var webViewWidth = window.innerWidth;
            var webViewHeight = window.innerHeight;
            var iframe = contents.document.defaultView.frameElement;
            var iframeRect = iframe.getBoundingClientRect();
            var absoluteLeft = iframeRect.left + clientRect.left;
            var absoluteTop = iframeRect.top + clientRect.top;
            rect = {
              left: absoluteLeft / webViewWidth,
              top: absoluteTop / webViewHeight,
              width: clientRect.width / webViewWidth,
              height: clientRect.height / webViewHeight,
              contentHeight: webViewHeight
            };
          }
          var args = [cfiRange.toString(), selectedText, rect, null];
          window.flutter_inappwebview.callHandler('selection', ...args);
        } catch (e2) {
          var args = [cfiRange.toString(), selectedText, null, null];
          window.flutter_inappwebview.callHandler('selection', ...args);
        }
      });
    });
  };

  // Also store locally for internal use
  var sendSelectionData = window.sendSelectionData;
  ///text selection callback
  rendition.on("selected", function (cfiRange, contents) {
    book.getRange(cfiRange).then(function (range) {
      var selectedText = range.toString();
      var args = [cfiRange.toString(), selectedText]
      window.flutter_inappwebview.callHandler('selection', ...args);
    })
  });

  //book location changes callback
  rendition.on("relocated", function (location) {
    var percent = location.start.percentage;
    var location = {
      startCfi: location.start.cfi,
      endCfi: location.end.cfi,
      progress: percent
    }
    var args = [location]
    window.flutter_inappwebview.callHandler('relocated', ...args);
  });

  rendition.on('displayError', function (e) {
    console.log("displayError")
    window.flutter_inappwebview.callHandler('displayError');
  })

  rendition.on('markClicked', function (cfiRange) {
    console.log("markClicked")
    var args = [cfiRange.toString()]
    window.flutter_inappwebview.callHandler('markClicked', ...args);
  })

  book.ready.then(function () {
    book.locations.generate(1600).then(() => {
      if(cfi){
        rendition.display(cfi)
      }
      window.flutter_inappwebview.callHandler('locationLoaded');
    })
  })

  rendition.hooks.content.register((contents) => {

    if (useCustomSwipe) {
      const el = contents.document.documentElement;

      if (el) {
        // console.log('EPUB_TEST_HOOK_IF')
        detectSwipe(el, function (el, direction) {
          // console.log("EPUB_TEST_DIR"+direction.toString())

          if (direction == 'l') {
            rendition.next()
          }
          if (direction == 'r') {
            rendition.prev()
          }
        });
      }
    }
  });
  rendition.themes.fontSize(fontSize + "px");
  //set background and foreground color
  updateTheme(backgroundColor, foregroundColor);
}

window.addEventListener("flutterInAppWebViewPlatformReady", function (event) {
  window.flutter_inappwebview.callHandler('readyToLoad');
});

//move to next page
function next() {
  rendition.next()
}

//move to previous page
function previous() {
  rendition.prev()
}

//move to given cfi location
function toCfi(cfi) {
  rendition.display(cfi)
}

//get all chapters
function getChapters() {
  return chapters;
}

async function getBookInfo() {
  const metadata = book.package.metadata;
  metadata['coverImage'] = book.cover;
  console.log("getBookInfo", await book.coverUrl());
  return metadata;
}

function getCurrentLocation() {
  var percent = rendition.location.start.percentage;
  // var percentage = Math.floor(percent * 100);
  var location = {
    startCfi: rendition.location.start.cfi,
    endCfi: rendition.location.end.cfi,
    progress: percent
  }
  return location;
}

///parsing chapters and subitems recursively
var parseChapters = function (toc) {
  var chapters = []
  toc.forEach(function (chapter) {
    chapters.push({
      title: chapter.label,
      href: chapter.href,
      id: chapter.id,
      subitems: parseChapters(chapter.subitems)
    })
  })
  return chapters;
}

function searchInBook(query) {
  search(query).then(function (data) {
    var args = [data]
    window.flutter_inappwebview.callHandler('search', ...args);
  })
}


// adds highlight with given color
function addHighlight(cfiRange, color, opacity) {
  rendition.annotations.highlight(cfiRange, {}, (e) => {
    // console.log("highlight clicked", e.target);
  }, "hl", { "fill": color, "fill-opacity": '0.3', "mix-blend-mode": "multiply" });
}

function addUnderLine(cfiString) {
  rendition.annotations.underline(cfiString)
}

function addMark(cfiString) {
  rendition.annotations.mark(cfiString)
}

function removeHighlight(cfiString) {
  rendition.annotations.remove(cfiString, "highlight");
}

function removeUnderLine(cfiString) {
  rendition.annotations.remove(cfiString, "underline");
}

function removeMark(cfiString) {
  rendition.annotations.remove(cfiString, "mark");
}

function toProgress(progress) {
  var cfi = book.locations.cfiFromPercentage(progress);
  rendition.display(cfi);
}


function search(q) {
  return Promise.all(
    book.spine.spineItems.map(item => item.load(book.load.bind(book)).then(item.find.bind(item, q)).finally(item.unload.bind(item)))
  ).then(results => Promise.resolve([].concat.apply([], results)));
};

function setFontSize(fontSize) {
  rendition.themes.default({
    p: {
      // "margin": '10px',
      "font-size": `${fontSize}px`
    }
  });
}

function setSpread(spread) {
  rendition.spread(spread);
}

function setFlow(flow) {
  rendition.flow(flow);
}

function setManager(manager) {
  rendition.manager(manager);
}

function setFontSize(fontSize) {
  rendition.themes.fontSize(`${fontSize}px`);
  rendition.reportLocation();
}

//get current page text
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

//get text from a range
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
    rendition.themes.register("dark", { "body": { "background": backgroundColor, "color": foregroundColor } });
    rendition.themes.select("dark");
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
  }, false);
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