export type SourceLocationState =
  | { status: 'loading' }
  | { status: 'resolved'; file: string; line: number }
  | { status: 'error'; message: string }
  | { status: 'unavailable' };

export interface SelectElement {
  selector: string;
  screenshot: string; // base64 encoded screenshot
  reactComponent?: {
    name: string;
    sourceLocation?: SourceLocationState;  // Changed from string to state object
  };
}
