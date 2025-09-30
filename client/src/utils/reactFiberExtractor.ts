import ErrorStackParser from "error-stack-parser";

/**
 * Extracts React component information from a DOM element using React Fiber internals.
 * Works with React 19's _debugStack property.
 */

export interface CompiledLocation {
	fileName: string;
	lineNumber: number;
	columnNumber: number;
}

export interface ReactComponentInfo {
	name: string; // Component hierarchy as string (e.g., "App → Router → Login")
	compiledLocation?: CompiledLocation; // Location in compiled bundle
}

/**
 * Finds the React Fiber internal property key on a DOM element.
 * React uses different key names across versions.
 */
function findReactFiberKey(element: Element): string | null {
	const keys = Object.keys(element);
	return (
		keys.find(
			(key) =>
				key.startsWith("__reactFiber$") ||
				key.startsWith("__reactInternalInstance$") ||
				key.startsWith("_reactInternalFiber") ||
				key.startsWith("_reactInternals"),
		) || null
	);
}

/**
 * Extracts the component hierarchy from a React Fiber.
 * Walks up the fiber tree collecting all function component names.
 */
function extractComponentPath(fiber: any): string[] {
	const componentPath: string[] = [];

	while (fiber) {
		if (fiber.type && typeof fiber.type === "function") {
			const componentName =
				fiber.type.displayName || fiber.type.name || "Anonymous";
			componentPath.push(componentName);
		}
		fiber = fiber.return;
	}

	// Reverse so it goes from root to leaf (App → Router → Login)
	return componentPath.reverse();
}

/**
 * Parses _debugStack to find the compiled source location.
 * Filters out node_modules and React internals.
 */
function parseDebugStack(debugStack: any): CompiledLocation | undefined {
	const frames = ErrorStackParser.parse(debugStack);

	// Find frames between react-stack-top-frame and react_stack_bottom_frame
	const topFrameIndex = frames.findIndex(
		(f) =>
			f.functionName?.includes("react-stack-top-frame") ||
			f.functionName?.includes("jsxDEV"),
	);
	const bottomFrameIndex = frames.findIndex((f) =>
		f.functionName?.includes("react_stack_bottom_frame"),
	);

	let relevantFrames = frames;
	if (
		topFrameIndex !== -1 &&
		bottomFrameIndex !== -1 &&
		bottomFrameIndex > topFrameIndex
	) {
		relevantFrames = frames.slice(topFrameIndex + 1, bottomFrameIndex);
	}

	// // Filter out node_modules, React internals, and framework chunks
	// const userFrames = relevantFrames.filter((frame) => {
	// 	const fileName = frame.fileName || "";
	// 	const funcName = frame.functionName || "";

	// 	// Exclude node_modules (various formats)
	// 	if (
	// 		fileName.includes("/node_modules/") ||
	// 		fileName.includes("node_modules_") ||
	// 		fileName.includes("/node_modules_")
	// 	) {
	// 		return false;
	// 	}

	// 	// Exclude React internals
	// 	if (
	// 		fileName.includes("/react-dom/") ||
	// 		fileName.includes("/react/") ||
	// 		funcName.includes("renderWith") ||
	// 		funcName.includes("beginWork") ||
	// 		funcName.includes("performWork") ||
	// 		funcName.includes("runWithFiber")
	// 	) {
	// 		return false;
	// 	}

	// 	return true;
	// });

	// if (userFrames.length === 0) {
	// 	return undefined;
	// }

	// Get the first user frame (top of user code stack)
	const topFrame = relevantFrames[0];

	return {
		fileName: topFrame.fileName || "",
		lineNumber: topFrame.lineNumber || 0,
		columnNumber: topFrame.columnNumber || 0,
	};
}

/**
 * Extracts React component information from a DOM element.
 * Returns component hierarchy and compiled source location.
 *
 * Note: This only works in development mode where React includes debug info.
 * In production, it will only return the component hierarchy without source location.
 */
export function getReactComponentInfo(
	element: Element,
): ReactComponentInfo | undefined {
	try {
		// Check if we're in development mode
		const isDevelopment = import.meta.env.DEV;
		
		// Find React fiber key
		const reactKey = findReactFiberKey(element);
		if (!reactKey) {
			return undefined;
		}

		// @ts-expect-error - Accessing React internal fiber
		let fiber = element[reactKey];

		// Extract component path
		const componentPath = extractComponentPath(fiber);
		if (componentPath.length === 0) {
			return undefined;
		}

		// Find the leaf component's fiber (the immediate parent of the element)
		// @ts-expect-error - Accessing React internal fiber
		fiber = element[reactKey];
		while (fiber && (!fiber.type || typeof fiber.type !== "function")) {
			fiber = fiber.return;
		}

		if (!fiber) {
			return {
				name: componentPath.join(" → "),
			};
		}

		// Skip _debugStack parsing in production
		if (!isDevelopment) {
			return {
				name: componentPath.join(" → "),
			};
		}

		// Try to get _debugStack
		if (!fiber._debugStack) {
			return {
				name: componentPath.join(" → "),
			};
		}

		// Parse the debug stack
		const compiledLocation = parseDebugStack(fiber._debugStack);

		return {
			name: componentPath.join(" → "),
			compiledLocation,
		};
	} catch (error) {
		console.warn("Could not extract React component info:", error);
		return undefined;
	}
}

/**
 * Generates a standalone JavaScript string that can be injected into iframes.
 * This is a self-contained version of getReactComponentInfo that doesn't rely on imports.
 */
export function generateIframeReactExtractorScript(): string {
	return `
function getReactComponentInfo(element) {
  try {
    // Find React fiber key
    const keys = Object.keys(element);
    const reactKey = keys.find(
      (key) =>
        key.startsWith("__reactFiber$") ||
        key.startsWith("__reactInternalInstance$") ||
        key.startsWith("_reactInternalFiber") ||
        key.startsWith("_reactInternals")
    );

    if (!reactKey) return null;

    let fiber = element[reactKey];
    const componentPath = [];

    // Walk up the fiber tree and collect all components
    while (fiber) {
      if (fiber.type && typeof fiber.type === "function") {
        const componentName = fiber.type.displayName || fiber.type.name || "Anonymous";
        componentPath.push(componentName);
      }
      fiber = fiber.return;
    }

    const reversedPath = componentPath.reverse();
    if (reversedPath.length === 0) return null;

    // For iframe injection, we don't do full source map resolution
    // Just return the component name - the parent will handle source location
    return {
      name: reversedPath.join(" → ")
    };
  } catch (error) {
    console.warn("Could not extract component path:", error);
    return null;
  }
}
`;
}
