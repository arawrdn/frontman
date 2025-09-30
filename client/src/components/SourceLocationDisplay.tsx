import { ReloadIcon } from "@radix-ui/react-icons";
import type React from "react";
import type { SourceLocationState } from "../types/SelectElement";

interface SourceLocationDisplayProps {
	sourceLocation: SourceLocationState;
	compact?: boolean;
}

const SourceLocationDisplay: React.FC<SourceLocationDisplayProps> = ({
	sourceLocation,
	compact = false,
}) => {
	switch (sourceLocation.status) {
		case "loading":
			return (
				<div
					style={{
						display: "flex",
						alignItems: "center",
						gap: "6px",
						color: "#6b7280",
						fontSize: compact ? "11px" : "12px",
						fontStyle: "italic",
					}}
				>
					<ReloadIcon
						width={12}
						height={12}
						style={{
							animation: "spin 1s linear infinite",
						}}
					/>
					<span>Resolving source location...</span>
				</div>
			);

		case "resolved":
			return (
				<div
					style={{
						display: "flex",
						alignItems: "flex-start",
						gap: "4px",
						color: "#10b981",
						fontSize: compact ? "11px" : "12px",
						fontFamily: "monospace",
						cursor: "pointer",
					}}
					onClick={() => {
						const text = `${sourceLocation.file}:${sourceLocation.line}`;
						navigator.clipboard.writeText(text);
					}}
					title={`${sourceLocation.file}:${sourceLocation.line} (click to copy)`}
				>
					<span style={{ color: "#6b7280", flexShrink: 0 }}>📍</span>
					<span
						style={{
							wordBreak: "break-all",
						}}
					>
						{sourceLocation.file}:{sourceLocation.line}
					</span>
				</div>
			);

		case "error":
			return (
				<div
					style={{
						color: "#ef4444",
						fontSize: compact ? "11px" : "12px",
						fontStyle: "italic",
					}}
				>
					⚠️ {sourceLocation.message}
				</div>
			);

		case "unavailable":
			return (
				<div
					style={{
						color: "#9ca3af",
						fontSize: compact ? "11px" : "12px",
						fontStyle: "italic",
					}}
				>
					Source location unavailable
				</div>
			);
	}
};

export default SourceLocationDisplay;
