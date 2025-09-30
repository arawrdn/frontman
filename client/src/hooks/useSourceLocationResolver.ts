import { useCallback } from "react";
import type { SourceLocationState } from "../types/SelectElement";
import { mapToOriginalSource } from "../utils/sourceMapResolver";

interface UseSourceLocationResolverResult {
	resolveSourceLocation: (compiledLocation: {
		fileName: string;
		lineNumber: number;
		columnNumber: number;
	}) => Promise<SourceLocationState>;
}

/**
 * Hook for resolving compiled locations to original source locations
 */
export function useSourceLocationResolver(): UseSourceLocationResolverResult {
	const resolveSourceLocation = useCallback(
		async (compiledLocation: {
			fileName: string;
			lineNumber: number;
			columnNumber: number;
		}): Promise<SourceLocationState> => {
			const originalLocation = (await mapToOriginalSource(compiledLocation))!;

			return {
				status: "resolved",
				file: originalLocation.source,
				line: originalLocation.line,
			};
		},
		[],
	);

	return { resolveSourceLocation };
}
