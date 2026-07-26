// CFI <-> XPath conversion utilities for the EPUB viewer.
// Pure helpers extracted from epubView.js; loaded before it in swipe.html.
// They only depend on the globals `book`, `rendition` and `ePub`.

function makeRangeCfi(a, b) {
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

// Convert a DOM node to XPath
function getXPath(node) {
  if (node.nodeType === Node.DOCUMENT_NODE) {
    return '/';
  }

  if (node.nodeType === Node.TEXT_NODE) {
    var parent = node.parentNode;
    var xpath = getXPath(parent);
    var index = 1;
    var sibling = node.previousSibling;
    while (sibling) {
      if (sibling.nodeType === Node.TEXT_NODE && sibling.nodeName === node.nodeName) {
        index++;
      }
      sibling = sibling.previousSibling;
    }
    return xpath + '/text()[' + index + ']';
  }

  if (node.nodeType === Node.ELEMENT_NODE) {
    var parts = [];
    var current = node;

    while (current && current.nodeType === Node.ELEMENT_NODE) {
      var index = 1;
      var sibling = current.previousSibling;
      while (sibling) {
        if (sibling.nodeType === Node.ELEMENT_NODE && sibling.nodeName === current.nodeName) {
          index++;
        }
        sibling = sibling.previousSibling;
      }

      var tagName = current.nodeName.toLowerCase();
      var xpathSegment = tagName + '[' + index + ']';

      // Add ID if available for more precise targeting
      if (current.id) {
        xpathSegment = tagName + '[@id="' + current.id + '"]';
      }

      parts.unshift(xpathSegment);
      current = current.parentNode;
    }

    return '/' + parts.join('/');
  }

  return '';
}

// Convert CFI to XPath/XPointer
// Returns a promise that resolves to an XPointer string or null if conversion fails
function cfiToXPath(cfiString) {
  if (!cfiString) {
    return Promise.resolve(null);
  }

  try {
    var cfi = new ePub.CFI(cfiString);
    var spineIndex = cfi.spinePos;

    // Get the spine item
    var spineItem = book.spine.get(spineIndex);
    if (!spineItem) {
      return Promise.resolve(null);
    }

    // Load the item and convert CFI to Range
    return spineItem.load(book.load.bind(book)).then(function () {
      try {
        var range = cfi.toRange(spineItem.document);
        if (!range) {
          return null;
        }

        // Build XPath from the range
        var startXPath = getXPath(range.startContainer);
        var endXPath = getXPath(range.endContainer);

        // Convert to KoReader format: /body/DocFragment[N]/body/...
        // Extract the path after /html[N]/body[N] and prepend /body/DocFragment[N]/body
        function convertToKoReaderFormat(xpath, offset) {
          // Match /html[N]/body[N] and extract the rest
          var match = xpath.match(/^\/html\[\d+\]\/body\[\d+\](.*)$/);
          if (match) {
            var elementPath = match[1] || '';
            // Convert /text()[1] to /text() for KoReader format
            elementPath = elementPath.replace(/\/text\(\)\[\d+\]$/, '/text()');
            // DocFragment index is spineIndex + 1 (1-based)
            var docFragmentIndex = spineIndex + 1;
            // Build KoReader format: /body/DocFragment[N]/body/...
            var koreaderPath = '/body/DocFragment[' + docFragmentIndex + ']/body' + elementPath;
            // Add offset for text nodes
            if (offset !== undefined && offset !== null) {
              koreaderPath += '.' + offset;
            }
            return koreaderPath;
          }
          // If format doesn't match, return original with offset
          if (offset !== undefined && offset !== null) {
            return xpath + '.' + offset;
          }
          return xpath;
        }

        // Add offset for text nodes and convert to KoReader format
        var startOffset = null;
        var endOffset = null;
        if (range.startContainer.nodeType === Node.TEXT_NODE) {
          startOffset = range.startOffset;
        }
        if (range.endContainer.nodeType === Node.TEXT_NODE) {
          endOffset = range.endOffset;
        }

        var startXPathKoReader = convertToKoReaderFormat(startXPath, startOffset);
        var endXPathKoReader = convertToKoReaderFormat(endXPath, endOffset);

        // Format as XPointer: /body/DocFragment[1]/body/div[2]/p[3]/text().123
        // For ranges, we return start and end separated by comma
        if (startXPathKoReader === endXPathKoReader && startOffset === endOffset) {
          return startXPathKoReader;
        } else {
          return startXPathKoReader + ',' + endXPathKoReader;
        }
      } catch (e) {
        console.error('Error converting CFI to XPath:', e);
        return null;
      }
    }).catch(function (e) {
      console.error('Error loading spine item for CFI conversion:', e);
      return null;
    });
  } catch (e) {
    console.error('Error parsing CFI:', e);
    return Promise.resolve(null);
  }
}

// Helper to convert CFI range to XPath range
function cfiRangeToXPath(cfiRangeString) {
  if (!cfiRangeString) {
    return Promise.resolve(null);
  }

  try {
    // Parse the CFI range to extract start and end CFIs
    var cfi = new ePub.CFI(cfiRangeString);
    var spineIndex = cfi.spinePos;

    var spineItem = book.spine.get(spineIndex);
    if (!spineItem) {
      return Promise.resolve(null);
    }

    return spineItem.load(book.load.bind(book)).then(function () {
      try {
        var range = cfi.toRange(spineItem.document);
        if (!range) {
          return null;
        }

        var startXPath = getXPath(range.startContainer);
        var endXPath = getXPath(range.endContainer);

        // Convert to KoReader format: /body/DocFragment[N]/body/...
        function convertToKoReaderFormat(xpath, offset) {
          // Match /html[N]/body[N] and extract the rest
          var match = xpath.match(/^\/html\[\d+\]\/body\[\d+\](.*)$/);
          if (match) {
            var elementPath = match[1] || '';
            // Convert /text()[1] to /text() for KoReader format
            elementPath = elementPath.replace(/\/text\(\)\[\d+\]$/, '/text()');
            // DocFragment index is spineIndex + 1 (1-based)
            var docFragmentIndex = spineIndex + 1;
            // Build KoReader format: /body/DocFragment[N]/body/...
            var koreaderPath = '/body/DocFragment[' + docFragmentIndex + ']/body' + elementPath;
            // Add offset for text nodes
            if (offset !== undefined && offset !== null) {
              koreaderPath += '.' + offset;
            }
            return koreaderPath;
          }
          // If format doesn't match, return original with offset
          if (offset !== undefined && offset !== null) {
            return xpath + '.' + offset;
          }
          return xpath;
        }

        // Add offset for text nodes and convert to KoReader format
        var startOffset = null;
        var endOffset = null;
        if (range.startContainer.nodeType === Node.TEXT_NODE) {
          startOffset = range.startOffset;
        }
        if (range.endContainer.nodeType === Node.TEXT_NODE) {
          endOffset = range.endOffset;
        }

        var startXPathKoReader = convertToKoReaderFormat(startXPath, startOffset);
        var endXPathKoReader = convertToKoReaderFormat(endXPath, endOffset);

        if (startXPathKoReader === endXPathKoReader && startOffset === endOffset) {
          return startXPathKoReader;
        } else {
          return startXPathKoReader + ',' + endXPathKoReader;
        }
      } catch (e) {
        console.error('Error converting CFI range to XPath:', e);
        return null;
      }
    }).catch(function (e) {
      console.error('Error loading spine item for CFI range conversion:', e);
      return null;
    });
  } catch (e) {
    console.error('Error parsing CFI range:', e);
    return Promise.resolve(null);
  }
}

// Convert XPath/XPointer to CFI
// Returns a promise that resolves to a CFI string or null if conversion fails
function xpathToCfi(xpathString) {
  if (!xpathString) {
    return Promise.resolve(null);
  }

  try {
    // Parse XPath - handle ranges (comma-separated) and offsets
    var parts = xpathString.split(',');
    var startXPath = parts[0].trim();
    var endXPath = parts.length > 1 ? parts[1].trim() : startXPath;

    // Extract offset from XPath if present (e.g., /path/to/text().123)
    var startOffset = 0;
    var endOffset = 0;
    var startXPathWithoutOffset = startXPath;
    var endXPathWithoutOffset = endXPath;

    var startOffsetMatch = startXPath.match(/\.(\d+)$/);
    if (startOffsetMatch) {
      startOffset = parseInt(startOffsetMatch[1]);
      startXPathWithoutOffset = startXPath.replace(/\.\d+$/, '');
    }

    var endOffsetMatch = endXPath.match(/\.(\d+)$/);
    if (endOffsetMatch) {
      endOffset = parseInt(endOffsetMatch[1]);
      endXPathWithoutOffset = endXPath.replace(/\.\d+$/, '');
    }

    // Extract DocFragment index if present (KoReader format: /body/DocFragment[9]/body/...)
    var docFragmentIndex = null;
    var docFragmentMatch = startXPathWithoutOffset.match(/\/DocFragment\[(\d+)\]/);
    if (docFragmentMatch) {
      docFragmentIndex = parseInt(docFragmentMatch[1]) - 1; // Convert to 0-based index
      // Remove /body/DocFragment[N]/ part, leaving /body/... or just the content path
      startXPathWithoutOffset = startXPathWithoutOffset.replace(/^\/body\/DocFragment\[\d+\]/, '');
    }

    // Try to find the node in each spine item (or just the specific one if DocFragment index was found)
    // Optimize: check sequentially and stop on first match to avoid loading all spine items
    var spineItemsToCheck = docFragmentIndex !== null
      ? [book.spine.spineItems[docFragmentIndex]].filter(function (item) { return item != null; })
      : book.spine.spineItems;

    // Optimize: if no DocFragment index, try to check currently displayed spine item first
    // Create a mapping to track original indices when reordering
    var indexMap = [];
    for (var mapIdx = 0; mapIdx < spineItemsToCheck.length; mapIdx++) {
      indexMap.push(mapIdx);
    }

    if (docFragmentIndex === null && rendition && rendition.location) {
      try {
        var currentLocation = rendition.location;
        if (currentLocation && currentLocation.start && currentLocation.start.index !== undefined) {
          var currentSpineIndex = currentLocation.start.index;
          if (currentSpineIndex >= 0 && currentSpineIndex < spineItemsToCheck.length) {
            // Check current spine item first by moving it to the front
            var currentItem = spineItemsToCheck[currentSpineIndex];
            var currentIndexInMap = indexMap[currentSpineIndex];
            spineItemsToCheck = [currentItem].concat(
              spineItemsToCheck.slice(0, currentSpineIndex),
              spineItemsToCheck.slice(currentSpineIndex + 1)
            );
            indexMap = [currentIndexInMap].concat(
              indexMap.slice(0, currentSpineIndex),
              indexMap.slice(currentSpineIndex + 1)
            );
          }
        }
      } catch (e) {
        // Silently fail - optimization is optional
      }
    }

    // Sequential check function that stops on first match
    function checkSpineItemSequentially(itemIndex) {
      if (itemIndex >= spineItemsToCheck.length) {
        // All items checked, no match found
        return Promise.resolve(null);
      }

      var item = spineItemsToCheck[itemIndex];
      // Use the mapped index to get the correct original spine index for CFI creation
      var index = docFragmentIndex !== null ? docFragmentIndex : indexMap[itemIndex];

      // Check if document is already loaded to avoid unnecessary loading
      var doc = item.document;
      var loadPromise = doc ? Promise.resolve() : item.load(book.load.bind(book));

      return loadPromise.then(function () {
        try {
          doc = item.document;
          if (!doc) {
            return null;
          }

          var startNode = null;
          var endNode = null;

          // Parse and resolve XPath manually (following Readest's approach)
          // This is more reliable than XPath evaluation in epub.js context
          function resolveXPointerPath(path) {
            var elementPath = '';
            var current = doc.body || doc.documentElement;

            if (!current) {
              return null;
            }

            // Handle empty path - return body element
            if (!path || path === '') {
              return current;
            }

            // Handle KoReader format: /body/DocFragment[N]/body/p[5]/text()
            var koreaderMatch = path.match(/^\/body\/DocFragment\[\d+\]\/body(.*)$/);
            if (koreaderMatch) {
              elementPath = koreaderMatch[1] || '';
            } else {
              // Handle our library's format: /html[1]/body[1]/p[1]/text()[1]
              var ourFormatMatch = path.match(/^\/html\[\d+\]\/body\[\d+\](.*)$/);
              if (ourFormatMatch) {
                elementPath = ourFormatMatch[1] || '';
              } else {
                // Try /body format
                var bodyMatch = path.match(/^\/body(.*)$/);
                if (bodyMatch) {
                  elementPath = bodyMatch[1] || '';
                } else {
                  // Try /html format
                  var htmlMatch = path.match(/^\/html\[\d+\](.*)$/);
                  if (htmlMatch) {
                    elementPath = htmlMatch[1] || '';
                  } else {
                    return null;
                  }
                }
              }
            }

            if (!elementPath || elementPath === '') {
              return current;
            }

            // Parse path segments (e.g., /p[5]/text() or /p[1]/text()[1] -> ['p[5]'] or ['p[1]', 'text()[1]'])
            var segments = elementPath.split('/').filter(function (s) { return s.length > 0; });

            for (var s = 0; s < segments.length; s++) {
              var segment = segments[s];

              // Handle text() or text()[1] - we'll handle this separately
              if (segment === 'text()' || segment.match(/^text\(\)\[\d+\]$/)) {
                break; // Stop here, current is the element containing the text
              }

              // Match tag[index] or just tag
              var segmentWithIndexMatch = segment.match(/^(\w+)\[(\d+)\]$/);
              var segmentWithoutIndexMatch = segment.match(/^(\w+)$/);

              var tagName = null;
              var index = 0;

              if (segmentWithIndexMatch) {
                tagName = segmentWithIndexMatch[1].toLowerCase();
                index = parseInt(segmentWithIndexMatch[2], 10) - 1; // Convert to 0-based
              } else if (segmentWithoutIndexMatch) {
                tagName = segmentWithoutIndexMatch[1].toLowerCase();
                index = 0;
              } else {
                return null;
              }

              // Find children with matching tag name
              var children = Array.from(current.children || []).filter(function (child) {
                return child.nodeType === Node.ELEMENT_NODE &&
                  child.tagName.toLowerCase() === tagName;
              });

              if (index >= children.length) {
                return null;
              }

              current = children[index];
            }

            return current;
          }

          // Resolve the start element
          var startElement = resolveXPointerPath(startXPathWithoutOffset);
          var startOffsetInNode = startOffset; // Default to original offset

          if (startElement) {
            // Handle text offset if present
            // If we have an offset (including 0) or explicit /text() in path, treat it as text node offset
            // Empty path with offset means we're targeting text nodes within the resolved element
            var hasTextOffset = startXPathWithoutOffset.includes('/text()') ||
              (startOffset >= 0 && (startXPathWithoutOffset === '' || startXPathWithoutOffset === '/body'));

            if (hasTextOffset) {
              // Find text node at the specified offset
              var textNodes = [];
              var walker = doc.createTreeWalker(startElement, NodeFilter.SHOW_TEXT, null, false);
              var textNode;
              while (textNode = walker.nextNode()) {
                if (textNode.textContent && textNode.textContent.length > 0) {
                  textNodes.push(textNode);
                }
              }

              if (textNodes.length > 0) {
                // If offset is 0, use the first text node
                if (startOffset === 0) {
                  startNode = textNodes[0];
                  startOffsetInNode = 0;
                } else {
                  // Calculate cumulative offset to find the right text node
                  var currentOffset = 0;
                  var targetTextNode = null;
                  var offsetInNode = 0;

                  for (var t = 0; t < textNodes.length; t++) {
                    var tn = textNodes[t];
                    var nodeLength = tn.textContent ? tn.textContent.length : 0;

                    // If offset is within this text node's range
                    if (currentOffset + nodeLength > startOffset) {
                      targetTextNode = tn;
                      offsetInNode = startOffset - currentOffset;
                      break;
                    }

                    currentOffset += nodeLength;
                  }

                  if (targetTextNode) {
                    startNode = targetTextNode;
                    startOffsetInNode = offsetInNode;
                  } else {
                    // Offset beyond all text, use last text node
                    var lastNode = textNodes[textNodes.length - 1];
                    startNode = lastNode;
                    var lastLength = lastNode.textContent ? lastNode.textContent.length : 0;
                    startOffsetInNode = lastLength;
                  }
                }
              } else {
                // No text nodes found, use the element itself
                startNode = startElement;
                startOffsetInNode = 0;
              }
            } else {
              // No text offset, use the element itself
              startNode = startElement;
              startOffsetInNode = 0;
            }
          }

          // If manual resolution failed, try XPath evaluation as fallback
          if (!startNode) {
            // Build XPath variations to try
            var xpathVariations = [startXPathWithoutOffset];

            if (startXPathWithoutOffset.startsWith('/body/')) {
              xpathVariations.push('/html' + startXPathWithoutOffset);
              xpathVariations.push(startXPathWithoutOffset.replace(/^\/body\//, '/'));
            }

            try {
              for (var v = 0; v < xpathVariations.length && !startNode; v++) {
                var xpathToTry = xpathVariations[v];
                try {
                  var startResult = doc.evaluate(xpathToTry, doc, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                  startNode = startResult.singleNodeValue;
                  if (startNode) {
                    break;
                  }
                } catch (e) {
                  // Try next variation
                }
              }
            } catch (e) {
              // XPath evaluation failed, continue
            }
          }

          // Resolve end node (same approach as start node)
          var endOffsetInNode = endOffset; // Default to original offset
          if (parts.length > 1) {
            var endElement = resolveXPointerPath(endXPathWithoutOffset);
            if (endElement) {
              // Handle text offset if present (same logic as start node)
              var hasEndTextOffset = endXPathWithoutOffset.includes('/text()') ||
                (endOffset >= 0 && (endXPathWithoutOffset === '' || endXPathWithoutOffset === '/body'));

              if (hasEndTextOffset) {
                var endTextNodes = [];
                var endWalker = doc.createTreeWalker(endElement, NodeFilter.SHOW_TEXT, null, false);
                var endTextNode;
                while (endTextNode = endWalker.nextNode()) {
                  if (endTextNode.textContent && endTextNode.textContent.length > 0) {
                    endTextNodes.push(endTextNode);
                  }
                }

                if (endTextNodes.length > 0) {
                  var endCurrentOffset = 0;
                  var endTargetTextNode = null;
                  var endOffsetInNodeCalc = 0;

                  for (var t = 0; t < endTextNodes.length; t++) {
                    var tn = endTextNodes[t];
                    var nodeLength = tn.textContent ? tn.textContent.length : 0;

                    if (endCurrentOffset + nodeLength >= endOffset) {
                      endTargetTextNode = tn;
                      endOffsetInNodeCalc = endOffset - endCurrentOffset;
                      break;
                    }

                    endCurrentOffset += nodeLength;
                  }

                  if (endTargetTextNode) {
                    endNode = endTargetTextNode;
                    endOffsetInNode = endOffsetInNodeCalc;
                  } else if (endTextNodes.length > 0) {
                    var lastEndNode = endTextNodes[endTextNodes.length - 1];
                    endNode = lastEndNode;
                    endOffsetInNode = lastEndNode.textContent ? lastEndNode.textContent.length : 0;
                  } else {
                    endNode = endElement;
                    endOffsetInNode = 0;
                  }
                } else {
                  endNode = endElement;
                  endOffsetInNode = 0;
                }
              } else {
                endNode = endElement;
                endOffsetInNode = 0;
              }
            }

            // Fallback to startNode if endNode not found
            if (!endNode && startNode) {
              endNode = startNode;
              endOffsetInNode = startOffsetInNode;
            }
          } else {
            endNode = startNode;
            endOffsetInNode = startOffsetInNode;
          }

          if (!startNode || !endNode) {
            console.error('Missing startNode or endNode. startNode:', startNode, 'endNode:', endNode);
            return null;
          }

          // Create a Range from the nodes
          try {
            var range = doc.createRange();

            if (startNode.nodeType === Node.TEXT_NODE) {
              var startTextLength = startNode.textContent ? startNode.textContent.length : 0;
              range.setStart(startNode, Math.min(startOffsetInNode, startTextLength));
            } else {
              range.setStart(startNode, 0);
            }

            if (endNode.nodeType === Node.TEXT_NODE) {
              var endTextLength = endNode.textContent ? endNode.textContent.length : 0;
              range.setEnd(endNode, Math.min(endOffsetInNode, endTextLength));
            } else {
              var endChildNodesLength = (endNode.childNodes && endNode.childNodes.length) || 0;
              range.setEnd(endNode, endChildNodesLength);
            }
          } catch (e) {
            console.error('Error creating range:', e);
            return null;
          }

          // Create CFI from the range
          var spineItem = book.spine.get(index);
          var cfiString = null;

          try {
            // Create CFI from range
            // epub.js CFI constructor needs the document to be in the book context
            var packageIndices = [6, 4];
            var created = false;

            // Check if range is valid
            if (!range || !range.startContainer || !range.endContainer) {
              console.error('Invalid range - missing containers');
              return null;
            }

            // Try creating CFI with base string directly (epub.js needs base)
            // The base format is /{packageIndex}/{spineIndex} where spineIndex is 1-based
            for (var p = 0; p < packageIndices.length && !created; p++) {
              try {
                var packageIndex = packageIndices[p];
                // epub.js uses even numbers for spine indices: 2, 4, 6, 8...
                // So spine index 8 (0-based) = 18 (2 * (8 + 1))
                var spineIndexCfi = (index + 1) * 2;
                var baseString = "/" + packageIndex + "/" + spineIndexCfi;

                var cfi = new ePub.CFI(range, baseString);
                var cfiStringWithoutBase = cfi.toString();

                // Parse it to verify
                var parsedCfi = new ePub.CFI(cfiStringWithoutBase);

                // If spinePos matches, use it
                if (parsedCfi.spinePos === index) {
                  cfiString = cfiStringWithoutBase;
                  created = true;
                  break;
                } else {
                  cfiString = null;
                }
              } catch (e) {
                cfiString = null;
              }
            }

            if (created && cfiString) {
              return cfiString;
            } else {
              console.error('Failed to create valid CFI with any package index');
              return null;
            }
          } catch (e) {
            console.error('Error creating CFI:', e);
            return null;
          }
        } catch (e) {
          console.error('Error creating CFI for spine item', index, ':', e);
          return null;
        }
      }).catch(function (e) {
        console.error('Error loading spine item', index, ':', e);
        return null;
      }).then(function (result) {
        // If we found a match, return it immediately
        if (result) {
          return result;
        }
        // Otherwise, check the next spine item
        return checkSpineItemSequentially(itemIndex + 1);
      });
    }

    // Start sequential checking from the first item
    return checkSpineItemSequentially(0).then(function (result) {
      if (!result) {
        console.warn('No CFI found for XPath:', xpathString);
      }
      return result;
    }).catch(function (e) {
      console.error('Error converting XPath to CFI:', e);
      return null;
    });
  } catch (e) {
    console.error('Error parsing XPath:', e);
    return Promise.resolve(null);
  }
}
