import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AxiosInstance, AxiosResponse } from 'axios';
import { vietnamTime } from '../../bookings/booking-time';
import {
  AI_HTTP_CLIENT,
  LlmGenerateOptions,
  LlmGenerateResult,
  LlmMessage,
  LlmProvider,
  LlmToolCall,
} from '../interfaces/llm-provider.interface';

const PROMPT_INJECTION_PATTERNS = [
  /ignore\s+(all\s+)?(previous|prior|above|system)\s+(instructions|prompts|rules)/i,
  /disregard\s+(all\s+)?(previous|prior|system)\s+(instructions|rules)/i,
  /reveal\s+(your\s+)?(system\s+prompt|api\s+key|secret|jwt|password|token)/i,
  /pretend\s+to\s+be\s+(an?\s+)?(admin|court_owner|owner|another\s+user|root)/i,
  /bypass\s+(rbac|auth|security|guard|permission)/i,
  /execute\s+(raw\s+)?sql/i,
  /\bDROP\s+TABLE\b/i,
  /\bUNION\s+SELECT\b/i,
];

@Injectable()
export class SwappableLlmProvider implements LlmProvider {
  constructor(
    private readonly config: ConfigService,
    @Inject(AI_HTTP_CLIENT) private readonly http: AxiosInstance,
  ) {}

  get name(): string {
    const configured = (this.config.get<string>('AI_PROVIDER') ?? '').trim().toLowerCase();
    const geminiKey = this.config.get<string>('GEMINI_API_KEY')?.trim();
    const openaiKey = this.config.get<string>('OPENAI_API_KEY')?.trim();

    if (configured === 'gemini' && geminiKey) return 'gemini';
    if ((configured === 'openai' || configured === 'openai-compatible') && openaiKey) return 'openai';
    if (!configured && geminiKey) return 'gemini';
    if (!configured && openaiKey) return 'openai';
    return 'local-tool-planner';
  }

  async generate(options: LlmGenerateOptions): Promise<LlmGenerateResult> {
    const provider = this.name;
    if (provider === 'gemini') {
      return this.generateWithGemini(options);
    }
    if (provider === 'openai') {
      return this.generateWithOpenAi(options);
    }
    return this.generateWithLocalPlanner(options);
  }

  async generateWithLocalFallback(options: LlmGenerateOptions): Promise<LlmGenerateResult> {
    return this.generateWithLocalPlanner(options);
  }

  formatToolResult(name: string, data: Record<string, unknown>): string | undefined {
    if (data.error) return this.synthesizeFromToolOutput(name, JSON.stringify(data));
    if (name === 'get_my_bookings' && Array.isArray(data.bookings) &&
        data.bookings.every((b: any) => b.bookingId != null && b.status && b.date && b.startTime && b.endTime && b.totalPriceVnd != null)) {
      return this.synthesizeFromToolOutput(name, JSON.stringify(data));
    }
    if (name === 'search_available_courts' && Array.isArray(data.facilities) &&
        data.facilities.every((f: any) => Array.isArray(f.courts) && f.courts.every((c: any) =>
          !c.sampleAvailableSlots?.length || c.sampleAvailableSlots.every((slot: any) => slot.hourlyRateVnd != null)))) {
      return this.synthesizeFromToolOutput(name, JSON.stringify(data));
    }
    return undefined;
  }

  private async generateWithGemini(options: LlmGenerateOptions): Promise<LlmGenerateResult> {
    const apiKey = this.config.get<string>('GEMINI_API_KEY')?.trim();
    const model = this.config.get<string>('GEMINI_MODEL')?.trim() || 'gemini-3.1-flash-lite';
    const timeoutMs = options.timeoutMs ?? 20000;

    const contents = options.messages
      .filter((m) => m.role !== 'system')
      .map((m) => {
        if (m.role === 'user') {
          return { role: 'user', parts: [{ text: m.content ?? '' }] };
        }
        if (m.role === 'assistant') {
          const parts: any[] = [];
          if (m.content) parts.push({ text: m.content });
          for (const tc of m.toolCalls ?? []) {
            parts.push({ functionCall: { name: tc.name, args: tc.arguments }, ...(tc.thoughtSignature ? { thoughtSignature: tc.thoughtSignature } : {}) });
          }
          return { role: 'model', parts };
        }
        if (m.role === 'tool') {
          let parsed: unknown = {};
          try {
            parsed = m.content ? JSON.parse(m.content) : {};
          } catch {
            parsed = { raw: m.content };
          }
          return {
            role: 'user',
            parts: [
              {
                functionResponse: {
                  name: m.toolName ?? 'tool',
                  response: { result: parsed },
                },
              },
            ],
          };
        }
        return { role: 'user', parts: [{ text: m.content ?? '' }] };
      });

    const payload: Record<string, unknown> = {
      systemInstruction: { parts: [{ text: options.systemPrompt }] },
      contents,
      generationConfig: {
        maxOutputTokens: options.maxTokens ?? 600,
        temperature: 0.1,
      },
    };

    if (options.tools.length > 0) {
      payload.tools = [
        {
          functionDeclarations: options.tools.map((t) => ({
            name: t.name,
            description: t.description,
            parameters: t.parameters,
          })),
        },
      ];
    }

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
      model,
    )}:generateContent`;

    // Each generation stage gets its own bounded timeout and retry budget.
    // Never retry authentication, invalid request, or other permanent failures.
    let res: AxiosResponse | undefined;
    for (let attempt = 0; attempt < 2; attempt++) {
      const remaining = options.deadlineAt ? options.deadlineAt - Date.now() : timeoutMs;
      if (remaining <= 100) throw new Error('Gemini deadline exceeded');
      try {
        res = await this.http.post(url, payload, {
          timeout: Math.max(1, Math.min(timeoutMs, remaining)),
          headers: { 'x-goog-api-key': apiKey! },
        });
        break;
      } catch (error: any) {
        const status = error?.response?.status;
        const transient = status === 429 || status === 503 ||
          (!status && ['ECONNABORTED', 'ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED', 'ENOTFOUND', 'EAI_AGAIN', 'ERR_NETWORK'].includes(error?.code));
        const delay = 300 * 2 ** attempt;
        if (!transient || attempt === 1 || (options.deadlineAt && Date.now() + delay + 500 >= options.deadlineAt)) throw error;
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
    if (!res) throw new Error('Gemini request did not complete');
    const candidate = res.data?.candidates?.[0];
    const parts: any[] = candidate?.content?.parts ?? [];

    const toolCalls: LlmToolCall[] = [];
    const textParts: string[] = [];

    for (const part of parts) {
      if (part.functionCall?.name) {
        toolCalls.push({
          id: `call_${toolCalls.length + 1}`,
          name: String(part.functionCall.name),
          thoughtSignature: typeof part.thoughtSignature === 'string' ? part.thoughtSignature : undefined,
          arguments:
            part.functionCall.args && typeof part.functionCall.args === 'object'
              ? part.functionCall.args
              : {},
        });
      } else if (typeof part.text === 'string') {
        textParts.push(part.text);
      }
    }

    return {
      providerName: 'gemini',
      reply: textParts.join('\n').trim() || undefined,
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
    };
  }

  private async generateWithOpenAi(options: LlmGenerateOptions): Promise<LlmGenerateResult> {
    const apiKey = this.config.get<string>('OPENAI_API_KEY')?.trim();
    const baseUrl =
      this.config.get<string>('OPENAI_BASE_URL')?.trim() || 'https://api.openai.com/v1';
    const model = this.config.get<string>('OPENAI_MODEL')?.trim() || 'gpt-4o-mini';
    const timeoutMs = options.timeoutMs ?? 8000;

    const messages: any[] = [{ role: 'system', content: options.systemPrompt }];

    for (const m of options.messages) {
      if (m.role === 'user') {
        messages.push({ role: 'user', content: m.content ?? '' });
      } else if (m.role === 'assistant') {
        messages.push({
          role: 'assistant',
          content: m.content ?? null,
          ...(m.toolCalls?.length
            ? {
                tool_calls: m.toolCalls.map((tc) => ({
                  id: tc.id,
                  type: 'function',
                  function: { name: tc.name, arguments: JSON.stringify(tc.arguments) },
                })),
              }
            : {}),
        });
      } else if (m.role === 'tool') {
        messages.push({
          role: 'tool',
          tool_call_id: m.toolCallId ?? 'call_1',
          content: m.content ?? '{}',
        });
      }
    }

    const payload: Record<string, unknown> = {
      model,
      messages,
      max_tokens: options.maxTokens ?? 600,
      temperature: 0.1,
    };

    if (options.tools.length > 0) {
      payload.tools = options.tools.map((t) => ({
        type: 'function',
        function: {
          name: t.name,
          description: t.description,
          parameters: t.parameters,
        },
      }));
    }

    const res = await this.http.post(`${baseUrl.replace(/\/$/, '')}/chat/completions`, payload, {
      timeout: timeoutMs,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
    });

    const msg = res.data?.choices?.[0]?.message;
    const rawToolCalls: any[] = msg?.tool_calls ?? [];

    const toolCalls: LlmToolCall[] = rawToolCalls.map((tc, idx) => {
      let parsedArgs: Record<string, unknown> = {};
      try {
        parsedArgs = tc.function?.arguments ? JSON.parse(tc.function.arguments) : {};
      } catch {
        parsedArgs = {};
      }
      return {
        id: String(tc.id ?? `call_${idx + 1}`),
        name: String(tc.function?.name ?? ''),
        arguments: parsedArgs,
      };
    });

    return {
      providerName: 'openai',
      reply: typeof msg?.content === 'string' ? msg.content.trim() : undefined,
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
    };
  }

  /**
   * Deterministic read-only function-calling planner when no external paid API key is configured.
   * Uses real tool calls and formats grounded responses strictly from tool outputs (never fabricates data).
   */
  private async generateWithLocalPlanner(options: LlmGenerateOptions): Promise<LlmGenerateResult> {
    const lastMessage = options.messages[options.messages.length - 1];

    // If last message is a tool response, synthesize a grounded natural language answer from the real tool data
    if (lastMessage?.role === 'tool') {
      return {
        providerName: 'local-tool-planner',
        reply: this.synthesizeFromToolOutput(lastMessage.toolName ?? '', lastMessage.content ?? '{}'),
      };
    }

    const userText = (lastMessage?.content ?? '').trim();
    const historyUsers = options.messages
      .filter((m) => m.role === 'user' && m !== lastMessage)
      .map((m) => m.content ?? '');

    // 1. Prompt Injection / Jailbreak defense
    if (PROMPT_INJECTION_PATTERNS.some((re) => re.test(userText))) {
      return {
        providerName: 'local-tool-planner',
        reply:
          'I am Smash Scot, the read-only S-Match badminton assistant. I cannot bypass security rules, reveal internal prompts or secrets, or impersonate another role.',
      };
    }

    // 2. Mutation / Write attempt defense (strictly read-only)
    if (
      /\b(book\s+a\s+court|create\s+(a\s+)?booking|cancel\s+(my\s+)?booking|delete\s+facility|update\s+price|change\s+weight|modify\s+database|reserve\s+for\s+me)\b/i.test(
        userText,
      )
    ) {
      return {
        providerName: 'local-tool-planner',
        reply:
          'I am a read-only assistant and cannot create, modify, or cancel bookings or change system data. Please use the Booking or Facility screens in the S-Match app to make changes.',
      };
    }

    const lower = userText.toLowerCase();
    const combinedContext = [...historyUsers, userText].join(' ');

    // 3. Detect Owner Analytics / Revenue intent
    if (
      /\b(revenue|analytics|doanh\s*thu|occupancy|utilization|owner\s+stats|facility\s+stats|earned|income|công\s*suất|thống\s*kê)\b/i.test(
        lower,
      )
    ) {
      const args: Record<string, unknown> = {};
      const facMatch = combinedContext.match(/\bfacility\s*(?:id|#)?\s*(\d+)\b/i);
      if (facMatch) {
        args.facilityId = Number(facMatch[1]);
      }
      const dateMatches = combinedContext.match(/\b(202\d-\d{2}-\d{2})\b/g);
      if (dateMatches && dateMatches.length >= 2) {
        args.from = dateMatches[0];
        args.to = dateMatches[1];
      } else if (dateMatches && dateMatches.length === 1) {
        args.from = dateMatches[0];
        args.to = dateMatches[0];
      }
      return {
        providerName: 'local-tool-planner',
        toolCalls: [{ id: 'call_1', name: 'get_owner_analytics', arguments: args }],
      };
    }

    // 4. Detect My Bookings intent
    if (
      /\b(my\s+bookings?|my\s+reservations?|my\s+schedule|check\s+my\s+bookings?|lịch\s+đặt\s+sân|đơn\s+đặt\s+sân)\b/i.test(
        lower,
      )
    ) {
      const args: Record<string, unknown> = {};
      if (/\bcancelled\b/i.test(lower)) args.status = 'CANCELLED';
      else if (/\bcompleted\b/i.test(lower)) args.status = 'COMPLETED';
      else if (/\bpending\b/i.test(lower)) args.status = 'PENDING';
      else if (/\bconfirmed\b/i.test(lower)) args.status = 'CONFIRMED';
      if (/\bupcoming\b/i.test(lower)) args.upcomingOnly = true;
      return {
        providerName: 'local-tool-planner',
        toolCalls: [{ id: 'call_1', name: 'get_my_bookings', arguments: args }],
      };
    }

    // 5. Detect Player Recommendation / Matchmaking intent
    if (
      /\b(recommend\s+players?|find\s+players?|player\s+insights?|matchmaking|partner|opponent|tìm\s+người\s+chơi|gợi\s+ý\s+người\s+chơi|compatibility)\b/i.test(
        lower,
      )
    ) {
      const args: Record<string, unknown> = {};
      const kmMatch = combinedContext.match(/(\d+(?:\.\d+)?)\s*km\b/i);
      if (kmMatch) args.maxDistanceKm = Number(kmMatch[1]);

      if (/\bbeginner\b/i.test(combinedContext)) {
        args.minSkillLevel = 1;
        args.maxSkillLevel = 2;
      } else if (/\bintermediate\b/i.test(combinedContext)) {
        args.minSkillLevel = 3;
        args.maxSkillLevel = 4;
      } else if (/\badvanced\b/i.test(combinedContext)) {
        args.minSkillLevel = 5;
        args.maxSkillLevel = 5;
      }

      const styles: string[] = [];
      if (/\b(attack|offensive)\b/i.test(combinedContext)) styles.push('Attack');
      if (/\b(defense|defensive)\b/i.test(combinedContext)) styles.push('Defense');
      if (/\bbalanced\b/i.test(combinedContext)) styles.push('Balanced');
      if (styles.length > 0) args.playingStyles = styles;

      return {
        providerName: 'local-tool-planner',
        toolCalls: [{ id: 'call_1', name: 'recommend_players', arguments: args }],
      };
    }

    // 6. Detect Court Search / Availability / Budget intent (including multi-turn follow-ups)
    if (
      /\b(court|courts|facility|facilities|slot|available|availability|price|budget|vnd|indoor|outdoor|hai\s+chau|son\s+tra|thanh\s+khe|ngu\s+hanh\s+son|lien\s+chieu|cam\s+le|sân|giá)\b/i.test(
        combinedContext,
      )
    ) {
      const args = this.extractCourtSearchArgs(userText, combinedContext);
      return {
        providerName: 'local-tool-planner',
        toolCalls: [{ id: 'call_1', name: 'search_available_courts', arguments: args }],
      };
    }

    return {
      providerName: 'local-tool-planner',
      reply:
        'Hi! I am Smash Scot 🏸. I can help you with:\n• Searching available courts & prices in Da Nang\n• Checking your bookings\n• Recommending compatible badminton players (5-factor matchmaking)\n• Viewing facility analytics & revenue (for Court Owners)',
    };
  }

  private extractCourtSearchArgs(currentText: string, combinedText: string): Record<string, unknown> {
    const args: Record<string, unknown> = {};

    // District / Keyword
    const districts = [
      'Hai Chau',
      'Son Tra',
      'Thanh Khe',
      'Ngu Hanh Son',
      'Lien Chieu',
      'Cam Le',
      'Hoa Vang',
    ];
    for (const d of districts) {
      if (new RegExp(`\\b${d.replace(/\s+/g, '\\s+')}\\b`, 'i').test(combinedText)) {
        args.districtOrKeyword = d;
        break;
      }
    }

    // Court Type
    if (/\bindoor\b/i.test(combinedText)) args.courtType = 'INDOOR';
    else if (/\boutdoor\b/i.test(combinedText)) args.courtType = 'OUTDOOR';

    // Budget / Max Price (e.g., "under 120000", "120k", "100,000 VND")
    const kMatch = combinedText.match(/\b(?:under|below|max|<=?|budget)?\s*(\d{2,3})\s*k\b/i);
    const vndMatch = combinedText.match(
      /\b(?:under|below|max|<=?|budget)\s*(\d{2,3}[,.]?\d{3})\b/i,
    );
    if (kMatch) {
      args.maxPriceVnd = Number(kMatch[1]) * 1000;
    } else if (vndMatch) {
      args.maxPriceVnd = Number(vndMatch[1].replace(/[,.]/g, ''));
    }

    // Date (explicit YYYY-MM-DD, or "today", "tomorrow")
    const explicitDate = combinedText.match(/\b(202\d-\d{2}-\d{2})\b/);
    const nowVn = vietnamTime(new Date());
    if (explicitDate) {
      args.date = explicitDate[1];
    } else if (/\btomorrow\b|ngày\s+mai/i.test(combinedText)) {
      const tomorrow = new Date(Date.now() + 86400000);
      args.date = vietnamTime(tomorrow).date;
    } else if (/\btoday\b|tonight\b|hôm\s+nay|tối\s+nay/i.test(combinedText)) {
      args.date = nowVn.date;
    }

    // Time range (e.g. "18:00 to 20:00", "18:00-20:00", "at 18:00", "evening", "morning")
    const rangeMatch = combinedText.match(/\b([01]?\d|2[0-3]):([0-5]\d)\s*(?:to|-|–)\s*([01]?\d|2[0-4]):([0-5]\d)\b/i);
    const singleTimeMatch = combinedText.match(/\b(?:at|from|after)\s+([01]?\d|2[0-3]):([0-5]\d)\b/i);
    if (rangeMatch) {
      args.startTimeFrom = `${rangeMatch[1].padStart(2, '0')}:${rangeMatch[2]}`;
      args.endTimeTo = `${rangeMatch[3].padStart(2, '0')}:${rangeMatch[4]}`;
    } else if (singleTimeMatch) {
      const h = Number(singleTimeMatch[1]);
      args.startTimeFrom = `${String(h).padStart(2, '0')}:${singleTimeMatch[2]}`;
      args.endTimeTo = `${String(Math.min(24, h + 2)).padStart(2, '0')}:${singleTimeMatch[2]}`;
    } else if (/\bevening\b|tonight\b|buổi\s+tối/i.test(combinedText)) {
      args.startTimeFrom = '17:00';
      args.endTimeTo = '22:00';
    } else if (/\bmorning\b|buổi\s+sáng/i.test(combinedText)) {
      args.startTimeFrom = '06:00';
      args.endTimeTo = '12:00';
    }

    const facMatch = currentText.match(/\bfacility\s*(?:id|#)?\s*(\d+)\b/i);
    if (facMatch) {
      args.facilityId = Number(facMatch[1]);
    }

    return args;
  }

  private synthesizeFromToolOutput(toolName: string, rawJson: string): string {
    let data: any;
    try {
      data = JSON.parse(rawJson);
    } catch {
      return 'Unable to parse tool response.';
    }

    if (data?.error) {
      return `I could not complete that request: ${data.error}`;
    }

    switch (toolName) {
      case 'search_available_courts': {
        const facilities: any[] = data.facilities ?? [];
        if (facilities.length === 0) {
          return 'No matching courts or available time slots were found for your criteria.';
        }
        const lines = facilities.map((f) => {
          const courtSummaries = (f.courts ?? []).map((c: any) => {
            if (c.sampleAvailableSlots?.length) {
              const slots = c.sampleAvailableSlots
                .slice(0, 3)
                .map((s: any) => `${s.startTime}-${s.endTime} (${s.hourlyRateVnd ?? s.slotPriceVnd ?? 'N/A'} VND/h)`)
                .join(', ');
              return `${c.courtName} (${c.courtType}): ${slots}`;
            }
            const priceText =
              c.minPriceVnd != null ? `from ${c.minPriceVnd} VND` : 'pricing per schedule';
            return `${c.courtName} (${c.courtType}, ${priceText})`;
          });
          return `• ${f.name} (${f.address}): ${courtSummaries.join('; ')}`;
        });
        return `Found ${data.totalMatchingFacilities} matching facility(s):\n${lines.join('\n')}`;
      }

      case 'get_my_bookings': {
        const bookings: any[] = data.bookings ?? [];
        if (bookings.length === 0) {
          return 'You have no bookings matching that filter.';
        }
        const lines = bookings.map(
          (b) =>
            `• Booking #${b.bookingId} [${b.status}]: ${b.facilityName ?? 'Facility'} - ${b.courtName ?? 'Court'} on ${b.date} (${b.startTime}–${b.endTime}), Total: ${b.totalPriceVnd} VND`,
        );
        return `You have ${data.totalMatchingBookings} booking(s):\n${lines.join('\n')}`;
      }

      case 'recommend_players': {
        if (data.status === 'LOCATION_REQUIRED' || data.status === 'AVAILABILITY_REQUIRED') {
          return data.message;
        }
        const recs: any[] = data.recommendations ?? [];
        if (recs.length === 0) {
          return 'No compatible players were found within your radius and time slots right now.';
        }
        const lines = recs.map((r) => {
          const dist = r.distanceKm != null ? `, ~${r.distanceKm} km away` : '';
          const score = r.matchScore != null ? ` — Match Score: ${r.matchScore}%` : '';
          const level = r.skillLevel ? ` (${r.skillLevel})` : '';
          return `• ${r.displayName}${level}${score}${dist}`;
        });
        return `Recommended badminton players for you:\n${lines.join('\n')}`;
      }

      case 'get_owner_analytics': {
        const range = data.range ? `${data.range.from} to ${data.range.to}` : 'selected period';
        const occ =
          data.occupancyRate != null ? `${(Number(data.occupancyRate) * 100).toFixed(1)}%` : 'N/A';
        return (
          `Owner Analytics (${range}):\n` +
          `• Gross Booked Revenue: ${data.grossBookedRevenueVnd ?? 0} VND\n` +
          `• Total Bookings: ${data.totalBookings ?? 0} (Confirmed/Completed: ${data.confirmedBookings ?? 0})\n` +
          `• Booked Hours: ${data.bookedHours ?? 0} / ${data.availableHours ?? 0} hrs (Occupancy: ${occ})`
        );
      }

      default:
        return 'Here is the information from S-Match.';
    }
  }
}
