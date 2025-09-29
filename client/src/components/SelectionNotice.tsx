import React, { useEffect, useState } from 'react';

interface SelectionNoticeProps {
  isSelecting: boolean;
  isIframeMode?: boolean;
  onCancel?: () => void;
}

const SelectionNotice: React.FC<SelectionNoticeProps> = ({
  isSelecting,
  isIframeMode = false,
  onCancel
}) => {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    if (isSelecting) {
      setIsVisible(true);
    } else {
      // Fade out after a short delay
      const timer = setTimeout(() => setIsVisible(false), 300);
      return () => clearTimeout(timer);
    }
  }, [isSelecting]);

  if (!isVisible) return null;

  return (
    <div
      style={{
        position: 'fixed',
        top: '20px',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 1000000,
        backgroundColor: isSelecting ? '#1f2937' : '#059669',
        color: 'white',
        padding: '12px 20px',
        borderRadius: '8px',
        boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        fontSize: '14px',
        fontWeight: '500',
        transition: 'all 0.3s ease',
        opacity: isSelecting ? 1 : 0,
        border: isSelecting ? '2px solid #3b82f6' : '2px solid #10b981'
      }}
    >
      {isSelecting ? (
        <>
          <div
            style={{
              width: '8px',
              height: '8px',
              backgroundColor: '#3b82f6',
              borderRadius: '50%',
              animation: 'pulse 2s infinite'
            }}
          />
          <span>
            {isIframeMode ? 
              '🎯 Click any element inside the iframe to select it' : 
              '🎯 Click any element to select it'
            }
          </span>
          <span style={{ color: '#9ca3af', fontSize: '12px' }}>
            Press ESC to cancel
          </span>
          {onCancel && (
            <button
              onClick={onCancel}
              style={{
                background: 'none',
                border: '1px solid #6b7280',
                color: '#9ca3af',
                padding: '4px 8px',
                borderRadius: '4px',
                fontSize: '12px',
                cursor: 'pointer',
                transition: 'all 0.2s'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = '#374151';
                e.currentTarget.style.color = 'white';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = 'transparent';
                e.currentTarget.style.color = '#9ca3af';
              }}
            >
              Cancel
            </button>
          )}
        </>
      ) : (
        <>
          <div
            style={{
              width: '8px',
              height: '8px',
              backgroundColor: '#10b981',
              borderRadius: '50%'
            }}
          />
          <span>✅ Element selected successfully!</span>
        </>
      )}
      
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>
    </div>
  );
};

export default SelectionNotice;
