import { useCallback } from 'react';
import { mapToOriginalSource } from '../utils/sourceMapResolver';
import { SourceLocationState } from '../types/SelectElement';

interface UseSourceLocationResolverResult {
  resolveSourceLocation: (
    compiledLocation: { fileName: string; lineNumber: number; columnNumber: number }
  ) => Promise<SourceLocationState>;
}

/**
 * Hook for resolving compiled locations to original source locations
 */
export function useSourceLocationResolver(): UseSourceLocationResolverResult {
  const resolveSourceLocation = useCallback(
    async (
      compiledLocation: { fileName: string; lineNumber: number; columnNumber: number }
    ): Promise<SourceLocationState> => {
      try {
        console.log('Resolving source location for:', compiledLocation);

        const originalLocation = await mapToOriginalSource(compiledLocation);

        console.log('Original location result:', originalLocation);

        if (!originalLocation) {
          console.warn('mapToOriginalSource returned null');
          return {
            status: 'error',
            message: 'Could not resolve source location'
          };
        }

        // Clean up the source path (remove webpack prefixes, file:// URIs, absolute paths, etc.)
        let cleanPath = originalLocation.source;

        // Remove webpack:// prefix if present
        cleanPath = cleanPath.replace(/^webpack:\/\//, '');

        // Remove file:// URI prefix
        cleanPath = cleanPath.replace(/^file:\/\//, '');

        // Remove leading ./ or /
        cleanPath = cleanPath.replace(/^\.?\//, '');

        console.log('Resolved to:', { file: cleanPath, line: originalLocation.line });

        return {
          status: 'resolved',
          file: cleanPath,
          line: originalLocation.line
        };
      } catch (error) {
        console.error('Error resolving source location:', error);
        return {
          status: 'error',
          message: error instanceof Error ? error.message : 'Unknown error'
        };
      }
    },
    []
  );

  return { resolveSourceLocation };
}