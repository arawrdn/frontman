import React from 'react';
import { ReloadIcon } from '@radix-ui/react-icons';
import { SourceLocationState } from '../types/SelectElement';

interface SourceLocationDisplayProps {
  sourceLocation: SourceLocationState;
  compact?: boolean;
}

const SourceLocationDisplay: React.FC<SourceLocationDisplayProps> = ({
  sourceLocation,
  compact = false
}) => {
  const renderContent = () => {
    try {
    switch (sourceLocation.status) {
      case 'loading':
        return (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            color: '#6b7280',
            fontSize: compact ? '11px' : '12px',
            fontStyle: 'italic'
          }}>
            <ReloadIcon
              width={12}
              height={12}
              style={{
                animation: 'spin 1s linear infinite'
              }}
            />
            <span>Resolving source location...</span>
          </div>
        );

      case 'resolved':
        return (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '4px',
            color: '#10b981',
            fontSize: compact ? '11px' : '12px',
            fontFamily: 'monospace'
          }}>
            <span style={{ color: '#6b7280' }}>📍</span>
            <span>{sourceLocation.file}:{sourceLocation.line}</span>
          </div>
        );

      case 'error':
        return (
          <div style={{
            color: '#ef4444',
            fontSize: compact ? '11px' : '12px',
            fontStyle: 'italic'
          }}>
            ⚠️ {sourceLocation.message}
          </div>
        );

      case 'unavailable':
        return (
          <div style={{
            color: '#9ca3af',
            fontSize: compact ? '11px' : '12px',
            fontStyle: 'italic'
          }}>
            Source location unavailable
          </div>
        );

      default:
        return null;
    }
    } catch (error) {
      console.error('Error rendering source location:', error);
      return (
        <div style={{
          color: '#ef4444',
          fontSize: compact ? '11px' : '12px',
          fontStyle: 'italic'
        }}>
          ⚠️ Error displaying location
        </div>
      );
    }
  };

  return (
    <div style={{
      marginTop: compact ? '2px' : '4px'
    }}>
      {renderContent()}
      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
};

export default SourceLocationDisplay;