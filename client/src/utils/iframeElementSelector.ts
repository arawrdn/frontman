// Utility for injecting element selection functionality into iframes
export const IFRAME_SELECTOR_SCRIPT = `
(function() {
  if (window.elementSelectorInjected) return;
  window.elementSelectorInjected = true;

  let isSelecting = false;
  let highlightOverlay = null;

  function createHighlightOverlay() {
    const overlay = document.createElement('div');
    overlay.id = 'element-selector-overlay';
    overlay.style.cssText = \`
      position: fixed;
      pointer-events: none;
      border: 2px solid #3b82f6;
      background: rgba(59, 130, 246, 0.1);
      z-index: 999999;
      transition: all 0.1s ease;
      box-shadow: 0 0 10px rgba(59, 130, 246, 0.5);
    \`;
    document.body.appendChild(overlay);
    return overlay;
  }

  function createSelectionNotice() {
    const notice = document.createElement('div');
    notice.id = 'iframe-selection-notice';
    notice.style.cssText = \`
      position: fixed;
      top: 10px;
      left: 50%;
      transform: translateX(-50%);
      z-index: 1000000;
      background: linear-gradient(135deg, #1f2937, #374151);
      color: white;
      padding: 8px 16px;
      border-radius: 6px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 12px;
      font-weight: 500;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
      border: 1px solid #3b82f6;
      animation: fadeInSlide 0.3s ease-out;
    \`;
    notice.innerHTML = \`
      <div style="display: flex; align-items: center; gap: 8px;">
        <div style="width: 6px; height: 6px; background: #3b82f6; border-radius: 50%; animation: pulse 2s infinite;"></div>
        <span>🎯 Click any element to select it • Press ESC to cancel</span>
      </div>
    \`;
    
    // Add CSS animations
    const style = document.createElement('style');
    style.textContent = \`
      @keyframes fadeInSlide {
        from { opacity: 0; transform: translateX(-50%) translateY(-10px); }
        to { opacity: 1; transform: translateX(-50%) translateY(0); }
      }
      @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
      }
    \`;
    document.head.appendChild(style);
    
    document.body.appendChild(notice);
    return notice;
  }

  function removeSelectionNotice() {
    const notice = document.getElementById('iframe-selection-notice');
    if (notice) notice.remove();
  }

  function updateHighlight(element) {
    if (!highlightOverlay) return;
    const rect = element.getBoundingClientRect();
    highlightOverlay.style.left = rect.left + 'px';
    highlightOverlay.style.top = rect.top + 'px';
    highlightOverlay.style.width = rect.width + 'px';
    highlightOverlay.style.height = rect.height + 'px';
  }

  function removeHighlight() {
    if (highlightOverlay) {
      highlightOverlay.remove();
      highlightOverlay = null;
    }
  }

  function getReactComponentInfo(element) {
    try {
      // Get all keys on the element
      const keys = Object.keys(element);

      // Find React fiber key (always present in React apps)
      const reactKey = keys.find(
        (key) =>
          key.startsWith("__reactFiber$") ||
          key.startsWith("__reactInternalInstance$") ||
          key.startsWith("_reactInternalFiber") ||
          key.startsWith("_reactInternals")
      );

      if (!reactKey) return null;

      let fiber = element[reactKey];
      const componentPath = [];

      // Walk up the fiber tree and collect all components
      while (fiber) {
        if (fiber.type && typeof fiber.type === "function") {
          const componentName =
            fiber.type.displayName || fiber.type.name || "Anonymous";
          componentPath.push({
            name: componentName,
            sourceLocation: fiber._debugSource ? 
              \`\${fiber._debugSource.fileName}:\${fiber._debugSource.lineNumber}\` : 
              undefined
          });
        }
        fiber = fiber.return;
      }

      // Reverse the path so root is first (leftmost) and immediate component is last (rightmost)
      const reversedPath = componentPath.reverse();

      if (reversedPath.length === 0) return null;

      return {
        name: reversedPath.map((comp) => comp.name).join(" "), // Human readable path (Root → ... → Component)
        sourceLocation: reversedPath[reversedPath.length - 1]?.sourceLocation // Source location of the immediate component
      };
    } catch (error) {
      // Graceful fallback
      console.warn("Could not extract component path:", error);
      return null;
    }
  }

  function handleMouseOver(event) {
    if (!isSelecting) return;
    updateHighlight(event.target);
  }

  function handleClick(event) {
    if (!isSelecting) return;
    
    event.preventDefault();
    event.stopPropagation();
    
    const element = event.target;
    
    // Get element selector (simple implementation)
    function getSelector(el) {
      if (el.id) return '#' + el.id;
      if (el.className) return '.' + el.className.split(' ').join('.');
      return el.tagName.toLowerCase();
    }
    
    const selector = getSelector(element);
    const reactComponent = getReactComponentInfo(element);
    
    // Send data back to parent
    window.parent.postMessage({
      type: 'ELEMENT_SELECTED',
      data: {
        selector,
        reactComponent,
        tagName: element.tagName,
        className: element.className,
        id: element.id,
        textContent: element.textContent?.substring(0, 100)
      }
    }, '*');
    
    stopSelection();
  }

  function handleKeyDown(event) {
    if (event.key === 'Escape') {
      stopSelection();
      window.parent.postMessage({ type: 'SELECTION_CANCELLED' }, '*');
    }
  }

  function startSelection() {
    isSelecting = true;
    document.body.style.cursor = 'crosshair';
    highlightOverlay = createHighlightOverlay();
    createSelectionNotice();
    
    document.addEventListener('mouseover', handleMouseOver, true);
    document.addEventListener('click', handleClick, true);
    document.addEventListener('keydown', handleKeyDown, true);
  }

  function stopSelection() {
    isSelecting = false;
    document.body.style.cursor = 'default';
    removeHighlight();
    removeSelectionNotice();
    
    document.removeEventListener('mouseover', handleMouseOver, true);
    document.removeEventListener('click', handleClick, true);
    document.removeEventListener('keydown', handleKeyDown, true);
  }

  // Listen for messages from parent
  window.addEventListener('message', function(event) {
    if (event.data.type === 'START_ELEMENT_SELECTION') {
      startSelection();
    } else if (event.data.type === 'STOP_ELEMENT_SELECTION') {
      stopSelection();
    }
  });

  console.log('Element selector injected into iframe');
})();
`;

export function injectSelectorScript(iframe: HTMLIFrameElement): boolean {
  try {
    if (iframe.contentDocument) {
      // Same-origin iframe - inject directly
      const script = iframe.contentDocument.createElement('script');
      script.textContent = IFRAME_SELECTOR_SCRIPT;
      iframe.contentDocument.head.appendChild(script);
      return true;
    }
  } catch (error) {
    console.warn('Cannot inject script directly into iframe (cross-origin):', error);
  }
  return false;
}

export function sendMessageToIframe(iframe: HTMLIFrameElement, message: any) {
  if (iframe.contentWindow) {
    iframe.contentWindow.postMessage(message, '*');
  }
}
