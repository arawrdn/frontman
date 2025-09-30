import React, { useState, useCallback, useEffect, useRef } from 'react';
import { TargetIcon } from '@radix-ui/react-icons';
import { finder } from '@medv/finder';
import { snapdom } from '@zumer/snapdom';
import ErrorStackParser from 'error-stack-parser';
import { SelectElement } from '../types/SelectElement';
import { injectSelectorScript, sendMessageToIframe } from '../utils/iframeElementSelector';
import { useSourceLocationResolver } from '../hooks/useSourceLocationResolver';
import SelectionNotice from './SelectionNotice';

interface SelectElementButtonProps {
  onElementSelected: (element: SelectElement) => void;
  disabled?: boolean;
  selectedElement?: SelectElement | null;
  onClearSelection?: () => void;
}

const SelectElementButton: React.FC<SelectElementButtonProps> = ({
  onElementSelected,
  disabled = false,
  selectedElement = null,
  onClearSelection
}) => {
  const [isSelecting, setIsSelecting] = useState(false);
  const [hasIframe, setHasIframe] = useState(false);
  const [selectionSuccessful, setSelectionSuccessful] = useState(false);
  const cleanupFunctionRef = useRef<(() => void) | null>(null);
  const { resolveSourceLocation } = useSourceLocationResolver();

  /**
   * Extracts React component information and compiled source location from fiber._debugStack
   */
  const getReactComponentInfo = (element: Element): {
    name: string;
    compiledLocation?: { fileName: string; lineNumber: number; columnNumber: number };
  } | undefined => {
    try {
      const isDevelopment = import.meta.env.DEV;

      // Get all keys on the element
      const keys = Object.keys(element);

      // Find React fiber key
      const reactKey = keys.find(
        (key) =>
          key.startsWith("__reactFiber$") ||
          key.startsWith("__reactInternalInstance$") ||
          key.startsWith("_reactInternalFiber") ||
          key.startsWith("_reactInternals")
      );

      if (!reactKey) return undefined;

      // @ts-expect-error - Accessing React internal fiber
      let fiber = element[reactKey];
      const componentPath = [];

      // Walk up the fiber tree and collect all components
      while (fiber) {
        if (fiber.type && typeof fiber.type === "function") {
          const componentName =
            fiber.type.displayName || fiber.type.name || "Anonymous";
          componentPath.push(componentName);
        }
        fiber = fiber.return;
      }

      // Reverse the path so root is first
      const reversedPath = componentPath.reverse();
      if (reversedPath.length === 0) return undefined;

      // Get the leaf component's fiber (the immediate parent of the element)
      // Walk back down to find it
      // @ts-expect-error - Accessing React internal fiber
      fiber = element[reactKey];
      while (fiber && (!fiber.type || typeof fiber.type !== "function")) {
        fiber = fiber.return;
      }

      if (!fiber) return {
        name: reversedPath.join(" → ")
      };

      // Skip _debugStack parsing in production
      if (!isDevelopment) {
        return {
          name: reversedPath.join(" → ")
        };
      }

      // Try to get _debugStack
      if (!fiber._debugStack) {
        console.warn("No _debugStack found on fiber");
        return {
          name: reversedPath.join(" → ")
        };
      }

      console.log("_debugStack type:", typeof fiber._debugStack);
      console.log("_debugStack value:", fiber._debugStack);

      // Parse the stack trace
      try {
        // _debugStack might be an Error object or a string
        let stackString: string;
        if (typeof fiber._debugStack === 'string') {
          stackString = fiber._debugStack;
        } else if (fiber._debugStack instanceof Error) {
          stackString = fiber._debugStack.stack || '';
        } else if (fiber._debugStack && typeof fiber._debugStack === 'object' && 'stack' in fiber._debugStack) {
          stackString = (fiber._debugStack as { stack?: string }).stack || '';
        } else {
          console.warn("_debugStack is not a string or Error object:", fiber._debugStack);
          return {
            name: reversedPath.join(" → ")
          };
        }

        if (!stackString) {
          console.warn("No stack string found");
          return {
            name: reversedPath.join(" → ")
          };
        }

        // Create an Error object with the debug stack
        const error = new Error();
        error.stack = stackString;

        console.log("Stack string to parse:", stackString);

        const frames = ErrorStackParser.parse(error);
        console.log("Parsed frames:", frames);

        // Filter to find the actual component frame
        // Look for frames between react-stack-top-frame and react_stack_bottom_frame
        const topFrameIndex = frames.findIndex(f =>
          f.functionName?.includes('react-stack-top-frame') ||
          f.functionName?.includes('jsxDEV')
        );
        const bottomFrameIndex = frames.findIndex(f =>
          f.functionName?.includes('react_stack_bottom_frame')
        );

        let relevantFrames = frames;
        if (topFrameIndex !== -1 && bottomFrameIndex !== -1 && bottomFrameIndex > topFrameIndex) {
          relevantFrames = frames.slice(topFrameIndex + 1, bottomFrameIndex);
        }

        // Filter out node_modules, React internals, and framework chunks
        const userFrames = relevantFrames.filter(frame => {
          const fileName = frame.fileName || '';
          const funcName = frame.functionName || '';

          // Exclude node_modules (various formats)
          if (fileName.includes('/node_modules/') ||
              fileName.includes('node_modules_') ||
              fileName.includes('/node_modules_')) {
            return false;
          }

          // Exclude React internals
          if (fileName.includes('/react-dom/') ||
              fileName.includes('/react/') ||
              funcName.includes('renderWith') ||
              funcName.includes('beginWork') ||
              funcName.includes('performWork') ||
              funcName.includes('runWithFiber')) {
            return false;
          }

          return true;
        });

        console.log("User frames after filtering:", userFrames);

        if (userFrames.length === 0) {
          console.warn("No user frames found in stack");
          return {
            name: reversedPath.join(" → ")
          };
        }

        // Get the first user frame (top of user code stack)
        const topFrame = userFrames[0];

        console.log("Top frame selected:", topFrame);

        return {
          name: reversedPath.join(" → "),
          compiledLocation: {
            fileName: topFrame.fileName || '',
            lineNumber: topFrame.lineNumber || 0,
            columnNumber: topFrame.columnNumber || 0
          }
        };
      } catch (stackError) {
        console.warn("Error parsing _debugStack:", stackError);
        return {
          name: reversedPath.join(" → ")
        };
      }
    } catch (error) {
      console.warn("Could not extract component path:", error);
      return undefined;
    }
  };

  const cleanup = useCallback(() => {
    setIsSelecting(false);
    document.body.style.cursor = 'default';
    
    // Remove event listeners from iframe if present and send stop message
    const iframe = document.getElementById('main-content-iframe') as HTMLIFrameElement;
    if (iframe) {
      sendMessageToIframe(iframe, { type: 'STOP_ELEMENT_SELECTION' });
    }
    
    // Remove highlight overlay if it exists
    const overlay = document.getElementById('select-element-overlay');
    if (overlay) {
      overlay.remove();
    }

    // Remove any stored event listeners
    if (cleanupFunctionRef.current) {
      cleanupFunctionRef.current();
      cleanupFunctionRef.current = null;
    }
  }, []);

  // Check for iframe and set up message listener
  useEffect(() => {
    const iframe = document.getElementById('main-content-iframe') as HTMLIFrameElement;
    setHasIframe(!!iframe);

    // Listen for messages from iframe
    const handleMessage = async (event: MessageEvent) => {
      if (event.data.type === 'ELEMENT_SELECTED') {
        const data = event.data.data;
        
        try {
          // Get iframe element for screenshot
          const iframe = document.getElementById('main-content-iframe') as HTMLIFrameElement;
          if (iframe) {
            // Take screenshot of the iframe (we can't screenshot individual elements inside cross-origin iframes)
            const result = await snapdom(iframe);
            const screenshot = result.url;

            const selectElement: SelectElement = {
              selector: data.selector,
              screenshot,
              reactComponent: data.reactComponent
            };

            onElementSelected(selectElement);
            setSelectionSuccessful(true);
            setTimeout(() => setSelectionSuccessful(false), 2000);
          }
        } catch (error) {
          console.error('Error processing iframe element selection:', error);
        }
        
        cleanup();
      } else if (event.data.type === 'SELECTION_CANCELLED') {
        cleanup();
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [onElementSelected, cleanup]);

  const handleElementSelection = useCallback(async (event: MouseEvent, targetDocument?: Document) => {
    event.preventDefault();
    event.stopPropagation();

    const element = event.target as Element;
    if (!element) return;

    // Ignore clicks on the widget itself (chat panel, buttons, etc.)
    // Check if the element or any parent has data-widget-ui attribute
    let checkElement: Element | null = element;
    while (checkElement) {
      if (checkElement.hasAttribute && checkElement.hasAttribute('data-widget-ui')) {
        console.log('Ignoring click on widget UI element');
        return;
      }
      checkElement = checkElement.parentElement;
    }

    try {
      // Determine the root for the selector
      const doc = targetDocument || document;
      const root = doc.body || doc.documentElement;

      // Generate selector using @medv/finder
      const selector = finder(element, {
        root: root,
        idName: () => true,
        className: () => true,
        tagName: () => true,
        attr: () => false,
        seedMinLength: 1,
        optimizedMinLength: 2,
        maxNumberOfPathChecks: 10000
      });

      // Take screenshot using @zumer/snapdom
      const result = await snapdom(element);
      const screenshot = result.url;

      // Get React component info (returns compiled location)
      const reactComponentInfo = getReactComponentInfo(element);

      // Add iframe context if element is from iframe
      const isFromIframe = targetDocument && targetDocument !== document;
      const finalSelector = isFromIframe ? `iframe ${selector}` : selector;

      // Create initial select element with loading state
      const selectElement: SelectElement = {
        selector: finalSelector,
        screenshot,
        reactComponent: reactComponentInfo ? {
          name: reactComponentInfo.name,
          sourceLocation: reactComponentInfo.compiledLocation
            ? { status: 'loading' }
            : { status: 'unavailable' }
        } : undefined
      };

      // Send initial selection immediately
      onElementSelected(selectElement);
      setSelectionSuccessful(true);
      setTimeout(() => setSelectionSuccessful(false), 2000);

      // Resolve source location asynchronously if we have a compiled location
      if (reactComponentInfo?.compiledLocation) {
        console.log('Starting async source location resolution...');

        // Clean up selection mode before starting async work
        cleanup();

        const resolvedState = await resolveSourceLocation(reactComponentInfo.compiledLocation);

        // Update the element with resolved source location
        const updatedElement: SelectElement = {
          ...selectElement,
          reactComponent: {
            name: reactComponentInfo.name,
            sourceLocation: resolvedState
          }
        };

        console.log('Calling onElementSelected with updated element:', updatedElement);
        onElementSelected(updatedElement);
      } else {
        // No source location to resolve, just cleanup
        cleanup();
      }
    } catch (error) {
      console.error('Error selecting element:', error);
      cleanup();
    }
  }, [onElementSelected, cleanup, resolveSourceLocation, getReactComponentInfo]);

  const handleButtonClick = () => {
    if (disabled) return;
    
    // If an element is already selected and we're not currently selecting, 
    // clear the selection and start fresh
    if (selectedElement && !isSelecting) {
      if (onClearSelection) {
        onClearSelection();
      }
      return;
    }
    
    // If we're currently selecting, cancel the selection
    if (isSelecting) {
      cleanup();
      return;
    }
    
    // Start new selection
    startSelection();
  };

  const startSelection = () => {
    setIsSelecting(true);
    document.body.style.cursor = 'crosshair';
    
    // Create event handlers
    const handleMainDocumentClick = (event: MouseEvent) => {
      handleElementSelection(event, document);
    };

    const handleIframeClick = (event: MouseEvent) => {
      const iframe = document.getElementById('main-content-iframe') as HTMLIFrameElement;
      if (iframe && iframe.contentDocument) {
        handleElementSelection(event, iframe.contentDocument);
      }
    };

    const handleEscapeKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        cleanup();
      }
    };

    // Add event listeners for element selection on main document
    document.addEventListener('click', handleMainDocumentClick, true);
    document.addEventListener('keydown', handleEscapeKey, true);
    
    // Store cleanup function
    cleanupFunctionRef.current = () => {
      document.removeEventListener('click', handleMainDocumentClick, true);
      document.removeEventListener('keydown', handleEscapeKey, true);
    };

    // Handle iframe content - try both same-origin and cross-origin approaches
    const iframe = document.getElementById('main-content-iframe') as HTMLIFrameElement;
    if (iframe) {
      try {
        if (iframe.contentDocument) {
          // Same-origin iframe - direct access
          iframe.contentDocument.addEventListener('click', handleIframeClick, true);
          iframe.contentDocument.addEventListener('keydown', handleEscapeKey, true);
          if (iframe.contentDocument.body) {
            iframe.contentDocument.body.style.cursor = 'crosshair';
          }
          
          // Update cleanup function to include iframe listeners
          const originalCleanup = cleanupFunctionRef.current;
          cleanupFunctionRef.current = () => {
            originalCleanup?.();
            if (iframe.contentDocument) {
              iframe.contentDocument.removeEventListener('click', handleIframeClick, true);
              iframe.contentDocument.removeEventListener('keydown', handleEscapeKey, true);
              if (iframe.contentDocument.body) {
                iframe.contentDocument.body.style.cursor = 'default';
              }
            }
          };
        }
      } catch (error) {
        console.warn('Cannot access iframe content directly (cross-origin):', error);
      }

      // Always try to inject script and send message (works for both same-origin and cross-origin)
      injectSelectorScript(iframe);
      sendMessageToIframe(iframe, { type: 'START_ELEMENT_SELECTION' });
    }
  };

  return (
    <>
      <SelectionNotice 
        isSelecting={isSelecting && !selectionSuccessful}
        isIframeMode={hasIframe}
        onCancel={cleanup}
      />
      {selectionSuccessful && (
        <SelectionNotice 
          isSelecting={false}
          isIframeMode={false}
        />
      )}
      <button
        onClick={handleButtonClick}
        disabled={disabled}
        title={
          selectedElement && !isSelecting ? "Clear Selection" :
          isSelecting ? "Cancel Selection" : 
          "Select Element"
        }
        style={{
          width: '28px',
          height: '28px',
          backgroundColor: 
            isSelecting ? '#ef4444' : 
            selectedElement ? '#10b981' : 
            '#6b7280',
          border: 'none',
          borderRadius: '4px',
          cursor: disabled ? 'not-allowed' : 'pointer',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transition: 'background-color 0.2s'
        }}
      >
        <TargetIcon 
          width={14} 
          height={14} 
          color="white" 
        />
      </button>
    </>
  );
};

export default SelectElementButton;