import React from 'react';
import ContentToolbar from './ContentToolbar';

interface ContentPanelProps {
  iframeUrl: string;
  iframeId?: string;
  title?: string;
  onReload?: () => void;
}

const ContentPanel: React.FC<ContentPanelProps> = ({
  iframeUrl,
  iframeId = 'main-content-iframe',
  title = "Original Page Content",
  onReload
}) => {
  return (
    <div
      style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column'
      }}
    >
      <ContentToolbar 
        url={iframeUrl} 
        onReload={onReload}
        iframeId={iframeId}
      />
      
      <iframe
        id={iframeId}
        src={iframeUrl}
        style={{
          flex: 1,
          border: 'none',
          width: '100%'
        }}
        title={title}
      />
    </div>
  );
};

export default ContentPanel;
