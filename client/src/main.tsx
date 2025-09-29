import React from 'react';
import ReactDOM from 'react-dom/client';
import SplitLayoutWidget from './SplitLayoutWidget';

// Function to inject the split layout widget into any webpage
function injectSplitLayoutWidget() {
  // Avoid multiple injections
  if (document.getElementById('split-layout-widget-root')) {
    return;
  }

  // Hide the original page content
  const originalBody = document.body;
  originalBody.style.overflow = 'hidden';

  // Create shadow host element that takes full page
  const shadowHost = document.createElement('div');
  shadowHost.id = 'split-layout-widget-root';
  shadowHost.style.position = 'fixed';
  shadowHost.style.top = '0';
  shadowHost.style.left = '0';
  shadowHost.style.width = '100vw';
  shadowHost.style.height = '100vh';
  shadowHost.style.zIndex = '999999';
  shadowHost.style.backgroundColor = '#fff';

  // Attach shadow DOM
  const shadowRoot = shadowHost.attachShadow({ mode: 'closed' });

  // Create style element for shadow DOM
  const style = document.createElement('style');
  style.textContent = `
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    html, body {
      height: 100%;
      overflow: hidden;
    }

    /* Reset any potential interference from host page */
    div, button, textarea, span, h1, h2, h3, h4, h5, h6, p {
      margin: 0;
      padding: 0;
      border: 0;
      outline: 0;
      font-size: 100%;
      vertical-align: baseline;
      background: transparent;
    }

    /* Enable all pointer events for our widget content */
    #widget-container {
      pointer-events: auto;
      height: 100vh;
      width: 100vw;
    }

    /* Ensure textarea behaves properly */
    textarea {
      font-family: inherit;
      resize: vertical;
    }

    button {
      font-family: inherit;
    }
  `;

  // Create container for React app within shadow DOM
  const container = document.createElement('div');
  container.id = 'widget-container';

  // Append styles and container to shadow root
  shadowRoot.appendChild(style);
  shadowRoot.appendChild(container);

  // Append shadow host to document body
  document.body.appendChild(shadowHost);

  // Create React root and render the widget
  const root = ReactDOM.createRoot(container);
  root.render(
    <React.StrictMode>
      <SplitLayoutWidget />
    </React.StrictMode>
  );

  return {
    unmount: () => {
      root.unmount();
      document.body.removeChild(shadowHost);
      originalBody.style.overflow = '';
    }
  };
}

// Auto-inject when script loads (for direct inclusion)
if (typeof window !== 'undefined') {
  // Wait for DOM to be ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectSplitLayoutWidget);
  } else {
    injectSplitLayoutWidget();
  }
}

// Export for manual usage
export { injectSplitLayoutWidget };
export default injectSplitLayoutWidget;
