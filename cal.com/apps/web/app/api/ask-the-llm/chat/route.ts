import * as fs from "node:fs";
import path from "node:path";
import { defaultResponderForAppDir } from "app/api/defaultResponderForAppDir";
import { glob } from "glob";
import { type NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";
import { z } from "zod";
import DiffMatchPatch from "diff-match-patch";

// Types for the request
const ChatRequestSchema = z.object({
	messages: z.array(z.string()),
	selectedElement: z
		.object({
			sourceLocation: z
				.object({
					file: z.string(),
					line: z.number(),
				})
				.optional(),
			selector: z.string().optional(),
			componentName: z.string().optional(),
		})
		.optional(),
});

// Tool implementations
async function executeReadFile(filePath: string): Promise<string> {
	try {
		// Security check - only allow reading files within the project
		const projectRoot = process.cwd();
		const resolvedPath = path.resolve(projectRoot, filePath);

		if (!resolvedPath.startsWith(projectRoot)) {
			throw new Error(
				"Access denied: Cannot read files outside project directory",
			);
		}

		const content = await fs.promises.readFile(resolvedPath, "utf-8");
		return `File content of ${filePath}:\n\`\`\`\n${content}\n\`\`\``;
	} catch (error) {
		return `Error reading file ${filePath}: ${error instanceof Error ? error.message : String(error)}`;
	}
}

async function executeSearchFiles(
	pattern: string,
	directory = ".",
): Promise<string> {
	try {
		const projectRoot = process.cwd();
		const searchDir = path.resolve(projectRoot, directory);

		if (!searchDir.startsWith(projectRoot)) {
			throw new Error("Access denied: Cannot search outside project directory");
		}

		const files = await glob(pattern, {
			cwd: searchDir,
			ignore: ["**/node_modules/**", "**/dist/**", "**/.git/**", "**/build/**"],
		});

		if (files.length === 0) {
			return `No files found matching pattern "${pattern}" in directory "${directory}"`;
		}

		return `Found ${files.length} files matching "${pattern}":\n${files
			.slice(0, 20)
			.map((f) => `- ${f}`)
			.join(
				"\n",
			)}${files.length > 20 ? `\n... and ${files.length - 20} more files` : ""}`;
	} catch (error) {
		return `Error searching files: ${error instanceof Error ? error.message : String(error)}`;
	}
}

async function executeListFolder(folderPath: string): Promise<string> {
	try {
		const projectRoot = process.cwd();
		const resolvedPath = path.resolve(projectRoot, folderPath);

		if (!resolvedPath.startsWith(projectRoot)) {
			throw new Error(
				"Access denied: Cannot list folders outside project directory",
			);
		}

		const items = await fs.promises.readdir(resolvedPath, {
			withFileTypes: true,
		});
		const folders = items
			.filter((item) => item.isDirectory())
			.map((item) => `📁 ${item.name}/`);
		const files = items
			.filter((item) => item.isFile())
			.map((item) => `📄 ${item.name}`);

		return `Contents of ${folderPath}:\n${[...folders, ...files].join("\n")}`;
	} catch (error) {
		return `Error listing folder ${folderPath}: ${error instanceof Error ? error.message : String(error)}`;
	}
}

async function executeApplyPatch(
	filePath: string,
	patch: string,
	description: string,
): Promise<string> {
	try {
		const projectRoot = process.cwd();
		const resolvedPath = path.resolve(projectRoot, filePath);

		if (!resolvedPath.startsWith(projectRoot)) {
			throw new Error(
				"Access denied: Cannot modify files outside project directory",
			);
		}

		// Apply patch (simple replacement for now - could be enhanced with proper diff/patch logic)
		const newContent = patch;

		// Write the new content
		await fs.promises.writeFile(resolvedPath, newContent, "utf-8");

		return `Successfully applied patch to ${filePath}. ${description}`;
	} catch (error) {
		return `Error applying patch to ${filePath}: ${error instanceof Error ? error.message : String(error)}`;
	}
}

// Generate unified diff string from current and proposed content
function generateUnifiedDiff(
	currentContent: string,
	proposedContent: string,
	filePath: string,
): string {
	const dmp = new DiffMatchPatch();
	const diffs = dmp.diff_main(currentContent, proposedContent);
	dmp.diff_cleanupSemantic(diffs);

	// Convert to unified diff format
	const lines: string[] = [`--- ${filePath}`, `+++ ${filePath}`];
	let currentLine = 1;
	let proposedLine = 1;

	// Group changes into hunks
	let hunkLines: string[] = [];
	let hunkStart = 1;

	for (const [operation, text] of diffs) {
		const textLines = text.split("\n");
		// Remove last empty line from split
		if (textLines[textLines.length - 1] === "") {
			textLines.pop();
		}

		if (operation === 0) {
			// Equal - context lines
			for (const line of textLines) {
				hunkLines.push(` ${line}`);
				currentLine++;
				proposedLine++;
			}
		} else if (operation === -1) {
			// Deletion
			for (const line of textLines) {
				hunkLines.push(`-${line}`);
				currentLine++;
			}
		} else if (operation === 1) {
			// Insertion
			for (const line of textLines) {
				hunkLines.push(`+${line}`);
				proposedLine++;
			}
		}
	}

	// Add hunk header and lines
	if (hunkLines.length > 0) {
		const hunkHeader = `@@ -${hunkStart},${currentLine - 1} +${hunkStart},${proposedLine - 1} @@`;
		lines.push(hunkHeader);
		lines.push(...hunkLines);
	}

	return lines.join("\n");
}

async function executeProposeChange(
	filePath: string,
	proposedContent: string,
	description: string,
	changeType: string = "modify",
): Promise<string> {
	try {
		// Security check - reuse same pattern as apply_patch
		const projectRoot = process.cwd();
		const resolvedPath = path.resolve(projectRoot, filePath);

		if (!resolvedPath.startsWith(projectRoot)) {
			throw new Error(
				"Access denied: Cannot access files outside project directory",
			);
		}

		// Read current content
		let currentContent = "";
		let exists = true;
		try {
			currentContent = await fs.promises.readFile(resolvedPath, "utf-8");
		} catch {
			exists = false;
			currentContent = "";
		}

		// Generate simple diff summary
		const currentLines = currentContent.split("\n").length;
		const proposedLines = proposedContent.split("\n").length;
		const lineDiff = proposedLines - currentLines;

		// Determine actual change type
		const actualChangeType = exists ? changeType : "create";

		// Generate unified diff for visualization
		const unifiedDiff = generateUnifiedDiff(
			currentContent,
			proposedContent,
			filePath,
		);

		// Return structured proposal data as JSON
		const proposal = {
			filePath,
			description,
			changeType: actualChangeType,
			currentExists: exists,
			currentLines,
			proposedLines,
			lineDiff,
			// Full content for applying the change
			proposedContent,
			// Diff string for visualization
			diff: unifiedDiff,
			// Preview for LLM context (keep short)
			preview: {
				currentContent: currentContent.substring(0, 500),
				proposedContent: proposedContent.substring(0, 500),
			},
		};

		return JSON.stringify(proposal, null, 2);
	} catch (error) {
		return `Error proposing change to ${filePath}: ${error instanceof Error ? error.message : String(error)}`;
	}
}

// Task classification types
interface TaskClassification {
	type: "i18n_change" | "component_modification" | "feature_addition" | "refactor" | "bug_fix" | "other";
	complexity: "simple" | "medium" | "complex";
	requiredFiles: string[];
	strategy: string[];
	successCriteria: string;
	estimatedIterations: number;
}

// System prompt for task classification
const TASK_CLASSIFIER_PROMPT = `You are a task classification expert. Analyze the user's request and classify it.

Return a JSON object with:
{
  "type": "i18n_change" | "component_modification" | "feature_addition" | "refactor" | "bug_fix" | "other",
  "complexity": "simple" | "medium" | "complex",
  "requiredFiles": ["list", "of", "files", "to", "examine"],
  "strategy": ["step 1", "step 2", "step 3"],
  "successCriteria": "how to know the task is complete",
  "estimatedIterations": <number between 5 and 25>
}

Examples:

User: "Change email label to 'Email'"
Response: {
  "type": "i18n_change",
  "complexity": "simple",
  "requiredFiles": ["component with email field", "apps/web/public/static/locales/en/common.json"],
  "strategy": ["Read component to find i18n key", "Read translation file", "Modify translation value"],
  "successCriteria": "Translation file updated with new value",
  "estimatedIterations": 6
}

User: "Add phone validation to signup form"
Response: {
  "type": "feature_addition",
  "complexity": "medium",
  "requiredFiles": ["signup form component", "validation utilities", "i18n files"],
  "strategy": ["Read signup form", "Add phone field component", "Add validation logic", "Add i18n keys"],
  "successCriteria": "Phone field with validation in signup form",
  "estimatedIterations": 12
}

Classify this request and respond with ONLY the JSON object:`;

// Base system prompt
const BASE_SYSTEM_PROMPT = `You are an AI coding assistant for Cal.com (Next.js 15/React/TypeScript monorepo).

## Key Patterns:
- **i18n**: UI text uses t("key") from apps/web/public/static/locales/en/common.json
- **Forms**: @calcom/ui components (TextField, EmailField, PasswordField) with react-hook-form
- **Files**: All paths relative to monorepo root (process.cwd())

## CRITICAL Rules:
- **ALWAYS use propose_change for code modifications** (shows diff with Accept/Reject buttons)
- **NEVER call apply_patch** (auto-called when user clicks Accept)
- **UI text changes** → Edit translation files, NOT component files
- **Be concise** → No long explanations, bullet points, or verbose formatting

You have limited iterations. Make every tool call count.`;

// Task-specific prompt additions
const TASK_SPECIFIC_PROMPTS = {
	i18n_change: `
## i18n Change Strategy:
1. **MUST read component file** to find the t("key") being used
2. **MUST read translation file** (apps/web/public/static/locales/en/common.json)
3. **MUST modify translation VALUE**, not the key reference
4. Verify other components don't break from this change`,

	component_modification: `
## Component Modification Strategy:
1. Read the target component file
2. Understand component hierarchy and props
3. Check for related components that might be affected
4. Consider type updates if needed`,

	feature_addition: `
## Feature Addition Strategy:
1. Understand existing patterns in codebase
2. Identify all files that need changes (component, types, i18n, validation)
3. Follow Cal.com conventions
4. Propose changes in logical order`,

	refactor: `
## Refactoring Strategy:
1. Read current implementation thoroughly
2. Identify all usages before changing
3. Ensure backwards compatibility
4. Propose changes incrementally`,

	bug_fix: `
## Bug Fix Strategy:
1. Understand the bug's root cause
2. Read relevant code to understand current behavior
3. Identify minimal fix
4. Consider edge cases`,

	other: `
## General Strategy:
1. Understand the request thoroughly
2. Read relevant files
3. Propose clear, focused changes`
};

function buildSystemPrompt(classification: TaskClassification): string {
	const taskSpecific = TASK_SPECIFIC_PROMPTS[classification.type] || TASK_SPECIFIC_PROMPTS.other;

	return `${BASE_SYSTEM_PROMPT}

## Your Task Classification:
- **Type**: ${classification.type}
- **Complexity**: ${classification.complexity}
- **Success Criteria**: ${classification.successCriteria}

${taskSpecific}

## Execution Strategy:
${classification.strategy.map((step, i) => `${i + 1}. ${step}`).join('\n')}

## Required Files to Examine:
${classification.requiredFiles.map(f => `- ${f}`).join('\n')}

Focus on achieving the success criteria efficiently.`;
}

async function handleStreamingRequest(
	_req: NextRequest,
	{ messages, selectedElement }: { messages: string[]; selectedElement?: any },
): Promise<NextResponse> {
	console.log("[Chat API] Starting streaming handler");
	const encoder = new TextEncoder();

	const stream = new ReadableStream({
		async start(controller) {
			try {
				console.log("[Chat API] Stream started");
				// Initialize OpenAI client
				const openai = new OpenAI({
					apiKey: process.env.OPENAI_API_KEY,
				});

				// Step 1: Classify the task
				controller.enqueue(
					encoder.encode(
						`data: ${JSON.stringify({
							type: "status",
							message: "Analyzing task...",
						})}\n\n`,
					),
				);

				const userRequest = messages[messages.length - 1] || "No request provided";
				const classificationMessages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
					{ role: "system", content: TASK_CLASSIFIER_PROMPT },
					{ role: "user", content: userRequest }
				];

				const classificationResponse = await openai.chat.completions.create({
					model: "gpt-5",
					messages: classificationMessages,
					response_format: { type: "json_object" }
				});

				let classification: TaskClassification;
				try {
					classification = JSON.parse(classificationResponse.choices[0]?.message?.content || "{}");
				} catch {
					// Fallback if parsing fails
					classification = {
						type: "other",
						complexity: "medium",
						requiredFiles: [],
						strategy: ["Analyze request", "Read relevant files", "Propose changes"],
						successCriteria: "User request fulfilled",
						estimatedIterations: 10
					};
				}

				// Step 2: Display strategy to user
				controller.enqueue(
					encoder.encode(
						`data: ${JSON.stringify({
							type: "strategy",
							classification: classification,
							message: `**Task Type**: ${classification.type}\n**Complexity**: ${classification.complexity}\n\n**Strategy**:\n${classification.strategy.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n\n**Success Criteria**: ${classification.successCriteria}`
						})}\n\n`,
					),
				);

				// Step 3: Build dynamic system prompt based on classification
				const SYSTEM_PROMPT = buildSystemPrompt(classification);

				// Build the conversation context
				const conversationHistory: OpenAI.Chat.Completions.ChatCompletionMessageParam[] =
					[{ role: "system", content: SYSTEM_PROMPT }];

				// Add element context if available
				if (selectedElement) {
					let contextMessage = "Element context: ";

					if (selectedElement.sourceLocation) {
						contextMessage += `I'm working on file "${selectedElement.sourceLocation.file}" at line ${selectedElement.sourceLocation.line}.`;
					} else {
						contextMessage += "I'm working on an element";
						if (selectedElement.componentName) {
							contextMessage += ` (React component: ${selectedElement.componentName})`;
						}
						if (selectedElement.selector) {
							contextMessage += ` with selector: ${selectedElement.selector}`;
						}
						contextMessage += ".";
					}

					conversationHistory.push({
						role: "user",
						content: contextMessage,
					});
				}

				// Add user messages
				messages.forEach((message, index) => {
					conversationHistory.push({
						role: index % 2 === 0 ? "user" : "assistant",
						content: message,
					});
				});

				// Define tools for OpenAI function calling
				const tools: OpenAI.Chat.Completions.ChatCompletionTool[] = [
					{
						type: "function",
						function: {
							name: "read_file",
							description: "Read the contents of a file",
							parameters: {
								type: "object",
								properties: {
									filePath: {
										type: "string",
										description: "Path to the file to read",
									},
								},
								required: ["filePath"],
							},
						},
					},
					{
						type: "function",
						function: {
							name: "search_files",
							description: "Search for files matching a pattern",
							parameters: {
								type: "object",
								properties: {
									pattern: {
										type: "string",
										description: "Glob pattern to search for files",
									},
									directory: {
										type: "string",
										description:
											"Directory to search in (optional, defaults to current directory)",
									},
								},
								required: ["pattern"],
							},
						},
					},
					{
						type: "function",
						function: {
							name: "list_folder",
							description: "List contents of a directory",
							parameters: {
								type: "object",
								properties: {
									folderPath: {
										type: "string",
										description: "Path to the folder to list",
									},
								},
								required: ["folderPath"],
							},
						},
					},
					{
						type: "function",
						function: {
							name: "apply_patch",
							description: "Apply code changes to a file",
							parameters: {
								type: "object",
								properties: {
									filePath: {
										type: "string",
										description: "Path to the file to modify",
									},
									patch: {
										type: "string",
										description: "New content for the file",
									},
									description: {
										type: "string",
										description: "Description of the changes being made",
									},
								},
								required: ["filePath", "patch", "description"],
							},
						},
					},
					{
						type: "function",
						function: {
							name: "propose_change",
							description:
								"Propose a code change to a file without applying it. Returns a detailed proposal for user review. Use this tool when suggesting code modifications.",
							parameters: {
								type: "object",
								properties: {
									filePath: {
										type: "string",
										description: "Path to the file to modify",
									},
									proposedContent: {
										type: "string",
										description: "The proposed new content for the file",
									},
									description: {
										type: "string",
										description:
											"Description of what changes are being made and why",
									},
									changeType: {
										type: "string",
										enum: ["create", "modify", "delete"],
										description: "Type of change being proposed (optional)",
									},
								},
								required: ["filePath", "proposedContent", "description"],
							},
						},
					},
				];

				// Send initial status
				controller.enqueue(
					encoder.encode(
						`data: ${JSON.stringify({
							type: "status",
							message: "Starting analysis...",
						})}\n\n`,
					),
				);

				// Agent loop - continue until no more tool calls are needed
				const maxIterations = classification.estimatedIterations;
				let currentIteration = 0;
				let finalResponse = "";
				let hasCalledProposeChange = false;

				// Task types that require code modifications
				const modificationTaskTypes = ["i18n_change", "component_modification", "feature_addition", "refactor", "bug_fix"];
				const requiresModification = modificationTaskTypes.includes(classification.type);

				while (currentIteration < maxIterations) {
					currentIteration++;

					// Send iteration status with progress
					const progress = Math.round((currentIteration / maxIterations) * 100);
					controller.enqueue(
						encoder.encode(
							`data: ${JSON.stringify({
								type: "status",
								message: `Iteration ${currentIteration}/${maxIterations} (${progress}%)...`,
								progress: progress
							})}\n\n`,
						),
					);

					// Force propose_change if this is a modification task and we're running out of iterations
					const shouldForcePropose = requiresModification &&
					                           !hasCalledProposeChange &&
					                           currentIteration >= maxIterations - 2;

					let toolChoice: "auto" | { type: "function"; function: { name: string } } = "auto";

					if (shouldForcePropose) {
						toolChoice = { type: "function", function: { name: "propose_change" } };
						controller.enqueue(
							encoder.encode(
								`data: ${JSON.stringify({
									type: "status",
									message: "Preparing code changes...",
								})}\n\n`,
							),
						);
						console.log(`[API DEBUG] Forcing propose_change on iteration ${currentIteration} for task type: ${classification.type}`);
					}

					// Call OpenAI with function calling
					const completion = await openai.chat.completions.create({
						model: "gpt-5",
						messages: conversationHistory,
						tools: tools,
						tool_choice: toolChoice,
					});

					const message = completion.choices[0]?.message;
					if (!message) {
						throw new Error("No response from OpenAI");
					}

					// Add assistant's response to conversation history
					conversationHistory.push(message);

					// Check if there are tool calls to execute
					if (message.tool_calls && message.tool_calls.length > 0) {
						// Send tool execution status
						controller.enqueue(
							encoder.encode(
								`data: ${JSON.stringify({
									type: "tool_start",
									message: `Executing ${message.tool_calls.length} tools...`,
									tools: message.tool_calls.map((tc) => ({
										name: tc.function.name,
										parameters: JSON.parse(tc.function.arguments),
									})),
								})}\n\n`,
							),
						);

						const toolResults = await Promise.all(
							message.tool_calls.map(async (toolCall) => {
								const { name, arguments: args } = toolCall.function;
								const parsedArgs = JSON.parse(args);

								// Track if propose_change was called
								if (name === "propose_change") {
									hasCalledProposeChange = true;
								}

								// Send individual tool execution
								controller.enqueue(
									encoder.encode(
										`data: ${JSON.stringify({
											type: "tool_executing",
											tool: name,
											parameters: parsedArgs,
										})}\n\n`,
									),
								);

								let result: string;
								const startTime = Date.now();

								switch (name) {
									case "read_file":
										result = await executeReadFile(parsedArgs.filePath);
										break;
									case "search_files":
										result = await executeSearchFiles(
											parsedArgs.pattern,
											parsedArgs.directory,
										);
										break;
									case "list_folder":
										result = await executeListFolder(parsedArgs.folderPath);
										break;
									case "apply_patch":
										result = await executeApplyPatch(
											parsedArgs.filePath,
											parsedArgs.patch,
											parsedArgs.description,
										);
										break;
									case "propose_change":
										result = await executeProposeChange(
											parsedArgs.filePath,
											parsedArgs.proposedContent,
											parsedArgs.description,
											parsedArgs.changeType,
										);
										break;
									default:
										result = `Unknown tool: ${name}`;
								}

								const executionTime = Date.now() - startTime;

								// Send tool completion
								const resultToSend =
									// Don't truncate propose_change results - client needs full JSON for parsing
									name === "propose_change"
										? result
										: result.length > 200
											? result.substring(0, 200) + "..."
											: result;

								console.log("[API DEBUG] Sending tool_completed event:", {
									tool: name,
									resultLength: result.length,
									truncated: name !== "propose_change" && result.length > 200,
									resultPreview: result.substring(0, 100),
									sending: resultToSend.length,
								});

								controller.enqueue(
									encoder.encode(
										`data: ${JSON.stringify({
											type: "tool_completed",
											tool: name,
											parameters: parsedArgs,
											result: resultToSend,
											executionTime,
										})}\n\n`,
									),
								);

								return {
									tool_call_id: toolCall.id,
									role: "tool" as const,
									content: result.length > 1000 ? result.substring(0, 1000) + `\n\n[... truncated ${result.length - 1000} characters ...]` : result,
								};
							}),
						);

						// Add tool results to conversation history
						conversationHistory.push(...toolResults);

						// If this is the last iteration, force a final response
						if (currentIteration >= maxIterations) {
							conversationHistory.push({
								role: "user",
								content:
									"Please provide a final response based on the information gathered. Do not make any more tool calls.",
							});

							const finalCompletion = await openai.chat.completions.create({
								model: "gpt-5",
								messages: conversationHistory,
								tools: [], // No tools available to force a text response
							});

							finalResponse =
								finalCompletion.choices[0]?.message?.content ||
								"I've completed the analysis but couldn't generate a final response.";
							break;
						}
					} else {
						// No more tool calls - check if we achieved the goal
						finalResponse = message.content || "No response content";

						// Goal achievement check
						if (finalResponse.toLowerCase().includes("proposed") ||
						    finalResponse.toLowerCase().includes("changed") ||
						    finalResponse.toLowerCase().includes("complete")) {
							controller.enqueue(
								encoder.encode(
									`data: ${JSON.stringify({
										type: "status",
										message: "✓ Goal achieved",
									})}\n\n`,
								),
							);
						}
						break;
					}
				}

				// Fallback if we still don't have a response
				if (!finalResponse) {
					finalResponse =
						"I've gathered information but reached the maximum number of iterations. Please try rephrasing your request.";
				}

				// Send final response
				controller.enqueue(
					encoder.encode(
						`data: ${JSON.stringify({
							type: "final_response",
							response: finalResponse,
							iterations: currentIteration,
						})}\n\n`,
					),
				);

				// Send completion signal
				controller.enqueue(
					encoder.encode(
						`data: ${JSON.stringify({
							type: "complete",
						})}\n\n`,
					),
				);

				controller.close();
			} catch (error) {
				console.error("Streaming chat API error:", error);
				controller.enqueue(
					encoder.encode(
						`data: ${JSON.stringify({
							type: "error",
							error: error instanceof Error ? error.message : String(error),
						})}\n\n`,
					),
				);
				controller.close();
			}
		},
	});

	return new NextResponse(stream, {
		headers: {
			"Content-Type": "text/event-stream",
			"Cache-Control": "no-cache",
			Connection: "keep-alive",
		},
	});
}

async function handleChatRequest(req: NextRequest): Promise<NextResponse> {
	try {
		const body = await req.json();
		console.log(
			"[Chat API] Received request body:",
			JSON.stringify(body, null, 2),
		);

		const { messages, selectedElement } = ChatRequestSchema.parse(body);

		console.log("[Chat API] Parsed selectedElement:", selectedElement);
		console.log("[Chat API] Using streaming handler");

		return handleStreamingRequest(req, { messages, selectedElement });
	} catch (error) {
		console.error("Chat API error:", error);
		return NextResponse.json(
			{
				error: "Internal server error",
				details: error instanceof Error ? error.message : String(error),
			},
			{ status: 500 },
		);
	}
}

export const POST = defaultResponderForAppDir(handleChatRequest);
