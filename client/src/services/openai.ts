// Types for OpenAI /v1/responses API
export interface OpenAIRequest {
  model: string;
  input: string;
  max_output_tokens?: number;
  temperature?: number;
}

export interface OpenAIResponse {
  id: string;
  object: string;
  created_at: number;
  status: string;
  model: string;
  output: Array<{
    type: string;
    content: Array<{
      type: string;
      text: string;
    }>;
  }>;
  usage: {
    input_tokens: number;
    output_tokens: number;
    total_tokens: number;
  };
}

export interface OpenAIErrorResponse {
  error: {
    message: string;
    type: string;
    code?: string;
  };
}

export enum OpenAIErrorType {
  AUTHENTICATION = 'authentication',
  RATE_LIMIT = 'rate_limit',
  NETWORK = 'network',
  TIMEOUT = 'timeout',
  UNKNOWN = 'unknown'
}

export class OpenAIError extends Error {
  public type: OpenAIErrorType;
  public statusCode?: number;

  constructor(message: string, type: OpenAIErrorType, statusCode?: number) {
    super(message);
    this.type = type;
    this.statusCode = statusCode;
    this.name = 'OpenAIError';
  }

  static fromResponse(status: number, data: unknown): OpenAIError {
    if (status === 401) {
      return new OpenAIError('Invalid API key', OpenAIErrorType.AUTHENTICATION, status);
    }
    if (status === 429) {
      return new OpenAIError('Rate limit exceeded', OpenAIErrorType.RATE_LIMIT, status);
    }
    const errorMessage = (data as OpenAIErrorResponse)?.error?.message || 'API request failed';
    return new OpenAIError(errorMessage, OpenAIErrorType.UNKNOWN, status);
  }
}

// Simple fetch-based client
export class OpenAIClient {
  private apiKey: string;
  private baseURL: string = 'https://api.openai.com/v1';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async createResponse(request: OpenAIRequest): Promise<OpenAIResponse> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout

    try {
      const response = await fetch(`${this.baseURL}/responses`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify(request),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData: OpenAIErrorResponse = await response.json();
        throw OpenAIError.fromResponse(response.status, errorData);
      }

      return await response.json();
    } catch (error) {
      clearTimeout(timeoutId);
      if (error instanceof OpenAIError) {
        throw error;
      }
      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          throw new OpenAIError('Request timed out', OpenAIErrorType.TIMEOUT);
        }
        if (error.message.includes('fetch')) {
          throw new OpenAIError('Network error occurred', OpenAIErrorType.NETWORK);
        }
        throw new OpenAIError(error.message, OpenAIErrorType.UNKNOWN);
      }
      throw new OpenAIError('Unknown error occurred', OpenAIErrorType.UNKNOWN);
    }
  }
}

// Environment validation
export function validateEnvironment(): { isValid: boolean; message?: string } {
  const apiKey = import.meta.env.VITE_OPENAI_API_KEY;

  if (!apiKey) {
    return {
      isValid: false,
      message: 'OpenAI API key not found. Please set VITE_OPENAI_API_KEY in your environment variables.'
    };
  }

  if (!apiKey.startsWith('sk-')) {
    return {
      isValid: false,
      message: 'Invalid OpenAI API key format. Key should start with "sk-".'
    };
  }

  return { isValid: true };
}

// Factory function for client creation
export function createOpenAIClient(): OpenAIClient {
  const validation = validateEnvironment();
  if (!validation.isValid) {
    throw new OpenAIError(validation.message || 'Environment validation failed', OpenAIErrorType.AUTHENTICATION);
  }

  const apiKey = import.meta.env.VITE_OPENAI_API_KEY;
  return new OpenAIClient(apiKey);
}