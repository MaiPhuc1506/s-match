export interface LlmToolParameterProperty {
  type: 'string' | 'number' | 'integer' | 'boolean' | 'array' | 'object';
  description?: string;
  enum?: string[];
  items?: { type: string };
}

export interface LlmToolDefinition {
  name: string;
  description: string;
  parameters: {
    type: 'object';
    properties: Record<string, LlmToolParameterProperty>;
    required?: string[];
  };
}

export interface LlmToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
  thoughtSignature?: string;
}

export interface LlmMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content?: string;
  toolCalls?: LlmToolCall[];
  toolCallId?: string;
  toolName?: string;
}

export interface LlmGenerateOptions {
  systemPrompt: string;
  messages: LlmMessage[];
  tools: LlmToolDefinition[];
  maxTokens?: number;
  timeoutMs?: number;
  deadlineAt?: number;
  userRole: string;
}

export interface LlmGenerateResult {
  reply?: string;
  toolCalls?: LlmToolCall[];
  providerName: string;
}

export const LLM_PROVIDER = Symbol('LLM_PROVIDER');
export const AI_HTTP_CLIENT = Symbol('AI_HTTP_CLIENT');

export interface LlmProvider {
  readonly name: string;
  generate(options: LlmGenerateOptions): Promise<LlmGenerateResult>;
  formatToolResult?(name: string, data: Record<string, unknown>): string | undefined;
  generateWithLocalFallback?(options: LlmGenerateOptions): Promise<LlmGenerateResult>;
}
