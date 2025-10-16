# Split Layout Chat Widget

A React-based split layout widget that can be injected into any webpage to create a full-screen chat interface with the original page content displayed in an iframe.

## Features

- 🛡️ **Shadow DOM isolation** - No CSS conflicts with host page
- ⚛️ **React + Radix UI** - Modern component library with icons
- 🖥️ **Split screen layout** - Chat panel on left, original content on right
- 📱 **Responsive design** - Adapts to different screen sizes
- 🔌 **Easy integration** - Just include the script
- 🖼️ **Iframe preservation** - Original page functionality maintained

## Development

### Install dependencies
```bash
make install
```

### Run the project

Run these commands in separate terminals:

```bash
make dev-build-watch    # Watch and build in development mode
make preview            # Preview the build
```

### Build the library
```bash
make build
```

This creates `dist/floating-widget.umd.js` and `dist/floating-widget.es.js` files.

### Other commands

See all available commands:
```bash
make help
```

## Usage

### Method 1: Development Source (with Vite dev server)
```html
<script src="http://localhost:5173/src/main.tsx" type="module"></script>
```

### Method 2: Development Bundle (served by Vite dev server)
```html
<!-- UMD bundle served by dev server -->
<script src="http://localhost:5173/bundle.js"></script>

<!-- Or ES module bundle served by dev server -->
<script type="module" src="http://localhost:5173/bundle.es.js"></script>
```

### Method 3: Production (built files)
```html
<!-- UMD version -->
<script src="./dist/floating-widget.umd.js"></script>

<!-- Or ES module version -->
<script type="module" src="./dist/floating-widget.es.js"></script>
```

### Method 4: Manual injection
```javascript
import { injectSplitLayoutWidget } from './dist/floating-widget.es.js';

// Inject the widget
const widget = injectSplitLayoutWidget();

// Later, remove the widget if needed
widget.unmount();
```

## Bundle Endpoints

The Vite development server provides these bundle endpoints:

- **`/bundle.js`** - UMD bundle (works with `<script>` tags)
- **`/bundle.es.js`** - ES module bundle (works with `type="module"`)

These endpoints serve the built bundle files during development, allowing you to test the actual production bundle while developing.

### Setup for Bundle Testing

1. **Build the bundle first:**
   ```bash
   npm run build
   ```

2. **Start the development server:**
   ```bash
   npm run dev
   ```

3. **Access the bundle:**
   - UMD: `http://localhost:5173/bundle.js`
   - ES Module: `http://localhost:5173/bundle.es.js`

## Testing

- **`test.html`** - Uses development source files
- **`demo-bundle.html`** - Uses the bundle endpoint for testing production builds

Open either file in your browser while the development server is running to see the widget in action.

## How it works

1. **Full page takeover**: The widget overlays the entire viewport
2. **Shadow DOM**: Creates an isolated DOM tree to prevent CSS conflicts
3. **Split layout**: Left panel for chat, right panel for iframe
4. **Origin detection**: Automatically loads the current page's origin in the iframe
5. **Auto-injection**: Automatically injects when the script loads

## Widget Features

### Left Chat Panel
- Dark theme design matching Claude interface
- Message input with send functionality
- Enter key support for sending messages
- Trial mode indicator and settings
- Responsive width (300-500px)

### Right Content Panel
- Iframe displaying original page content
- Top bar showing current URL
- Reload button functionality
- Seamless integration with original page

### Layout Details
- **Chat panel**: Fixed 400px width (resizable between 300-500px)
- **Content area**: Takes remaining space
- **Full screen**: 100vh height, 100vw width
- **Z-index**: 999999 to stay on top
