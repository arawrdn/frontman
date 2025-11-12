// Type definitions for serialized Figma nodes
type rec serializedNode = {
  id: string,
  @as("type") type_: string,
  name: string,
  css: option<Js.Json.t>,
  width: option<float>,
  height: option<float>,
  x: option<float>,
  y: option<float>,
  visible: option<bool>,
  locked: option<bool>,
  children: option<array<serializedNode>>,
}

// Figma node type (minimal definition)
type figmaNode

// Check if value is empty object
let isEmptyObject: Js.Json.t => bool = %raw(`
  function(obj) {
    return obj !== null && 
           typeof obj === 'object' && 
           !Array.isArray(obj) && 
           Object.keys(obj).length === 0;
  }
`)

// Check if value is empty array
let isEmptyArray: Js.Json.t => bool = %raw(`
  function(arr) {
    return Array.isArray(arr) && arr.length === 0;
  }
`)

// Check if value is empty (null, undefined, empty string, 0, empty object, empty array)
let isEmpty: Js.Json.t => bool = %raw(`
  function(value) {
    return value === null ||
           value === undefined ||
           value === '' ||
           value === 0 ||
           (value !== null && 
            typeof value === 'object' && 
            !Array.isArray(value) && 
            Object.keys(value).length === 0) ||
           (Array.isArray(value) && value.length === 0);
  }
`)

// Serialize a single Figma node
let serializeFigmaNode: figmaNode => promise<serializedNode> = %raw(`
  async function(node) {
    const serialized = {
      id: node.id,
      type: node.type,
      name: node.name
    };
    
    // Get CSS properties using the built-in getCSSAsync function
    try {
      const css = await node.getCSSAsync();
      const isEmpty = (value) => {
        return value === null ||
               value === undefined ||
               value === '' ||
               value === 0 ||
               (value !== null && 
                typeof value === 'object' && 
                !Array.isArray(value) && 
                Object.keys(value).length === 0) ||
               (Array.isArray(value) && value.length === 0);
      };
      
      if (!isEmpty(css)) {
        serialized.css = css;
      }
    } catch (e) {
      // Some nodes might not support getCSSAsync
    }
    
    // Get additional useful properties
    try {
      if (node.width !== undefined) serialized.width = node.width;
      if (node.height !== undefined) serialized.height = node.height;
      if (node.x !== undefined) serialized.x = node.x;
      if (node.y !== undefined) serialized.y = node.y;
      if (node.visible !== undefined && !node.visible) serialized.visible = node.visible;
      if (node.locked !== undefined && node.locked) serialized.locked = node.locked;
    } catch (e) {
      // Skip if properties not accessible
    }
    
    return serialized;
  }
`)

// Traverse and serialize a Figma node tree recursively
let traverseAndSerialize: figmaNode => promise<serializedNode> = %raw(`
  async function traverseAndSerialize(node) {
    const isEmptyObject = (obj) => {
      return obj !== null && 
             typeof obj === 'object' && 
             !Array.isArray(obj) && 
             Object.keys(obj).length === 0;
    };
    
    const isEmpty = (value) => {
      return value === null ||
             value === undefined ||
             value === '' ||
             value === 0 ||
             isEmptyObject(value) ||
             (Array.isArray(value) && value.length === 0);
    };
    
    const serializeFigmaNode = async (node) => {
      const serialized = {
        id: node.id,
        type: node.type,
        name: node.name
      };
      
      // Get CSS properties using the built-in getCSSAsync function
      try {
        const css = await node.getCSSAsync();
        if (!isEmpty(css)) {
          serialized.css = css;
        }
      } catch (e) {
        // Some nodes might not support getCSSAsync
      }
      
      // Get additional useful properties
      try {
        if (node.width !== undefined) serialized.width = node.width;
        if (node.height !== undefined) serialized.height = node.height;
        if (node.x !== undefined) serialized.x = node.x;
        if (node.y !== undefined) serialized.y = node.y;
        if (node.visible !== undefined && !node.visible) serialized.visible = node.visible;
        if (node.locked !== undefined && node.locked) serialized.locked = node.locked;
      } catch (e) {
        // Skip if properties not accessible
      }
      
      return serialized;
    };
    
    // Serialize the current node
    const serialized = await serializeFigmaNode(node);
    
    // Handle children recursively
    if ("children" in node) {
      if (node.type !== "INSTANCE") {
        const children = [];
        for (const child of node.children) {
          const serializedChild = await traverseAndSerialize(child);
          // Only add if not empty
          if (!isEmptyObject(serializedChild)) {
            children.push(serializedChild);
          }
        }
        // Only add children array if it has items
        if (children.length > 0) {
          serialized.children = children;
        }
      }
    }
    
    return serialized;
  }
`)

// Helper to serialize multiple nodes
let serializeNodes: array<figmaNode> => promise<array<serializedNode>> = %raw(`
  async function(nodes) {
    return Promise.all(nodes.map(node => traverseAndSerialize(node)));
  }
`)

// Figma API bindings
type figmaApi
type pageNode

@val external figma: figmaApi = "figma"

// Get current page
@get external currentPage: figmaApi => pageNode = "currentPage"

// Get selection from page
@get external selection: pageNode => array<figmaNode> = "selection"

// Custom selection change listener using click events
let onSelectionChange: (figmaApi, unit => unit) => unit = %raw(`
  function(figma, callback) {
    let previousFirstNodeId = null;
    
    const checkSelection = () => {
      try {
        const selection = window.figma?.currentPage?.selection;
        
        // Check if selection exists and is not empty
        if (selection && selection.length > 0) {
          const firstNode = selection[0];
          const currentFirstNodeId = firstNode?.id;
          
          // Fire callback only if the first element has changed
          if (currentFirstNodeId && currentFirstNodeId !== previousFirstNodeId) {
            previousFirstNodeId = currentFirstNodeId;
            callback();
          }
        }
      } catch (e) {
        // Silently ignore errors
      }
    };
    
    // Listen to click events on document with capture phase
    document.addEventListener('click', checkSelection, true);
    
    // Return cleanup function (optional)
    return () => {
      document.removeEventListener('click', checkSelection, true);
    };
  }
`)

