import React, { useState, useCallback, useEffect, useRef } from 'react';
import { TargetIcon } from '@radix-ui/react-icons';
import { finder } from '@medv/finder';
import { snapdom } from '@zumer/snapdom';
import { SelectElement } from '../types/SelectElement';
import { injectSelectorScript, sendMessageToIframe } from '../utils/iframeElementSelector';
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

  const getReactComponentInfo = (element: Element) => {
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

      if (!reactKey) return undefined;

      // @ts-ignore
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
              `${fiber._debugSource.fileName}:${fiber._debugSource.lineNumber}` : 
              undefined
          });
        }
        fiber = fiber.return;
      }

      // Reverse the path so root is first (leftmost) and immediate component is last (rightmost)
      const reversedPath = componentPath.reverse();

      if (reversedPath.length === 0) return undefined;

      return {
        name: reversedPath.map((comp) => comp.name).join(" → "), // Human readable path (Root → ... → Component)
        sourceLocation: reversedPath[reversedPath.length - 1]?.sourceLocation // Source location of the immediate component
      };
    } catch (error) {
      // Graceful fallback
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

    try {
      // Determine the root for the selector
      const doc = targetDocument || document;
      const root = doc.body || doc.documentElement;

      // Generate selector using @medv/finder
      const selector = finder(element, {
        root: root,
        idName: (name) => true,
        className: (name) => true,
        tagName: (name) => true,
        attr: (name, value) => false,
        seedMinLength: 1,
        optimizedMinLength: 2,
        maxNumberOfPathChecks: 10000
      });

      // Take screenshot using @zumer/snapdom and get base64 data URL
      const result = await snapdom(element);
      const screenshot = result.url; // This is a base64 data URL

      // Get React component info
      const reactComponent = getReactComponentInfo(element);

      // Add iframe context if element is from iframe
      const isFromIframe = targetDocument && targetDocument !== document;
      const finalSelector = isFromIframe ? `iframe ${selector}` : selector;

      const selectElement: SelectElement = {
        selector: finalSelector,
        screenshot,
        reactComponent
      };

      onElementSelected(selectElement);
      setSelectionSuccessful(true);
      setTimeout(() => setSelectionSuccessful(false), 2000);
      cleanup();
    } catch (error) {
      console.error('Error selecting element:', error);
      cleanup();
    }
  }, [onElementSelected, cleanup]);

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