import { finder } from "@medv/finder";
import { TargetIcon } from "@radix-ui/react-icons";
import { snapdom } from "@zumer/snapdom";
import type React from "react";
import { useCallback, useEffect, useRef, useState } from "react";
import { useSourceLocationResolver } from "../hooks/useSourceLocationResolver";
import type { SelectElement } from "../types/SelectElement";
import {
	injectSelectorScript,
	sendMessageToIframe,
} from "../utils/iframeElementSelector";
import { getReactComponentInfo } from "../utils/reactFiberExtractor";
import SelectionNotice from "./SelectionNotice";

interface SelectElementButtonProps {
	onElementSelected: (element: SelectElement) => void;
	disabled?: boolean;
	selectedElement?: SelectElement | null;
	onClearSelection?: () => void;
}

const SelectElementButton: React.FC<SelectElementButtonProps> = ({
	onElementSelected,
	disabled = false,
	selectedElement = null,
	onClearSelection,
}) => {
	const [isSelecting, setIsSelecting] = useState(false);
	const [hasIframe, setHasIframe] = useState(false);
	const [selectionSuccessful, setSelectionSuccessful] = useState(false);
	const cleanupFunctionRef = useRef<(() => void) | null>(null);
	const { resolveSourceLocation } = useSourceLocationResolver();

	const cleanup = useCallback(() => {
		setIsSelecting(false);
		document.body.style.cursor = "default";

		// Remove event listeners from iframe if present and send stop message
		const iframe = document.getElementById(
			"main-content-iframe",
		) as HTMLIFrameElement;
		if (iframe) {
			sendMessageToIframe(iframe, { type: "STOP_ELEMENT_SELECTION" });
		}

		// Remove highlight overlay if it exists
		const overlay = document.getElementById("select-element-overlay");
		if (overlay) {
			overlay.remove();
		}

		// Remove any stored event listeners
		if (cleanupFunctionRef.current) {
			cleanupFunctionRef.current();
			cleanupFunctionRef.current = null;
		}
	}, []);

	// Check for iframe and set up message listener
	useEffect(() => {
		const iframe = document.getElementById(
			"main-content-iframe",
		) as HTMLIFrameElement;
		setHasIframe(!!iframe);

		// Listen for messages from iframe
		const handleMessage = async (event: MessageEvent) => {
			if (event.data.type === "ELEMENT_SELECTED") {
				const data = event.data.data;

				try {
					// Get iframe element for screenshot
					const iframe = document.getElementById(
						"main-content-iframe",
					) as HTMLIFrameElement;
					if (iframe) {
						// Take screenshot of the iframe (we can't screenshot individual elements inside cross-origin iframes)
						const result = await snapdom(iframe);
						const screenshot = result.url;

						const selectElement: SelectElement = {
							selector: data.selector,
							screenshot,
							reactComponent: data.reactComponent,
						};

						onElementSelected(selectElement);
						setSelectionSuccessful(true);
						setTimeout(() => setSelectionSuccessful(false), 2000);
					}
				} catch (error) {
					console.error("Error processing iframe element selection:", error);
				}
			} else if (event.data.type === "SELECTION_CANCELLED") {
				cleanup();
			}
		};

		window.addEventListener("message", handleMessage);
		return () => window.removeEventListener("message", handleMessage);
	}, [onElementSelected, cleanup]);

	const handleElementSelection = useCallback(
		async (event: MouseEvent, targetDocument?: Document) => {
			event.preventDefault();
			event.stopPropagation();

			const element = event.target as Element;
			if (!element) return;

			// Ignore clicks on the widget itself (chat panel, buttons, etc.)
			// Check if the element or any parent has data-widget-ui attribute
			let checkElement: Element | null = element;
			while (checkElement) {
				if (checkElement.hasAttribute?.("data-widget-ui")) {
					console.log("Ignoring click on widget UI element");
					return;
				}
				checkElement = checkElement.parentElement;
			}

			try {
				// Determine the root for the selector
				const doc = targetDocument || document;
				const root = doc.body || doc.documentElement;

				// Generate selector using @medv/finder
				const selector = finder(element, {
					root: root,
					idName: () => true,
					className: () => true,
					tagName: () => true,
					attr: () => false,
					seedMinLength: 1,
					optimizedMinLength: 2,
					maxNumberOfPathChecks: 10000,
				});

				// Take screenshot using @zumer/snapdom
				const result = await snapdom(element);
				const screenshot = result.url;

				// Get React component info (returns compiled location)
				const reactComponentInfo = getReactComponentInfo(element);

				// Add iframe context if element is from iframe
				const isFromIframe = targetDocument && targetDocument !== document;
				const finalSelector = isFromIframe ? `iframe ${selector}` : selector;

				// Create initial select element with loading state
				const selectElement: SelectElement = {
					selector: finalSelector,
					screenshot,
					reactComponent: reactComponentInfo
						? {
								name: reactComponentInfo.name,
								sourceLocation: reactComponentInfo.compiledLocation
									? { status: "loading" }
									: { status: "unavailable" },
							}
						: undefined,
				};

				// Send initial selection immediately
				onElementSelected(selectElement);
				setSelectionSuccessful(true);
				setTimeout(() => setSelectionSuccessful(false), 2000);

				// Resolve source location asynchronously if we have a compiled location
				if (reactComponentInfo?.compiledLocation) {
					console.log("Starting async source location resolution...");

					// Clean up selection mode before starting async work
					cleanup();

					const resolvedState = await resolveSourceLocation(
						reactComponentInfo.compiledLocation,
					);

					// Update the element with resolved source location
					const updatedElement: SelectElement = {
						...selectElement,
						reactComponent: {
							name: reactComponentInfo.name,
							sourceLocation: resolvedState,
						},
					};

					console.log(
						"Calling onElementSelected with updated element:",
						updatedElement,
					);
					onElementSelected(updatedElement);
				} else {
					// No source location to resolve, just cleanup
					cleanup();
				}
			} catch (error) {
				console.error("Error selecting element:", error);
				cleanup();
			}
		},
		[onElementSelected, cleanup, resolveSourceLocation],
	);

	const handleButtonClick = () => {
		if (disabled) return;

		// If an element is already selected and we're not currently selecting,
		// clear the selection and start fresh
		if (selectedElement && !isSelecting) {
			if (onClearSelection) {
				onClearSelection();
			}
			return;
		}

		// If we're currently selecting, cancel the selection
		if (isSelecting) {
			cleanup();
			return;
		}

		// Start new selection
		startSelection();
	};

	const startSelection = () => {
		setIsSelecting(true);
		document.body.style.cursor = "crosshair";

		// Highlight overlay management
		let highlightOverlay: HTMLDivElement | null = null;

		const createHighlight = (doc: Document) => {
			const overlay = doc.createElement('div');
			overlay.style.cssText = `
				position: fixed;
				pointer-events: none;
				border: 2px solid #3b82f6;
				background: rgba(59, 130, 246, 0.1);
				z-index: 999999;
				box-shadow: 0 0 10px rgba(59, 130, 246, 0.5);
			`;
			doc.body.appendChild(overlay);
			return overlay;
		};

		const updateHighlight = (element: Element, doc: Document) => {
			if (!highlightOverlay) {
				highlightOverlay = createHighlight(document); // Always create in main document
			}
			const rect = element.getBoundingClientRect();

			// If element is in an iframe, offset by iframe position
			let offsetX = 0;
			let offsetY = 0;
			if (doc !== document) {
				const iframe = document.getElementById('main-content-iframe') as HTMLIFrameElement;
				if (iframe) {
					const iframeRect = iframe.getBoundingClientRect();
					offsetX = iframeRect.left;
					offsetY = iframeRect.top;
				}
			}

			highlightOverlay.style.left = (rect.left + offsetX) + 'px';
			highlightOverlay.style.top = (rect.top + offsetY) + 'px';
			highlightOverlay.style.width = rect.width + 'px';
			highlightOverlay.style.height = rect.height + 'px';
			highlightOverlay.style.display = 'block';
		};

		const removeHighlight = () => {
			if (highlightOverlay) {
				highlightOverlay.remove();
				highlightOverlay = null;
			}
		};

		// Create event handlers
		const handleMainDocumentClick = (event: MouseEvent) => {
			removeHighlight();
			handleElementSelection(event, document);
		};

		const handleMainDocumentMouseOver = (event: MouseEvent) => {
			const element = event.target as Element;
			if (element) updateHighlight(element, document);
		};

		const handleIframeClick = (event: MouseEvent) => {
			const iframe = document.getElementById(
				"main-content-iframe",
			) as HTMLIFrameElement;
			if (iframe && iframe.contentDocument) {
				removeHighlight();
				handleElementSelection(event, iframe.contentDocument);
			}
		};

		const handleIframeMouseOver = (event: MouseEvent) => {
			const iframe = document.getElementById(
				"main-content-iframe",
			) as HTMLIFrameElement;
			if (iframe && iframe.contentDocument) {
				const element = event.target as Element;
				if (element) updateHighlight(element, iframe.contentDocument);
			}
		};

		const handleEscapeKey = (event: KeyboardEvent) => {
			if (event.key === "Escape") {
				removeHighlight();
				cleanup();
			}
		};

		// Add event listeners for element selection on main document
		document.addEventListener("click", handleMainDocumentClick, true);
		document.addEventListener("mouseover", handleMainDocumentMouseOver, true);
		document.addEventListener("keydown", handleEscapeKey, true);

		// Store cleanup function
		cleanupFunctionRef.current = () => {
			removeHighlight();
			document.removeEventListener("click", handleMainDocumentClick, true);
			document.removeEventListener("mouseover", handleMainDocumentMouseOver, true);
			document.removeEventListener("keydown", handleEscapeKey, true);
		};

		// Handle iframe content - try both same-origin and cross-origin approaches
		const iframe = document.getElementById(
			"main-content-iframe",
		) as HTMLIFrameElement;
		if (iframe) {
			try {
				if (iframe.contentDocument) {
					// Same-origin iframe - direct access
					iframe.contentDocument.addEventListener(
						"click",
						handleIframeClick,
						true,
					);
					iframe.contentDocument.addEventListener(
						"mouseover",
						handleIframeMouseOver,
						true,
					);
					iframe.contentDocument.addEventListener(
						"keydown",
						handleEscapeKey,
						true,
					);
					if (iframe.contentDocument.body) {
						iframe.contentDocument.body.style.cursor = "crosshair";
					}

					// Update cleanup function to include iframe listeners
					const originalCleanup = cleanupFunctionRef.current;
					cleanupFunctionRef.current = () => {
						originalCleanup?.();
						if (iframe.contentDocument) {
							iframe.contentDocument.removeEventListener(
								"click",
								handleIframeClick,
								true,
							);
							iframe.contentDocument.removeEventListener(
								"mouseover",
								handleIframeMouseOver,
								true,
							);
							iframe.contentDocument.removeEventListener(
								"keydown",
								handleEscapeKey,
								true,
							);
							if (iframe.contentDocument.body) {
								iframe.contentDocument.body.style.cursor = "default";
							}
						}
					};
				}
			} catch (error) {
				console.warn(
					"Cannot access iframe content directly (cross-origin):",
					error,
				);
			}

			// Only inject script for cross-origin iframes
			// (for same-origin, we use direct event listeners above)
			if (!iframe.contentDocument) {
				// Cross-origin iframe - use message-based approach
				injectSelectorScript(iframe);
				sendMessageToIframe(iframe, { type: "START_ELEMENT_SELECTION" });
			}
		}
	};

	return (
		<>
			<SelectionNotice
				isSelecting={isSelecting && !selectionSuccessful}
				isIframeMode={hasIframe}
				onCancel={cleanup}
			/>
			{selectionSuccessful && (
				<SelectionNotice isSelecting={false} isIframeMode={false} />
			)}
			<button
				onClick={handleButtonClick}
				disabled={disabled}
				title={
					selectedElement && !isSelecting
						? "Clear Selection"
						: isSelecting
							? "Cancel Selection"
							: "Select Element"
				}
				style={{
					width: "28px",
					height: "28px",
					backgroundColor: isSelecting
						? "#ef4444"
						: selectedElement
							? "#10b981"
							: "#6b7280",
					border: "none",
					borderRadius: "4px",
					cursor: disabled ? "not-allowed" : "pointer",
					display: "flex",
					alignItems: "center",
					justifyContent: "center",
					transition: "background-color 0.2s",
				}}
			>
				<TargetIcon width={14} height={14} color="white" />
			</button>
		</>
	);
};

export default SelectElementButton;