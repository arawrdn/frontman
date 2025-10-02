import type React from "react";

interface ProposalDiffProps {
	diff: string;
}

const ProposalDiff: React.FC<ProposalDiffProps> = ({ diff }) => {
	const lines = diff.split("\n");

	return (
		<div
			style={{
				backgroundColor: "#1f2937",
				borderRadius: "4px",
				padding: "8px",
				marginTop: "8px",
				fontFamily: "Monaco, Consolas, monospace",
				fontSize: "11px",
				lineHeight: "1.4",
				overflow: "auto",
				maxHeight: "400px",
			}}
		>
			{lines.map((line, idx) => {
				let backgroundColor = "transparent";
				let color = "#e5e7eb";

				if (line.startsWith("---") || line.startsWith("+++")) {
					// File headers
					color = "#9ca3af";
					backgroundColor = "#111827";
				} else if (line.startsWith("@@")) {
					// Hunk headers
					color = "#60a5fa";
					backgroundColor = "#1e3a8a";
				} else if (line.startsWith("+")) {
					// Additions
					color = "#86efac";
					backgroundColor = "#064e3b";
				} else if (line.startsWith("-")) {
					// Deletions
					color = "#fca5a5";
					backgroundColor = "#7f1d1d";
				}

				return (
					<div
						key={idx}
						style={{
							backgroundColor,
							color,
							padding: "2px 4px",
							whiteSpace: "pre",
						}}
					>
						{line || " "}
					</div>
				);
			})}
		</div>
	);
};

export default ProposalDiff;
