import { SourceMapConsumer, type RawSourceMap } from 'source-map-js';

/**
 * In-memory cache for parsed source maps
 * Key: source map URL, Value: SourceMapConsumer instance
 */
const sourceMapCache = new Map<string, SourceMapConsumer>();

/**
 * Original source location after source map resolution
 */
export interface OriginalLocation {
  source: string;      // Original file path (e.g., "src/components/Button.tsx")
  line: number;        // Line number in original source (1-based)
  column: number;      // Column number in original source (0-based)
}

/**
 * Compiled location from stack frame
 */
export interface CompiledLocation {
  fileName: string;    // Compiled file URL
  lineNumber: number;  // Line in compiled code (1-based)
  columnNumber: number; // Column in compiled code (1-based, needs conversion)
}

/**
 * Fetches the source map file for a given JavaScript file
 * @param jsFileUrl - URL of the compiled JavaScript file
 * @returns Raw source map JSON or null if not found
 *
 * Includes a 5-second timeout to prevent hanging on slow networks.
 */
async function fetchSourceMap(jsFileUrl: string): Promise<RawSourceMap | null> {
  try {
    // Create abort controller for 5-second timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    try {
      // Fetch the JavaScript file to find source map reference
      const jsResponse = await fetch(jsFileUrl, { signal: controller.signal });
      clearTimeout(timeoutId);

      if (!jsResponse.ok) {
        console.warn(`Failed to fetch JS file: ${jsFileUrl}`);
        return null;
      }

      const jsContent = await jsResponse.text();

      // Look for sourceMappingURL comment
      const sourceMapMatch = jsContent.match(/\/\/# sourceMappingURL=(.+)$/m);
      if (!sourceMapMatch) {
        console.warn(`No source map found in: ${jsFileUrl}`);
        return null;
      }

      // Resolve source map URL relative to JS file
      const sourceMapUrl = new URL(sourceMapMatch[1], jsFileUrl).href;

      // Fetch the source map file with same timeout
      const mapTimeoutId = setTimeout(() => controller.abort(), 5000);
      const mapResponse = await fetch(sourceMapUrl, { signal: controller.signal });
      clearTimeout(mapTimeoutId);

      if (!mapResponse.ok) {
        console.warn(`Failed to fetch source map: ${sourceMapUrl}`);
        return null;
      }

      return await mapResponse.json();
    } finally {
      clearTimeout(timeoutId);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      console.warn(`Timeout fetching source map for ${jsFileUrl}`);
    } else {
      console.warn(`Error fetching source map for ${jsFileUrl}:`, error);
    }
    return null;
  }
}

/**
 * Gets or creates a SourceMapConsumer, using cache when available
 * @param sourceMapUrl - URL of the source map file
 * @param rawSourceMap - Raw source map JSON
 * @returns SourceMapConsumer instance or null
 */
async function getCachedSourceMapConsumer(
  sourceMapUrl: string,
  rawSourceMap: RawSourceMap
): Promise<SourceMapConsumer | null> {
  try {
    // Check cache first
    if (sourceMapCache.has(sourceMapUrl)) {
      return sourceMapCache.get(sourceMapUrl)!;
    }

    // Create new consumer
    const consumer = await new SourceMapConsumer(rawSourceMap);

    // Cache it
    sourceMapCache.set(sourceMapUrl, consumer);

    return consumer;
  } catch (error) {
    console.warn(`Error creating SourceMapConsumer:`, error);
    return null;
  }
}

/**
 * Maps a compiled location to its original source location
 * @param location - Compiled location from stack frame
 * @returns Original location or null if mapping failed
 */
export async function mapToOriginalSource(
  location: CompiledLocation
): Promise<OriginalLocation | null> {
  try {
    console.log('[sourceMapResolver] Fetching source map for:', location.fileName);

    // Fetch source map
    const rawSourceMap = await fetchSourceMap(location.fileName);
    if (!rawSourceMap) {
      console.warn('[sourceMapResolver] Failed to fetch source map');
      return null;
    }

    console.log('[sourceMapResolver] Source map fetched successfully');

    // Get or create consumer (with caching)
    const sourceMapUrl = `${location.fileName}.map`;
    const consumer = await getCachedSourceMapConsumer(sourceMapUrl, rawSourceMap);
    if (!consumer) {
      console.warn('[sourceMapResolver] Failed to create source map consumer');
      return null;
    }

    console.log('[sourceMapResolver] Mapping position:', {
      line: location.lineNumber,
      column: location.columnNumber - 1
    });

    // Map the position
    // Note: error-stack-parser returns 1-based columns, but source-map expects 0-based
    const originalPosition = consumer.originalPositionFor({
      line: location.lineNumber,
      column: location.columnNumber - 1  // Convert to 0-based
    });

    console.log('[sourceMapResolver] Original position:', originalPosition);

    // Check if we got a valid result
    if (!originalPosition.source) {
      console.warn(`[sourceMapResolver] No original source found for:`, location);
      return null;
    }

    return {
      source: originalPosition.source,
      line: originalPosition.line || 0,
      column: originalPosition.column || 0
    };
  } catch (error) {
    console.warn(`[sourceMapResolver] Error mapping to original source:`, error);
    return null;
  }
}

/**
 * Clears the source map cache (useful for testing or if source maps change)
 */
export function clearSourceMapCache(): void {
  // Clear the cache
  sourceMapCache.clear();
}