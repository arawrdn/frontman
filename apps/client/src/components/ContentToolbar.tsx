import React from 'react';
import { ReloadIcon } from '@radix-ui/react-icons';

interface ContentToolbarProps {
  url: string;
  onReload?: () => void;
  iframeId?: string;
}

const ContentToolbar: React.FC<ContentToolbarProps> = ({
  url,
  onReload,
  iframeId = 'main-content-iframe'
}) => {
  const handleReload = () => {
    if (onReload) {
      onReload();
    } else {
      const iframe = document.querySelector(`#${iframeId}`) as HTMLIFrameElement;
      if (iframe) {
        iframe.src = iframe.src; // Reload iframe
      }
    }
  };

  return (
    <div
      style={{
        height: '50px',
        backgroundColor: '#f8fafc',
        borderBottom: '1px solid #e2e8f0',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 16px'
      }}
    >
      <div
        style={{
          fontSize: '14px',
          color: '#64748b',
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}
      >
        <ReloadIcon width={16} height={16} />
        {url}
      </div>

      <button
        onClick={handleReload}
        style={{
          padding: '6px 12px',
          backgroundColor: '#3b82f6',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          fontSize: '12px',
          cursor: 'pointer'
        }}
      >
        Reload
      </button>
    </div>
  );
};

export default ContentToolbar;
