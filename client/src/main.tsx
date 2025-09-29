import React from 'react';
import ReactDOM from 'react-dom/client';
import SplitLayoutWidget from './SplitLayoutWidget';
import './index.css';

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', () => {
  const rootElement = document.getElementById('root');
  console.log('rootElement', rootElement);
  if (rootElement) {
    ReactDOM.createRoot(rootElement).render(
      <React.StrictMode>
        <SplitLayoutWidget />
      </React.StrictMode>
    );
  }
});
