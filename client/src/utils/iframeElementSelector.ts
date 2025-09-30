import { finder } from "@medv/finder";
import { snapdom } from "@zumer/snapdom";
import { useCallback, useEffect, useRef } from "react";
import { getReactComponentInfo as extractReactComponentInfo, generateIframeReactExtractorScript } from "./reactFiberExtractor";

interface ElementSelectorProps {
	isActive: boolean;
	onElementSelected: (
		element: Element,
		imageDataUrl?: string,
		cssSelector?: string,
		componentPath?: string,
	) => void;
	onCancel: () => void;
	onOpenDialog: () => void;
	selectedElements: Element[];
}

export const ElementSelector: React.FC<ElementSelectorProps> = ({
	isActive,
	onElementSelected,
	onCancel,
	onOpenDialog,
	selectedElements,
}) => {
	const lastHighlightedElement = useRef<Element | null>(null);
	const overlayRef = useRef<HTMLDivElement | null>(null);

	// Hover-cycle state
	const hoverStartTopElementRef = useRef<Element | null>(null);
	const hoverTimeoutRef = useRef<number | null>(null);
	const hoverIntervalRef = useRef<number | null>(null);
	const lastMousePosRef = useRef<{ x: number; y: number } | null>(null);
	const elementStackRef = useRef<Element[]>([]);
	const stackIndexRef = useRef<number>(0);

	const removeHighlight = useCallback(() => {
		if (lastHighlightedElement.current) {
			lastHighlightedElement.current.classList.remove(
				"element-selector-highlight",
			);
			lastHighlightedElement.current = null;
		}
		if (overlayRef.current) {
			overlayRef.current.style.display = "none";
		}
	}, []);

	const isElementSelected = useCallback(
		(element: Element) => {
			return selectedElements.includes(element);
		},
		[selectedElements],
	);

	const getComponentPath = useCallback((element: Element) => {
		const componentInfo = extractReactComponentInfo(element);
		if (!componentInfo) return null;

		// Return in the format expected by the rest of the code
		return {
			pathString: componentInfo.name,
			// Legacy fields not used but kept for compatibility
			path: [],
			root: null
		};
	}, []);

	const generateCssSelector = useCallback((element: Element): string => {
		try {
			// Generate optimal CSS selector
			console.log("📋 Generating CSS selector for element:", element);
			return finder(element, {
				root: document.body,
				className: (name: string) =>
					!name.includes("element-selector-") && !name.includes("ask-the-llm-"),
			});
		} catch (error) {
			console.warn("Failed to generate CSS selector:", error);
			// Fallback to basic selector
			const tagName = element.tagName.toLowerCase();
			const id = element.id ? `#${element.id}` : "";
			const classes = element.className
				? `.${element.className.split(" ").join(".")}`
				: "";
			return `${tagName}${id}${classes}`.replace(/\s+/g, "");
		}
	}, []);

	const highlightElement = useCallback(
		(element: Element) => {
			removeHighlight();

			const shadowHost = element.closest("#ask-the-llm-host");
			if (shadowHost) return;

			element.classList.add("element-selector-highlight");
			lastHighlightedElement.current = element;

			if (!overlayRef.current) {
				overlayRef.current = document.createElement("div");
				overlayRef.current.className = "element-selector-overlay";
				document.body.appendChild(overlayRef.current);
			}

			const rect = element.getBoundingClientRect();
			const overlay = overlayRef.current;
			const isSelected = isElementSelected(element);

			overlay.style.display = "block";
			overlay.style.left = `${rect.left + window.scrollX}px`;
			overlay.style.top = `${rect.top + window.scrollY}px`;
			overlay.style.width = `${rect.width}px`;
			overlay.style.height = `${rect.height}px`;

			if (isSelected) {
				overlay.className =
					"element-selector-overlay element-selector-overlay-selected";
			} else {
				overlay.className = "element-selector-overlay";
			}
		},
		[removeHighlight, isElementSelected],
	);

	const isOurUiElement = useCallback((element: Element): boolean => {
		if (element.closest(".element-selector-overlay")) {
			return true;
		}
		const shadowHost = element.closest("#ask-the-llm-host");
		return Boolean(shadowHost);
	}, []);

	const getFilteredElementsFromPoint = useCallback(
		(x: number, y: number): Element[] => {
			const all = document.elementsFromPoint(x, y);
			return all.filter((el) => !isOurUiElement(el));
		},
		[isOurUiElement],
	);

	const clearHoverTimers = useCallback(() => {
		if (hoverTimeoutRef.current !== null) {
			window.clearTimeout(hoverTimeoutRef.current);
			hoverTimeoutRef.current = null;
		}
		if (hoverIntervalRef.current !== null) {
			window.clearInterval(hoverIntervalRef.current);
			hoverIntervalRef.current = null;
		}
	}, []);

	const startHoverCycle = useCallback(() => {
		clearHoverTimers();
		// First descent after 1s, then every 1s
		hoverTimeoutRef.current = window.setTimeout(() => {
			const stack = elementStackRef.current;
			if (stack.length === 0) return;
			stackIndexRef.current = Math.min(
				stackIndexRef.current + 1,
				stack.length - 1,
			);
			highlightElement(stack[stackIndexRef.current]);
			// Continue descending every second until bottom reached
			hoverIntervalRef.current = window.setInterval(() => {
				const s = elementStackRef.current;
				if (s.length === 0) return;
				if (stackIndexRef.current >= s.length - 1) {
					clearHoverTimers();
					return;
				}
				stackIndexRef.current += 1;
				highlightElement(s[stackIndexRef.current]);
			}, 1000);
		}, 1000);
	}, [clearHoverTimers, highlightElement]);

	const captureElementImage = useCallback(
		async (element: Element): Promise<string | undefined> => {
			try {
				const result = await snapdom(element as HTMLElement);
				const canvas = await result.toCanvas();
        return canvas.toDataURL("image/png");
			} catch (error) {
				console.warn("Failed to capture element image:", error);
				return undefined;
			}
		},
		[],
	);

	const handleMouseMove = useCallback(
		(e: MouseEvent) => {
			if (!isActive) return;

			e.preventDefault();
			e.stopPropagation();

			const { clientX, clientY } = e;

			const lastPos = lastMousePosRef.current;
			const moved = !lastPos || lastPos.x !== clientX || lastPos.y !== clientY;
			if (moved) {
				lastMousePosRef.current = { x: clientX, y: clientY };
				// Rebuild stack and reset cycle when pointer moves
				const elements = getFilteredElementsFromPoint(clientX, clientY);
				if (elements.length > 0) {
					elementStackRef.current = elements;
					stackIndexRef.current = 0;
					hoverStartTopElementRef.current = elements[0];
					highlightElement(elements[0]);
					startHoverCycle();
				} else {
					clearHoverTimers();
					removeHighlight();
				}
				return;
			}

			// If not moved, ensure we are still over the same starting top element
			const currentTop = document.elementFromPoint(clientX, clientY);
			if (
				currentTop &&
				!isOurUiElement(currentTop) &&
				hoverStartTopElementRef.current &&
				currentTop !== hoverStartTopElementRef.current
			) {
				// Pointer left the original element; reset to new context
				const elements = getFilteredElementsFromPoint(clientX, clientY);
				if (elements.length > 0) {
					elementStackRef.current = elements;
					stackIndexRef.current = 0;
					hoverStartTopElementRef.current = elements[0];
					highlightElement(elements[0]);
					startHoverCycle();
				} else {
					clearHoverTimers();
					removeHighlight();
				}
			}
		},
		[
			isActive,
			getFilteredElementsFromPoint,
			isOurUiElement,
			highlightElement,
			startHoverCycle,
			clearHoverTimers,
			removeHighlight,
		],
	);

	const handleClick = useCallback(
		async (e: MouseEvent) => {
			if (!isActive) return;

			const possibleOurUiElement = document.elementFromPoint(
				e.clientX,
				e.clientY,
			);
			if (possibleOurUiElement) {
				// Don't select our own components - let them handle their own clicks
				if (isOurUiElement(possibleOurUiElement)) return;
			}

			// Only prevent default and stop propagation for actual element selection
			e.preventDefault();
			e.stopPropagation();

			const element =
				lastHighlightedElement.current ||
				document.elementFromPoint(e.clientX, e.clientY);

			if (element) {
				clearHoverTimers();

				// Generate CSS selector for this element
				const cssSelector = generateCssSelector(element);

				// Get full component path from element to root
				const componentPath = getComponentPath(element);

				// Capture the element image before calling onElementSelected (only if not already selected)
				const isSelected = isElementSelected(element);
				let imageDataUrl: string | undefined;

				if (!isSelected) {
					imageDataUrl = await captureElementImage(element);
				}

				onElementSelected(
					element,
					imageDataUrl,
					cssSelector,
					componentPath?.pathString,
				);
			}
		},
		[
			isActive,
			onElementSelected,
			clearHoverTimers,
			captureElementImage,
			isElementSelected,
			generateCssSelector,
			getComponentPath,
			isOurUiElement,
		],
	);

	const handleKeyDown = useCallback(
		(e: KeyboardEvent) => {
			if (!isActive) return;

			if (e.key === "Escape") {
				e.preventDefault();
				removeHighlight();
				onCancel();
			} else if (e.key === "Enter") {
				e.preventDefault();
				removeHighlight();
				onOpenDialog();
			}
		},
		[isActive, onCancel, onOpenDialog, removeHighlight],
	);

	useEffect(() => {
		if (isActive) {
			// Add CSS for highlighting including selected state
			const style = document.createElement("style");
			style.id = "element-selector-styles";
			style.textContent = `
        .element-selector-highlight {
          outline: 2px solid #667eea !important;
          outline-offset: -2px !important;
          background-color: rgba(102, 126, 234, 0.1) !important;
          cursor: grab !important;
        }
        
        .element-selector-overlay {
          position: absolute;
          pointer-events: none;
          border: 2px solid #667eea;
          background-color: rgba(102, 126, 234, 0.1);
          z-index: 9999;
          box-sizing: border-box;
        }
        
        .element-selector-overlay-selected {
          border: 2px solid #f59e0b !important;
          background-color: rgba(245, 158, 11, 0.2) !important;
        }
        
        * {
          cursor: grab !important;
        }
      `;
			document.head.appendChild(style);

			// Add persistent styling to already selected elements
			for (const element of selectedElements) {
				element.classList.add("element-selector-selected");
			}

			// Add styles for selected elements
			const selectedStyle = document.createElement("style");
			selectedStyle.id = "element-selector-selected-styles";
			selectedStyle.textContent = `
        .element-selector-selected {
          background-color: rgba(245, 158, 11, 0.15) !important;
          outline: 1px solid #f59e0b !important;
          outline-offset: -1px !important;
        }
      			`;
			document.head.appendChild(selectedStyle);

			// Add event listeners
			document.addEventListener("mousemove", handleMouseMove, true);
			document.addEventListener("click", handleClick, true);
			document.addEventListener("keydown", handleKeyDown, true);

			// Prevent text selection during element selection
			document.body.style.userSelect = "none";

			return () => {
				// Cleanup
				document.removeEventListener("mousemove", handleMouseMove, true);
				document.removeEventListener("click", handleClick, true);
				document.removeEventListener("keydown", handleKeyDown, true);
				clearHoverTimers();

				const existingStyle = document.getElementById(
					"element-selector-styles",
				);
				if (existingStyle) {
					existingStyle.remove();
				}

				const existingSelectedStyle = document.getElementById(
					"element-selector-selected-styles",
				);
				if (existingSelectedStyle) {
					existingSelectedStyle.remove();
				}

				// Remove selected styling from all elements
				for (const element of selectedElements) {
					element.classList.remove("element-selector-selected");
				}

				removeHighlight();

				if (overlayRef.current) {
					overlayRef.current.remove();
					overlayRef.current = null;
				}

				document.body.style.userSelect = "";
			};
		}
	}, [
		isActive,
		handleMouseMove,
		handleClick,
		handleKeyDown,
		removeHighlight,
		clearHoverTimers,
		selectedElements,
	]);

	return null; // This component doesn't render anything itself
};

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

  ${generateIframeReactExtractorScript()}

  function handleMouseOver(event) {
    if (!isSelecting) return;
    updateHighlight(event.target);
  }

  function handleClick(event) {
    if (!isSelecting) return;
    
    event.preventDefault();
    event.stopPropagation();
    
    const element = event.target;
    
    function getSelector(el) {
      if (el.id) return '#' + el.id;
      if (el.className) return '.' + el.className.split(' ').join('.');
      return el.tagName.toLowerCase();
    }
    
    const selector = getSelector(element);
    const reactComponent = getReactComponentInfo(element);
    
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
})();
`;

export function injectSelectorScript(iframe: HTMLIFrameElement): boolean {
	try {
		if (iframe.contentDocument) {
			// Same-origin iframe - inject directly
			const script = iframe.contentDocument.createElement("script");
			script.textContent = IFRAME_SELECTOR_SCRIPT;
			iframe.contentDocument.head.appendChild(script);
			return true;
		}
	} catch (error) {
		console.warn(
			"Cannot inject script directly into iframe (cross-origin):",
			error,
		);
	}
	return false;
}

export function sendMessageToIframe(iframe: HTMLIFrameElement, message: any) {
	if (iframe.contentWindow) {
		iframe.contentWindow.postMessage(message, "*");
	}
}
