# WYSIWYG Editing for Frontman — Research & Architecture Proposal

## Executive Summary

Add direct visual editing of CSS properties (padding, margin, width, height) and text content in the browser preview. Edits manipulate the DOM in-place for instant feedback — like traditional WYSIWYG tools — then the LLM "commits" changes to actual source code, translating DOM mutations into the correct format for the project (Tailwind, CSS modules, inline styles, etc.).

This approach:
- **Gives instant visual feedback** — no waiting for LLM inference on each drag
- **Leverages the LLM's strengths** — it reads the source file and figures out the right code format
- **Avoids building a style-system-aware codegen layer** — the LLM handles Tailwind vs CSS modules vs inline styles
- **Integrates with the existing agentic workflow** — visual edits become context for the conversation

---

## 1. Current Architecture (Relevant Pieces)

### 1.1 Overlay System (`Client__WebPreview__Stage.res`)

The Stage component renders an overlay `<div>` on top of the iframe preview. It:
- Tracks mouse hover and click events via hooks (`Client__Hooks.MouseClick`, `Client__Hooks.MouseMove`)
- Renders `Client__WebPreview__HoveredElement` (blue outline on hover during selection mode)
- Renders `Client__WebPreview__ClickedElement` (purple `#985DF7` border on selected element)
- Handles both normal and device-mode viewport scaling
- Uses `getBoundingClientRect()` to position overlays relative to iframe content
- Monitors scroll and DOM mutations to keep overlays in sync

The overlay container is `pointer-events-none` with `absolute inset-0`, sitting on top of the iframe.

### 1.2 Element Selection Flow

1. User enters selection mode → `webPreviewIsSelecting = true`
2. Hover shows blue outline, cursor becomes crosshair
3. Click captures `element` + `clickId` from iframe DOM
4. `Client__State.Actions.setSelectedElement()` dispatches to reducer
5. `SelectedElement.t` contains: `element`, `selector`, `screenshot`, `sourceLocation`
6. Source detection runs async: React fiber first → Astro annotation fallback (`Bindings__SourceDetection.res`)
7. `SourceLocation.t` captures: `file`, `line`, `column`, `componentName`, `tagName`, `parent` chain, `componentProps`

### 1.3 How the LLM Receives Context

When a user sends a message with a selected element, the server (`interaction.ex`) enriches it:

```
[Selected Component Location]
File: /path/to/Component.tsx
Line: 42
Column: 5
Component: Button
Source Context:
  <Button className="bg-blue-500 px-4 py-2" onClick={handleClick}>Click me</Button>
Component Props: {"size": "lg", "variant": "primary"}
Parent Component Hierarchy:
  1. /path/to/App.tsx:15:3 (App)
```

The LLM reads the file, understands the styling approach, and modifies code accordingly.

### 1.4 State Management

All state changes flow through `Client__State__StateReducer.res`:
- Actions are dispatched synchronously
- Side effects (API calls, etc.) are declared as `effect` variants returned alongside state
- `handleEffect` executes effects asynchronously and dispatches result actions
- Components read state via `Client__State.useSelector()`

### 1.5 MCP Tool System

The LLM executes code changes via MCP tools:
- `write_file` — writes content to a file in the user's project
- `read_file` — reads file content
- Tool calls are routed through the task channel WebSocket
- Results stream back in real-time

---

## 2. Proposed Architecture

### 2.1 Core Concept: DOM-First, LLM-Commit

```
┌──────────────────────────────────────────────────────────────┐
│                    User Interaction                           │
│                                                              │
│  1. Select element (existing flow)                           │
│  2. Visual handles appear (NEW)                              │
│  3. Drag/resize handles → DOM updated instantly              │
│  4. User clicks "Apply" or sends chat message                │
│  5. Pending changes sent to LLM as structured context        │
│  6. LLM reads source file, writes correct code               │
│  7. HMR reloads preview with real source changes             │
└──────────────────────────────────────────────────────────────┘
```

**Phase 1: Instant DOM manipulation**
- User drags a padding handle → `element.style.paddingLeft = "24px"` applied directly to the iframe DOM
- Visual feedback is immediate (< 16ms, same frame)
- Changes are tracked as a list of `PendingEdit` records

**Phase 2: LLM commit**
- Pending edits are formatted as structured context and sent to the LLM
- LLM reads the source file, sees the current styling approach, writes the change
- HMR updates the preview with the real source-code-driven render
- Pending edits are cleared

### 2.2 Data Model

```rescript
// New types for WYSIWYG editing

module WysiwygEdit = {
  type cssProperty =
    | PaddingTop(float)
    | PaddingRight(float)
    | PaddingBottom(float)
    | PaddingLeft(float)
    | MarginTop(float)
    | MarginRight(float)
    | MarginBottom(float)
    | MarginLeft(float)
    | Width(float)
    | Height(float)

  type textEdit = {
    oldText: string,
    newText: string,
  }

  type editKind =
    | CSSEdit(array<cssProperty>)
    | TextEdit(textEdit)

  type t = {
    id: string,
    // Where in the source this element lives
    sourceLocation: Client__Types.SourceLocation.t,
    // CSS selector for re-finding the element after HMR
    selector: string,
    // What the user changed
    edit: editKind,
    // Original values (for undo)
    originalValues: Dict.t<string>,
    // Timestamp
    timestamp: float,
  }
}

module WysiwygState = {
  type mode =
    | Inactive
    | Editing  // Visual handles visible, user can drag

  type t = {
    mode: mode,
    pendingEdits: array<WysiwygEdit.t>,
    activeProperty: option<string>, // Which handle is being dragged
  }
}
```

### 2.3 UI Components

#### 2.3.1 Visual Handles Overlay

A new component rendered in `Client__WebPreview__Stage` alongside existing overlays:

```
┌─────────────────────────────────────────────┐
│  margin-top handle (drag zone)              │
│  ┌───────────────────────────────────────┐  │
│  │ padding-top handle                    │  │
│  │ ┌─────────────────────────────────┐   │  │
│  │ │                                 │   │  │
│m │p│         Element Content         │p  │m │
│  │ │                                 │   │  │
│  │ └─────────────────────────────────┘   │  │
│  │ padding-bottom handle                 │  │
│  └───────────────────────────────────────┘  │
│  margin-bottom handle                       │
└─────────────────────────────────────────────┘
     + width handle (right edge)
     + height handle (bottom edge)
```

**Implementation approach:**
- Render in the overlay layer (same `absolute inset-0 pointer-events-none` container)
- Handle zones get `pointer-events-auto` so they're draggable
- Use `getComputedStyle()` on the iframe element to read current padding/margin values
- On drag, calculate delta and update `element.style.*` properties directly
- Color coding: green for padding, orange for margin (following browser DevTools convention)

#### 2.3.2 Text Editing

When a text element is selected and user double-clicks:
- Set `contentEditable = "true"` on the element inside the iframe
- Track text changes via `input` event listener
- On blur/escape, capture the old→new text diff as a `TextEdit`
- Reset `contentEditable = "false"`

#### 2.3.3 Property Inspector Panel (Optional, Phase 2)

A small panel near the selected element showing current values:
```
┌──────────────────────┐
│ padding  8  12  8  12│
│ margin   0   0  16  0│
│ width    auto        │
│ height   48px        │
└──────────────────────┘
```

### 2.4 Integration with Agent Workflow

#### Option A: Chat-Integrated (Recommended)

Visual edits appear in the chat as structured messages. When the user clicks "Apply" or sends a follow-up message, the pending edits are included as context:

```
[Visual Edits - Pending]
Element: Button at /src/components/Button.tsx:42:5
CSS Selector: button.bg-blue-500.px-4
Changes:
  - padding-left: 8px → 24px
  - padding-right: 8px → 24px
  - margin-top: 0px → 16px

IMPORTANT: Apply these visual changes to the source code.
Read the file and modify the styling to match these new values.
Use whatever styling approach the file already uses (Tailwind classes, CSS modules, inline styles, etc.).
```

The LLM then:
1. Reads the source file via `read_file`
2. Sees `className="bg-blue-500 px-4 py-2"` → Tailwind project
3. Changes `px-4` to `px-6` and adds `mt-4`
4. Writes back via `write_file`
5. HMR updates the preview

#### Option B: Auto-Commit with Debounce

After 2 seconds of no interaction, pending edits are automatically sent to the LLM. More seamless but higher LLM usage and potentially noisy.

### 2.5 State Reducer Integration

New actions in `Client__State__StateReducer.res`:

```rescript
type action =
  | ...existing actions...
  // WYSIWYG actions
  | EnterWysiwygMode
  | ExitWysiwygMode
  | AddWysiwygEdit(WysiwygEdit.t)
  | UndoWysiwygEdit(string) // edit id
  | ClearWysiwygEdits
  | CommitWysiwygEdits // triggers LLM to write to source
```

### 2.6 Cross-Origin Considerations

The iframe preview must be same-origin for WYSIWYG to work (need direct DOM access for `element.style`, `getComputedStyle`, `contentEditable`). The current architecture already assumes same-origin access — the overlay hooks call `getBoundingClientRect()` and read event targets from the iframe document.

If the preview is cross-origin in some configurations, WYSIWYG mode should be disabled with a clear message.

---

## 3. Implementation Plan

### Phase 1: Box Model Handles (padding + margin)

**Files to create/modify:**

| File | Action | Purpose |
|------|--------|---------|
| `Client__Wysiwyg__Types.res` | Create | Type definitions for edits, state |
| `Client__Wysiwyg__Handles.res` | Create | Drag handle component for padding/margin |
| `Client__Wysiwyg__DOMBridge.res` | Create | Read computed styles, apply inline overrides |
| `Client__Wysiwyg__EditTracker.res` | Create | Track pending edits with undo support |
| `Client__WebPreview__Stage.res` | Modify | Render WYSIWYG handles alongside existing overlays |
| `Client__State__StateReducer.res` | Modify | Add WYSIWYG actions |
| `Client__State__Types.res` | Modify | Add WysiwygState to global state |
| `Client__State.res` | Modify | Add selectors and action creators |

**Steps:**
1. Define types (`WysiwygEdit`, `WysiwygState`)
2. Build DOM bridge: read `getComputedStyle()` values, apply `element.style.*` overrides
3. Build drag handle component that renders padding/margin zones around selected element
4. Wire drag events: mousedown → track delta → update DOM → record edit
5. Add reducer actions for WYSIWYG state
6. Render handles in Stage when WYSIWYG mode is active
7. Build "commit" flow: format pending edits as LLM context, dispatch via existing message flow

### Phase 2: Width/Height Resize Handles

- Add resize handles on right edge (width) and bottom edge (height)
- Same drag mechanics as padding/margin
- Track original dimensions for undo

### Phase 3: Text Editing

- Double-click to enter contentEditable mode
- Capture text diffs
- Include in pending edits for LLM commit

### Phase 4: Property Inspector Panel

- Show current computed values in a small overlay panel
- Allow direct numeric input (click value, type new number)
- Same commit flow as drag handles

---

## 4. Key Design Decisions

### 4.1 Why DOM-first, not LLM-first?

| Approach | Latency | Complexity | LLM Usage |
|----------|---------|------------|-----------|
| **DOM-first** (proposed) | ~0ms visual, ~3-5s commit | Medium | 1 call per commit batch |
| LLM-per-edit | ~3-5s per drag | Low | 1 call per property change |
| Deterministic codegen | ~0ms visual + write | High (must understand all style systems) | 0 |

DOM-first gives the best UX (instant feedback) while keeping the codegen simple (LLM handles it).

### 4.2 Why not deterministic codegen?

Building a reliable codegen layer that handles Tailwind, CSS modules, styled-components, CSS-in-JS, plain CSS, and arbitrary combinations is a massive undertaking. The LLM already does this well — it reads the file, sees the pattern, and writes matching code. The tradeoff is a few seconds of latency at commit time, which is acceptable since the user has already seen the visual result.

### 4.3 Why batch edits?

Sending each drag event to the LLM would be expensive and slow. Batching lets the user make multiple adjustments (padding left, padding right, margin top) and commit them all at once. The LLM sees the full picture and can make a single coherent code change.

### 4.4 Handling HMR Reconciliation

After the LLM writes to source and HMR reloads:
- The inline style overrides from DOM manipulation are wiped out (HMR replaces the DOM)
- The new DOM reflects the source code changes
- If the LLM's code change doesn't match the visual edit exactly (e.g., Tailwind's `px-6` = 24px but user dragged to 23px), the post-HMR state shows the actual code result
- Pending edits are cleared after successful commit

### 4.5 Undo Strategy

Two levels:
1. **Pre-commit undo**: Revert inline style overrides (restore `originalValues` from `WysiwygEdit`)
2. **Post-commit undo**: The LLM's `write_file` change can be undone via git (existing mechanism)

---

## 5. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Cross-origin iframe | WYSIWYG won't work | Detect and disable with message; same-origin is already assumed |
| Shadow DOM elements | Can't style via `element.style` | Detect shadow roots, skip or warn |
| CSS specificity wars | Inline style override might not win | Use `element.style.setProperty(prop, value, "important")` |
| LLM generates wrong code format | Tailwind class instead of CSS module | Source snippet in context helps; retry with correction |
| Stale element references after HMR | Handles point to dead DOM nodes | Re-query via CSS selector after mutation/load events |
| Complex layout interactions | Changing padding breaks grid/flex layout | Show computed values; let user see result before committing |
| ContentEditable quirks | Text editing in iframe is notoriously buggy | Keep it simple: plain text only, no rich text |

---

## 6. Open Questions

1. **Commit trigger UX**: Manual "Apply" button vs auto-commit with debounce vs commit-on-chat-message? Recommend manual button for v1.
2. **Unit system**: Should handles show px values or the project's unit system (rem, Tailwind spacing scale)? Suggest px for DOM manipulation, LLM translates to project units.
3. **Multi-element editing**: Should the user be able to select multiple elements and edit them together? Suggest single-element for v1.
4. **Responsive preview**: Should edits be scoped to the current viewport size? The LLM might need guidance on whether to use responsive classes.
5. **Keyboard shortcuts**: Should there be shortcuts for nudging values (arrow keys ±1px, shift+arrow ±10px)?
