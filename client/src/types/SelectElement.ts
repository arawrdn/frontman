export interface SelectElement {
  selector: string;
  screenshot: string; // base64 encoded screenshot
  reactComponent?: {
    name: string;
    sourceLocation?: string;
  };
}
