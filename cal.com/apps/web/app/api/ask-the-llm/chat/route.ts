import { defaultResponderForAppDir } from "app/api/defaultResponderForAppDir";
import { NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";
import { z } from "zod";
import { promises as fs } from "fs";
import path from "path";
import { glob } from "glob";

// Types for the request
const ChatRequestSchema = z.object({
  messages: z.array(z.string()),
  selectedElement: z.object({
    sourceLocation: z.object({
      file: z.string(),
      line: z.number(),
    }).optional(),
    selector: z.string().optional(),
    componentName: z.string().optional(),
  }).optional(),
});

// Tool calling schemas
const ReadFileToolSchema = z.object({
  type: z.literal("read_file"),
  parameters: z.object({
    filePath: z.string(),
  }),
});

const SearchFilesToolSchema = z.object({
  type: z.literal("search_files"),
  parameters: z.object({
    pattern: z.string(),
    directory: z.string().optional(),
  }),
});

const ListFolderToolSchema = z.object({
  type: z.literal("list_folder"),
  parameters: z.object({
    folderPath: z.string(),
  }),
});

const ApplyPatchToolSchema = z.object({
  type: z.literal("apply_patch"),
  parameters: z.object({
    filePath: z.string(),
    patch: z.string(),
    description: z.string(),
  }),
});

const ToolCallSchema = z.union([
  ReadFileToolSchema,
  SearchFilesToolSchema,
  ListFolderToolSchema,
  ApplyPatchToolSchema,
]);

// Tool implementations
async function executeReadFile(filePath: string): Promise<string> {
  try {
    // Security check - only allow reading files within the project
    const projectRoot = process.cwd();
    const resolvedPath = path.resolve(projectRoot, filePath);
    
    if (!resolvedPath.startsWith(projectRoot)) {
      throw new Error("Access denied: Cannot read files outside project directory");
    }

    const content = await fs.readFile(resolvedPath, "utf-8");
    return `File content of ${filePath}:\n\`\`\`\n${content}\n\`\`\``;
  } catch (error) {
    return `Error reading file ${filePath}: ${error instanceof Error ? error.message : String(error)}`;
  }
}

async function executeSearchFiles(pattern: string, directory = "."): Promise<string> {
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
    
    return `Found ${files.length} files matching "${pattern}":\n${files.slice(0, 20).map(f => `- ${f}`).join("\n")}${files.length > 20 ? `\n... and ${files.length - 20} more files` : ""}`;
  } catch (error) {
    return `Error searching files: ${error instanceof Error ? error.message : String(error)}`;
  }
}

async function executeListFolder(folderPath: string): Promise<string> {
  try {
    const projectRoot = process.cwd();
    const resolvedPath = path.resolve(projectRoot, folderPath);
    
    if (!resolvedPath.startsWith(projectRoot)) {
      throw new Error("Access denied: Cannot list folders outside project directory");
    }

    const items = await fs.readdir(resolvedPath, { withFileTypes: true });
    const folders = items.filter(item => item.isDirectory()).map(item => `📁 ${item.name}/`);
    const files = items.filter(item => item.isFile()).map(item => `📄 ${item.name}`);
    
    return `Contents of ${folderPath}:\n${[...folders, ...files].join("\n")}`;
  } catch (error) {
    return `Error listing folder ${folderPath}: ${error instanceof Error ? error.message : String(error)}`;
  }
}

async function executeApplyPatch(filePath: string, patch: string, description: string): Promise<string> {
  try {
    const projectRoot = process.cwd();
    const resolvedPath = path.resolve(projectRoot, filePath);
    
    if (!resolvedPath.startsWith(projectRoot)) {
      throw new Error("Access denied: Cannot modify files outside project directory");
    }

    // Read current file content
    let currentContent = "";
    try {
      currentContent = await fs.readFile(resolvedPath, "utf-8");
    } catch {
      // File doesn't exist, will create new file
    }

    // Apply patch (simple replacement for now - could be enhanced with proper diff/patch logic)
    const newContent = patch;
    
    // Write the new content
    await fs.writeFile(resolvedPath, newContent, "utf-8");
    
    return `Successfully applied patch to ${filePath}. ${description}`;
  } catch (error) {
    return `Error applying patch to ${filePath}: ${error instanceof Error ? error.message : String(error)}`;
  }
}

async function executeTool(toolCall: z.infer<typeof ToolCallSchema>): Promise<string> {
  switch (toolCall.type) {
    case "read_file":
      return executeReadFile(toolCall.parameters.filePath);
    case "search_files":
      return executeSearchFiles(toolCall.parameters.pattern, toolCall.parameters.directory);
    case "list_folder":
      return executeListFolder(toolCall.parameters.folderPath);
    case "apply_patch":
      return executeApplyPatch(
        toolCall.parameters.filePath,
        toolCall.parameters.patch,
        toolCall.parameters.description
      );
    default:
      return "Unknown tool type";
  }
}

// System prompt for the AI agent
const SYSTEM_PROMPT = `You are an AI coding assistant that helps users make changes to their codebase with precise source location context. Your purpose is to:

1. Analyze code and understand the current project structure
2. Help users implement features, fix bugs, and refactor code
3. Use source location information (file path and line number) to understand exactly where the user is working
4. Make precise and safe code changes

Available tools:
- read_file: Read the contents of a file
- search_files: Search for files matching a pattern
- list_folder: List contents of a directory
- apply_patch: Apply code changes to a file

Guidelines:
- Always understand the current code before making changes
- When provided with source location context (file and line number), focus your analysis and changes around that specific location
- Make minimal, focused changes
- Explain your reasoning for each change
- Ensure code quality and follow existing patterns
- Be careful with file operations and validate paths
- Use the exact file path and line number information to provide targeted assistance

When the user provides source location context, prioritize reading that specific file and understanding the code around the specified line number.`;

async function handleStreamingRequest(
  req: NextRequest, 
  { messages, selectedElement }: { messages: string[], selectedElement?: any }
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

        // Build the conversation context
        let conversationHistory: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
          { role: "system", content: SYSTEM_PROMPT },
        ];

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
                    description: "Directory to search in (optional, defaults to current directory)",
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
        ];

        // Send initial status
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          type: 'status',
          message: 'Starting analysis...'
        })}\n\n`));

        // Agent loop - continue until no more tool calls are needed
        let maxIterations = 5;
        let currentIteration = 0;
        let finalResponse = "";

        while (currentIteration < maxIterations) {
          currentIteration++;

          // Send iteration status
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({
            type: 'status',
            message: `Iteration ${currentIteration}/${maxIterations}...`
          })}\n\n`));

          // Call OpenAI with function calling
          const completion = await openai.chat.completions.create({
            model: "gpt-5",
            messages: conversationHistory,
            tools: tools,
            tool_choice: "auto",
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
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({
              type: 'tool_start',
              message: `Executing ${message.tool_calls.length} tools...`,
              tools: message.tool_calls.map(tc => ({ name: tc.function.name, parameters: JSON.parse(tc.function.arguments) }))
            })}\n\n`));

            const toolResults = await Promise.all(
              message.tool_calls.map(async (toolCall) => {
                const { name, arguments: args } = toolCall.function;
                const parsedArgs = JSON.parse(args);
                
                // Send individual tool execution
                controller.enqueue(encoder.encode(`data: ${JSON.stringify({
                  type: 'tool_executing',
                  tool: name,
                  parameters: parsedArgs
                })}\n\n`));
                
                let result: string;
                const startTime = Date.now();
                
                switch (name) {
                  case "read_file":
                    result = await executeReadFile(parsedArgs.filePath);
                    break;
                  case "search_files":
                    result = await executeSearchFiles(parsedArgs.pattern, parsedArgs.directory);
                    break;
                  case "list_folder":
                    result = await executeListFolder(parsedArgs.folderPath);
                    break;
                  case "apply_patch":
                    result = await executeApplyPatch(parsedArgs.filePath, parsedArgs.patch, parsedArgs.description);
                    break;
                  default:
                    result = `Unknown tool: ${name}`;
                }

                const executionTime = Date.now() - startTime;
                
                // Send tool completion
                controller.enqueue(encoder.encode(`data: ${JSON.stringify({
                  type: 'tool_completed',
                  tool: name,
                  parameters: parsedArgs,
                  result: result.length > 200 ? result.substring(0, 200) + "..." : result,
                  executionTime
                })}\n\n`));

                return {
                  tool_call_id: toolCall.id,
                  role: "tool" as const,
                  content: result,
                };
              })
            );

            // Add tool results to conversation history
            conversationHistory.push(...toolResults);

            // If this is the last iteration, force a final response
            if (currentIteration >= maxIterations) {
              conversationHistory.push({
                role: "user",
                content: "Please provide a final response based on the information gathered. Do not make any more tool calls.",
              });

              const finalCompletion = await openai.chat.completions.create({
                model: "gpt-5",
                messages: conversationHistory,
                tools: [], // No tools available to force a text response
              });

              finalResponse = finalCompletion.choices[0]?.message?.content || "I've completed the analysis but couldn't generate a final response.";
              break;
            }
          } else {
            // No more tool calls, we have the final response
            finalResponse = message.content || "No response content";
            break;
          }
        }

        // Fallback if we still don't have a response
        if (!finalResponse) {
          finalResponse = "I've gathered information but reached the maximum number of iterations. Please try rephrasing your request.";
        }

        // Send final response
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          type: 'final_response',
          response: finalResponse,
          iterations: currentIteration
        })}\n\n`));

        // Send completion signal
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          type: 'complete'
        })}\n\n`));

        controller.close();

      } catch (error) {
        console.error("Streaming chat API error:", error);
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          type: 'error',
          error: error instanceof Error ? error.message : String(error)
        })}\n\n`));
        controller.close();
      }
    }
  });

  return new NextResponse(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}

async function handleChatRequest(req: NextRequest): Promise<NextResponse> {
  try {
    const body = await req.json();
    console.log("[Chat API] Received request body:", JSON.stringify(body, null, 2));
    
    const { messages, selectedElement } = ChatRequestSchema.parse(body);
    
    console.log("[Chat API] Parsed selectedElement:", selectedElement);
<<<<<<< HEAD

    // Check if client wants streaming
    const acceptHeader = req.headers.get('accept');
    const streamHeader = req.headers.get('x-stream-request');
    const isStreaming = acceptHeader === 'text/event-stream' || streamHeader === 'true';
    
    console.log("[Chat API] Accept header:", acceptHeader);
    console.log("[Chat API] Stream header:", streamHeader);
    console.log("[Chat API] Is streaming:", isStreaming);
    
    if (isStreaming) {
      console.log("[Chat API] Using streaming handler");
      return handleStreamingRequest(req, { messages, selectedElement });
    }
    
    console.log("[Chat API] Using non-streaming handler");
=======
>>>>>>> e42543244 (try to use sourceLocation)

    // Check if client wants streaming
    const acceptHeader = req.headers.get('accept');
    const streamHeader = req.headers.get('x-stream-request');
    const isStreaming = acceptHeader === 'text/event-stream' || streamHeader === 'true';
    
    console.log("[Chat API] Accept header:", acceptHeader);
    console.log("[Chat API] Stream header:", streamHeader);
    console.log("[Chat API] Is streaming:", isStreaming);
    
    if (isStreaming) {
      console.log("[Chat API] Using streaming handler");
      return handleStreamingRequest(req, { messages, selectedElement });
    }
    
    console.log("[Chat API] Using non-streaming handler");

    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    // Build the conversation context
    let conversationHistory: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
      { role: "system", content: SYSTEM_PROMPT },
    ];

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
      
      console.log("[Chat API] Adding element context:", contextMessage);
      
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
                description: "Directory to search in (optional, defaults to current directory)",
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
    ];

    // Agent loop - continue until no more tool calls are needed
    let maxIterations = 5;
    let currentIteration = 0;
    let finalResponse = "";
    let allToolCalls: Array<{
      tool: string;
      parameters: any;
      result: string;
    }> = [];

    while (currentIteration < maxIterations) {
      currentIteration++;

      // Call OpenAI with function calling
      const completion = await openai.chat.completions.create({
        model: "gpt-5",
        messages: conversationHistory,
        tools: tools,
        tool_choice: "auto",
      });

      const message = completion.choices[0]?.message;
      if (!message) {
        throw new Error("No response from OpenAI");
      }

      // Add assistant's response to conversation history
      conversationHistory.push(message);

<<<<<<< HEAD
        // Check if there are tool calls to execute
        if (message.tool_calls && message.tool_calls.length > 0) {
          console.log(`[Chat API] Executing ${message.tool_calls.length} tool calls in iteration ${currentIteration}`);
          
          const toolResults = await Promise.all(
            message.tool_calls.map(async (toolCall) => {
              const { name, arguments: args } = toolCall.function;
              const parsedArgs = JSON.parse(args);
              
              console.log(`[Chat API] Executing tool: ${name}`, parsedArgs);
              
              let result: string;
              const startTime = Date.now();
              
              switch (name) {
                case "read_file":
                  result = await executeReadFile(parsedArgs.filePath);
                  break;
                case "search_files":
                  result = await executeSearchFiles(parsedArgs.pattern, parsedArgs.directory);
                  break;
                case "list_folder":
                  result = await executeListFolder(parsedArgs.folderPath);
                  break;
                case "apply_patch":
                  result = await executeApplyPatch(parsedArgs.filePath, parsedArgs.patch, parsedArgs.description);
                  break;
                default:
                  result = `Unknown tool: ${name}`;
              }

              const executionTime = Date.now() - startTime;
              console.log(`[Chat API] Tool ${name} completed in ${executionTime}ms`);
              
              // Store tool call info for response
              allToolCalls.push({
                tool: name,
                parameters: parsedArgs,
                result: result.length > 500 ? result.substring(0, 500) + "..." : result,
              });

              return {
                tool_call_id: toolCall.id,
                role: "tool" as const,
                content: result,
              };
            })
          );
=======
      // Check if there are tool calls to execute
      if (message.tool_calls && message.tool_calls.length > 0) {
        console.log(`[Chat API] Executing ${message.tool_calls.length} tool calls in iteration ${currentIteration}`);
        
        const toolResults = await Promise.all(
          message.tool_calls.map(async (toolCall) => {
            const { name, arguments: args } = toolCall.function;
            const parsedArgs = JSON.parse(args);
            
            console.log(`[Chat API] Executing tool: ${name}`, parsedArgs);
            
            let result: string;
            const startTime = Date.now();
            
            switch (name) {
              case "read_file":
                result = await executeReadFile(parsedArgs.filePath);
                break;
              case "search_files":
                result = await executeSearchFiles(parsedArgs.pattern, parsedArgs.directory);
                break;
              case "list_folder":
                result = await executeListFolder(parsedArgs.folderPath);
                break;
              case "apply_patch":
                result = await executeApplyPatch(parsedArgs.filePath, parsedArgs.patch, parsedArgs.description);
                break;
              default:
                result = `Unknown tool: ${name}`;
            }

            const executionTime = Date.now() - startTime;
            console.log(`[Chat API] Tool ${name} completed in ${executionTime}ms`);
            
            // Store tool call info for response
            allToolCalls.push({
              tool: name,
              parameters: parsedArgs,
              result: result.length > 500 ? result.substring(0, 500) + "..." : result,
            });

            return {
              tool_call_id: toolCall.id,
              role: "tool" as const,
              content: result,
            };
          })
        );
>>>>>>> e42543244 (try to use sourceLocation)

        // Add tool results to conversation history
        conversationHistory.push(...toolResults);

        // If this is the last iteration, force a final response
        if (currentIteration >= maxIterations) {
          conversationHistory.push({
            role: "user",
            content: "Please provide a final response based on the information gathered. Do not make any more tool calls.",
          });

          const finalCompletion = await openai.chat.completions.create({
            model: "gpt-5",
            messages: conversationHistory,
            tools: [], // No tools available to force a text response
          });

          finalResponse = finalCompletion.choices[0]?.message?.content || "I've completed the analysis but couldn't generate a final response.";
          break;
        }
      } else {
        // No more tool calls, we have the final response
        finalResponse = message.content || "No response content";
        break;
      }
    }

    // Fallback if we still don't have a response
    if (!finalResponse) {
      finalResponse = "I've gathered information but reached the maximum number of iterations. Please try rephrasing your request.";
    }

    console.log(`[Chat API] Request completed after ${currentIteration} iterations with ${allToolCalls.length} total tool calls`);

    return NextResponse.json({
      response: finalResponse,
      status: "completed",
      iterations: currentIteration,
      toolCalls: allToolCalls,
    });

  } catch (error) {
    console.error("Chat API error:", error);
    return NextResponse.json(
      { error: "Internal server error", details: error instanceof Error ? error.message : String(error) },
      { status: 500 }
    );
  }
}

export const POST = defaultResponderForAppDir(handleChatRequest);
