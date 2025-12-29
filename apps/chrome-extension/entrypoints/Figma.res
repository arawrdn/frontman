open AskTheLlmBindings

// Bulletproof monkey patching for Figma API access
// This patches Error.prototype.stack AND intercepts Object.defineProperty
// to handle both cases: running before OR after Figma's code
let patchForFigmaAccess: unit => unit = %raw(`
  function() {
    // Storage for intercepted property values
    const propertyValues = new Map();
    const originalDefineProperty = Object.defineProperty;
    
    // Regex to match extension URLs in stack traces
    const chromeExtRegex = new RegExp('chrome-extension://[^/]+/', 'g');
    const mozExtRegex = new RegExp('moz-extension://[^/]+/', 'g');
    
    function cleanStack(stack) {
      if (typeof stack === 'string') {
        return stack.replace(chromeExtRegex, '').replace(mozExtRegex, '');
      }
      return stack;
    }
    
    // Step 1: Patch Error.prototype.stack to hide extension URLs
    const originalStackDescriptor = Object.getOwnPropertyDescriptor(Error.prototype, 'stack');
    const originalStackGetter = originalStackDescriptor?.get;
    
    if (originalStackGetter) {
      originalDefineProperty.call(Object, Error.prototype, 'stack', {
        get: function() {
          const stack = originalStackGetter.call(this);
          return cleanStack(stack);
        },
        configurable: true
      });
    } else {
      const OriginalError = Error;
      Error = function(...args) {
        const err = new OriginalError(...args);
        const originalStack = err.stack;
        if (originalStack) {
          originalDefineProperty.call(Object, err, 'stack', {
            get: function() {
              return cleanStack(originalStack);
            },
            configurable: true
          });
        }
        return err;
      };
      Error.prototype = OriginalError.prototype;
    }
    
    // Step 2: Intercept Object.defineProperty to catch Figma's property definitions
    Object.defineProperty = function(obj, prop, descriptor) {
      // Only intercept window properties with getters (likely Figma's anti-extension code)
      if (obj === window && descriptor && (descriptor.get || descriptor.set)) {
        const propName = String(prop);
        
        // Check if this looks like a Figma-protected property
        // We intercept all getter/setter definitions on window to be safe
        const originalSet = descriptor.set;
        const originalGet = descriptor.get;
        
        // Create a clean property that bypasses any stack checks in the original getter
        return originalDefineProperty.call(Object, obj, prop, {
          get: function() {
            // Return our stored value if we have one
            if (propertyValues.has(propName)) {
              return propertyValues.get(propName);
            }
            // Try calling original getter - should work since Error.stack is patched
            if (originalGet) {
              try {
                const value = originalGet.call(this);
                if (value !== undefined) {
                  propertyValues.set(propName, value);
                }
                return value;
              } catch (e) {
                console.warn('[Frontman] Getter failed for', propName, e);
                return undefined;
              }
            }
            return undefined;
          },
          set: function(value) {
            propertyValues.set(propName, value);
            // Also call original setter to maintain Figma's internal state
            if (originalSet) {
              try {
                originalSet.call(this, value);
              } catch (e) {
                // Ignore errors from original setter
              }
            }
          },
          configurable: true,
          enumerable: descriptor.enumerable !== false
        });
      }
      
      // Pass through for all other cases
      return originalDefineProperty.call(Object, obj, prop, descriptor);
    };
    
    // Copy static properties from original
    Object.keys(originalDefineProperty).forEach(key => {
      Object.defineProperty[key] = originalDefineProperty[key];
    });
    
    // Step 3: If window.figma already exists (we ran after Figma), re-patch it
    const existingDescriptor = Object.getOwnPropertyDescriptor(window, 'figma');
    if (existingDescriptor && existingDescriptor.get) {
      console.log('[Frontman] Figma property already exists, re-patching...');
      
      // Try to get the current value
      try {
        const currentValue = window.figma;
        if (currentValue !== undefined) {
          propertyValues.set('figma', currentValue);
        }
      } catch (e) {
        console.warn('[Frontman] Could not read existing figma value:', e);
      }
      
      // Redefine with our clean getter
      const originalGet = existingDescriptor.get;
      const originalSet = existingDescriptor.set;
      
      originalDefineProperty.call(Object, window, 'figma', {
        get: function() {
          if (propertyValues.has('figma')) {
            return propertyValues.get('figma');
          }
          if (originalGet) {
            try {
              const value = originalGet.call(this);
              if (value !== undefined) {
                propertyValues.set('figma', value);
              }
              return value;
            } catch (e) {
              return undefined;
            }
          }
          return undefined;
        },
        set: function(value) {
          propertyValues.set('figma', value);
          if (originalSet) {
            try {
              originalSet.call(this, value);
            } catch (e) {}
          }
        },
        configurable: true,
        enumerable: true
      });
    }
    
    console.log('[Frontman] Figma access patches applied');
  }
`)

// Wait for window.figma to be available with an actual value
// This handles the case where the property is defined but value is not yet set
let waitForFigma: unit => promise<FigmaClientApiBindings.figmaApi> = %raw(`
  function() {
    return new Promise((resolve) => {
      let timeoutId = null;
      
      function checkFigma() {
        // Check if figma exists AND has actual content (not just defined but undefined)
        if (typeof window !== 'undefined' && 
            window.figma !== undefined && 
            window.figma !== null &&
            typeof window.figma === 'object') {
          return true;
        }
        return false;
      }
      
      if (checkFigma()) {
        console.log('[Frontman] Figma API already available');
        resolve(window.figma);
        return;
      }
      
      console.log('[Frontman] Waiting for Figma API...');
      
      const checkInterval = setInterval(() => {
        if (checkFigma()) {
          clearInterval(checkInterval);
          clearTimeout(timeoutId);
          console.log('[Frontman] Figma API now available');
          resolve(window.figma);
        }
      }, 50); // Check more frequently
      
      timeoutId = setTimeout(() => {
        clearInterval(checkInterval);
        console.warn('[Frontman] Figma API not found after 10 seconds');
        resolve(undefined);
      }, 10000);
    });
  }
`)

// Helper to post any message through a port (bypasses type checking)
let postMessageRaw: ('port, 'message) => unit = %raw(`
  function(port, message) {
    port.postMessage(message);
  }
`)

let main = () => {
  patchForFigmaAccess()

  let runAsync = async () => {
    let figma = await waitForFigma()

    Console.log("[Frontman] Figma API is ready!")

    // Connect to the extension background via port for bidirectional communication
    let port = Chrome.Runtime.Connect.connectExternal(
      "kfdpjbmabcelpgoipaccjijhehdmeghp",
      Some({name: "FigmaContentScript"}),
    )
    Console.log("[Frontman] Connected to extension via port")

    // Listen for messages from the background (tool calls)
    Chrome.Port.addMessageListener(port, message => {
      let messageType = %raw(`message.type`)

      switch messageType {
      | "GetFigmaNodeRequest" =>
        Console.log2("[Frontman] Received GetFigmaNodeRequest:", message)
        let requestId: string = %raw(`message.requestId`)
        let nodeId: string = %raw(`message.nodeId`)
        let settings = %raw(`message.settings`)

        // Process the request asynchronously
        let handleRequest = async () => {
          try {
            let conversionSettings: FigmaClientApiBindings.conversionSettings = {
              embedVectors: settings["embedVectors"],
              embedImages: settings["embedImages"],
              maxIconSize: settings["maxIconSize"],
              withChildren: settings["withChildren"],
            }

            let includeImage = settings["includeImage"] == true

            let nodeResult = await FigmaClientApiBindings.getFigmaNodeJSON(nodeId, conversionSettings)

            switch nodeResult->Js.Nullable.toOption {
            | Some(node) =>
              // Export image if requested
              let imageDataUrl = if includeImage {
                try {
                  let figmaNodeOpt = await FigmaClientApiBindings.getNodeByIdAsync(figma, nodeId)
                  switch figmaNodeOpt {
                  | Some(figmaNode) =>
                    try {
                      let bytes = await FigmaClientApiBindings.exportAsync(figmaNode, {format: "PNG"})
                      let base64 = FigmaClientApiBindings.base64Encode(bytes)
                      Some(`data:image/png;base64,${base64}`)
                    } catch {
                    | exn =>
                      let errorMsg =
                        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
                      Console.warn2("[Frontman] Failed to export node image:", errorMsg)
                      None
                    }
                  | None => None
                  }
                } catch {
                | exn =>
                  let errorMsg =
                    exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
                  Console.warn2("[Frontman] Failed to get node for image export:", errorMsg)
                  None
                }
              } else {
                None
              }

              postMessageRaw(port, {
                "type": "GetFigmaNodeResponse",
                "requestId": requestId,
                "node": Js.Nullable.return(node->Obj.magic),
                "error": Js.Nullable.null,
                "image": imageDataUrl->Option.map(dataUrl => dataUrl->Obj.magic)->Option.getOr(Js.Nullable.null)->Obj.magic,
              })
            | None =>
              postMessageRaw(port, {
                "type": "GetFigmaNodeResponse",
                "requestId": requestId,
                "node": Js.Nullable.null,
                "error": Js.Nullable.return(`Node with ID "${nodeId}" not found in the current document`),
                "image": Js.Nullable.null,
              })
            }
          } catch {
          | exn =>
            let errorMsg =
              exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
            Console.error2("[Frontman] Error fetching node:", errorMsg)
            postMessageRaw(port, {
              "type": "GetFigmaNodeResponse",
              "requestId": requestId,
              "node": Js.Nullable.null,
              "error": Js.Nullable.return(errorMsg),
              "image": Js.Nullable.null,
            })
          }
        }
        handleRequest()->ignore
      | _ => ()
      }
    })

    // Serialize first selected node when selection changes
    FigmaClientApiBindings.onSelectionChange(figma, () => {
      let runSerialize = async () => {
        let selection =
          figma->FigmaClientApiBindings.currentPage->FigmaClientApiBindings.selection
        switch selection[0] {
        | Some(firstNode) =>
          // Get node ID
          let nodeId = firstNode->FigmaClientApiBindings.id
          
          // Get node DSL representation
          let nodeDSL = await FigmaClientApiBindings.figmaToDSL(
            firstNode,
            FigmaClientApiBindings.defaultSettings,
            FigmaClientApiBindings.defaultDslOptions,
          )
          
          // Export node as PNG image
          let imageDataUrl = try {
            let bytes = await FigmaClientApiBindings.exportAsync(firstNode, {format: "PNG"})
            let base64 = FigmaClientApiBindings.base64Encode(bytes)
            Some(`data:image/png;base64,${base64}`)
          } catch {
          | exn =>
            let errorMsg =
              exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
            Console.warn2("[Frontman] Failed to export node image:", errorMsg)
            None
          }

          // Send to extension with both node data (DSL) and image
          let nodeData = switch nodeDSL->Js.Nullable.toOption {
          | Some(dsl) => dsl->Obj.magic
          | None => %raw(`null`)->Obj.magic
          }
          
          let figmaNodeData = {
            "nodeId": nodeId,
            "nodeData": nodeData, // DSL representation (isDsl: true)
            "image": imageDataUrl->Option.map(dataUrl => dataUrl->Obj.magic)->Option.getOr(Js.Nullable.null)->Obj.magic,
          }
          
          let data = {"selectedFigmaNode": Js.Nullable.return(figmaNodeData), "type": "FigmaNodeSelected"}
          Chrome.Runtime.sendMessageExternal("kfdpjbmabcelpgoipaccjijhehdmeghp", data, response => {
            Console.log2("[Frontman] Response from extension:", response)
          })
        | None => ()
        }
      }
      runSerialize()->ignore
    })
  }

  runAsync()->ignore
}

let config = {
  "matches": ["https://figma.com/design/*", "https://www.figma.com/design/*"],
}
