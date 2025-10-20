// Message types mirroring Agent__Task__Message.res structure
// ReScript variant types are serialized with TAG and _0 fields

// ============ Role ============

export type MessageRole = 'user' | 'agent' | 'assistant' | 'system' | 'tool';

// ============ Internal part types ============

interface TextPartData {
  text: string;
  metadata?: Record<string, unknown>;
}

interface MessageFile {
  name?: string;
  mimeType: string;
  bytes: string; // base64 encoded
}

interface FilePartData {
  file: MessageFile;
  metadata?: Record<string, unknown>;
}

interface DataPartData {
  data: unknown;
  metadata?: Record<string, unknown>;
}

interface ToolUsePartData {
  toolCallId: string;
  toolName: string;
  args: unknown;
  metadata?: Record<string, unknown>;
}

interface ToolResultPartData {
  toolCallId: string;
  toolName: string;
  result: unknown;
  metadata?: Record<string, unknown>;
}

// ============ ReScript variant representation ============
// These match how ReScript serializes variant types

export type MessagePart = 
  | { TAG: 'text'; _0: TextPartData }
  | { TAG: 'file'; _0: FilePartData }
  | { TAG: 'data'; _0: DataPartData }
  | { TAG: 'toolUse'; _0: ToolUsePartData }
  | { TAG: 'toolResult'; _0: ToolResultPartData };

// ============ Normalized types for easier consumption ============

export interface TextPart {
  type: 'text';
  text: string;
  metadata?: Record<string, unknown>;
}

export interface FilePart {
  type: 'file';
  file: MessageFile;
  metadata?: Record<string, unknown>;
}

export interface DataPart {
  type: 'data';
  data: unknown;
  metadata?: Record<string, unknown>;
}

export interface ToolUsePart {
  type: 'toolUse';
  toolCallId: string;
  toolName: string;
  args: unknown;
  metadata?: Record<string, unknown>;
}

export interface ToolResultPart {
  type: 'toolResult';
  toolCallId: string;
  toolName: string;
  result: unknown;
  metadata?: Record<string, unknown>;
}

export type NormalizedPart = 
  | TextPart 
  | FilePart 
  | DataPart 
  | ToolUsePart 
  | ToolResultPart;

// ============ Message ============

// ReScript IDs are also serialized with TAG and _0
interface IdType {
  TAG: 'id';
  _0: string;
}

export interface Message {
  role: MessageRole;
  parts: MessagePart[];
  messageId?: IdType;
  taskId?: IdType;
  metadata?: Record<string, unknown>;
}

// ============ Normalization helpers ============

export function normalizeId(id: IdType | string | undefined | null): string {
  if (!id) {
    console.warn('[normalizeId] Received undefined/null id, generating fallback');
    return `fallback-${Date.now()}-${Math.random()}`;
  }
  if (typeof id === 'string') {
    return id;
  }
  if (id._0) {
    return id._0;
  }
  console.warn('[normalizeId] ID object has no _0 property:', id);
  return `fallback-${Date.now()}-${Math.random()}`;
}

export function normalizePart(part: MessagePart): NormalizedPart {
  switch (part.TAG) {
    case 'text':
      return {
        type: 'text',
        text: part._0.text,
        metadata: part._0.metadata,
      };
    case 'file':
      return {
        type: 'file',
        file: part._0.file,
        metadata: part._0.metadata,
      };
    case 'data':
      return {
        type: 'data',
        data: part._0.data,
        metadata: part._0.metadata,
      };
    case 'toolUse':
      return {
        type: 'toolUse',
        toolCallId: part._0.toolCallId,
        toolName: part._0.toolName,
        args: part._0.args,
        metadata: part._0.metadata,
      };
    case 'toolResult':
      return {
        type: 'toolResult',
        toolCallId: part._0.toolCallId,
        toolName: part._0.toolName,
        result: part._0.result,
        metadata: part._0.metadata,
      };
  }
}

// ============ Helper constructors ============

export const createTextPart = (
  text: string, 
  metadata?: Record<string, unknown>
): TextPart => ({
  type: 'text',
  text,
  metadata,
});

export const createFilePart = (
  file: MessageFile, 
  metadata?: Record<string, unknown>
): FilePart => ({
  type: 'file',
  file,
  metadata,
});

export const createDataPart = (
  data: unknown, 
  metadata?: Record<string, unknown>
): DataPart => ({
  type: 'data',
  data,
  metadata,
});

export const createToolUsePart = (
  toolCallId: string,
  toolName: string,
  args: unknown,
  metadata?: Record<string, unknown>
): ToolUsePart => ({
  type: 'toolUse',
  toolCallId,
  toolName,
  args,
  metadata,
});

export const createToolResultPart = (
  toolCallId: string,
  toolName: string,
  result: unknown,
  metadata?: Record<string, unknown>
): ToolResultPart => ({
  type: 'toolResult',
  toolCallId,
  toolName,
  result,
  metadata,
});

// ============ Type guards ============

export const isTextPart = (part: NormalizedPart): part is TextPart => 
  part.type === 'text';

export const isFilePart = (part: NormalizedPart): part is FilePart => 
  part.type === 'file';

export const isDataPart = (part: NormalizedPart): part is DataPart => 
  part.type === 'data';

export const isToolUsePart = (part: NormalizedPart): part is ToolUsePart => 
  part.type === 'toolUse';

export const isToolResultPart = (part: NormalizedPart): part is ToolResultPart => 
  part.type === 'toolResult';

