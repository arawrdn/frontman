import type React from "react";
import { useState } from "react";
import ProposalDiff from "./ProposalDiff";
import type { ProposalState } from "../SplitLayoutWidget";

interface ProposalCardProps {
	proposalState: ProposalState;
	onAccept: () => Promise<void>;
	onReject: () => void;
}

const ProposalCard: React.FC<ProposalCardProps> = ({
	proposalState,
	onAccept,
	onReject,
}) => {
	const { proposal, status, errorMessage } = proposalState;
	const [isApplying, setIsApplying] = useState(false);

	const handleAccept = async () => {
		setIsApplying(true);
		try {
			await onAccept();
		} finally {
			setIsApplying(false);
		}
	};

	return (
		<div
			style={{
				backgroundColor: "#111827",
				borderRadius: "6px",
				padding: "12px",
				marginTop: "8px",
				border: "1px solid #374151",
			}}
		>
			{/* Header */}
			<div
				style={{
					display: "flex",
					justifyContent: "space-between",
					alignItems: "center",
					marginBottom: "8px",
				}}
			>
				<div>
					<div
						style={{
							fontSize: "12px",
							fontWeight: "600",
							color: "#f3f4f6",
							fontFamily: "Monaco, Consolas, monospace",
						}}
					>
						{proposal.changeType === "create" ? "Create" : "Modify"}{" "}
						{proposal.filePath}
					</div>
					<div
						style={{
							fontSize: "11px",
							color: "#9ca3af",
							marginTop: "2px",
						}}
					>
						{proposal.description}
					</div>
				</div>

				{/* Status badge */}
				{status === "accepted" && (
					<span
						style={{
							fontSize: "11px",
							color: "#86efac",
							fontWeight: "500",
						}}
					>
						✓ Applied
					</span>
				)}
				{status === "rejected" && (
					<span
						style={{
							fontSize: "11px",
							color: "#9ca3af",
							fontWeight: "500",
						}}
					>
						Rejected
					</span>
				)}
			</div>

			{/* Line count summary */}
			<div style={{ fontSize: "10px", color: "#6b7280", marginBottom: "8px" }}>
				{proposal.currentExists
					? `${proposal.currentLines} → ${proposal.proposedLines} lines (${proposal.lineDiff >= 0 ? "+" : ""}${proposal.lineDiff})`
					: `New file, ${proposal.proposedLines} lines`}
			</div>

			{/* Diff display */}
			<ProposalDiff diff={proposal.diff} />

			{/* Error message */}
			{status === "error" && errorMessage && (
				<div
					style={{
						marginTop: "8px",
						padding: "8px",
						backgroundColor: "#7f1d1d",
						color: "#fca5a5",
						borderRadius: "4px",
						fontSize: "11px",
					}}
				>
					⚠️ {errorMessage}
				</div>
			)}

			{/* Action buttons */}
			{status === "pending" && (
				<div
					style={{
						display: "flex",
						gap: "8px",
						marginTop: "12px",
						justifyContent: "flex-end",
					}}
				>
					<button
						onClick={onReject}
						disabled={isApplying}
						style={{
							background: "none",
							border: "1px solid #6b7280",
							color: "#9ca3af",
							padding: "4px 12px",
							borderRadius: "4px",
							fontSize: "11px",
							cursor: isApplying ? "not-allowed" : "pointer",
							transition: "all 0.2s",
							opacity: isApplying ? 0.5 : 1,
						}}
						onMouseEnter={(e) => {
							if (!isApplying) {
								e.currentTarget.style.backgroundColor = "#374151";
								e.currentTarget.style.color = "white";
							}
						}}
						onMouseLeave={(e) => {
							e.currentTarget.style.backgroundColor = "transparent";
							e.currentTarget.style.color = "#9ca3af";
						}}
					>
						Reject
					</button>
					<button
						onClick={handleAccept}
						disabled={isApplying}
						style={{
							backgroundColor: isApplying ? "#6b7280" : "#10b981",
							border: "none",
							color: "white",
							padding: "4px 12px",
							borderRadius: "4px",
							fontSize: "11px",
							fontWeight: "500",
							cursor: isApplying ? "not-allowed" : "pointer",
							transition: "all 0.2s",
						}}
						onMouseEnter={(e) => {
							if (!isApplying) {
								e.currentTarget.style.backgroundColor = "#059669";
							}
						}}
						onMouseLeave={(e) => {
							if (!isApplying) {
								e.currentTarget.style.backgroundColor = "#10b981";
							}
						}}
					>
						{isApplying ? "Applying..." : "Accept"}
					</button>
				</div>
			)}

			{/* Retry button for errors */}
			{status === "error" && (
				<div
					style={{
						display: "flex",
						gap: "8px",
						marginTop: "12px",
						justifyContent: "flex-end",
					}}
				>
					<button
						onClick={handleAccept}
						style={{
							backgroundColor: "#3b82f6",
							border: "none",
							color: "white",
							padding: "4px 12px",
							borderRadius: "4px",
							fontSize: "11px",
							fontWeight: "500",
							cursor: "pointer",
							transition: "all 0.2s",
						}}
						onMouseEnter={(e) => {
							e.currentTarget.style.backgroundColor = "#2563eb";
						}}
						onMouseLeave={(e) => {
							e.currentTarget.style.backgroundColor = "#3b82f6";
						}}
					>
						Retry
					</button>
				</div>
			)}
		</div>
	);
};

export default ProposalCard;
